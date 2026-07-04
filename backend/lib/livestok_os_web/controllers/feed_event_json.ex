defmodule LivestokOsWeb.FeedEventJSON do
  alias LivestokOs.ZeroGrazing.FeedEvent

  def index(%{feed_events: feed_events}) do
    %{data: for(fe <- feed_events, do: data(fe))}
  end

  def show(%{feed_event: feed_event}) do
    %{data: data(feed_event)}
  end

  defp data(%FeedEvent{} = fe) do
    %{
      id: fe.id,
      cow_id: fe.cow_id,
      farm_id: fe.farm_id,
      feed_type: fe.feed_type,
      quantity_kg: fe.quantity_kg,
      dry_matter_pct: fe.dry_matter_pct,
      protein_pct: fe.protein_pct,
      inhibitor_added: fe.inhibitor_added,
      fed_at: fe.fed_at,
      notes: fe.notes,
      inserted_at: fe.inserted_at
    }
  end
end
