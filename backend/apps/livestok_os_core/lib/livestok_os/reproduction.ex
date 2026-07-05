defmodule LivestokOs.Reproduction do
  @moduledoc """
  Reproduction and Lactation bounded context.

  Covers: estrus proxy detection, breeding records, gestation tracking,
  calving events, lactation records, and dry-off scheduling.

  Applies to ALL `grazing_mode` values — not gated behind `feature_enabled?/2`.

  All queries are farm-scoped and additionally filter `sex: :female` (or
  `:unknown`) where reproduction status is relevant.

  ## Alert integration
  This context inserts alerts directly via the `Alert` schema and `Repo`
  (rather than `Operations.create_alert/1`) to avoid a circular dependency
  between `livestok_os_core` and `livestok_os_ops`.
  """

  import Ecto.Query, warn: false
  alias LivestokOs.Repo

  alias LivestokOs.Inventory.Cow
  alias LivestokOs.Operations.Alert
  alias LivestokOs.Telemetry.CowStateLog
  alias LivestokOs.Reproduction.{BreedingRecord, CalvingEvent, DryOffSchedule, Gestation,
                                   LactationRecord}

  require Logger

  # ---------------------------------------------------------------------------
  # Constants
  # ---------------------------------------------------------------------------

  # Standard Bos taurus gestation period in days.
  # Source: Beef Cattle Science, Jurgens & Bregendahl, 7th ed. — configurable per breed.
  @bos_taurus_gestation_days 283

  # Standard dry period before calving in days.
  # Source: standard 60-day dry period; verify with herd vet before adjusting.
  @dry_period_days 60

  # Default rolling window for estrus proxy in hours.
  # TODO: make farm-configurable — currently a module-level default.
  @default_estrus_window_hours 24

  # Default estrus proxy score threshold above which an alert is raised.
  # TODO: validate proxy heuristic with agronomic data — not a confirmed estrus
  # detection method; threshold requires farm-specific calibration.
  @default_estrus_threshold 0.60

  # Default window (in days) before expected calving to raise a calving-imminent alert.
  @default_calving_alert_window_days 7

  # Default window (in days) before scheduled dry-off to raise a dry-off alert.
  @default_dry_off_alert_window_days 3

  # ---------------------------------------------------------------------------
  # Sex field helpers
  # ---------------------------------------------------------------------------

  @doc "Returns all female (and unknown-sex) cows for a farm, farm-scoped."
  def list_female_cows(farm_id) do
    from(c in Cow,
      where: c.farm_id == ^farm_id and c.sex in [:female, :unknown]
    )
    |> Repo.all()
  end

  # ---------------------------------------------------------------------------
  # Estrus / heat proxy detection
  # ---------------------------------------------------------------------------

  @doc """
  Proxy heuristic for heat/estrus detection based on elevated activity in the
  rolling behavioral window.

  # NOTE: The collar classifier records only the following states:
  # "grazing", "ruminating", "idle", "resting". There is NO direct heat/estrus
  # behavioral state available from the hardware classifier. This function
  # implements a WEAK BEHAVIORAL PROXY only.
  #
  # TODO: validate proxy heuristic with agronomic data — not a confirmed
  # estrus detection method. Threshold and weighting require calibration
  # against confirmed estrus observations per herd.
  #
  # Proxy rationale: during estrus, cows exhibit elevated restlessness
  # (increased walking/grazing activity) and reduced rumination time.
  # Source: Løvendahl & Munksgaard (2016), J. Dairy Sci. 99(12):9925–9935.

  Returns `{:likely_heat, score}` when the proxy score exceeds `threshold`,
  or `{:normal}` otherwise.

  ## Options
    - `:window_hours` — rolling window in hours (default: #{@default_estrus_window_hours})
    - `:threshold`    — score cutoff 0–1 (default: #{@default_estrus_threshold})
    - `:farm_id`      — required for farm-scoping the query
  """
  def check_estrus_proxy(cow_id, opts \\ []) do
    window_hours = Keyword.get(opts, :window_hours, @default_estrus_window_hours)
    threshold = Keyword.get(opts, :threshold, @default_estrus_threshold)
    farm_id = Keyword.get(opts, :farm_id)

    since = DateTime.add(DateTime.utc_now(), -window_hours * 3600, :second)

    base_query =
      from(l in CowStateLog,
        where: l.cow_id == ^cow_id and l.occurred_at >= ^since,
        select: l.to_state
      )

    query =
      if farm_id do
        where(base_query, [l], l.farm_id == ^farm_id)
      else
        base_query
      end

    states = Repo.all(query)
    total = length(states)

    if total == 0 do
      {:normal}
    else
      grazing_count = Enum.count(states, &(&1 == "grazing"))
      ruminating_count = Enum.count(states, &(&1 == "ruminating"))

      # Activity proxy: high grazing % + low rumination % → elevated score
      activity_score = grazing_count / total
      low_rumination_score = 1.0 - ruminating_count / total

      score = Float.round((activity_score * 0.6 + low_rumination_score * 0.4), 4)

      if score >= threshold do
        {:likely_heat, score}
      else
        {:normal}
      end
    end
  end

  @doc """
  Checks estrus proxy for all female cows in a farm and creates alerts for
  any cow whose score exceeds the threshold.

  Options are the same as `check_estrus_proxy/2` plus `:farm_id` (required).
  """
  def check_farm_estrus(farm_id, opts \\ []) do
    opts = Keyword.put(opts, :farm_id, farm_id)
    cows = list_female_cows(farm_id)

    Enum.each(cows, fn cow ->
      case check_estrus_proxy(cow.id, opts) do
        {:likely_heat, score} ->
          create_alert(%{
            type: "ESTRUS_PROXY",
            message:
              "Cow #{cow.tag_id}: elevated activity proxy score #{score} — possible heat " <>
                "(proxy only; agronomic validation required)",
            cow_id: cow.id,
            farm_id: farm_id,
            severity: "warning",
            priority: "high",
            is_resolved: false
          })

        {:normal} ->
          :ok
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # Breeding records
  # ---------------------------------------------------------------------------

  @doc "Returns all breeding records for a farm, farm-scoped."
  def list_breeding_records(farm_id) do
    from(b in BreedingRecord, where: b.farm_id == ^farm_id, order_by: [desc: b.insemination_date])
    |> Repo.all()
  end

  @doc "Returns all breeding records for a cow, farm-scoped."
  def list_breeding_records_for_cow(cow_id, farm_id) do
    from(b in BreedingRecord,
      where: b.cow_id == ^cow_id and b.farm_id == ^farm_id,
      order_by: [desc: b.insemination_date]
    )
    |> Repo.all()
  end

  @doc "Creates a breeding record. Farm-scoped."
  def create_breeding_record(attrs) do
    %BreedingRecord{}
    |> BreedingRecord.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Updates a breeding record outcome."
  def update_breeding_record(%BreedingRecord{} = record, attrs) do
    record
    |> BreedingRecord.changeset(attrs)
    |> Repo.update()
  end

  # ---------------------------------------------------------------------------
  # Gestation tracking
  # ---------------------------------------------------------------------------

  @doc """
  Returns the projected calving date for a breeding record.

  Adds #{@bos_taurus_gestation_days} days (Bos taurus standard) to
  `insemination_date` as the conception proxy. Breed-specific constant —
  configurable if extending to non-Bos-taurus herds.
  """
  def expected_calving_date(%BreedingRecord{insemination_date: date})
      when not is_nil(date) do
    Date.add(date, @bos_taurus_gestation_days)
  end

  @doc "Creates a gestation record derived from a breeding record. Farm-scoped."
  def create_gestation(%BreedingRecord{} = breeding_record) do
    calving_date = expected_calving_date(breeding_record)

    %Gestation{}
    |> Gestation.changeset(%{
      cow_id: breeding_record.cow_id,
      farm_id: breeding_record.farm_id,
      breeding_record_id: breeding_record.id,
      conception_date: breeding_record.insemination_date,
      expected_calving_date: calving_date,
      status: :active
    })
    |> Repo.insert()
  end

  @doc "Returns all active gestations for a farm, farm-scoped."
  def list_active_gestations(farm_id) do
    from(g in Gestation,
      where: g.farm_id == ^farm_id and g.status == :active,
      order_by: [asc: g.expected_calving_date]
    )
    |> Repo.all()
  end

  @doc """
  Checks all active gestations for a farm and creates alerts for:
  - Gestations whose `expected_calving_date` is within the alert window (default #{@default_calving_alert_window_days} days).
  - Gestations that are overdue (past `expected_calving_date` with no `actual_calving_date`).

  Options:
    - `:alert_window_days` — days before calving to alert (default: #{@default_calving_alert_window_days})
  """
  def check_calving_alerts(farm_id, opts \\ []) do
    window_days = Keyword.get(opts, :alert_window_days, @default_calving_alert_window_days)
    today = Date.utc_today()
    alert_cutoff = Date.add(today, window_days)

    gestations = list_active_gestations(farm_id)

    Enum.each(gestations, fn g ->
      cond do
        Date.compare(g.expected_calving_date, today) == :lt ->
          create_alert(%{
            type: "CALVING_OVERDUE",
            message:
              "Cow #{g.cow_id}: calving overdue — expected #{g.expected_calving_date}, no calving recorded",
            cow_id: g.cow_id,
            farm_id: farm_id,
            severity: "critical",
            priority: "critical",
            is_resolved: false
          })

        Date.compare(g.expected_calving_date, alert_cutoff) != :gt ->
          create_alert(%{
            type: "CALVING_IMMINENT",
            message:
              "Cow #{g.cow_id}: calving expected on #{g.expected_calving_date} " <>
                "(within #{window_days} days)",
            cow_id: g.cow_id,
            farm_id: farm_id,
            severity: "warning",
            priority: "high",
            is_resolved: false
          })

        true ->
          :ok
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # Calving events
  # ---------------------------------------------------------------------------

  @doc """
  Records a calving event for a dam cow.

  Within a database transaction:
  1. Inserts the `CalvingEvent` record.
  2. Finds the most recent active `Gestation` for the cow and marks it
     `actual_calving_date` / `status: :calved`.
  3. Creates a calving-complete alert with `priority: :critical`.

  Returns `{:ok, %CalvingEvent{}}` or `{:error, reason}`.
  """
  def record_calving_event(attrs) do
    Repo.transaction(fn ->
      with {:ok, event} <-
             %CalvingEvent{}
             |> CalvingEvent.changeset(attrs)
             |> Repo.insert(),
           :ok <- update_gestation_for_calving(event),
           :ok <- create_calving_complete_alert(event) do
        event
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp update_gestation_for_calving(%CalvingEvent{} = event) do
    gestation =
      from(g in Gestation,
        where:
          g.cow_id == ^event.cow_id and
            g.farm_id == ^event.farm_id and
            g.status == :active,
        order_by: [asc: g.expected_calving_date],
        limit: 1
      )
      |> Repo.one()

    case gestation do
      nil ->
        Logger.warning("record_calving_event: no active gestation found for cow #{event.cow_id}")
        :ok

      %Gestation{} = g ->
        calving_date = DateTime.to_date(event.occurred_at)

        case Repo.update(Gestation.changeset(g, %{
               actual_calving_date: calving_date,
               status: :calved
             })) do
          {:ok, _} -> :ok
          {:error, cs} -> {:error, cs}
        end
    end
  end

  defp create_calving_complete_alert(%CalvingEvent{} = event) do
    create_alert(%{
      type: "CALVING_COMPLETE",
      message:
        "Cow #{event.cow_id}: calving recorded at #{event.occurred_at} " <>
          "(difficulty: #{event.difficulty})",
      cow_id: event.cow_id,
      farm_id: event.farm_id,
      severity: "critical",
      priority: "critical",
      is_resolved: false
    })
    |> case do
      {:ok, _} -> :ok
      {:error, cs} -> {:error, cs}
    end
  end

  # ---------------------------------------------------------------------------
  # Lactation records
  # ---------------------------------------------------------------------------

  @doc """
  Creates a lactation record for a cow. Farm-scoped.

  # TODO: wire to milking-parlor/robot integration endpoint
  """
  def create_lactation_record(attrs) do
    %LactationRecord{}
    |> LactationRecord.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns a lactation summary for a cow over a date range.

  Returns a map with:
    - `:total_liters`   — sum of all yield_liters in the range
    - `:avg_daily_liters` — average yield per milking day
    - `:peak_liters`    — maximum yield in any single record
    - `:record_count`   — number of milking records

  Farm-scoped.
  """
  def lactation_summary(cow_id, farm_id, from_date, to_date) do
    records =
      from(l in LactationRecord,
        where:
          l.cow_id == ^cow_id and
            l.farm_id == ^farm_id and
            l.milking_date >= ^from_date and
            l.milking_date <= ^to_date,
        select: l.yield_liters
      )
      |> Repo.all()

    if records == [] do
      %{total_liters: 0.0, avg_daily_liters: 0.0, peak_liters: 0.0, record_count: 0}
    else
      count = length(records)
      total = Enum.sum(records)
      peak = Enum.max(records)
      avg = Float.round(total / count, 4)

      %{
        total_liters: Float.round(total, 4),
        avg_daily_liters: avg,
        peak_liters: peak,
        record_count: count
      }
    end
  end

  # ---------------------------------------------------------------------------
  # Dry-off scheduling
  # ---------------------------------------------------------------------------

  @doc """
  Creates a dry-off schedule for a gestation.

  `scheduled_dry_off_date` = `expected_calving_date - #{@dry_period_days} days`.
  Source: standard 60-day dry period; verify with herd vet before adjusting.
  """
  def create_dry_off_schedule(%Gestation{} = gestation) do
    dry_off_date = Date.add(gestation.expected_calving_date, -@dry_period_days)

    %DryOffSchedule{}
    |> DryOffSchedule.changeset(%{
      cow_id: gestation.cow_id,
      farm_id: gestation.farm_id,
      gestation_id: gestation.id,
      scheduled_dry_off_date: dry_off_date,
      status: :scheduled
    })
    |> Repo.insert()
  end

  @doc """
  Checks upcoming dry-off schedules and creates alerts for any scheduled within
  the alert window.

  Options:
    - `:alert_window_days` — days before dry-off to alert (default: #{@default_dry_off_alert_window_days})
  """
  def check_dry_off_alerts(farm_id, opts \\ []) do
    window_days = Keyword.get(opts, :alert_window_days, @default_dry_off_alert_window_days)
    today = Date.utc_today()
    alert_cutoff = Date.add(today, window_days)

    schedules =
      from(d in DryOffSchedule,
        where:
          d.farm_id == ^farm_id and
            d.status == :scheduled and
            d.scheduled_dry_off_date >= ^today and
            d.scheduled_dry_off_date <= ^alert_cutoff
      )
      |> Repo.all()

    Enum.each(schedules, fn d ->
      create_alert(%{
        type: "DRY_OFF_DUE",
        message:
          "Cow #{d.cow_id}: dry-off scheduled on #{d.scheduled_dry_off_date} " <>
            "(within #{window_days} days)",
        cow_id: d.cow_id,
        farm_id: farm_id,
        severity: "warning",
        priority: "medium",
        is_resolved: false
      })
    end)
  end

  # ---------------------------------------------------------------------------
  # Reproductive score (used by FeedEfficiency extension)
  # ---------------------------------------------------------------------------

  @doc """
  Computes a composite reproductive score (0–1) for a female cow.

  Components (equal weight):
    1. Conception rate: confirmed_pregnant / total breeding attempts (0–1)
    2. Lactation yield rank: relative to farm median (0–1 where 1 = highest)
    3. Calving interval rank: shorter interval relative to farm (0–1 where 1 = shortest)

  Returns `nil` if insufficient data exists to compute any component.

  Farm-scoped.
  """
  def reproductive_score(cow_id, farm_id) do
    conception = conception_rate(cow_id, farm_id)
    yield_rank = lactation_yield_rank(cow_id, farm_id)
    interval_rank = calving_interval_rank(cow_id, farm_id)

    components = Enum.reject([conception, yield_rank, interval_rank], &is_nil/1)

    case components do
      [] -> nil
      parts -> Float.round(Enum.sum(parts) / length(parts), 4)
    end
  end

  defp conception_rate(cow_id, farm_id) do
    records =
      from(b in BreedingRecord,
        where: b.cow_id == ^cow_id and b.farm_id == ^farm_id,
        select: b.outcome
      )
      |> Repo.all()

    total = length(records)

    if total == 0 do
      nil
    else
      confirmed = Enum.count(records, &(&1 == :confirmed_pregnant))
      confirmed / total
    end
  end

  defp lactation_yield_rank(cow_id, farm_id) do
    all_yields =
      from(l in LactationRecord,
        where: l.farm_id == ^farm_id,
        group_by: l.cow_id,
        select: {l.cow_id, sum(l.yield_liters)}
      )
      |> Repo.all()

    if all_yields == [] do
      nil
    else
      sorted = Enum.sort_by(all_yields, &elem(&1, 1))
      total = length(sorted)
      index = Enum.find_index(sorted, fn {cid, _} -> cid == cow_id end)

      case index do
        nil -> nil
        i -> Float.round((i + 1) / total, 4)
      end
    end
  end

  defp calving_interval_rank(cow_id, farm_id) do
    intervals =
      from(g in Gestation,
        where: g.farm_id == ^farm_id and not is_nil(g.actual_calving_date),
        group_by: g.cow_id,
        select: {g.cow_id, count(g.id)}
      )
      |> Repo.all()

    if intervals == [] do
      nil
    else
      sorted = Enum.sort_by(intervals, &elem(&1, 1), :desc)
      total = length(sorted)
      index = Enum.find_index(sorted, fn {cid, _} -> cid == cow_id end)

      case index do
        nil -> nil
        i -> Float.round((i + 1) / total, 4)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Internal helpers
  # ---------------------------------------------------------------------------

  defp create_alert(attrs) do
    attrs_with_defaults = Map.put_new(attrs, :is_resolved, false)

    %Alert{}
    |> Alert.changeset(attrs_with_defaults)
    |> Repo.insert()
    |> case do
      {:ok, alert} ->
        {:ok, alert}

      {:error, cs} ->
        Logger.warning("Reproduction: failed to create alert: #{inspect(cs.errors)}")
        {:error, cs}
    end
  end
end
