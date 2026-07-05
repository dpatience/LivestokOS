defmodule LivestokOs.AI.ConsultSession do
  @moduledoc """
  Multi-turn conversational interface for vet consults about a specific cow.

  Each session is a GenServer registered via `LivestokOs.AI.SessionRegistry`,
  started on demand through `LivestokOs.AI.SessionSupervisor` (DynamicSupervisor),
  and keyed by `{cow_id, user_id, session_id}`.

  ## Context Window Management

  - The last 10 turns are kept in full in the prompt.
  - Older turns are summarized into a single "conversation so far" block (via
    LLM summarization or simple concatenation of key points).
  - Total prompt size target: stay under 100k tokens (for GPT-4o context window).

  ## Session Lifecycle

  Sessions terminate automatically after `@idle_timeout_ms` (default 30 min)
  of inactivity. The GenServer uses `handle_info(:timeout, ...)` to self-terminate.
  """
  use GenServer

  require Logger

  alias LivestokOs.AI.{CaseHistoryFormatter, Grounding, LLMConfig, LocalResponder, Retrieval}

  @idle_timeout_ms 30 * 60 * 1_000
  @max_full_turns 10

  # ---- Public API ----

  def start_session(cow_id, farm_id, user_id) do
    session_id = generate_session_id()
    name = via(cow_id, user_id, session_id)

    state = %{
      session_id: session_id,
      cow_id: cow_id,
      farm_id: farm_id,
      user_id: user_id,
      history: [],
      older_summary: nil
    }

    case DynamicSupervisor.start_child(
           LivestokOs.AI.SessionSupervisor,
           {__MODULE__, state: state, name: name}
         ) do
      {:ok, _pid} -> {:ok, session_id}
      {:error, {:already_started, _}} -> {:ok, session_id}
      error -> error
    end
  end

  def send_message(session_id, user_message) do
    case find_session(session_id) do
      nil -> {:error, :session_not_found}
      pid -> GenServer.call(pid, {:message, user_message}, 60_000)
    end
  end

  def get_history(session_id) do
    case find_session(session_id) do
      nil -> {:error, :session_not_found}
      pid -> GenServer.call(pid, :get_history)
    end
  end

  # ---- GenServer Callbacks ----

  def start_link(opts) do
    state = Keyword.fetch!(opts, :state)
    name = Keyword.get(opts, :name)
    GenServer.start_link(__MODULE__, state, name: name, timeout: @idle_timeout_ms)
  end

  @impl true
  def init(state) do
    {:ok, state, @idle_timeout_ms}
  end

  @impl true
  def handle_call({:message, user_message}, _from, state) do
    timestamp = DateTime.utc_now()

    user_entry = %{role: :user, content: user_message, timestamp: timestamp}
    state = %{state | history: state.history ++ [user_entry]}

    case process_message(state, user_message) do
      {:ok, reply} ->
        assistant_entry = %{
          role: :assistant,
          content: reply.response,
          timestamp: DateTime.utc_now(),
          metadata: Map.drop(reply, [:response])
        }

        state = %{state | history: state.history ++ [assistant_entry]}
        state = maybe_summarize_old_turns(state)

        {:reply, {:ok, reply}, state, @idle_timeout_ms}
    end
  end

  @impl true
  def handle_call(:get_history, _from, state) do
    {:reply, state.history, state, @idle_timeout_ms}
  end

  @impl true
  def handle_info(:timeout, state) do
    {:stop, :normal, state}
  end

  # ---- Message Processing Pipeline ----

  defp process_message(state, user_message) do
    llm = llm_client()

    retrieval =
      Retrieval.gather(state.cow_id, state.farm_id, user_message, llm)

    classified = Grounding.classify_sources(retrieval.sources)

    result =
      if LLMConfig.chat_configured?() do
        respond_with_llm(state, user_message, retrieval, classified, llm)
      else
        respond_locally(user_message, retrieval, classified)
      end

    :telemetry.execute(
      [:livestok_os, :ai, :consult_completed],
      %{count: 1},
      %{
        farm_id: state.farm_id,
        cow_id: state.cow_id,
        llm_configured: LLMConfig.chat_configured?(),
        used_vector_search: retrieval.used_vector_search,
        source_count: length(retrieval.sources)
      }
    )

    result
  end

  defp respond_with_llm(state, user_message, retrieval, classified, llm) do
    prompt = build_prompt(state, retrieval, classified, user_message)
    model = LLMConfig.thinking_model()

    case llm.chat_completion(prompt, model: model) do
      {:ok, llm_response} when is_binary(llm_response) and llm_response != "" ->
        attributed = Grounding.build_response_with_attribution(classified, llm_response)

        {:ok, build_reply(attributed.response, classified)}

      {:ok, _} ->
        Logger.warning("[ConsultSession] thinking model #{model} returned empty response")
        respond_locally_with_llm_fallback(user_message, retrieval, classified, :empty_response)

      {:error, reason} ->
        Logger.warning("[ConsultSession] thinking model #{model} failed: #{inspect(reason)}")
        respond_locally_with_llm_fallback(user_message, retrieval, classified, reason)
    end
  end

  defp respond_locally_with_llm_fallback(user_message, retrieval, classified, reason) do
    {:ok, reply} = LocalResponder.respond(user_message, retrieval, classified, llm_fallback: reason)
    {:ok, reply}
  end

  defp respond_locally(user_message, retrieval, classified) do
    {:ok, reply} = LocalResponder.respond(user_message, retrieval, classified)
    {:ok, reply}
  end

  defp build_reply(response, classified, opts \\ []) do
    %{
      response: response,
      sources: Enum.map(classified, &serialize_source/1),
      insufficient_data: Keyword.get(opts, :insufficient_data, false),
      confirmed_case_reused: Keyword.get(opts, :confirmed_case_reused, false),
      confirmed_case: Keyword.get(opts, :confirmed_case),
      recommended_next_steps: Keyword.get(opts, :recommended_next_steps),
      attributions: build_attributions(classified),
      local_only: Keyword.get(opts, :local_only, false)
    }
  end

  defp build_attributions(classified) do
    classified
    |> Enum.group_by(& &1.source_type)
    |> Enum.map(fn {type, items} ->
      %{source_type: Atom.to_string(type), count: length(items)}
    end)
  end

  defp serialize_source(%{source_type: type, data: data}) do
    %{source_type: Atom.to_string(type), data: data}
  end

  defp build_prompt(state, retrieval, classified, user_message) do
    system_prompt = load_system_prompt()
    baseline = load_baseline_knowledge()
    case_history = retrieval.case_history

    case_summary =
      "Cow #{state.cow_id} on farm #{state.farm_id}: " <>
        "#{case_history.summary.total_events} recorded events."

    source_text =
      classified
      |> CaseHistoryFormatter.format_sources()

    conversation_context = format_conversation_history(state)

    thinking_note =
      "First, interpret what the farmer is asking in plain language. Then answer using only the records below — do not invent data."

    [
      %{role: "system", content: system_prompt},
      %{role: "system", content: "Baseline veterinary knowledge:\n#{baseline}"},
      %{role: "system", content: "Case history summary: #{case_summary}"},
      %{role: "system", content: thinking_note},
      %{role: "system", content: "Retrieved sources (local database first):\n#{source_text}"}
    ] ++
      conversation_context ++
      [%{role: "user", content: user_message}]
  end

  defp format_conversation_history(state) do
    recent = Enum.take(state.history, -@max_full_turns)

    summary_prefix =
      if state.older_summary do
        [%{role: "system", content: "Previous conversation summary: #{state.older_summary}"}]
      else
        []
      end

    turns =
      Enum.map(recent, fn entry ->
        role = if entry.role == :user, do: "user", else: "assistant"
        %{role: role, content: entry.content}
      end)

    summary_prefix ++ turns
  end

  defp maybe_summarize_old_turns(%{history: history} = state) when length(history) > @max_full_turns * 2 do
    {old, recent} = Enum.split(history, length(history) - @max_full_turns)

    summary =
      old
      |> Enum.map(fn e -> "[#{e.role}] #{String.slice(e.content, 0, 200)}" end)
      |> Enum.join("\n")

    %{state | history: recent, older_summary: summary}
  end

  defp maybe_summarize_old_turns(state), do: state

  defp load_baseline_knowledge do
    priv_dir = :code.priv_dir(:livestok_os_ai)

    case File.read(Path.join(priv_dir, "prompts/baseline_vet_knowledge.txt")) do
      {:ok, content} -> content
      {:error, _} -> ""
    end
  end

  defp load_system_prompt do
    priv_dir = :code.priv_dir(:livestok_os_ai)

    case File.read(Path.join(priv_dir, "prompts/vet_consult_system.txt")) do
      {:ok, content} -> content
      {:error, _} -> default_system_prompt()
    end
  end

  defp default_system_prompt do
    "You do not diagnose. You summarize recorded history, surface similar past patterns, " <>
      "and point to relevant research. The judgment call belongs to the veterinarian."
  end

  # ---- Helpers ----

  defp via(cow_id, user_id, session_id) do
    {:via, Registry, {LivestokOs.AI.SessionRegistry, {cow_id, user_id, session_id}}}
  end

  defp find_session(session_id) do
    case Registry.select(LivestokOs.AI.SessionRegistry, [
           {{{:"$1", :"$2", :"$3"}, :"$4", :_}, [{:==, :"$3", session_id}], [:"$4"]}
         ]) do
      [pid | _] -> pid
      [] -> nil
    end
  end

  defp generate_session_id do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end

  defp llm_client do
    Application.get_env(:livestok_os_ai, :llm_client, LivestokOs.AI.LLMClient)
  end
end
