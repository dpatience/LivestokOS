defmodule LivestokOs.ReproductionTest do
  use LivestokOs.DataCase

  alias LivestokOs.Inventory
  alias LivestokOs.Reproduction
  alias LivestokOs.Reproduction.{BreedingRecord, CalvingEvent, DryOffSchedule, Gestation}
  alias LivestokOs.Operations.Alert
  alias LivestokOs.Telemetry.CowStateLog

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp farm_fixture do
    {:ok, farm} =
      Inventory.create_farm(%{name: "Test Farm", location: "Nairobi", grazing_mode: :pasture})

    farm
  end

  defp cow_fixture(farm, attrs \\ %{}) do
    {:ok, cow} =
      Inventory.create_cow(
        Map.merge(
          %{
            tag_id: "TAG-#{System.unique_integer([:positive])}",
            name: "Bessie",
            breed: "Friesian",
            birth_date: ~D[2022-01-01],
            status: "active",
            farm_id: farm.id
          },
          attrs
        )
      )

    cow
  end

  defp breeding_record_fixture(cow, farm, attrs \\ %{}) do
    {:ok, record} =
      Reproduction.create_breeding_record(
        Map.merge(
          %{
            cow_id: cow.id,
            farm_id: farm.id,
            insemination_date: ~D[2026-01-01],
            method: :ai,
            outcome: :pending
          },
          attrs
        )
      )

    record
  end

  defp gestation_fixture(cow, farm, breeding_record) do
    {:ok, gestation} =
      Repo.insert(
        Gestation.changeset(%Gestation{}, %{
          cow_id: cow.id,
          farm_id: farm.id,
          breeding_record_id: breeding_record.id,
          conception_date: breeding_record.insemination_date,
          expected_calving_date: Reproduction.expected_calving_date(breeding_record),
          status: :active
        })
      )

    gestation
  end

  # ---------------------------------------------------------------------------
  # Sex field
  # ---------------------------------------------------------------------------

  describe "sex field" do
    test "cow created without sex field defaults to :unknown" do
      farm = farm_fixture()
      cow = cow_fixture(farm)
      assert cow.sex == :unknown
    end

    test "cow can be created with sex: :female" do
      farm = farm_fixture()
      cow = cow_fixture(farm, %{sex: :female})
      assert cow.sex == :female
    end

    test "cow can be created with sex: :male" do
      farm = farm_fixture()
      cow = cow_fixture(farm, %{sex: :male})
      assert cow.sex == :male
    end
  end

  # ---------------------------------------------------------------------------
  # Estrus proxy
  # ---------------------------------------------------------------------------

  describe "check_estrus_proxy/2" do
    test "returns {:likely_heat, score} above threshold when high grazing, low rumination" do
      farm = farm_fixture()
      cow = cow_fixture(farm, %{sex: :female})

      now = DateTime.truncate(DateTime.utc_now(), :second)

      # Insert 8 "grazing" logs and 1 "ruminating" log (high activity, low rumination)
      for _ <- 1..8 do
        Repo.insert!(%CowStateLog{
          cow_id: cow.id,
          farm_id: farm.id,
          from_state: "idle",
          to_state: "grazing",
          occurred_at: DateTime.add(now, -3600, :second),
          metadata: %{}
        })
      end

      Repo.insert!(%CowStateLog{
        cow_id: cow.id,
        farm_id: farm.id,
        from_state: "grazing",
        to_state: "ruminating",
        occurred_at: DateTime.add(now, -1800, :second),
        metadata: %{}
      })

      result = Reproduction.check_estrus_proxy(cow.id, farm_id: farm.id)

      assert {:likely_heat, score} = result
      assert score > 0.60
    end

    test "returns {:normal} when rumination is high and grazing is low" do
      farm = farm_fixture()
      cow = cow_fixture(farm, %{sex: :female})

      now = DateTime.truncate(DateTime.utc_now(), :second)

      # Insert 1 "grazing" log and 8 "ruminating" logs (normal behaviour)
      Repo.insert!(%CowStateLog{
        cow_id: cow.id,
        farm_id: farm.id,
        from_state: "idle",
        to_state: "grazing",
        occurred_at: DateTime.add(now, -3600, :second),
        metadata: %{}
      })

      for _ <- 1..8 do
        Repo.insert!(%CowStateLog{
          cow_id: cow.id,
          farm_id: farm.id,
          from_state: "grazing",
          to_state: "ruminating",
          occurred_at: DateTime.add(now, -1800, :second),
          metadata: %{}
        })
      end

      result = Reproduction.check_estrus_proxy(cow.id, farm_id: farm.id)
      assert result == {:normal}
    end

    test "returns {:normal} when no state logs exist" do
      farm = farm_fixture()
      cow = cow_fixture(farm, %{sex: :female})
      assert Reproduction.check_estrus_proxy(cow.id, farm_id: farm.id) == {:normal}
    end
  end

  # ---------------------------------------------------------------------------
  # Breeding records
  # ---------------------------------------------------------------------------

  describe "create_breeding_record/1" do
    test "creates a breeding record and it is farm-scoped" do
      farm = farm_fixture()
      cow = cow_fixture(farm, %{sex: :female})

      assert {:ok, %BreedingRecord{} = record} =
               Reproduction.create_breeding_record(%{
                 cow_id: cow.id,
                 farm_id: farm.id,
                 insemination_date: ~D[2026-03-01],
                 method: :ai,
                 outcome: :pending
               })

      assert record.cow_id == cow.id
      assert record.farm_id == farm.id
      assert record.method == :ai
      assert record.outcome == :pending
    end

    test "farm-scoping: records for another farm are not listed" do
      farm1 = farm_fixture()
      farm2 = farm_fixture()
      cow1 = cow_fixture(farm1, %{sex: :female})
      cow2 = cow_fixture(farm2, %{sex: :female})

      breeding_record_fixture(cow1, farm1)
      breeding_record_fixture(cow2, farm2)

      records_for_farm1 = Reproduction.list_breeding_records(farm1.id)
      assert length(records_for_farm1) == 1
      assert hd(records_for_farm1).farm_id == farm1.id
    end

    test "returns error changeset with missing required fields" do
      assert {:error, %Ecto.Changeset{}} = Reproduction.create_breeding_record(%{})
    end
  end

  # ---------------------------------------------------------------------------
  # Gestation / expected_calving_date
  # ---------------------------------------------------------------------------

  describe "expected_calving_date/1" do
    test "returns conception_date + 283 days" do
      farm = farm_fixture()
      cow = cow_fixture(farm, %{sex: :female})
      record = breeding_record_fixture(cow, farm, %{insemination_date: ~D[2026-01-01]})

      expected = Date.add(~D[2026-01-01], 283)
      assert Reproduction.expected_calving_date(record) == expected
    end

    test "computes correct date across year boundary" do
      farm = farm_fixture()
      cow = cow_fixture(farm, %{sex: :female})
      record = breeding_record_fixture(cow, farm, %{insemination_date: ~D[2025-09-01]})

      expected = Date.add(~D[2025-09-01], 283)
      assert Reproduction.expected_calving_date(record) == expected
    end
  end

  # ---------------------------------------------------------------------------
  # Calving events
  # ---------------------------------------------------------------------------

  describe "record_calving_event/1" do
    test "records event, updates gestation status to :calved, creates alert" do
      farm = farm_fixture()
      cow = cow_fixture(farm, %{sex: :female})
      breeding = breeding_record_fixture(cow, farm)
      gestation = gestation_fixture(cow, farm, breeding)

      assert {:ok, %CalvingEvent{} = event} =
               Reproduction.record_calving_event(%{
                 cow_id: cow.id,
                 farm_id: farm.id,
                 occurred_at: DateTime.truncate(DateTime.utc_now(), :second),
                 difficulty: :easy
               })

      assert event.cow_id == cow.id
      assert event.farm_id == farm.id

      updated_gestation = Repo.get!(Gestation, gestation.id)
      assert updated_gestation.status == :calved
      assert updated_gestation.actual_calving_date != nil
    end

    test "calving alert has :critical priority" do
      farm = farm_fixture()
      cow = cow_fixture(farm, %{sex: :female})
      breeding = breeding_record_fixture(cow, farm)
      _gestation = gestation_fixture(cow, farm, breeding)

      {:ok, _event} =
        Reproduction.record_calving_event(%{
          cow_id: cow.id,
          farm_id: farm.id,
          occurred_at: DateTime.truncate(DateTime.utc_now(), :second),
          difficulty: :assisted
        })

      calving_alert =
        from(a in Alert,
          where:
            a.cow_id == ^cow.id and
              a.farm_id == ^farm.id and
              a.type == "CALVING_COMPLETE"
        )
        |> Repo.one()

      assert calving_alert != nil
      assert calving_alert.priority == "critical"
      assert calving_alert.severity == "critical"
    end
  end

  # ---------------------------------------------------------------------------
  # Lactation summary
  # ---------------------------------------------------------------------------

  describe "lactation_summary/4" do
    test "returns correct total, avg, and peak across multiple records" do
      farm = farm_fixture()
      cow = cow_fixture(farm, %{sex: :female})

      yields = [10.5, 12.0, 8.5, 14.0, 11.0]
      base_date = ~D[2026-06-01]

      Enum.each(Enum.with_index(yields), fn {yield, i} ->
        {:ok, _} =
          Reproduction.create_lactation_record(%{
            cow_id: cow.id,
            farm_id: farm.id,
            milking_date: Date.add(base_date, i),
            yield_liters: yield
          })
      end)

      summary =
        Reproduction.lactation_summary(cow.id, farm.id, ~D[2026-06-01], ~D[2026-06-10])

      assert summary.record_count == 5
      assert_in_delta summary.total_liters, 56.0, 0.001
      assert_in_delta summary.avg_daily_liters, 11.2, 0.001
      assert_in_delta summary.peak_liters, 14.0, 0.001
    end

    test "returns zeroes when no records exist" do
      farm = farm_fixture()
      cow = cow_fixture(farm, %{sex: :female})

      summary = Reproduction.lactation_summary(cow.id, farm.id, ~D[2026-01-01], ~D[2026-12-31])

      assert summary == %{total_liters: 0.0, avg_daily_liters: 0.0, peak_liters: 0.0, record_count: 0}
    end

    test "summary is farm-scoped (another farm's records are excluded)" do
      farm1 = farm_fixture()
      farm2 = farm_fixture()
      cow1 = cow_fixture(farm1, %{sex: :female})
      cow2 = cow_fixture(farm2, %{sex: :female})

      {:ok, _} =
        Reproduction.create_lactation_record(%{
          cow_id: cow2.id,
          farm_id: farm2.id,
          milking_date: ~D[2026-06-01],
          yield_liters: 20.0
        })

      summary = Reproduction.lactation_summary(cow1.id, farm1.id, ~D[2026-01-01], ~D[2026-12-31])
      assert summary.record_count == 0
    end
  end

  # ---------------------------------------------------------------------------
  # Dry-off scheduling
  # ---------------------------------------------------------------------------

  describe "create_dry_off_schedule/1" do
    test "scheduled_dry_off_date = expected_calving_date - 60 days" do
      farm = farm_fixture()
      cow = cow_fixture(farm, %{sex: :female})
      breeding = breeding_record_fixture(cow, farm, %{insemination_date: ~D[2026-01-01]})
      gestation = gestation_fixture(cow, farm, breeding)

      assert {:ok, %DryOffSchedule{} = schedule} =
               Reproduction.create_dry_off_schedule(gestation)

      expected_dry_off = Date.add(gestation.expected_calving_date, -60)
      assert schedule.scheduled_dry_off_date == expected_dry_off
      assert schedule.status == :scheduled
      assert schedule.farm_id == farm.id
    end
  end
end
