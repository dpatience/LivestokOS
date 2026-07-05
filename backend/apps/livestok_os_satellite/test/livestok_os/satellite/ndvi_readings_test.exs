defmodule LivestokOs.Satellite.NdviReadingsTest do
  @moduledoc """
  Tests for NdviReadings.latest_ndvi_for_paddock/1.

  Confirms the three possible return values:
  - {:ok, %NdviReading{}} — fresh reading
  - {:error, :stale}      — reading exists but is marked stale
  - {:error, :no_data}    — no reading at all for this paddock
  """

  use LivestokOsSatellite.DataCase

  alias LivestokOs.Satellite.{NdviReadings, NdviReading}
  alias LivestokOs.Inventory
  alias LivestokOs.Infrastructure

  setup do
    {:ok, farm} =
      Inventory.create_farm(%{
        name: "NDVI Test Farm #{System.unique_integer([:positive])}",
        location: "Test",
        grazing_mode: :pasture
      })

    {:ok, paddock} =
      Infrastructure.create_geofence(%{
        name: "Paddock #{System.unique_integer([:positive])}",
        enforcement_scope: "keep_in",
        geometry: %{"type" => "circle", "center_lat" => 0.0, "center_lng" => 0.0, "radius_m" => 100.0},
        is_active: true,
        farm_id: farm.id
      })

    %{farm: farm, paddock: paddock}
  end

  describe "latest_ndvi_for_paddock/1" do
    test "returns {:error, :no_data} when no reading exists", %{paddock: paddock} do
      assert {:error, :no_data} = NdviReadings.latest_ndvi_for_paddock(paddock.id)
    end

    test "returns {:ok, reading} for a fresh non-stale reading", %{farm: farm, paddock: paddock} do
      {:ok, reading} =
        %NdviReading{}
        |> NdviReading.changeset(%{
          paddock_id: paddock.id,
          farm_id: farm.id,
          captured_at: DateTime.utc_now(),
          ndvi_score: 0.65,
          is_stale: false
        })
        |> Repo.insert()

      assert {:ok, ^reading} = NdviReadings.latest_ndvi_for_paddock(paddock.id)
    end

    test "returns {:error, :stale} when the reading is marked stale", %{farm: farm, paddock: paddock} do
      {:ok, _reading} =
        %NdviReading{}
        |> NdviReading.changeset(%{
          paddock_id: paddock.id,
          farm_id: farm.id,
          captured_at: DateTime.utc_now() |> DateTime.add(-7 * 86_400, :second),
          ndvi_score: 0.45,
          is_stale: true
        })
        |> Repo.insert()

      assert {:error, :stale} = NdviReadings.latest_ndvi_for_paddock(paddock.id)
    end

    test "returns the most recent reading when multiple exist", %{farm: farm, paddock: paddock} do
      older_ts = DateTime.utc_now() |> DateTime.add(-86_400, :second)
      newer_ts = DateTime.utc_now()

      {:ok, _old} =
        %NdviReading{}
        |> NdviReading.changeset(%{
          paddock_id: paddock.id,
          farm_id: farm.id,
          captured_at: older_ts,
          ndvi_score: 0.30,
          is_stale: false
        })
        |> Repo.insert()

      {:ok, fresh} =
        %NdviReading{}
        |> NdviReading.changeset(%{
          paddock_id: paddock.id,
          farm_id: farm.id,
          captured_at: newer_ts,
          ndvi_score: 0.72,
          is_stale: false
        })
        |> Repo.insert()

      assert {:ok, returned} = NdviReadings.latest_ndvi_for_paddock(paddock.id)
      assert returned.id == fresh.id
      assert returned.ndvi_score == 0.72
    end
  end
end
