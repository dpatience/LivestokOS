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
      is_resolved: alert.is_resolved
    }
  end
end
