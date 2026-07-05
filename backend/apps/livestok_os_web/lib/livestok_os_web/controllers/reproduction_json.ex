defmodule LivestokOsWeb.ReproductionJSON do
  alias LivestokOs.Reproduction.{BreedingRecord, CalvingEvent, DryOffSchedule, Gestation,
                                   LactationRecord}

  def index_breeding(%{breeding_records: records}) do
    %{data: for(r <- records, do: breeding_data(r))}
  end

  def show_breeding(%{breeding_record: record}) do
    %{data: breeding_data(record)}
  end

  def index_gestations(%{gestations: gestations}) do
    %{data: for(g <- gestations, do: gestation_data(g))}
  end

  def show_gestation(%{gestation: gestation}) do
    %{data: gestation_data(gestation)}
  end

  def index_lactation(%{lactation_records: records}) do
    %{data: for(r <- records, do: lactation_data(r))}
  end

  def show_lactation(%{lactation_record: record}) do
    %{data: lactation_data(record)}
  end

  def index_dry_off(%{dry_off_schedules: schedules}) do
    %{data: for(s <- schedules, do: dry_off_data(s))}
  end

  def show_dry_off(%{dry_off_schedule: schedule}) do
    %{data: dry_off_data(schedule)}
  end

  def index_calving(%{calving_events: events}) do
    %{data: for(e <- events, do: calving_data(e))}
  end

  def show_calving(%{calving_event: event}) do
    %{data: calving_data(event)}
  end

  defp breeding_data(%BreedingRecord{} = r) do
    %{
      id: r.id,
      cow_id: r.cow_id,
      farm_id: r.farm_id,
      insemination_date: r.insemination_date,
      method: r.method,
      sire_id: r.sire_id,
      sire_reference: r.sire_reference,
      outcome: r.outcome,
      confirmed_at: r.confirmed_at,
      inserted_at: r.inserted_at
    }
  end

  defp gestation_data(%Gestation{} = g) do
    today = Date.utc_today()
    days_until = Date.diff(g.expected_calving_date, today)

    %{
      id: g.id,
      cow_id: g.cow_id,
      farm_id: g.farm_id,
      breeding_record_id: g.breeding_record_id,
      conception_date: g.conception_date,
      expected_calving_date: g.expected_calving_date,
      actual_calving_date: g.actual_calving_date,
      status: g.status,
      days_until_calving: days_until,
      inserted_at: g.inserted_at
    }
  end

  defp lactation_data(%LactationRecord{} = l) do
    %{
      id: l.id,
      cow_id: l.cow_id,
      farm_id: l.farm_id,
      milking_date: l.milking_date,
      yield_liters: l.yield_liters,
      fat_pct: l.fat_pct,
      protein_pct: l.protein_pct,
      source: l.source,
      inserted_at: l.inserted_at
    }
  end

  defp dry_off_data(%DryOffSchedule{} = d) do
    %{
      id: d.id,
      cow_id: d.cow_id,
      farm_id: d.farm_id,
      gestation_id: d.gestation_id,
      scheduled_dry_off_date: d.scheduled_dry_off_date,
      actual_dry_off_date: d.actual_dry_off_date,
      status: d.status,
      inserted_at: d.inserted_at
    }
  end

  defp calving_data(%CalvingEvent{} = c) do
    %{
      id: c.id,
      cow_id: c.cow_id,
      farm_id: c.farm_id,
      occurred_at: c.occurred_at,
      calf_id: c.calf_id,
      birth_weight_kg: c.birth_weight_kg,
      difficulty: c.difficulty,
      notes: c.notes,
      inserted_at: c.inserted_at
    }
  end
end
