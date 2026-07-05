defmodule LivestokOsWeb.ConsultJSON do
  def session(%{session: session}) do
    %{data: session}
  end

  def message(%{reply: reply}) do
    %{data: reply_data(reply)}
  end

  def history(%{history: history}) do
    %{
      data:
        Enum.map(history, fn entry ->
          base = %{
            role: Atom.to_string(entry.role),
            content: entry.content,
            timestamp: entry.timestamp
          }

          case Map.get(entry, :metadata) do
            nil -> base
            metadata -> Map.put(base, :metadata, metadata_data(metadata))
          end
        end)
    }
  end

  defp metadata_data(metadata) do
    %{
      sources: Map.get(metadata, :sources, []),
      insufficient_data: Map.get(metadata, :insufficient_data, false),
      confirmed_case_reused: Map.get(metadata, :confirmed_case_reused, false),
      confirmed_case: serialize_confirmed_case(Map.get(metadata, :confirmed_case)),
      recommended_next_steps: Map.get(metadata, :recommended_next_steps),
      attributions: Map.get(metadata, :attributions, [])
    }
  end

  defp reply_data(reply) when is_map(reply) do
    %{
      response: reply.response,
      sources: reply.sources || [],
      insufficient_data: Map.get(reply, :insufficient_data, false),
      confirmed_case_reused: Map.get(reply, :confirmed_case_reused, false),
      confirmed_case: serialize_confirmed_case(Map.get(reply, :confirmed_case)),
      recommended_next_steps: Map.get(reply, :recommended_next_steps),
      attributions: reply.attributions || []
    }
  end

  defp serialize_confirmed_case(nil), do: nil

  defp serialize_confirmed_case(%{confirmed_at: at, situation_summary: summary}) do
    %{confirmed_at: at, situation_summary: summary}
  end

  defp serialize_confirmed_case(map) when is_map(map) do
    %{
      confirmed_at: Map.get(map, :confirmed_at) || Map.get(map, "confirmed_at"),
      situation_summary: Map.get(map, :situation_summary) || Map.get(map, "situation_summary")
    }
  end
end
