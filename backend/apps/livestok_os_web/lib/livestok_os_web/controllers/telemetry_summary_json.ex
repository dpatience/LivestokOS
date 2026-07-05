defmodule LivestokOsWeb.TelemetrySummaryJSON do
  @moduledoc false

  def index(%{summaries: summaries}) do
    %{data: Enum.map(summaries, &format/1)}
  end

  defp format(summary) do
    %{
      entity: summary.entity,
      windowMinutes: summary.window_minutes,
      cow: summary.cow,
      device: summary.device,
      lastReadingAt: summary.last_reading_at,
      lastCoordinates: summary.last_coordinates,
      avgSpeedMps: summary.avg_speed_mps,
      behaviorCounts: summary.behavior_counts,
      batteryLevel: summary.battery_level,
      analysisSnapshot: summary.analysis_snapshot,
      alerts: summary.alerts
    }
  end
end
