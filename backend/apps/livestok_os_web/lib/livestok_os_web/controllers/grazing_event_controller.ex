defmodule LivestokOsWeb.GrazingEventController do
  use LivestokOsWeb, :controller

  alias LivestokOs.Operations
  alias LivestokOs.Operations.GrazingEvent

  action_fallback LivestokOsWeb.FallbackController

  def index(conn, params) do
    grazing_events = Operations.list_grazing_events(params)
    render(conn, :index, grazing_events: grazing_events)
  end

  def create(conn, %{"grazing_event" => grazing_event_params}) do
    with {:ok, %GrazingEvent{} = grazing_event} <-
           Operations.create_grazing_event(grazing_event_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/grazing_events/#{grazing_event}")
      |> render(:show, grazing_event: grazing_event)
    end
  end

  def show(conn, %{"id" => id}) do
    grazing_event = Operations.get_grazing_event!(id)
    render(conn, :show, grazing_event: grazing_event)
  end

  def update(conn, %{"id" => id, "grazing_event" => grazing_event_params}) do
    grazing_event = Operations.get_grazing_event!(id)

    with {:ok, %GrazingEvent{} = grazing_event} <-
           Operations.update_grazing_event(grazing_event, grazing_event_params) do
      render(conn, :show, grazing_event: grazing_event)
    end
  end

  def delete(conn, %{"id" => id}) do
    grazing_event = Operations.get_grazing_event!(id)

    with {:ok, %GrazingEvent{}} <- Operations.delete_grazing_event(grazing_event) do
      send_resp(conn, :no_content, "")
    end
  end
end
