defmodule LivestokOs.Operations.HeatStressTest do
  @moduledoc """
  Tests for mode-aware heat-stress alert dispatch in GrazingCoach.check_heat_stress/2.
  """

  use LivestokOs.DataCase

  alias LivestokOs.Inventory
  alias LivestokOs.Operations.GrazingCoach
  alias LivestokOs.Operations.Alert
  import Ecto.Query

  defp create_farm(mode) do
    {:ok, farm} =
      Inventory.create_farm(%{
        name: "Heat Test Farm #{System.unique_integer([:positive])}",
        location: "Test",
        grazing_mode: mode
      })

    farm
  end

  defp create_cow(farm_id) do
    {:ok, cow} =
      Inventory.create_cow(%{
        tag_id: "HS-COW-#{System.unique_integer([:positive])}",
        name: "Heat Cow",
        breed: "Angus",
        birth_date: ~D[2022-01-01],
        status: "active",
        farm_id: farm_id
      })

    cow
  end

  defp alerts_for_cow_and_type(cow_id, type) do
    LivestokOs.Repo.all(
      from(a in Alert,
        where: a.cow_id == ^cow_id and a.type == ^type
      )
    )
  end

  describe ":zero_grazing farm" do
    test "creates BMS command alert only — no shade/water alert" do
      farm = create_farm(:zero_grazing)
      cow = create_cow(farm.id)

      results = GrazingCoach.check_heat_stress(cow.id, farm.id)

      assert Enum.any?(results, fn
               {:bms_command, {:ok, _alert}} -> true
               _ -> false
             end)

      refute Enum.any?(results, fn
               {:shade_water_alert, _} -> true
               _ -> false
             end)

      bms_alerts = alerts_for_cow_and_type(cow.id, "bms_command")
      shade_alerts = alerts_for_cow_and_type(cow.id, "shade_water_alert")

      assert length(bms_alerts) == 1
      assert length(shade_alerts) == 0
    end

    test "skips BMS command when bms_climate_control feature is disabled" do
      # bms_climate_control is enabled for :zero_grazing; we can only test
      # the skip path by using a mode that does not enable the feature.
      # For full branch coverage we test :pasture instead, which also
      # does NOT create a BMS alert.
      farm = create_farm(:pasture)
      cow = create_cow(farm.id)

      results = GrazingCoach.check_heat_stress(cow.id, farm.id)

      refute Enum.any?(results, fn
               {:bms_command, _} -> true
               _ -> false
             end)
    end
  end

  describe ":pasture farm" do
    test "creates shade/water alert only — no BMS command alert" do
      farm = create_farm(:pasture)
      cow = create_cow(farm.id)

      results = GrazingCoach.check_heat_stress(cow.id, farm.id)

      assert Enum.any?(results, fn
               {:shade_water_alert, {:ok, _alert}} -> true
               _ -> false
             end)

      refute Enum.any?(results, fn
               {:bms_command, _} -> true
               _ -> false
             end)

      shade_alerts = alerts_for_cow_and_type(cow.id, "shade_water_alert")
      bms_alerts = alerts_for_cow_and_type(cow.id, "bms_command")

      assert length(shade_alerts) == 1
      assert length(bms_alerts) == 0
    end
  end

  describe ":mixed farm" do
    test "creates both BMS command alert AND shade/water alert" do
      farm = create_farm(:mixed)
      cow = create_cow(farm.id)

      results = GrazingCoach.check_heat_stress(cow.id, farm.id)

      assert Enum.any?(results, fn
               {:bms_command, {:ok, _}} -> true
               _ -> false
             end)

      assert Enum.any?(results, fn
               {:shade_water_alert, {:ok, _}} -> true
               _ -> false
             end)

      bms_alerts = alerts_for_cow_and_type(cow.id, "bms_command")
      shade_alerts = alerts_for_cow_and_type(cow.id, "shade_water_alert")

      assert length(bms_alerts) == 1
      assert length(shade_alerts) == 1
    end
  end
end
