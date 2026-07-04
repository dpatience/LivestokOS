defmodule LivestokOsWeb.FeedEventController do
  use LivestokOsWeb, :controller

  alias LivestokOs.ZeroGrazing
  alias LivestokOs.ZeroGrazing.FeedEvent

  action_fallback LivestokOsWeb.FallbackController

  def index(conn, params) do
    feed_events = ZeroGrazing.list_feed_events(params)
    render(conn, :index, feed_events: feed_events)
  end

  def create(conn, %{"feed_event" => fe_params}) do
    with {:ok, %FeedEvent{} = fe} <- ZeroGrazing.create_feed_event(fe_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/feed_events/#{fe}")
      |> render(:show, feed_event: fe)
    end
  end

  def show(conn, %{"id" => id}) do
    fe = ZeroGrazing.get_feed_event!(id)
    render(conn, :show, feed_event: fe)
  end

  def update(conn, %{"id" => id, "feed_event" => fe_params}) do
    fe = ZeroGrazing.get_feed_event!(id)

    with {:ok, %FeedEvent{} = fe} <- ZeroGrazing.update_feed_event(fe, fe_params) do
      render(conn, :show, feed_event: fe)
    end
  end

  def delete(conn, %{"id" => id}) do
    fe = ZeroGrazing.get_feed_event!(id)

    with {:ok, %FeedEvent{}} <- ZeroGrazing.delete_feed_event(fe) do
      send_resp(conn, :no_content, "")
    end
  end
end
