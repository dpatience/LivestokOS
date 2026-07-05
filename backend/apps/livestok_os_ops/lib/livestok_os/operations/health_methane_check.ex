defmodule LivestokOs.Operations.HealthMethaneCheck do
  @moduledoc """
  Behavioral-pattern analysis for methane efficiency scoring.

  Analyzes recent sensor readings for a cow to produce a methane efficiency
  score (0.0 – 1.0) based on:

    * Idle duration ratio    — long idle periods correlate with fermentation/methane
    * Eating frequency       — more frequent, shorter meals reduce rumen load
    * Movement deviation     — low movement suggests poor digestion
    * NDVI (pasture quality) — dry grass = harder digestion = higher methane
  """

  import Ecto.Query, warn: false
  alias LivestokOs.Repo
  alias LivestokOs.Telemetry.SensorReading
  alias LivestokOs.Satellite

  @lookback_hours 24
  @idle_labels ~w(idle resting lying)
  @eating_labels ~w(eating grazing ruminating)

  @doc """
  Runs a methane-efficiency analysis for a single cow over the last 24 hours.

  Returns `{:ok, %{score: float, factors: map}}` or `{:error, reason}`.
  """
  def analyze(cow_id, lat \\ nil, long \\ nil) do
    since = DateTime.utc_now() |> DateTime.add(-@lookback_hours * 3600, :second)

    readings =
      from(s in SensorReading,
        where: s.cow_id == ^cow_id and s.timestamp >= ^since,
        order_by: [asc: s.timestamp]
      )
      |> Repo.all()

    if readings == [] do
      {:error, :no_readings}
    else
      idle_ratio = idle_ratio(readings)
      eating_freq = eating_frequency(readings)
      movement_dev = movement_deviation(readings)
      ndvi_factor = ndvi_factor(lat, long)

      # Lower idle ratio is better (less fermentation time)
      # Higher eating frequency is better (smaller meals)
      # Higher movement is better (active digestion)
      # Higher NDVI is better (quality feed)
      score =
        (1.0 - idle_ratio) * 0.25 +
          min(eating_freq / 10.0, 1.0) * 0.25 +
          min(movement_dev / 2.0, 1.0) * 0.25 +
          ndvi_factor * 0.25

      {:ok,
       %{
         cow_id: cow_id,
         score: Float.round(score, 3),
         grade: grade(score),
         factors: %{
           idle_ratio: Float.round(idle_ratio, 3),
           eating_frequency: eating_freq,
           movement_deviation: Float.round(movement_dev, 3),
           ndvi_factor: Float.round(ndvi_factor, 3)
         },
         readings_analyzed: length(readings),
         window_hours: @lookback_hours
       }}
    end
  end

  # ---------------------------------------------------------------------------

  defp idle_ratio(readings) do
    total = length(readings)
    if total == 0, do: 0.0, else: count_labels(readings, @idle_labels) / total
  end

  defp eating_frequency(readings) do
    readings
    |> Enum.filter(fn r -> label(r) in @eating_labels end)
    |> length()
  end

  defp movement_deviation(readings) do
    speeds =
      readings
      |> Enum.map(& &1.speed_mps)
      |> Enum.filter(&is_number/1)

    case speeds do
      [] ->
        0.0

      [_single] ->
        0.0

      speeds ->
        mean = Enum.sum(speeds) / length(speeds)

        variance =
          speeds
          |> Enum.map(fn s -> (s - mean) * (s - mean) end)
          |> Enum.sum()
          |> Kernel./(length(speeds))

        :math.sqrt(variance)
    end
  end

  defp ndvi_factor(nil, _), do: 0.5
  defp ndvi_factor(_, nil), do: 0.5

  defp ndvi_factor(lat, long) do
    case Satellite.get_current_ndvi(lat, long) do
      {:ok, ndvi} -> ndvi
      _ -> 0.5
    end
  end

  defp count_labels(readings, labels) do
    Enum.count(readings, fn r -> label(r) in labels end)
  end

  defp label(%SensorReading{behavior_label: bl, activity: act}) do
    (bl || act || "") |> String.downcase()
  end

  defp grade(score) when score >= 0.8, do: "excellent"
  defp grade(score) when score >= 0.6, do: "good"
  defp grade(score) when score >= 0.4, do: "moderate"
  defp grade(_), do: "poor"
end
