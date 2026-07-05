defmodule LivestokOsWeb.AlertJSON do
  alias LivestokOs.Operations.Alert

  @doc """
  Renders a list of alerts.
  """
  def index(%{alerts: alerts}) do
    %{data: for(alert <- alerts, do: data(alert))}
  end

  @doc """
  Renders a single alert.
  """
  def show(%{alert: alert}) do
    %{data: data(alert)}
  end

  defp data(%Alert{} = alert) do
    %{
      id: alert.id,
      type: alert.type,
      message: alert.message,
      is_resolved: alert.is_resolved,
      severity: alert.severity,
      priority: alert.priority,
      cow_id: alert.cow_id,
      farm_id: alert.farm_id,
      # severity_score is additive — new field, backward-compatible
      severity_score: Alert.score_for_type(alert.type),
      inserted_at: alert.inserted_at
    }
  end
end
