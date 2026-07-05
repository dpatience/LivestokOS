defmodule LivestokOs.DigitalTwin.CowProcessTest do
  use LivestokOs.DataCase

  alias LivestokOs.DigitalTwin.CowProcess
  alias LivestokOs.Inventory

  @registry LivestokOs.DigitalTwin.Registry

  setup do
    {:ok, farm} =
      Inventory.create_farm(%{
        name: "Test Farm",
        location: "Nairobi"
      })

    {:ok, cow1} =
      Inventory.create_cow(%{
        tag_id: "COW-A01",
        name: "Bessie",
        breed: "Holstein",
        birth_date: ~D[2020-01-15],
        status: "active",
        farm_id: farm.id
      })

    {:ok, cow2} =
      Inventory.create_cow(%{
        tag_id: "COW-A02",
        name: "Daisy",
        breed: "Angus",
        birth_date: ~D[2020-06-01],
        status: "active",
        farm_id: farm.id
      })

    on_exit(fn ->
      for cow <- [cow1, cow2] do
        case Registry.lookup(@registry, cow.id) do
          [{pid, _}] ->
            try do
              GenServer.stop(pid, :normal, 500)
            catch
              :exit, _ -> :ok
            end

          [] ->
            :ok
        end
      end
    end)

    %{farm: farm, cow1: cow1, cow2: cow2}
  end

  defp telemetry_reading(overrides) do
    base = %{
      behavior_label: "grazing",
      latitude: -1.2921,
      longitude: 36.8219,
      speed_mps: 0.3,
      battery_level: 87.5,
      timestamp: DateTime.utc_now()
    }

    Map.merge(base, Map.new(overrides))
  end

  # ── Lazy Spawning ──────────────────────────────────────────────────

  describe "lazy spawning" do
    test "twin is NOT pre-spawned at boot — process starts only on first telemetry", %{cow1: cow} do
      count_before = Registry.count(@registry)
      assert Registry.lookup(@registry, cow.id) == []

      CowProcess.push_telemetry(cow.id, telemetry_reading(behavior_label: "grazing"))
      Process.sleep(300)

      count_after = Registry.count(@registry)
      assert count_after == count_before + 1
      assert [{_pid, _}] = Registry.lookup(@registry, cow.id)
    end

    test "get_state returns :not_running for a cow with no twin yet", %{cow1: cow} do
      assert {:error, :not_running} = CowProcess.get_state(cow.id)
    end

    test "get_state returns snapshot after telemetry arrives", %{cow1: cow} do
      CowProcess.push_telemetry(cow.id, telemetry_reading(behavior_label: "ruminating"))
      Process.sleep(300)

      assert {:ok, state} = CowProcess.get_state(cow.id)
      assert state.cow_id == cow.id
      assert state.current_behavior == "ruminating"
      assert state.status == :running
    end
  end

  # ── Fault Isolation ────────────────────────────────────────────────

  describe "fault isolation" do
    test "crashing one cow's twin does NOT affect another cow's twin", %{cow1: cow1, cow2: cow2} do
      CowProcess.push_telemetry(cow1.id, telemetry_reading(behavior_label: "grazing"))
      CowProcess.push_telemetry(cow2.id, telemetry_reading(behavior_label: "ruminating"))
      Process.sleep(300)

      assert {:ok, s1} = CowProcess.get_state(cow1.id)
      assert s1.current_behavior == "grazing"

      assert {:ok, s2} = CowProcess.get_state(cow2.id)
      assert s2.current_behavior == "ruminating"

      # Kill cow1's twin — simulates a crash
      [{pid1, _}] = Registry.lookup(@registry, cow1.id)
      ref = Process.monitor(pid1)
      Process.exit(pid1, :kill)
      assert_receive {:DOWN, ^ref, :process, ^pid1, :killed}, 2000

      # cow2 must still be alive and responsive
      assert {:ok, s2_after} = CowProcess.get_state(cow2.id)
      assert s2_after.current_behavior == "ruminating"
      assert s2_after.reading_count == s2.reading_count

      # cow1's supervisor restarts it — send telemetry to trigger start if needed
      Process.sleep(500)
      CowProcess.push_telemetry(cow1.id, telemetry_reading(behavior_label: "resting"))
      Process.sleep(300)

      assert {:ok, s1_restarted} = CowProcess.get_state(cow1.id)
      assert s1_restarted.cow_id == cow1.id
      assert s1_restarted.current_behavior == "resting"
    end

    test "restarted twin reports :recovering status then transitions to :running", %{cow1: cow} do
      CowProcess.push_telemetry(cow.id, telemetry_reading(behavior_label: "grazing"))
      Process.sleep(300)

      [{pid, _}] = Registry.lookup(@registry, cow.id)
      ref = Process.monitor(pid)
      Process.exit(pid, :kill)
      assert_receive {:DOWN, ^ref, :process, ^pid, :killed}, 2000

      # Wait for supervisor to restart
      Process.sleep(500)

      case Registry.lookup(@registry, cow.id) do
        [{new_pid, _}] when new_pid != pid ->
          {:ok, state} = CowProcess.get_state(cow.id)
          assert state.status == :recovering

        _ ->
          # Supervisor may not have restarted yet; push_telemetry will start fresh
          CowProcess.push_telemetry(cow.id, telemetry_reading(behavior_label: "resting"))
          Process.sleep(300)
          {:ok, state} = CowProcess.get_state(cow.id)
          assert state.status in [:running, :recovering]
      end

      # After receiving telemetry, status transitions to :running
      CowProcess.push_telemetry(cow.id, telemetry_reading(behavior_label: "walking"))
      Process.sleep(300)

      {:ok, state_after} = CowProcess.get_state(cow.id)
      assert state_after.status == :running
    end

    test "HTTP-style read for different cow succeeds while one twin is crashing", %{
      cow1: cow1,
      cow2: cow2
    } do
      CowProcess.push_telemetry(cow1.id, telemetry_reading(behavior_label: "grazing"))
      CowProcess.push_telemetry(cow2.id, telemetry_reading(behavior_label: "ruminating"))
      Process.sleep(300)

      [{pid1, _}] = Registry.lookup(@registry, cow1.id)
      Process.exit(pid1, :kill)

      # Immediately read cow2 — must succeed without blocking or error
      assert {:ok, state} = CowProcess.get_state(cow2.id)
      assert state.cow_id == cow2.id
      assert state.current_behavior == "ruminating"
    end
  end

  # ── Debouncing ─────────────────────────────────────────────────────

  describe "alert debouncing" do
    setup do
      # Lower thresholds so tests are fast and deterministic.
      # reading_count starts at 0; we need > 10 before the alert condition is
      # evaluated, so we send 11 "grazing" readings first to warm up the counter.
      Application.put_env(:livestok_os_twin, :anomaly_fire_threshold, 3)
      Application.put_env(:livestok_os_twin, :alert_cooldown_seconds, 1800)

      on_exit(fn ->
        Application.delete_env(:livestok_os_twin, :anomaly_fire_threshold)
        Application.delete_env(:livestok_os_twin, :alert_cooldown_seconds)
      end)

      :ok
    end

    defp idle_reading do
      # rumination_minutes is accumulated; after warm-up we haven't sent ruminating
      # readings yet, so rumination_minutes should be < 5 only if we warm up with grazing.
      telemetry_reading(behavior_label: "idle")
    end

    test "2 consecutive anomalous readings → no alert", %{cow1: cow} do
      import Ecto.Query

      # Warm up: > 10 readings, no rumination (so rumination_minutes stays 0)
      for _ <- 1..11 do
        CowProcess.push_telemetry(cow.id, telemetry_reading(behavior_label: "grazing"))
        Process.sleep(20)
      end

      alert_count_before =
        LivestokOs.Repo.one(
          from(a in LivestokOs.Operations.Alert,
            where: a.cow_id == ^cow.id and a.type == "HEALTH_RISK",
            select: count(a.id)
          )
        )

      # 2 anomalous readings — threshold is 3, so no alert should fire
      for _ <- 1..2 do
        CowProcess.push_telemetry(cow.id, idle_reading())
        Process.sleep(50)
      end

      alert_count_after =
        LivestokOs.Repo.one(
          from(a in LivestokOs.Operations.Alert,
            where: a.cow_id == ^cow.id and a.type == "HEALTH_RISK",
            select: count(a.id)
          )
        )

      assert alert_count_after == alert_count_before
    end

    test "3 consecutive anomalous readings → alert fires", %{cow1: cow} do
      import Ecto.Query

      for _ <- 1..11 do
        CowProcess.push_telemetry(cow.id, telemetry_reading(behavior_label: "grazing"))
        Process.sleep(20)
      end

      alert_count_before =
        LivestokOs.Repo.one(
          from(a in LivestokOs.Operations.Alert,
            where: a.cow_id == ^cow.id and a.type == "HEALTH_RISK",
            select: count(a.id)
          )
        )

      for _ <- 1..3 do
        CowProcess.push_telemetry(cow.id, idle_reading())
        Process.sleep(50)
      end

      alert_count_after =
        LivestokOs.Repo.one(
          from(a in LivestokOs.Operations.Alert,
            where: a.cow_id == ^cow.id and a.type == "HEALTH_RISK",
            select: count(a.id)
          )
        )

      assert alert_count_after == alert_count_before + 1
    end

    test "4th anomalous reading within cooldown → no second alert", %{cow1: cow} do
      import Ecto.Query

      for _ <- 1..11 do
        CowProcess.push_telemetry(cow.id, telemetry_reading(behavior_label: "grazing"))
        Process.sleep(20)
      end

      # Fire the first alert (3 anomalies)
      for _ <- 1..3 do
        CowProcess.push_telemetry(cow.id, idle_reading())
        Process.sleep(50)
      end

      count_after_first_fire =
        LivestokOs.Repo.one(
          from(a in LivestokOs.Operations.Alert,
            where: a.cow_id == ^cow.id and a.type == "HEALTH_RISK",
            select: count(a.id)
          )
        )

      assert count_after_first_fire >= 1

      # 4th anomalous reading — still within cooldown, no new alert
      CowProcess.push_telemetry(cow.id, idle_reading())
      Process.sleep(100)

      count_after_4th =
        LivestokOs.Repo.one(
          from(a in LivestokOs.Operations.Alert,
            where: a.cow_id == ^cow.id and a.type == "HEALTH_RISK",
            select: count(a.id)
          )
        )

      assert count_after_4th == count_after_first_fire
    end
  end

  # ── State Transitions ──────────────────────────────────────────────

  describe "state transitions" do
    test "persists state transition to cow_state_logs", %{cow1: cow} do
      CowProcess.push_telemetry(cow.id, telemetry_reading(behavior_label: "grazing"))
      Process.sleep(200)

      CowProcess.push_telemetry(cow.id, telemetry_reading(behavior_label: "ruminating"))
      Process.sleep(300)

      logs =
        Repo.all(
          from(l in LivestokOs.Telemetry.CowStateLog,
            where: l.cow_id == ^cow.id,
            order_by: [asc: l.occurred_at]
          )
        )

      assert length(logs) >= 1
      log = List.last(logs)
      assert log.from_state == "grazing"
      assert log.to_state == "ruminating"
    end
  end
end
