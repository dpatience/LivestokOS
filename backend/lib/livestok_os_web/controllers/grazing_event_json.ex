defmodule LivestokOsWeb.GrazingEventJSON do
  alias LivestokOs.Operations.GrazingEvent

  @doc """
  Renders a list of grazing_events.
  """
  def index(%{grazing_events: grazing_events}) do
    %{data: for(grazing_event <- grazing_events, do: data(grazing_event))}
  end

  @doc """
  Renders a single grazing_event.
  """
  def show(%{grazing_event: grazing_event}) do
    %{data: data(grazing_event)}
  end

  defp data(%GrazingEvent{} = grazing_event) do
    %{
      id: grazing_event.id,
      zone_id: grazing_event.zone_id,
      entered_at: grazing_event.entered_at,
      left_at: grazing_event.left_at
    }
  end
end
