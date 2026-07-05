defmodule LivestokOs.CarbonSequestrationTest do
  @moduledoc """
  Tests for CarbonSequestration.calculate_and_store/6.

  Hand-computed expected outputs per the Stage 4A formula:
    Carbon Sequestered (tCO2e) = soil_type_factor × NDVI_grass_growth_index × rotational_compliance_score

  Example 1 — full compliance (score = 1.0):
    soil_type_factor = 2.5, ndvi_score = 0.8, compliance_score = 1.0
    carbon_tco2e    = 2.5 × 0.8 × 1.0 = 2.0

  Example 2 — partial compliance (score = 0.6):
    soil_type_factor = 2.5, ndvi_score = 0.8, compliance_score = 0.6
    carbon_tco2e    = 2.5 × 0.8 × 0.6 = 1.2

  The multiplier penalises (not bonuses) partial compliance.
  """

  use LivestokOs.DataCase

  alias LivestokOs.CarbonSequestration
  alias LivestokOs.Carbon.CarbonSequestrationRecord
  alias LivestokOs.Inventory

  setup do
    {:ok, farm} =
      Inventory.create_farm(%{
        name: "Carbon Test Farm #{System.unique_integer([:positive])}",
        location: "Test",
        grazing_mode: :pasture
      })

    {:ok, paddock} =
      LivestokOs.Infrastructure.create_geofence(%{
        name: "Carbon Paddock #{System.unique_integer([:positive])}",
        enforcement_scope: "keep_in",
        geometry: %{
          "type" => "circle",
          "center_lat" => 0.0,
          "center_lng" => 0.0,
          "radius_m" => 100.0
        },
        is_active: true,
        farm_id: farm.id,
        soil_type_factor: 2.5,
        soil_classification: "clay_loam"
      })

    period_start = ~U[2026-01-01 00:00:00Z]
    period_end = ~U[2026-01-28 00:00:00Z]

    %{farm: farm, paddock: paddock, period_start: period_start, period_end: period_end}
  end

  describe "calculate_and_store/6" do
    test "full compliance (score=1.0): carbon_tco2e = soil_factor × ndvi × compliance",
         %{farm: farm, paddock: paddock, period_start: ps, period_end: pe} do
      # Hand-computed: 2.5 × 0.8 × 1.0 = 2.0
      assert {:ok, %CarbonSequestrationRecord{} = record} =
               CarbonSequestration.calculate_and_store(farm, paddock, 0.8, 1.0, ps, pe)

      assert record.carbon_tco2e == 2.0
      assert record.soil_type_factor == 2.5
      assert record.ndvi_score == 0.8
      assert record.compliance_score == 1.0
      assert record.farm_id == farm.id
      assert record.paddock_id == paddock.id
    end

    test "partial compliance (score=0.6) penalises: carbon_tco2e < full-compliance value",
         %{farm: farm, paddock: paddock, period_start: ps, period_end: pe} do
      # Hand-computed: 2.5 × 0.8 × 0.6 = 1.2
      assert {:ok, %CarbonSequestrationRecord{} = record} =
               CarbonSequestration.calculate_and_store(farm, paddock, 0.8, 0.6, ps, pe)

      assert record.carbon_tco2e == 1.2
      # Confirm penalty: 1.2 < 2.0 (full-compliance value)
      assert record.carbon_tco2e < 2.0
    end

    test "returns error when farm is zero_grazing (feature disabled)" do
      {:ok, zero_farm} =
        Inventory.create_farm(%{
          name: "ZG Farm #{System.unique_integer([:positive])}",
          location: "Test",
          grazing_mode: :zero_grazing
        })

      {:ok, paddock} =
        LivestokOs.Infrastructure.create_geofence(%{
          name: "ZG Paddock",
          enforcement_scope: "keep_in",
          geometry: %{"type" => "circle", "center_lat" => 0.0, "center_lng" => 0.0, "radius_m" => 100.0},
          is_active: true,
          farm_id: zero_farm.id,
          soil_type_factor: 2.5
        })

      assert {:error, :wrong_grazing_mode} =
               CarbonSequestration.calculate_and_store(
                 zero_farm, paddock, 0.8, 1.0,
                 ~U[2026-01-01 00:00:00Z], ~U[2026-01-28 00:00:00Z]
               )
    end

    test "returns error when paddock has no soil_type_factor",
         %{farm: farm, period_start: ps, period_end: pe} do
      {:ok, bare_paddock} =
        LivestokOs.Infrastructure.create_geofence(%{
          name: "Bare Paddock #{System.unique_integer([:positive])}",
          enforcement_scope: "keep_in",
          geometry: %{"type" => "circle", "center_lat" => 0.0, "center_lng" => 0.0, "radius_m" => 100.0},
          is_active: true,
          farm_id: farm.id
          # no soil_type_factor — farmer hasn't provided it yet
        })

      assert {:error, :soil_type_factor_missing} =
               CarbonSequestration.calculate_and_store(farm, bare_paddock, 0.8, 1.0, ps, pe)
    end
  end

  describe "check_ndvi_alert/3" do
    test "creates NDVI_LOW_CARBON alert when ndvi < threshold",
         %{farm: farm, paddock: paddock} do
      farm_with_threshold = Map.put(farm, :ndvi_alert_threshold, 0.4)

      CarbonSequestration.check_ndvi_alert(farm_with_threshold, paddock.id, 0.25)

      import Ecto.Query
      alerts = from(a in LivestokOs.Operations.Alert, where: a.type == "NDVI_LOW_CARBON" and a.farm_id == ^farm.id)
               |> Repo.all()

      assert length(alerts) == 1
      assert String.contains?(hd(alerts).message, "lick block")
    end

    test "no alert when ndvi >= threshold", %{farm: farm, paddock: paddock} do
      farm_with_threshold = Map.put(farm, :ndvi_alert_threshold, 0.4)

      CarbonSequestration.check_ndvi_alert(farm_with_threshold, paddock.id, 0.55)

      import Ecto.Query
      alerts = from(a in LivestokOs.Operations.Alert, where: a.type == "NDVI_LOW_CARBON" and a.farm_id == ^farm.id)
               |> Repo.all()

      assert alerts == []
    end

    test "no alert when threshold is nil (not configured)", %{farm: farm, paddock: paddock} do
      # farm.ndvi_alert_threshold is nil by default
      CarbonSequestration.check_ndvi_alert(farm, paddock.id, 0.1)

      import Ecto.Query
      alerts = from(a in LivestokOs.Operations.Alert, where: a.type == "NDVI_LOW_CARBON")
               |> Repo.all()

      assert alerts == []
    end
  end
end
