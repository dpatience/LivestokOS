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

  alias LivestokOs.AI.{CaseHistory, CaseMemory, ResearchCorpus, Grounding}

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
      {:ok, response, sources} ->
        assistant_entry = %{
          role: :assistant,
          content: response,
          timestamp: DateTime.utc_now()
        }

        state = %{state | history: state.history ++ [assistant_entry]}
        state = maybe_summarize_old_turns(state)

        {:reply, {:ok, %{response: response, sources: sources}}, state, @idle_timeout_ms}

      {:error, reason} ->
        {:reply, {:error, reason}, state, @idle_timeout_ms}
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

    case_history = CaseHistory.build(state.cow_id, state.farm_id)

    with {:ok, embedding} <- llm.embed(user_message) do
      confirmed_cases = CaseMemory.search_confirmed(embedding, state.farm_id)
      research = ResearchCorpus.search(embedding, 5)

      retrieval_results = build_retrieval_results(case_history, confirmed_cases, research)
      classified = Grounding.classify_sources(retrieval_results)

      had_confirmed_match = has_confirmed_match?(confirmed_cases)

      result =
        if had_confirmed_match do
          best = List.first(confirmed_cases)

          response =
            "Similar confirmed case found:\n\n#{best.situation_summary}\n\n" <>
              "Previous answer: #{best.assistant_answer}"

          {:ok, response, classified}
        else
          if all_empty?(retrieval_results) do
            insufficient = Grounding.handle_insufficient_data(user_message, [])
            {:ok, insufficient.message, classified}
          else
            prompt = build_prompt(state, case_history, classified, user_message)

            case llm.chat_completion(prompt) do
              {:ok, llm_response} ->
                attributed = Grounding.build_response_with_attribution(classified, llm_response)
                {:ok, attributed.response, classified}

              {:error, reason} ->
                {:error, reason}
            end
          end
        end

      :telemetry.execute(
        [:livestok_os, :ai, :consult_completed],
        %{count: 1},
        %{
          farm_id: state.farm_id,
          cow_id: state.cow_id,
          had_confirmed_match: had_confirmed_match
        }
      )

      result
    end
  end

  defp build_retrieval_results(case_history, confirmed_cases, research) do
    own_data =
      if case_history.timeline != [] do
        [%{source: :case_history, data: %{timeline_count: length(case_history.timeline)}}]
      else
        []
      end

    cross_farm =
      Enum.map(confirmed_cases, fn c ->
        %{source: :confirmed_case, data: Map.from_struct(c)}
      end)

    research_data =
      Enum.map(research, fn r ->
        %{source: :research, data: r}
      end)

    own_data ++ cross_farm ++ research_data
  end

  defp has_confirmed_match?([_ | _]), do: true
  defp has_confirmed_match?(_), do: false

  defp all_empty?(results), do: results == []

  defp build_prompt(state, case_history, classified, user_message) do
    system_prompt = load_system_prompt()

    case_summary =
      "Cow #{state.cow_id} on farm #{state.farm_id}: " <>
        "#{case_history.summary.total_events} recorded events."

    source_text =
      classified
      |> Enum.map(fn %{source_type: type, data: data} ->
        "[#{type}] #{inspect(data)}"
      end)
      |> Enum.join("\n")

    conversation_context = format_conversation_history(state)

    [
      %{role: "system", content: system_prompt},
      %{role: "system", content: "Case history summary: #{case_summary}"},
      %{role: "system", content: "Retrieved sources:\n#{source_text}"}
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
