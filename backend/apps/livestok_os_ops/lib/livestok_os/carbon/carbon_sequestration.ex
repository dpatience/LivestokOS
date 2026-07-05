defmodule LivestokOs.CarbonSequestration do
  @moduledoc """
  Outdoor carbon sequestration accounting for :pasture and :mixed farms.

  ## Carbon formula (Stage 4A)
  Carbon Sequestered (tCO2e) = soil_type_factor × NDVI_grass_growth_index × rotational_compliance_score

  Per paddock per grazing period. Summed across paddocks and periods for the annual farm figure.

  ## Feature gate
  All entry points check `feature_enabled?(:satellite_ndvi, farm)` and
  `farm.grazing_mode in [:pasture, :mixed]`. Zero-grazing farms are excluded.
  """

  import Ecto.Query, warn: false
  alias LivestokOs.Repo
  alias LivestokOs.Carbon.CarbonSequestrationRecord
  alias LivestokOs.Inventory
  alias LivestokOs.Operations

  require Logger

  @doc """
  Calculates and persists a carbon sequestration record for a paddock.

  `paddock` must be a `%Geofence{}` with `soil_type_factor` populated.
  `ndvi_score` comes from `NdviReadings.latest_ndvi_for_paddock/1`.
  `compliance_score` comes from `PaddockCompliance.get_compliance/2`.

  Returns `{:ok, %CarbonSequestrationRecord{}}` or `{:error, reason}`.
  """
  def calculate_and_store(farm, paddock, ndvi_score, compliance_score, period_start, period_end) do
    with :ok <- check_feature_gate(farm),
         {:ok, soil_factor} <- get_soil_factor(paddock) do
      carbon_tco2e = Float.round(soil_factor * ndvi_score * compliance_score, 6)

      %CarbonSequestrationRecord{}
      |> CarbonSequestrationRecord.changeset(%{
        paddock_id: paddock.id,
        farm_id: farm.id,
        period_start: period_start,
        period_end: period_end,
        soil_type_factor: soil_factor,
        ndvi_score: ndvi_score,
        compliance_score: compliance_score,
        carbon_tco2e: carbon_tco2e
      })
      |> Repo.insert()
    end
  end

  @doc """
  Returns the sum of all carbon_tco2e for a farm, optionally filtered to a
  date range ([period_start, period_end]).
  """
  def annual_carbon_for_farm(farm_id, opts \\ []) do
    since = Keyword.get(opts, :since)
    until_dt = Keyword.get(opts, :until)

    query =
      from(r in CarbonSequestrationRecord,
        where: r.farm_id == ^farm_id,
        select: sum(r.carbon_tco2e)
      )

    query = if since, do: from(r in query, where: r.period_start >= ^since), else: query
    query = if until_dt, do: from(r in query, where: r.period_end <= ^until_dt), else: query

    case Repo.one(query) do
      nil -> 0.0
      total -> total
    end
  end

  @doc """
  Checks whether the active paddock's NDVI has dropped below the farm's
  `ndvi_alert_threshold`. If so, creates an NDVI_LOW_CARBON alert recommending
  lick-block deployment.

  No-ops when `farm.ndvi_alert_threshold` is nil (threshold not configured).
  """
  def check_ndvi_alert(farm, paddock_id, ndvi_score) do
    case farm.ndvi_alert_threshold do
      nil ->
        :ok

      threshold when ndvi_score < threshold ->
        unless recent_ndvi_alert?(farm.id, paddock_id) do
          Operations.create_alert(%{
            type: "NDVI_LOW_CARBON",
            message:
              "NDVI score #{Float.round(ndvi_score, 3)} is below threshold #{threshold} " <>
                "for paddock #{paddock_id}. " <>
                "Deploy lick blocks to mitigate methane output and support grass recovery.",
            is_resolved: false,
            farm_id: farm.id,
            severity: "warning"
          })
        end

        :ok

      _above_threshold ->
        :ok
    end
  end

  # ---------------------------------------------------------------------------

  defp check_feature_gate(farm) do
    cond do
      farm.grazing_mode not in [:pasture, :mixed] ->
        {:error, :wrong_grazing_mode}

      not Inventory.feature_enabled?(farm, :satellite_ndvi) ->
        {:error, :feature_disabled}

      true ->
        :ok
    end
  end

  defp get_soil_factor(%{soil_type_factor: nil}) do
    {:error, :soil_type_factor_missing}
  end

  defp get_soil_factor(%{soil_type_factor: factor}) when is_float(factor) do
    {:ok, factor}
  end

  defp recent_ndvi_alert?(farm_id, paddock_id) do
    cutoff = DateTime.utc_now() |> DateTime.add(-24 * 3600, :second)
    marker = "paddock #{paddock_id}"

    from(a in LivestokOs.Operations.Alert,
      where:
        a.farm_id == ^farm_id and
          a.type == "NDVI_LOW_CARBON" and
          a.is_resolved == false and
          a.inserted_at >= ^cutoff and
          like(a.message, ^"%#{marker}%")
    )
    |> Repo.exists?()
  end
end
