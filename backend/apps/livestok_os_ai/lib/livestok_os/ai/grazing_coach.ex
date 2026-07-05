defmodule LivestokOs.AI.GrazingCoach do
  @moduledoc """
  Deterministic paddock ranking algorithm for grazing recommendations.

  ## Ranking Formula

      paddock_score = (ndvi_percentile × 0.4)
                    + (days_since_last_grazed_normalized × 0.3)
                    + (projected_recovery_score × 0.3)

  Where:
  - `ndvi_percentile`: current NDVI relative to all farm paddocks, normalized [0,1].
  - `days_since_last_grazed_normalized`: days since the most recent rotation event
    for a paddock, normalized to [0,1] against the maximum across all paddocks.
  - `projected_recovery_score`: grass recovery projection confidence ×
    (1 − days_to_recovery / max_days), clamped to [0,1].

  ## Feature Gate
  Gated behind `Inventory.feature_enabled?(farm, :grazing_coach)`.
  Returns `{:ok, %{recommendations: [], reason: :feature_disabled}}` for
  `:zero_grazing` farms.

  ## Stale NDVI Handling
  Paddocks whose latest NDVI reading is stale (`:is_stale == true`) or absent
  are excluded from ranking and listed in `stale_paddocks`. If *all* paddocks
  are stale, the response is `{:ok, %{recommendations: [], reason: :all_ndvi_stale}}`.
  """

  import Ecto.Query, warn: false
  alias LivestokOs.Repo
  alias LivestokOs.Inventory
  alias LivestokOs.Inventory.Farm
  alias LivestokOs.Infrastructure.Geofence
  alias LivestokOs.Satellite.NdviReading
  alias LivestokOs.Satellite.GrassRecoveryProjection
  alias LivestokOs.Infrastructure.RotationEvent
  alias LivestokOs.Operations.Alert

  @ndvi_weight 0.4
  @rest_weight 0.3
  @recovery_weight 0.3

  @doc """
  Generates ranked paddock recommendations for `farm_id`.
  """
  def recommend(farm_id) do
    farm = Repo.get!(Farm, farm_id)

    if not Inventory.feature_enabled?(farm, :grazing_coach) do
      {:ok, %{recommendations: [], reason: :feature_disabled}}
    else
      do_recommend(farm)
    end
  end

  defp do_recommend(farm) do
    paddocks = list_active_paddocks(farm.id)

    {fresh, stale_or_missing} =
      paddocks
      |> Enum.map(fn paddock -> {paddock, latest_ndvi(paddock.id)} end)
      |> Enum.split_with(fn {_p, result} -> match?({:ok, _}, result) end)

    stale_paddocks =
      Enum.map(stale_or_missing, fn {paddock, _} ->
        %{
          paddock_id: paddock.id,
          name: paddock.name,
          reason: "NDVI data older than expected revisit cadence"
        }
      end)

    if fresh == [] do
      {:ok, %{recommendations: [], reason: :all_ndvi_stale, stale_paddocks: stale_paddocks}}
    else
      build_recommendations(farm.id, fresh, stale_paddocks)
    end
  end

  defp build_recommendations(farm_id, fresh, stale_paddocks) do
    ndvi_values = Enum.map(fresh, fn {_, {:ok, r}} -> r.ndvi_score end)
    rotation_map = last_rotation_map(farm_id)
    recovery_map = latest_recovery_map(farm_id)

    recommendations =
      fresh
      |> Enum.map(fn {paddock, {:ok, reading}} ->
        score =
          calculate_score(reading.ndvi_score, ndvi_values, paddock.id, rotation_map, recovery_map)

        %{
          paddock_id: paddock.id,
          name: paddock.name,
          score: Float.round(score, 4),
          ndvi: reading.ndvi_score
        }
      end)
      |> Enum.sort_by(& &1.score, :desc)

    if top = List.first(recommendations) do
      create_recommendation_alert(farm_id, top)
    end

    {:ok, %{recommendations: recommendations, stale_paddocks: stale_paddocks}}
  end

  defp list_active_paddocks(farm_id) do
    from(g in Geofence,
      where: g.farm_id == ^farm_id and g.is_active == true and g.enforcement_scope == "keep_in"
    )
    |> Repo.all()
  end

  defp latest_ndvi(paddock_id) do
    reading =
      from(r in NdviReading,
        where: r.paddock_id == ^paddock_id,
        order_by: [desc: r.captured_at],
        limit: 1
      )
      |> Repo.one()

    case reading do
      nil -> {:error, :no_data}
      %NdviReading{is_stale: true} -> {:error, :stale}
      %NdviReading{} = r -> {:ok, r}
    end
  end

  defp last_rotation_map(farm_id) do
    from(r in RotationEvent,
      where: r.farm_id == ^farm_id,
      group_by: r.paddock_id,
      select: %{paddock_id: r.paddock_id, last_at: max(r.occurred_at)}
    )
    |> Repo.all()
    |> Map.new(fn %{paddock_id: pid, last_at: at} -> {pid, at} end)
  end

  defp latest_recovery_map(farm_id) do
    from(g in GrassRecoveryProjection,
      where: g.farm_id == ^farm_id,
      distinct: g.paddock_id,
      order_by: [asc: g.paddock_id, desc: g.projected_at]
    )
    |> Repo.all()
    |> Map.new(fn proj -> {proj.paddock_id, proj} end)
  end

  defp calculate_score(ndvi, all_ndvi_values, paddock_id, rotation_map, recovery_map) do
    ndvi_pct = ndvi_percentile(ndvi, all_ndvi_values)
    rest_norm = days_since_last_grazed_normalized(paddock_id, rotation_map)
    recovery = projected_recovery_score(paddock_id, recovery_map)

    ndvi_pct * @ndvi_weight + rest_norm * @rest_weight + recovery * @recovery_weight
  end

  defp ndvi_percentile(ndvi, all_values) do
    count_below = Enum.count(all_values, &(&1 < ndvi))
    count_below / max(length(all_values), 1)
  end

  defp days_since_last_grazed_normalized(paddock_id, rotation_map) do
    now = DateTime.utc_now()

    days_map =
      Map.new(rotation_map, fn {pid, last_at} ->
        {pid, DateTime.diff(now, last_at, :day)}
      end)

    max_days = days_map |> Map.values() |> Enum.max(fn -> 1 end)

    case Map.get(days_map, paddock_id) do
      nil -> 1.0
      days -> days / max(max_days, 1)
    end
  end

  defp projected_recovery_score(paddock_id, recovery_map) do
    case Map.get(recovery_map, paddock_id) do
      nil ->
        0.5

      proj ->
        max_days =
          recovery_map
          |> Map.values()
          |> Enum.map(& &1.days_to_recovery)
          |> Enum.max(fn -> 1 end)

        raw = proj.confidence * (1 - proj.days_to_recovery / max(max_days, 1))
        max(0.0, min(1.0, raw))
    end
  end

  defp create_recommendation_alert(farm_id, top) do
    %Alert{}
    |> Alert.changeset(%{
      farm_id: farm_id,
      type: "GRAZING_RECOMMENDATION",
      message:
        "Recommended paddock: \"#{top.name}\" " <>
          "(score: #{top.score}, NDVI: #{top.ndvi})",
      is_resolved: false,
      severity: "info",
      priority: "low"
    })
    |> Repo.insert()
  end
end
