defmodule LivestokOs.Operations.GrazingCoachFeatureTest do
  @moduledoc """
  Tests that `GrazingCoach` respects the farm's `grazing_mode` feature gate.

  - A `:zero_grazing` farm cannot trigger coaching (check_methane_risk returns
    `{:ok, :feature_disabled}` when farm_id is passed).
  - A `:pasture` farm cannot trigger RFID inhibitor dosing (feature not in
    the pasture feature set — tested via Inventory.feature_enabled? directly).
  - `check_grazing_pressure/0` skips paddocks on zero-grazing farms.
  """

  use LivestokOs.DataCase

  alias LivestokOs.Inventory
  alias LivestokOs.Operations.GrazingCoach

  defmodule StubSatellite do
    @moduledoc false
    def get_current_ndvi(_lat, _lng), do: {:ok, 0.1}
    def get_soil_factor(_lat, _lng), do: 1.0
  end

  setup do
    Application.put_env(:livestok_os_ops, :satellite_module, StubSatellite)
    on_exit(fn -> Application.delete_env(:livestok_os_ops, :satellite_module) end)
    :ok
  end

  test ":zero_grazing farm cannot trigger a paddock-rotation coaching job" do
    {:ok, farm} =
      Inventory.create_farm(%{
        name: "ZG Farm #{System.unique_integer([:positive])}",
        location: "Test",
        grazing_mode: :zero_grazing
      })

    {:ok, cow} =
      Inventory.create_cow(%{
        tag_id: "ZG-COW-#{System.unique_integer([:positive])}",
        name: "Test",
        breed: "Angus",
        birth_date: ~D[2023-01-01],
        status: "active",
        farm_id: farm.id
      })

    result = GrazingCoach.check_methane_risk(cow.id, 0.0, 0.0, farm.id)
    assert result == {:ok, :feature_disabled}
  end

  test ":pasture farm cannot trigger RFID inhibitor dosing (feature disabled)" do
    {:ok, farm} =
      Inventory.create_farm(%{
        name: "Pasture Farm #{System.unique_integer([:positive])}",
        location: "Test",
        grazing_mode: :pasture
      })

    refute Inventory.feature_enabled?(farm, :rfid_inhibitor_dosing)
  end

  test "check_grazing_pressure/0 skips paddocks on zero_grazing farms" do
    # Create a zero_grazing farm with a keep_in paddock
    {:ok, farm} =
      Inventory.create_farm(%{
        name: "ZG Pressure Farm #{System.unique_integer([:positive])}",
        location: "Test",
        grazing_mode: :zero_grazing
      })

    {:ok, _paddock} =
      LivestokOs.Infrastructure.create_geofence(%{
        name: "Zero Grazing Paddock",
        enforcement_scope: "keep_in",
        geometry: %{"type" => "circle", "center_lat" => 0.0, "center_lng" => 0.0, "radius_m" => 100.0},
        is_active: true,
        farm_id: farm.id
      })

    # GrazingCoach.check_grazing_pressure/0 will query paddocks joined to farms
    # with grazing_mode in [:pasture, :mixed]. Zero-grazing paddocks are excluded.
    # The satellite stub would return NDVI 0.1 (< 0.2 threshold), so if the
    # paddock were included, an OVERGRAZING alert would be created.
    # Assert no alert is created for this farm.
    GrazingCoach.check_grazing_pressure()

    import Ecto.Query
    alert_count =
      LivestokOs.Repo.one(
        from(a in LivestokOs.Operations.Alert,
          where: a.type == "OVERGRAZING" and like(a.message, ^"%Zero Grazing Paddock%"),
          select: count(a.id)
        )
      )

    assert alert_count == 0
  end
end
