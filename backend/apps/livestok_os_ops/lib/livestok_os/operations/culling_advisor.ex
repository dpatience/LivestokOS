defmodule LivestokOs.Operations.CullingAdvisor do
  @moduledoc """
  Aggregates historical performance data per cow and classifies animals
  into tiers to guide culling/selection decisions.

  Tiers:
    * **super_cow**         – top performers (carbon-positive, healthy, good grazers)
    * **average**           – acceptable performers
    * **methane_factory**   – high methane risk, poor grazing behaviour, low carbon yield
  """

  import Ecto.Query, warn: false
  alias LivestokOs.Repo
  alias LivestokOs.Telemetry.SensorReading
  alias LivestokOs.Operations.Alert

  @doc """
  Returns a ranked list of cow performance summaries sorted by composite score (desc).
  Accepts an optional list of cow_ids to scope the analysis.
  """
  def rank(cow_ids \\ nil) do
    cow_ids = cow_ids || all_cow_ids()

    cow_ids
    |> Enum.map(&build_profile/1)
    |> Enum.sort_by(& &1.composite_score, :desc)
  end

  @doc """
  Classifies a single cow and returns its performance profile.
  """
  def classify(cow_id), do: build_profile(cow_id)

  # ---------------------------------------------------------------------------

  defp build_profile(cow_id) do
    carbon = total_carbon_tons(cow_id)
    alert_count = unresolved_alert_count(cow_id)
    grazing_score = avg_grazing_score(cow_id)

    # Composite: reward carbon yield and grazing quality, penalize alerts
    composite =
      carbon * 10.0 +
        grazing_score * 5.0 -
        alert_count * 2.0

    tier = classify_tier(composite)

    %{
      cow_id: cow_id,
      total_carbon_tons: Float.round(carbon, 4),
      unresolved_alerts: alert_count,
      avg_grazing_score: Float.round(grazing_score, 3),
      composite_score: Float.round(composite, 3),
      tier: tier
    }
  end

  defp total_carbon_tons(_cow_id) do
    # Carbon credits table removed — carbon is now tracked via satellite_records.
    # Return 0.0 as a placeholder; integrate with satellite metrics in the future.
    0.0
  end

  defp unresolved_alert_count(cow_id) do
    from(a in Alert,
      where: a.cow_id == ^cow_id and a.is_resolved == false,
      select: count(a.id)
    )
    |> Repo.one()
  end

  defp avg_grazing_score(cow_id) do
    # Use speed_mps as proxy for grazing activity — active cows with moderate speed
    # are healthier grazers.
    from(s in SensorReading,
      where: s.cow_id == ^cow_id and not is_nil(s.speed_mps),
      select: avg(s.speed_mps)
    )
    |> Repo.one()
    |> to_float()
    |> then(fn avg_speed ->
      # Normalize: ideal speed ~0.3–0.8 m/s for grazing
      cond do
        avg_speed >= 0.3 and avg_speed <= 0.8 -> 1.0
        avg_speed > 0.8 -> max(0.0, 1.0 - (avg_speed - 0.8))
        true -> max(0.0, avg_speed / 0.3)
      end
    end)
  end

  defp all_cow_ids do
    from(s in SensorReading,
      where: not is_nil(s.cow_id),
      distinct: s.cow_id,
      select: s.cow_id
    )
    |> Repo.all()
  end

  defp classify_tier(composite) when composite >= 3.0, do: "super_cow"
  defp classify_tier(composite) when composite >= 0.0, do: "average"
  defp classify_tier(_), do: "methane_factory"

  defp to_float(nil), do: 0.0
  defp to_float(%Decimal{} = d), do: Decimal.to_float(d)
  defp to_float(f) when is_float(f), do: f
  defp to_float(i) when is_integer(i), do: i / 1
end
