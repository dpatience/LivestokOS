defmodule LivestokOsWeb.AlertController do
  use LivestokOsWeb, :controller

  alias LivestokOs.Operations
  alias LivestokOs.Operations.Alert

  action_fallback LivestokOsWeb.FallbackController

  # List only unresolved alerts ordered by severity score (highest first),
  # then by inserted_at descending within the same score.
  def index(conn, params) do
    farm_id = conn.assigns[:current_farm_id]
    alerts = Operations.list_by_priority(farm_id, params)
    render(conn, :index, alerts: alerts)
  end

  # Mark an alert as resolved
  def update(conn, %{"id" => id, "alert" => alert_params}) do
    alert = Operations.get_alert!(id)

    with {:ok, %Alert{} = alert} <- Operations.update_alert(alert, alert_params) do
      render(conn, :show, alert: Alert.with_severity_score(alert))
    end
  end
end
