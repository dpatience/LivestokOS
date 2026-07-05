defmodule LivestokOs.Operations.GrazingCoach do
  @moduledoc """
  Advisory monitoring layer — evaluates pasture quality and triggers
  methane-risk, overgrazing, and heat-stress alerts with 24-hour deduplication.

  Satellite calls are isolated to a configurable module (default:
  `LivestokOs.Satellite`) so tests can substitute a stub without coupling
  to real HTTP calls.  All satellite errors are handled gracefully: a failure
  logs a warning and returns `{:ok, :satellite_unavailable}` rather than
  crashing the caller.

  ## Feature gating
  Entry points respect `LivestokOs.Inventory.feature_enabled?/2`:
  - `check_methane_risk/4` with an explicit `farm_id` skips the check and
    returns `{:ok, :feature_disabled}` when `:grazing_coach` is not enabled
    for the farm.
  - `check_grazing_pressure/0` filters paddocks to farms whose grazing_mode
    enables `:grazing_coach`.
  - `check_heat_stress/2` dispatches mode-aware alerts:
    * `:zero_grazing` → BMS command alert (gated on `:bms_climate_control` feature)
    * `:pasture` → shade/water access alert
    * `:mixed` → both types

  When `farm_id` is `nil` the feature gate is bypassed for backward
  compatibility (useful for legacy callers and tests that do not provide a
  farm_id).
  """
  import Ecto.Query, warn: false
  alias LivestokOs.Repo
  alias LivestokOs.Operations.Alert
  alias LivestokOs.Infrastructure.Geofence
  alias LivestokOs.Inventory
  alias LivestokOs.Inventory.Farm

  require Logger

  @dedup_window_hours 24

  # ---------------------------------------------------------------------------
  # Heat stress (per-cow, triggered from digital twin or ingest)
  # ---------------------------------------------------------------------------

  @doc """
  Dispatches mode-aware heat-stress alerts for a cow, based on the farm's
  `grazing_mode`.

  - `:zero_grazing` → creates a `"bms_command"` alert if
    `:bms_climate_control` feature is enabled; logs a warning and skips
    otherwise.
  - `:pasture` → creates a `"shade_water_alert"` (no BMS command).
  - `:mixed` → creates both types.

  Returns a list of `{type, result}` tuples where each result is either
  `{:ok, alert}`, `{:error, reason}`, or `:feature_disabled`.
  """
  def check_heat_stress(cow_id, farm_id) do
    farm = Repo.get!(Farm, farm_id)
    dispatch_heat_stress_alerts(cow_id, farm)
  end

  defp dispatch_heat_stress_alerts(cow_id, %Farm{grazing_mode: mode} = farm)
       when mode in [:zero_grazing, :mixed] do
    bms_result =
      if Inventory.feature_enabled?(farm, :bms_climate_control) do
        {:bms_command,
         create_heat_stress_alert(cow_id, farm.id, "bms_command",
           "Heat stress: trigger fan/misting BMS command"
         )}
      else
        Logger.warning(
          "GrazingCoach: bms_climate_control feature disabled for farm #{farm.id}, " <>
            "skipping BMS command alert for cow #{cow_id}"
        )

        {:bms_command, :feature_disabled}
      end

    if mode == :mixed do
      shade_result =
        {:shade_water_alert,
         create_heat_stress_alert(cow_id, farm.id, "shade_water_alert",
           "Heat stress: ensure shade and water access"
         )}

      [bms_result, shade_result]
    else
      [bms_result]
    end
  end

  defp dispatch_heat_stress_alerts(cow_id, %Farm{grazing_mode: :pasture} = farm) do
    result =
      {:shade_water_alert,
       create_heat_stress_alert(cow_id, farm.id, "shade_water_alert",
         "Heat stress: ensure shade and water access"
       )}

    [result]
  end

  defp dispatch_heat_stress_alerts(_cow_id, %Farm{} = _farm) do
    []
  end

  defp create_heat_stress_alert(cow_id, farm_id, type, message) do
    %Alert{}
    |> Alert.changeset(%{
      cow_id: cow_id,
      farm_id: farm_id,
      type: type,
      message: message,
      is_resolved: false,
      severity: "warning"
    })
    |> Repo.insert()
  end

  # ---------------------------------------------------------------------------
  # Methane risk (per-cow, triggered from ingest pipeline)
  # ---------------------------------------------------------------------------

  @doc """
  Checks NDVI at the cow's location. If grass is dry (NDVI < 0.3),
  creates a METHANE_RISK alert unless one already exists within the
  deduplication window.

  When `farm_id` is provided (non-nil), the `:grazing_coach` feature flag
  is checked. Returns `{:ok, :feature_disabled}` for zero_grazing farms.
  """
  def check_methane_risk(cow_id, lat, long, farm_id \\ nil) do
    if farm_id && !feature_enabled_for_farm?(farm_id, :grazing_coach) do
      {:ok, :feature_disabled}
    else
      do_check_methane_risk(cow_id, lat, long)
    end
  end

  defp do_check_methane_risk(cow_id, lat, long) do
    satellite = satellite_module()

    result =
      try do
        satellite.get_current_ndvi(lat, long)
      rescue
        e ->
          Logger.warning(
            "GrazingCoach: satellite raised #{inspect(e.__struct__)} for cow #{cow_id}, " <>
              "treating as unavailable"
          )

          {:error, :satellite_raised}
      end

    case result do
      {:ok, ndvi} when ndvi < 0.3 ->
        if recent_alert_exists?(cow_id, "METHANE_RISK") do
          {:ok, :alert_already_active}
        else
          create_methane_alert(cow_id, ndvi)
        end

      {:ok, _ndvi} ->
        {:ok, :safe_grazing}

      {:error, reason} ->
        Logger.warning(
          "GrazingCoach: satellite unavailable (#{inspect(reason)}), " <>
            "skipping methane risk check for cow #{cow_id}"
        )

        {:ok, :satellite_unavailable}
    end
  end

  # ---------------------------------------------------------------------------
  # Grazing pressure (per-paddock, run periodically by GrazingCoachServer)
  # ---------------------------------------------------------------------------

  @doc """
  Evaluates grazing pressure for all active keep_in paddocks whose farm has
  the `:grazing_coach` feature enabled (i.e. `grazing_mode` is `:pasture` or
  `:mixed`).

  Uses satellite NDVI at a representative coordinate (currently the origin
  of the paddock geometry).  If NDVI < 0.2 (severely depleted pasture),
  raises an OVERGRAZING alert.

  TODO: replace the fixed origin with `ST_Centroid` once paddock geometry
  is stored as a PostGIS type; the current JSONB map does not support
  centroid computation server-side without deserialisation.
  """
  def check_grazing_pressure do
    satellite = satellite_module()

    paddocks =
      from(g in Geofence,
        join: f in Farm,
        on: g.farm_id == f.id,
        where:
          g.is_active == true and
            g.enforcement_scope == "keep_in" and
            f.grazing_mode in ^["pasture", "mixed"]
      )
      |> Repo.all()

    Enum.each(paddocks, fn paddock ->
      {lat, lng} = centroid_approx(paddock.geometry)

      case satellite.get_current_ndvi(lat, lng) do
        {:ok, ndvi} when ndvi < 0.2 ->
          unless recent_paddock_alert_exists?(paddock.id) do
            create_overgrazing_alert(paddock, ndvi)
          end

        {:ok, _ndvi} ->
          :ok

        {:error, reason} ->
          Logger.warning(
            "GrazingCoach: satellite unavailable (#{inspect(reason)}), " <>
              "skipping pressure check for paddock #{paddock.id}"
          )
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp feature_enabled_for_farm?(farm_id, feature) do
    try do
      Inventory.feature_enabled?(farm_id, feature)
    rescue
      Ecto.NoResultsError ->
        Logger.warning("GrazingCoach: farm #{farm_id} not found, skipping feature check")
        false
    end
  end

  defp satellite_module do
    Application.get_env(:livestok_os_ops, :satellite_module, LivestokOs.Satellite)
  end

  # Approximate centroid: use first polygon coordinate or default to origin.
  # TODO: replace with PostGIS ST_Centroid when geometry is a native PostGIS type.
  defp centroid_approx(%{"type" => "polygon", "coordinates" => [[lng, lat] | _]}), do: {lat, lng}
  defp centroid_approx(%{"type" => "circle", "center_lat" => lat, "center_lng" => lng}), do: {lat, lng}
  defp centroid_approx(%{"type" => "rectangle", "min_lat" => min_lat, "max_lat" => max_lat,
                         "min_lng" => min_lng, "max_lng" => max_lng}) do
    {(min_lat + max_lat) / 2.0, (min_lng + max_lng) / 2.0}
  end
  defp centroid_approx(_), do: {0.0, 0.0}

  defp recent_alert_exists?(cow_id, type) do
    cutoff = DateTime.utc_now() |> DateTime.add(-@dedup_window_hours * 3600, :second)

    from(a in Alert,
      where:
        a.cow_id == ^cow_id and
          a.type == ^type and
          a.is_resolved == false and
          a.inserted_at >= ^cutoff
    )
    |> Repo.exists?()
  end

  defp recent_paddock_alert_exists?(geofence_id) do
    cutoff = DateTime.utc_now() |> DateTime.add(-@dedup_window_hours * 3600, :second)
    marker = "geofence_id=#{geofence_id}"

    from(a in Alert,
      where:
        a.type == "OVERGRAZING" and
          a.is_resolved == false and
          a.inserted_at >= ^cutoff and
          like(a.message, ^"%#{marker}%")
    )
    |> Repo.exists?()
  end

  defp create_methane_alert(cow_id, ndvi) do
    %Alert{}
    |> Alert.changeset(%{
      cow_id: cow_id,
      type: "METHANE_RISK",
      message:
        "Pasture quality low (NDVI: #{ndvi}). Methane risk high. Deploy Molasses Lick Blocks immediately.",
      is_resolved: false
    })
    |> Repo.insert()
  end

  defp create_overgrazing_alert(paddock, ndvi) do
    %Alert{}
    |> Alert.changeset(%{
      type: "OVERGRAZING",
      message:
        "Paddock \"#{paddock.name}\" is overgrazed (NDVI: #{ndvi}). " <>
          "geofence_id=#{paddock.id}. Rotate cattle immediately.",
      is_resolved: false
    })
    |> Repo.insert()
  end
end
