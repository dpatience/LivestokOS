defmodule LivestokOs.AI.LocalResponder do
  @moduledoc """
  Offline fallback when no reasoning model is reachable.

  Does not interpret clinical questions — it only reads back farm records in
  plain language and explains how to enable the thinking model.
  """

  alias LivestokOs.AI.{CaseHistoryFormatter, LLMConfig}

  @greeting ~r/^(hi|hello|hey|good morning|good afternoon|jambo|habari)/i

  @doc """
  Builds a reply from local context only.

  Options:
  - `:llm_fallback` — set when the reasoning model was configured but the HTTP call failed
  """
  def respond(user_message, retrieval, classified, opts \\ []) do
    case_history = retrieval.case_history
    llm_fallback = Keyword.get(opts, :llm_fallback)

    cond do
      String.match?(String.trim(user_message), @greeting) ->
        {:ok, build_reply(greeting_text(case_history, llm_fallback), classified)}

      case_history.summary.total_events > 0 and activity_question?(user_message) ->
        {:ok, build_reply(summarize_activity(case_history, llm_fallback), classified, local_only: true)}

      match = List.first(retrieval.confirmed_cases) ->
        {:ok,
         build_reply(
           format_confirmed_case(match),
           classified,
           confirmed_case_reused: true,
           confirmed_case: %{
             confirmed_at: match.confirmed_at,
             situation_summary: match.situation_summary
           }
         )}

      retrieval.sources != [] ->
        {:ok,
         build_reply(
           readable_records_reply(case_history, classified, llm_fallback),
           classified,
           local_only: true
         )}

      true ->
        {:ok,
         build_reply(
           no_records_reply(user_message, llm_fallback),
           classified,
           local_only: true,
           insufficient_data: true,
           recommended_next_steps: default_next_steps()
         )}
    end
  end

  defp greeting_text(case_history, llm_fallback) do
    events = case_history.summary.total_events
    thinking_note = thinking_status_line(llm_fallback)

    base =
      if events > 0 do
        "Hello — I'm your veterinary assistant for this cow. I can see #{events} recorded events on file. What would you like to know?"
      else
        "Hello — I'm your veterinary assistant. We don't have much logged for this cow yet, but ask away and I'll use what we have plus general husbandry guidance."
      end

    if thinking_note == "", do: base, else: base <> "\n\n" <> thinking_note
  end

  defp activity_question?(msg) do
    msg = String.downcase(msg)
    String.contains?(msg, ["activity", "recent", "happening", "history", "last few days", "timeline"])
  end

  defp summarize_activity(case_history, llm_fallback) do
    body = CaseHistoryFormatter.format_case_history(case_history)

    """
    Here's what we have on file for this cow:

    #{body}

    #{thinking_status_line(llm_fallback)}
    """
    |> String.trim()
  end

  defp readable_records_reply(case_history, classified, llm_fallback) do
    records = CaseHistoryFormatter.format_sources(classified)
    summary = CaseHistoryFormatter.format_case_history(case_history)

    body =
      if records != "" do
        records
      else
        summary
      end

    """
    I can't fully interpret your question without a connected reasoning model yet. Here is what we have recorded for this cow:

    #{body}

    #{thinking_status_line(llm_fallback)}

    Try asking: "What happened recently?", "Summarise feed and meds", or "Anything I should tell the vet?" — or connect LLM_THINKING_MODEL so I can answer in plain language.
    """
    |> String.trim()
  end

  defp no_records_reply(_user_message, llm_fallback) do
    """
    I don't have enough logged for this cow to answer that yet, and I'm not connected to a reasoning model to interpret general questions.

    #{thinking_status_line(llm_fallback)}

    You can log feed, meds, and observations in the Diary, then ask again.
    """
    |> String.trim()
  end

  defp thinking_status_line(nil) do
    if LLMConfig.chat_configured?() do
      ""
    else
      LLMConfig.consult_setup_hint()
    end
  end

  defp thinking_status_line(_reason) do
    "The reasoning model (#{LLMConfig.thinking_model()}) could not be reached just now. " <>
      LLMConfig.consult_setup_hint() <>
      " Below is a factual readout only — not clinical interpretation."
  end

  defp format_confirmed_case(case) do
    """
    A similar situation was vet-confirmed on this farm before:

    #{case.situation_summary}

    What was agreed then:
    #{case.assistant_answer || "No answer text stored."}

    Treat this as a pattern to discuss with your vet — not an automatic diagnosis for today.
    """
    |> String.trim()
  end

  defp default_next_steps do
    [
      "Log feed, meds, or observations in the Diary",
      "Ask: \"What happened recently?\" for a timeline readout",
      "Set LLM_THINKING_MODEL in backend/.env for plain-language answers",
      "Consult your veterinarian for clinical decisions"
    ]
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
end
