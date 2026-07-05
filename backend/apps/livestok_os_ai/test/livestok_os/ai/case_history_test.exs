defmodule LivestokOs.AI.CaseHistoryTest do
  use LivestokOs.AI.DataCase

  alias LivestokOs.AI.CaseHistory
  alias LivestokOs.Inventory.{Farm, Cow}
  alias LivestokOs.Telemetry.CowStateLog
  alias LivestokOs.ZeroGrazing.FeedEvent
  alias LivestokOs.Operations.Alert

  defp create_farm do
    {:ok, farm} =
      Repo.insert(Farm.changeset(%Farm{}, %{name: "Test Farm", location: "Nairobi"}))

    farm
  end

  defp create_cow(farm_id) do
    {:ok, cow} =
      Repo.insert(
        Cow.changeset(%Cow{}, %{
          tag_id: "COW-#{System.unique_integer([:positive])}",
          name: "Bessie",
          breed: "Holstein",
          birth_date: ~D[2020-01-01],
          status: "active",
          farm_id: farm_id
        })
      )

    cow
  end

  describe "build/2" do
    test "builds timeline across 3+ subsystems, sorted by timestamp" do
      farm = create_farm()
      cow = create_cow(farm.id)

      t1 = ~U[2026-06-01 08:00:00Z]
      t2 = ~U[2026-06-15 10:00:00Z]
      _t3 = ~U[2026-07-01 14:00:00Z]

      Repo.insert!(
        CowStateLog.changeset(%CowStateLog{}, %{
          cow_id: cow.id,
          farm_id: farm.id,
          from_state: "resting",
          to_state: "grazing",
          occurred_at: t1
        })
      )

      Repo.insert!(
        FeedEvent.changeset(%FeedEvent{}, %{
          cow_id: cow.id,
          farm_id: farm.id,
          feed_type: "hay",
          quantity_kg: 5.0,
          fed_at: t2
        })
      )

      Repo.insert!(
        Alert.changeset(%Alert{}, %{
          cow_id: cow.id,
          farm_id: farm.id,
          type: "HEALTH_CHECK",
          message: "Scheduled vet visit",
          is_resolved: false
        })
      )

      result = CaseHistory.build(cow.id, farm.id)

      assert result.cow_id == cow.id
      assert result.farm_id == farm.id
      assert result.summary.total_events >= 3

      sources = Enum.map(result.timeline, & &1.source) |> Enum.uniq()
      assert :cow_state_log in sources
      assert :feed_event in sources
      assert :alert in sources

      timestamps = Enum.map(result.timeline, & &1.timestamp)
      assert timestamps == Enum.sort(timestamps, {:asc, DateTime})
    end

    test "returns empty timeline for cow with no events" do
      farm = create_farm()
      cow = create_cow(farm.id)

      result = CaseHistory.build(cow.id, farm.id)
      assert result.timeline == []
      assert result.summary.total_events == 0
    end
  end
end
