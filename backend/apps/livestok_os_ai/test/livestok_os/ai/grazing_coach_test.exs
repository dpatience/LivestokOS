defmodule LivestokOs.AI.GrazingCoachTest do
  use LivestokOs.AI.DataCase

  alias LivestokOs.AI.GrazingCoach
  alias LivestokOs.Inventory.Farm
  alias LivestokOs.Infrastructure.Geofence
  alias LivestokOs.Satellite.NdviReading
  alias LivestokOs.Infrastructure.RotationEvent
  alias LivestokOs.Satellite.GrassRecoveryProjection

  defp create_farm(attrs \\ %{}) do
    default = %{name: "Test Farm", location: "Nairobi", grazing_mode: :pasture}
    {:ok, farm} = Repo.insert(Farm.changeset(%Farm{}, Map.merge(default, attrs)))
    farm
  end

  defp create_paddock(farm_id, name) do
    {:ok, g} =
      Repo.insert(
        Geofence.changeset(%Geofence{}, %{
          name: name,
          enforcement_scope: "keep_in",
          geometry: %{"type" => "circle", "center_lat" => -1.0, "center_lng" => 36.0},
          is_active: true,
          farm_id: farm_id
        })
      )

    g
  end

  defp create_ndvi(paddock_id, farm_id, ndvi_score, opts \\ []) do
    is_stale = Keyword.get(opts, :is_stale, false)

    {:ok, r} =
      Repo.insert(
        NdviReading.changeset(%NdviReading{}, %{
          paddock_id: paddock_id,
          farm_id: farm_id,
          captured_at: DateTime.utc_now(),
          ndvi_score: ndvi_score,
          is_stale: is_stale
        })
      )

    r
  end

  defp create_rotation(paddock_id, farm_id, days_ago) do
    {:ok, r} =
      Repo.insert(
        RotationEvent.changeset(%RotationEvent{}, %{
          paddock_id: paddock_id,
          farm_id: farm_id,
          occurred_at: DateTime.add(DateTime.utc_now(), -days_ago * 86400, :second),
          centroid_lat: -1.0,
          centroid_lng: 36.0
        })
      )

    r
  end

  defp create_recovery(paddock_id, farm_id, days, confidence) do
    {:ok, p} =
      Repo.insert(
        GrassRecoveryProjection.changeset(%GrassRecoveryProjection{}, %{
          paddock_id: paddock_id,
          farm_id: farm_id,
          projected_at: DateTime.utc_now(),
          days_to_recovery: days,
          confidence: confidence,
          weather_source: "mock"
        })
      )

    p
  end

  describe "recommend/1" do
    test "zero_grazing farm returns feature_disabled" do
      farm = create_farm(%{grazing_mode: :zero_grazing})
      assert {:ok, %{recommendations: [], reason: :feature_disabled}} = GrazingCoach.recommend(farm.id)
    end

    test "all NDVI stale returns all_ndvi_stale" do
      farm = create_farm()
      p1 = create_paddock(farm.id, "Paddock P1")
      p2 = create_paddock(farm.id, "Paddock P2")
      create_ndvi(p1.id, farm.id, 0.5, is_stale: true)
      create_ndvi(p2.id, farm.id, 0.6, is_stale: true)

      assert {:ok, %{recommendations: [], reason: :all_ndvi_stale, stale_paddocks: stale}} =
               GrazingCoach.recommend(farm.id)

      assert length(stale) == 2
    end

    test "paddocks ranked correctly by score formula" do
      farm = create_farm()
      p1 = create_paddock(farm.id, "Low NDVI")
      p2 = create_paddock(farm.id, "High NDVI")

      create_ndvi(p1.id, farm.id, 0.3)
      create_ndvi(p2.id, farm.id, 0.8)

      create_rotation(p1.id, farm.id, 2)
      create_rotation(p2.id, farm.id, 10)

      create_recovery(p1.id, farm.id, 10, 0.5)
      create_recovery(p2.id, farm.id, 3, 0.8)

      assert {:ok, %{recommendations: recs}} = GrazingCoach.recommend(farm.id)
      assert length(recs) == 2

      [top | _] = recs
      assert top.name == "High NDVI"
    end

    test "stale paddock excluded from ranking but listed in stale_paddocks" do
      farm = create_farm()
      fresh = create_paddock(farm.id, "Fresh")
      stale = create_paddock(farm.id, "Stale")

      create_ndvi(fresh.id, farm.id, 0.6)
      create_ndvi(stale.id, farm.id, 0.7, is_stale: true)

      assert {:ok, %{recommendations: recs, stale_paddocks: stale_list}} =
               GrazingCoach.recommend(farm.id)

      assert length(recs) == 1
      assert hd(recs).name == "Fresh"
      assert length(stale_list) == 1
      assert hd(stale_list).name == "Stale"
    end
  end
end
