defmodule LivestokOsWeb.AlertController do
  use LivestokOsWeb, :controller

  alias LivestokOs.Operations
  alias LivestokOs.Operations.Alert

  action_fallback LivestokOsWeb.FallbackController

  # List only unresolved alerts (The "To-Do" list for the farmer)
  def index(conn, params) do
    alerts = Operations.list_alerts(params)
    render(conn, :index, alerts: alerts)
  end

  # Mark an alert as resolved
  def update(conn, %{"id" => id, "alert" => alert_params}) do
    alert = Operations.get_alert!(id)

    with {:ok, %Alert{} = alert} <- Operations.update_alert(alert, alert_params) do
      render(conn, :show, alert: alert)
    end
  end
end
