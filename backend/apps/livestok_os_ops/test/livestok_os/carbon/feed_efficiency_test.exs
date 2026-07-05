defmodule LivestokOs.FeedEfficiencyTest do
  @moduledoc """
  Tests for FeedEfficiency.calculate_and_store/2 and ranked_recommendations/1.
  """

  use LivestokOs.DataCase

  alias LivestokOs.FeedEfficiency
  alias LivestokOs.Carbon.FeedEfficiencyRecord
  alias LivestokOs.Inventory
  alias LivestokOs.Operations

  setup do
    {:ok, farm} =
      Inventory.create_farm(%{
        name: "FeedEff Test Farm #{System.unique_integer([:positive])}",
        location: "Test",
        grazing_mode: :pasture
      })

    {:ok, cow} =
      Inventory.create_cow(%{
        tag_id: "FE-#{System.unique_integer([:positive])}",
        name: "Test Cow",
        breed: "Angus",
        birth_date: ~D[2023-01-01],
        status: "active",
        farm_id: farm.id
      })

    %{farm: farm, cow: cow}
  end

  describe "calculate_and_store/2" do
    test "returns error when no abattoir record exists", %{cow: cow, farm: farm} do
      assert {:error, :no_abattoir_record} = FeedEfficiency.calculate_and_store(cow.id, farm.id)
    end

    test "computes feed efficiency index = deadweight_kg / grazing_hours", %{cow: cow, farm: farm} do
      {:ok, _} = FeedEfficiency.record_deadweight(cow.id, farm.id, 300.0)

      # Insert a grazing event with 10 hours of grazing
      t0 = ~U[2026-01-01 08:00:00Z]
      t1 = ~U[2026-01-01 18:00:00Z]

      {:ok, _} =
        Operations.create_grazing_event(%{
          cow_id: cow.id,
          farm_id: farm.id,
          zone_id: "paddock-1",
          entered_at: t0,
          left_at: t1
        })

      assert {:ok, %FeedEfficiencyRecord{} = record} =
               FeedEfficiency.calculate_and_store(cow.id, farm.id)

      # 300 kg / 10 hours = 30.0 kg/h
      assert record.deadweight_kg == 300.0
      assert record.cumulative_grazing_hours == 10.0
      assert record.feed_efficiency_index == 30.0
    end
  end

  describe "ranked_recommendations/1" do
    test "returns animals ranked by feed_efficiency_index descending (best first)", %{farm: farm} do
      {:ok, cow_a} =
        Inventory.create_cow(%{
          tag_id: "FE-A-#{System.unique_integer([:positive])}",
          name: "Best Cow",
          breed: "Angus",
          birth_date: ~D[2023-01-01],
          status: "active",
          farm_id: farm.id
        })

      {:ok, cow_b} =
        Inventory.create_cow(%{
          tag_id: "FE-B-#{System.unique_integer([:positive])}",
          name: "Culling Candidate",
          breed: "Angus",
          birth_date: ~D[2023-01-01],
          status: "active",
          farm_id: farm.id
        })

      now = DateTime.utc_now()

      {:ok, _} =
        %FeedEfficiencyRecord{}
        |> FeedEfficiencyRecord.changeset(%{
          cow_id: cow_a.id,
          farm_id: farm.id,
          calculated_at: now,
          deadweight_kg: 400.0,
          cumulative_grazing_hours: 10.0,
          feed_efficiency_index: 40.0
        })
        |> Repo.insert()

      {:ok, _} =
        %FeedEfficiencyRecord{}
        |> FeedEfficiencyRecord.changeset(%{
          cow_id: cow_b.id,
          farm_id: farm.id,
          calculated_at: now,
          deadweight_kg: 200.0,
          cumulative_grazing_hours: 10.0,
          feed_efficiency_index: 20.0
        })
        |> Repo.insert()

      # Default: descending (best performers first)
      recs = FeedEfficiency.ranked_recommendations(farm.id)
      assert length(recs) == 2
      assert hd(recs).cow_id == cow_a.id
      assert hd(recs).feed_efficiency_index == 40.0

      # Ascending: culling candidates first
      culling = FeedEfficiency.ranked_recommendations(farm.id, order: :asc)
      assert hd(culling).cow_id == cow_b.id
    end

    test "results are farm-scoped — other farms not returned", %{farm: farm, cow: cow} do
      {:ok, other_farm} =
        Inventory.create_farm(%{
          name: "Other Farm",
          location: "Other",
          grazing_mode: :pasture
        })

      now = DateTime.utc_now()

      {:ok, _} =
        %FeedEfficiencyRecord{}
        |> FeedEfficiencyRecord.changeset(%{
          cow_id: cow.id,
          farm_id: farm.id,
          calculated_at: now,
          deadweight_kg: 300.0,
          cumulative_grazing_hours: 10.0,
          feed_efficiency_index: 30.0
        })
        |> Repo.insert()

      # other_farm has no records
      assert FeedEfficiency.ranked_recommendations(other_farm.id) == []
    end
  end
end
