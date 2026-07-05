defmodule LivestokOs.AI.CaseHistory do
  @moduledoc """
  Builds a unified, read-only timeline of all recorded events for a single cow.

  Pulls from every subsystem in the umbrella:
  - cow_state_logs (digital twin state transitions)
  - geofence_events (boundary breaches, joined via device)
  - rotation_events (paddock-level herd movements)
  - feed_events
  - biogas_records (farm-level)
  - inhibitor_doses
  - breeding_records
  - gestation_records
  - calving_events
  - lactation_records
  - alerts
  - carbon_sequestration_records (paddock-level)
  - methane_avoidance_credits (farm-level summary)
  - feed_efficiency_records
  - deterrent_commands

  All queries are scoped to `farm_id`.
  """

  import Ecto.Query, warn: false
  alias LivestokOs.Repo

  alias LivestokOs.Telemetry.CowStateLog
  alias LivestokOs.Infrastructure.GeofenceEvent
  alias LivestokOs.Infrastructure.RotationEvent
  alias LivestokOs.Infrastructure.DeterrentCommand
  alias LivestokOs.ZeroGrazing.FeedEvent
  alias LivestokOs.ZeroGrazing.BiogasRecord
  alias LivestokOs.ZeroGrazing.InhibitorDose
  alias LivestokOs.Reproduction.BreedingRecord
  alias LivestokOs.Reproduction.Gestation
  alias LivestokOs.Reproduction.CalvingEvent
  alias LivestokOs.Reproduction.LactationRecord
  alias LivestokOs.Operations.Alert
  alias LivestokOs.Carbon.CarbonSequestrationRecord
  alias LivestokOs.Carbon.MethaneAvoidanceCredit
  alias LivestokOs.Carbon.FeedEfficiencyRecord
  alias LivestokOs.Telemetry.Device

  @doc """
  Builds a complete case history for a cow on a given farm.

  Returns a map with:
  - `cow_id` / `farm_id`
  - `timeline` — chronologically sorted list of event maps
  - `summary` — aggregate statistics
  """
  def build(cow_id, farm_id) do
    timeline =
      [
        fetch_state_logs(cow_id, farm_id),
        fetch_geofence_events(cow_id, farm_id),
        fetch_rotation_events(farm_id),
        fetch_feed_events(cow_id, farm_id),
        fetch_biogas_records(farm_id),
        fetch_inhibitor_doses(cow_id),
        fetch_breeding_records(cow_id, farm_id),
        fetch_gestations(cow_id, farm_id),
        fetch_calving_events(cow_id, farm_id),
        fetch_lactation_records(cow_id, farm_id),
        fetch_alerts(cow_id, farm_id),
        fetch_carbon_sequestration(farm_id),
        fetch_methane_credits(farm_id),
        fetch_feed_efficiency(cow_id, farm_id),
        fetch_deterrent_commands(cow_id, farm_id)
      ]
      |> List.flatten()
      |> Enum.sort_by(& &1.timestamp, {:asc, DateTime})

    %{
      cow_id: cow_id,
      farm_id: farm_id,
      timeline: timeline,
      summary: build_summary(timeline)
    }
  end

  defp build_summary([]), do: %{total_events: 0, date_range: nil, categories: %{}}

  defp build_summary(timeline) do
    first = List.first(timeline).timestamp
    last = List.last(timeline).timestamp

    categories =
      Enum.frequencies_by(timeline, & &1.source)

    %{
      total_events: length(timeline),
      date_range: {DateTime.to_date(first), DateTime.to_date(last)},
      categories: categories
    }
  end

  # ---- Individual subsystem fetchers ----

  defp fetch_state_logs(cow_id, farm_id) do
    from(l in CowStateLog, where: l.cow_id == ^cow_id and l.farm_id == ^farm_id)
    |> Repo.all()
    |> Enum.map(fn l ->
      %{
        timestamp: l.occurred_at,
        source: :cow_state_log,
        event_type: "state_transition",
        data: %{from: l.from_state, to: l.to_state, metadata: l.metadata}
      }
    end)
  end

  defp fetch_geofence_events(cow_id, farm_id) do
    from(e in GeofenceEvent,
      join: d in Device,
      on: d.id == e.device_id,
      where: d.cow_id == ^cow_id and e.farm_id == ^farm_id,
      select: {e, d}
    )
    |> Repo.all()
    |> Enum.map(fn {e, _d} ->
      %{
        timestamp: e.occurred_at,
        source: :geofence_event,
        event_type: e.event_type,
        data: %{geofence_id: e.geofence_id, payload: e.payload}
      }
    end)
  end

  defp fetch_rotation_events(farm_id) do
    from(r in RotationEvent, where: r.farm_id == ^farm_id)
    |> Repo.all()
    |> Enum.map(fn r ->
      %{
        timestamp: r.occurred_at,
        source: :rotation_event,
        event_type: "paddock_rotation",
        data: %{paddock_id: r.paddock_id, lat: r.centroid_lat, lng: r.centroid_lng}
      }
    end)
  end

  defp fetch_feed_events(cow_id, farm_id) do
    from(f in FeedEvent, where: f.cow_id == ^cow_id and f.farm_id == ^farm_id)
    |> Repo.all()
    |> Enum.map(fn f ->
      %{
        timestamp: f.fed_at,
        source: :feed_event,
        event_type: "feeding",
        data: %{
          feed_type: f.feed_type,
          quantity_kg: f.quantity_kg,
          inhibitor_added: f.inhibitor_added
        }
      }
    end)
  end

  defp fetch_biogas_records(farm_id) do
    from(b in BiogasRecord, where: b.farm_id == ^farm_id)
    |> Repo.all()
    |> Enum.map(fn b ->
      %{
        timestamp: b.captured_at,
        source: :biogas_record,
        event_type: "biogas_capture",
        data: %{volume_m3: b.volume_m3, methane_pct: b.methane_pct}
      }
    end)
  end

  defp fetch_inhibitor_doses(cow_id) do
    from(d in InhibitorDose, where: d.cow_id == ^cow_id)
    |> Repo.all()
    |> Enum.map(fn d ->
      %{
        timestamp: d.administered_at,
        source: :inhibitor_dose,
        event_type: "inhibitor_administration",
        data: %{type: d.inhibitor_type, dose_mg: d.dose_mg, effectiveness_pct: d.effectiveness_pct}
      }
    end)
  end

  defp fetch_breeding_records(cow_id, farm_id) do
    from(b in BreedingRecord, where: b.cow_id == ^cow_id and b.farm_id == ^farm_id)
    |> Repo.all()
    |> Enum.map(fn b ->
      ts =
        case b.confirmed_at do
          nil -> DateTime.new!(b.insemination_date, ~T[00:00:00], "Etc/UTC")
          dt -> dt
        end

      %{
        timestamp: ts,
        source: :breeding_record,
        event_type: "breeding",
        data: %{method: b.method, outcome: b.outcome, sire_reference: b.sire_reference}
      }
    end)
  end

  defp fetch_gestations(cow_id, farm_id) do
    from(g in Gestation, where: g.cow_id == ^cow_id and g.farm_id == ^farm_id)
    |> Repo.all()
    |> Enum.map(fn g ->
      ts = DateTime.new!(g.conception_date, ~T[00:00:00], "Etc/UTC")

      %{
        timestamp: ts,
        source: :gestation,
        event_type: "gestation",
        data: %{
          status: g.status,
          expected_calving: g.expected_calving_date,
          actual_calving: g.actual_calving_date
        }
      }
    end)
  end

  defp fetch_calving_events(cow_id, farm_id) do
    from(c in CalvingEvent, where: c.cow_id == ^cow_id and c.farm_id == ^farm_id)
    |> Repo.all()
    |> Enum.map(fn c ->
      %{
        timestamp: c.occurred_at,
        source: :calving_event,
        event_type: "calving",
        data: %{
          difficulty: c.difficulty,
          birth_weight_kg: c.birth_weight_kg,
          calf_id: c.calf_id
        }
      }
    end)
  end

  defp fetch_lactation_records(cow_id, farm_id) do
    from(l in LactationRecord, where: l.cow_id == ^cow_id and l.farm_id == ^farm_id)
    |> Repo.all()
    |> Enum.map(fn l ->
      ts = DateTime.new!(l.milking_date, ~T[00:00:00], "Etc/UTC")

      %{
        timestamp: ts,
        source: :lactation_record,
        event_type: "milking",
        data: %{yield_liters: l.yield_liters, fat_pct: l.fat_pct, protein_pct: l.protein_pct}
      }
    end)
  end

  defp fetch_alerts(cow_id, farm_id) do
    from(a in Alert, where: a.cow_id == ^cow_id and a.farm_id == ^farm_id)
    |> Repo.all()
    |> Enum.map(fn a ->
      %{
        timestamp: a.inserted_at,
        source: :alert,
        event_type: a.type,
        data: %{message: a.message, severity: a.severity, resolved: a.is_resolved}
      }
    end)
  end

  defp fetch_carbon_sequestration(farm_id) do
    from(c in CarbonSequestrationRecord, where: c.farm_id == ^farm_id)
    |> Repo.all()
    |> Enum.map(fn c ->
      %{
        timestamp: c.period_start,
        source: :carbon_sequestration,
        event_type: "carbon_sequestration",
        data: %{
          paddock_id: c.paddock_id,
          carbon_tco2e: c.carbon_tco2e,
          period_end: c.period_end
        }
      }
    end)
  end

  defp fetch_methane_credits(farm_id) do
    from(m in MethaneAvoidanceCredit, where: m.farm_id == ^farm_id)
    |> Repo.all()
    |> Enum.map(fn m ->
      %{
        timestamp: m.period_start,
        source: :methane_avoidance_credit,
        event_type: "methane_avoidance",
        data: %{credit_tco2e: m.credit_tco2e, methane_avoided_kg: m.methane_avoided_kg}
      }
    end)
  end

  defp fetch_feed_efficiency(cow_id, farm_id) do
    from(f in FeedEfficiencyRecord, where: f.cow_id == ^cow_id and f.farm_id == ^farm_id)
    |> Repo.all()
    |> Enum.map(fn f ->
      %{
        timestamp: f.calculated_at,
        source: :feed_efficiency,
        event_type: "feed_efficiency_calc",
        data: %{
          feed_efficiency_index: f.feed_efficiency_index,
          deadweight_kg: f.deadweight_kg,
          cumulative_grazing_hours: f.cumulative_grazing_hours
        }
      }
    end)
  end

  defp fetch_deterrent_commands(cow_id, farm_id) do
    from(d in DeterrentCommand, where: d.cow_id == ^cow_id and d.farm_id == ^farm_id)
    |> Repo.all()
    |> Enum.map(fn d ->
      %{
        timestamp: d.issued_at,
        source: :deterrent_command,
        event_type: d.command_type,
        data: %{
          geofence_id: d.geofence_id,
          acknowledged_at: d.acknowledged_at,
          payload: d.payload
        }
      }
    end)
  end
end
