defmodule LivestokOs.FarmsFeatureTest do
  @moduledoc """
  Tests for `LivestokOs.Inventory.feature_enabled?/2`.

  Verifies that farm grazing_mode correctly gates pasture-only and
  zero-grazing-only features, and that mixed farms enable both.
  """

  use LivestokOs.DataCase

  alias LivestokOs.Inventory

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp pasture_farm do
    {:ok, farm} =
      Inventory.create_farm(%{
        name: "Pasture Farm #{System.unique_integer([:positive])}",
        location: "Test",
        grazing_mode: :pasture
      })

    farm
  end

  defp zero_grazing_farm do
    {:ok, farm} =
      Inventory.create_farm(%{
        name: "Zero Grazing Farm #{System.unique_integer([:positive])}",
        location: "Test",
        grazing_mode: :zero_grazing
      })

    farm
  end

  defp mixed_farm do
    {:ok, farm} =
      Inventory.create_farm(%{
        name: "Mixed Farm #{System.unique_integer([:positive])}",
        location: "Test",
        grazing_mode: :mixed
      })

    farm
  end

  # ---------------------------------------------------------------------------
  # Feature-flag correctness
  # ---------------------------------------------------------------------------

  describe "pasture features" do
    test ":zero_grazing farm returns false for :grazing_coach" do
      farm = zero_grazing_farm()
      refute Inventory.feature_enabled?(farm, :grazing_coach)
    end

    test ":zero_grazing farm returns false for :satellite_ndvi" do
      farm = zero_grazing_farm()
      refute Inventory.feature_enabled?(farm, :satellite_ndvi)
    end

    test ":zero_grazing farm returns false for :virtual_fence_rotation" do
      farm = zero_grazing_farm()
      refute Inventory.feature_enabled?(farm, :virtual_fence_rotation)
    end

    test ":pasture farm returns true for :grazing_coach" do
      farm = pasture_farm()
      assert Inventory.feature_enabled?(farm, :grazing_coach)
    end

    test ":pasture farm returns true for :satellite_ndvi" do
      farm = pasture_farm()
      assert Inventory.feature_enabled?(farm, :satellite_ndvi)
    end
  end

  describe "zero-grazing features" do
    test ":pasture farm returns false for :rfid_inhibitor_dosing" do
      farm = pasture_farm()
      refute Inventory.feature_enabled?(farm, :rfid_inhibitor_dosing)
    end

    test ":pasture farm returns false for :feed_robot_integration" do
      farm = pasture_farm()
      refute Inventory.feature_enabled?(farm, :feed_robot_integration)
    end

    test ":pasture farm returns false for :bms_climate_control" do
      farm = pasture_farm()
      refute Inventory.feature_enabled?(farm, :bms_climate_control)
    end

    test ":zero_grazing farm returns true for :rfid_inhibitor_dosing" do
      farm = zero_grazing_farm()
      assert Inventory.feature_enabled?(farm, :rfid_inhibitor_dosing)
    end
  end

  describe "mixed farm enables both feature sets" do
    test ":mixed farm returns true for :grazing_coach" do
      farm = mixed_farm()
      assert Inventory.feature_enabled?(farm, :grazing_coach)
    end

    test ":mixed farm returns true for :satellite_ndvi" do
      farm = mixed_farm()
      assert Inventory.feature_enabled?(farm, :satellite_ndvi)
    end

    test ":mixed farm returns true for :rfid_inhibitor_dosing" do
      farm = mixed_farm()
      assert Inventory.feature_enabled?(farm, :rfid_inhibitor_dosing)
    end

    test ":mixed farm returns true for :feed_robot_integration" do
      farm = mixed_farm()
      assert Inventory.feature_enabled?(farm, :feed_robot_integration)
    end

    test ":mixed farm returns true for :bms_climate_control" do
      farm = mixed_farm()
      assert Inventory.feature_enabled?(farm, :bms_climate_control)
    end
  end

  describe "farm_id overload" do
    test "feature_enabled?/2 accepts an integer farm_id" do
      farm = pasture_farm()
      assert Inventory.feature_enabled?(farm.id, :grazing_coach)
    end
  end

  describe "unknown features" do
    test "returns false for an unknown feature" do
      farm = mixed_farm()
      refute Inventory.feature_enabled?(farm, :some_unknown_feature)
    end
  end

end
