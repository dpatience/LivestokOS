defmodule LivestokOsWeb.ReproductionController do
  use LivestokOsWeb, :controller

  alias LivestokOs.Reproduction
  alias LivestokOs.Reproduction.{BreedingRecord, CalvingEvent, DryOffSchedule, Gestation,
                                   LactationRecord}

  action_fallback LivestokOsWeb.FallbackController

  # ---------------------------------------------------------------------------
  # Breeding records
  # ---------------------------------------------------------------------------

  def index_breeding(conn, _params) do
    farm_id = conn.assigns[:current_farm_id]
    records = Reproduction.list_breeding_records(farm_id)
    render(conn, :index_breeding, breeding_records: records)
  end

  def create_breeding(conn, %{"breeding_record" => params}) do
    farm_id = conn.assigns[:current_farm_id]
    attrs = Map.put(params, "farm_id", farm_id)

    with {:ok, %BreedingRecord{} = record} <- Reproduction.create_breeding_record(attrs) do
      conn
      |> put_status(:created)
      |> render(:show_breeding, breeding_record: record)
    end
  end

  def update_breeding(conn, %{"id" => id, "breeding_record" => params}) do
    farm_id = conn.assigns[:current_farm_id]
    record = Reproduction.get_breeding_record!(id, farm_id)

    with {:ok, %BreedingRecord{} = record} <- Reproduction.update_breeding_record(record, params) do
      render(conn, :show_breeding, breeding_record: record)
    end
  end

  def confirm_breeding(conn, %{"id" => id}) do
    farm_id = conn.assigns[:current_farm_id]
    record = Reproduction.get_breeding_record!(id, farm_id)

    with {:ok, %Gestation{} = gestation} <- Reproduction.confirm_pregnancy(record) do
      render(conn, :show_gestation, gestation: gestation)
    end
  end

  # ---------------------------------------------------------------------------
  # Gestations (calving countdown)
  # ---------------------------------------------------------------------------

  def index_gestations(conn, _params) do
    farm_id = conn.assigns[:current_farm_id]
    gestations = Reproduction.list_active_gestations(farm_id)
    render(conn, :index_gestations, gestations: gestations)
  end

  # ---------------------------------------------------------------------------
  # Lactation records
  # ---------------------------------------------------------------------------

  def index_lactation(conn, _params) do
    farm_id = conn.assigns[:current_farm_id]
    records = Reproduction.list_lactation_records(farm_id)
    render(conn, :index_lactation, lactation_records: records)
  end

  def create_lactation(conn, %{"lactation_record" => params}) do
    farm_id = conn.assigns[:current_farm_id]
    attrs = Map.put(params, "farm_id", farm_id)

    with {:ok, %LactationRecord{} = record} <- Reproduction.create_lactation_record(attrs) do
      conn
      |> put_status(:created)
      |> render(:show_lactation, lactation_record: record)
    end
  end

  def lactation_summary(conn, %{"cow_id" => cow_id} = params) do
    farm_id = conn.assigns[:current_farm_id]
    today = Date.utc_today()
    from_date = parse_date(params["from"], Date.add(today, -30))
    to_date = parse_date(params["to"], today)

    summary = Reproduction.lactation_summary(String.to_integer(cow_id), farm_id, from_date, to_date)
    json(conn, %{data: summary})
  end

  # ---------------------------------------------------------------------------
  # Dry-off schedules
  # ---------------------------------------------------------------------------

  def index_dry_off(conn, _params) do
    farm_id = conn.assigns[:current_farm_id]
    schedules = Reproduction.list_dry_off_schedules(farm_id)
    render(conn, :index_dry_off, dry_off_schedules: schedules)
  end

  def create_dry_off(conn, %{"gestation_id" => gestation_id}) do
    farm_id = conn.assigns[:current_farm_id]

    gestation =
      Reproduction.list_active_gestations(farm_id)
      |> Enum.find(&(&1.id == String.to_integer(gestation_id)))

    if gestation do
      with {:ok, %DryOffSchedule{} = schedule} <- Reproduction.create_dry_off_schedule(gestation) do
        conn
        |> put_status(:created)
        |> render(:show_dry_off, dry_off_schedule: schedule)
      end
    else
      conn
      |> put_status(:not_found)
      |> json(%{error: "Active gestation not found"})
    end
  end

  # ---------------------------------------------------------------------------
  # Calving events
  # ---------------------------------------------------------------------------

  def index_calving(conn, _params) do
    farm_id = conn.assigns[:current_farm_id]
    events = Reproduction.list_calving_events(farm_id)
    render(conn, :index_calving, calving_events: events)
  end

  def create_calving(conn, %{"calving_event" => params}) do
    farm_id = conn.assigns[:current_farm_id]
    attrs = Map.put(params, "farm_id", farm_id)

    with {:ok, %CalvingEvent{} = event} <- Reproduction.record_calving_event(attrs) do
      conn
      |> put_status(:created)
      |> render(:show_calving, calving_event: event)
    end
  end

  defp parse_date(nil, default), do: default
  defp parse_date(date, _default) when is_binary(date), do: Date.from_iso8601!(date)
end
