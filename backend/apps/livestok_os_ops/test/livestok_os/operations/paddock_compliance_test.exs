defmodule LivestokOs.Operations.PaddockComplianceTest do
  @moduledoc """
  Tests for PaddockCompliance.get_compliance/2 and on_rotation_event/1.

  Confirms the compliance_score field is stored in the DB and queryable.
  """

  use LivestokOs.DataCase

  alias LivestokOs.Operations.PaddockCompliance
  alias LivestokOs.Infrastructure.{PaddockComplianceScore, RotationEvent}
  alias LivestokOs.Inventory

  setup do
    {:ok, farm} =
      Inventory.create_farm(%{
        name: "Compliance Test Farm #{System.unique_integer([:positive])}",
        location: "Test",
        grazing_mode: :pasture
      })

    {:ok, paddock} =
      LivestokOs.Infrastructure.create_geofence(%{
        name: "Test Paddock #{System.unique_integer([:positive])}",
        enforcement_scope: "keep_in",
        geometry: %{"type" => "circle", "center_lat" => 0.0, "center_lng" => 0.0, "radius_m" => 100.0},
        is_active: true,
        farm_id: farm.id
      })

    %{farm: farm, paddock: paddock}
  end

  describe "get_compliance/2" do
    test "returns {:error, :no_data} when no compliance record exists", %{farm: farm, paddock: paddock} do
      assert {:error, :no_data} = PaddockCompliance.get_compliance(paddock.id, farm.id)
    end

    test "returns {:ok, score} with a queryable compliance_score after a rotation event", %{
      farm: farm,
      paddock: paddock
    } do
      rotation = %RotationEvent{
        paddock_id: paddock.id,
        farm_id: farm.id,
        occurred_at: DateTime.utc_now(),
        centroid_lat: 0.0,
        centroid_lng: 0.0
      }

      assert {:ok, _updated} = PaddockCompliance.on_rotation_event(rotation)
      assert {:ok, %PaddockComplianceScore{} = score} = PaddockCompliance.get_compliance(paddock.id, farm.id)
      # 1 actual rotation out of 4 prescribed → 0.25
      assert score.compliance_score == 0.25
      assert is_float(score.compliance_score)
    end

    test "compliance_score caps at 1.0 when actual exceeds prescribed", %{farm: farm, paddock: paddock} do
      now = DateTime.utc_now()

      for _i <- 1..6 do
        rotation = %RotationEvent{
          paddock_id: paddock.id,
          farm_id: farm.id,
          occurred_at: now,
          centroid_lat: 0.0,
          centroid_lng: 0.0
        }
        PaddockCompliance.on_rotation_event(rotation)
      end

      assert {:ok, score} = PaddockCompliance.get_compliance(paddock.id, farm.id)
      assert score.compliance_score == 1.0
    end
  end
end
