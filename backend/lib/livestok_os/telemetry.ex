defmodule LivestokOs.Telemetry do
  @moduledoc """
  Telemetry ingest + device management layer.
  """

  import Ecto.Query, warn: false
  import LivestokOs.Pagination

  alias LivestokOs.{Inventory, Operations, Repo}
  alias LivestokOs.Infrastructure.GeofenceEnforcer
  alias LivestokOs.Operations.Alert
  alias LivestokOs.Telemetry.{Device, SensorReading}

  # Devices -------------------------------------------------------------------

  def list_devices(opts \\ %{}) do
    from(d in Device, preload: [:cow, :farm])
    |> paginate(opts)
    |> Repo.all()
  end

  def get_device!(id) do
    Device
    |> Repo.get!(id)
    |> Repo.preload([:cow, :farm])
  end

  def upsert_device(attrs \\ %{}) do
    serial = Map.get(attrs, :serial) || Map.get(attrs, "serial")

    case Repo.get_by(Device, serial: serial) do
      nil -> create_device(attrs)
      %Device{} = device -> update_device(device, attrs)
    end
  end

  def create_device(attrs \\ %{}) do
    %Device{}
    |> Device.changeset(attrs)
    |> Repo.insert()
    |> preload_device()
  end

  def update_device(%Device{} = device, attrs) do
    device
    |> Device.changeset(attrs)
    |> Repo.update()
    |> preload_device()
  end

  def delete_device(%Device{} = device) do
    Repo.delete(device)
  end

  def change_device(%Device{} = device, attrs \\ %{}) do
    Device.changeset(device, attrs)
  end

  def get_device_by_serial(serial) when is_binary(serial) do
    Repo.get_by(Device, serial: serial)
  end

  def get_device_by_serial(_), do: nil

  # Sensor readings -----------------------------------------------------------

  def list_sensor_readings(opts \\ %{}) do
    from(s in SensorReading, preload: [:cow, :device])
    |> paginate(opts)
    |> Repo.all()
  end

  def get_sensor_reading!(id) do
    SensorReading
    |> Repo.get!(id)
    |> Repo.preload([:cow, :device])
  end

  def create_sensor_reading(attrs) do
    %SensorReading{}
    |> SensorReading.changeset(attrs)
    |> Repo.insert()
    |> preload_reading()
  end

  def update_sensor_reading(%SensorReading{} = sensor_reading, attrs) do
    sensor_reading
    |> SensorReading.changeset(attrs)
    |> Repo.update()
    |> preload_reading()
  end

  def delete_sensor_reading(%SensorReading{} = sensor_reading) do
    Repo.delete(sensor_reading)
  end

  def change_sensor_reading(%SensorReading{} = sensor_reading, attrs \\ %{}) do
    SensorReading.changeset(sensor_reading, attrs)
  end

  # Ingestion -----------------------------------------------------------------

  def ingest_reading(%{"reading" => reading_params} = payload) when is_map(reading_params) do
    payload
    |> do_ingest_reading(reading_params)
    |> normalize_transaction()
    |> maybe_post_process(payload)
  end

  def ingest_reading(_), do: {:error, :invalid_payload}

  def ingest_batch(%{"readings" => readings}) when is_list(readings) do
    readings
    |> Enum.reduce_while({:ok, []}, fn entry, {:ok, acc} ->
      case ingest_reading(entry) do
        {:ok, reading} -> {:cont, {:ok, [reading | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, ingested} -> {:ok, Enum.reverse(ingested)}
      {:error, reason} -> {:error, reason}
    end
  end

  def ingest_batch(_), do: {:error, :invalid_payload}

  # Aggregations --------------------------------------------------------------

  def aggregate_recent_activity(params \\ %{}) do
    window_minutes = parse_window_minutes(params)
    since = DateTime.utc_now() |> DateTime.add(-window_minutes * 60, :second)

    query =
      from s in SensorReading,
        where: s.timestamp >= ^since,
        preload: [:cow, :device],
        order_by: [asc: s.timestamp]

    readings = Repo.all(query)

    grouped =
      readings
      |> Enum.group_by(&group_key/1)

    alerts_map =
      grouped
      |> Map.keys()
      |> Enum.map(&cow_id_from_group/1)
      |> Enum.reject(&is_nil/1)
      |> Operations.list_alerts_for_cows()

    grouped
    |> Enum.map(fn {key, entries} ->
      build_summary(key, entries, alerts_map, window_minutes)
    end)
  end

  # -- helpers ----------------------------------------------------------------

  defp do_ingest_reading(payload, reading_params) do
    Repo.transaction(fn ->
      with {:ok, device} <- ensure_device(payload),
           {:ok, cow_id} <- resolve_cow_id(payload, device),
           attrs <- build_reading_attrs(reading_params, device, cow_id),
           {:ok, reading} <- create_sensor_reading(attrs) do
        reading
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp ensure_device(payload) do
    device_payload = map_get(payload, :device) || %{}
    serial = map_get(device_payload, :serial) || map_get(payload, :serial)

    if is_nil(serial) do
      {:error, {:invalid_device, :serial_missing}}
    else
      device_attrs =
        device_payload
        |> Map.put("serial", serial)
        |> Map.put_new(:serial, serial)
        |> maybe_put_last_seen(payload)

      with {:ok, attrs} <- attach_cow(device_attrs, payload) do
        upsert_device(attrs)
      end
    end
  end

  defp attach_cow(attrs, payload) do
    case cow_id_from_payload(attrs, payload) do
      {:ok, nil} -> {:ok, drop_virtual_keys(attrs)}
      {:ok, cow_id} -> {:ok, attrs |> drop_virtual_keys() |> Map.put("cow_id", cow_id)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp drop_virtual_keys(attrs) do
    Map.drop(attrs, ["cow_tag", :cow_tag])
  end

  defp resolve_cow_id(payload, device) do
    case cow_id_from_payload(%{}, payload) do
      {:ok, nil} -> {:ok, device.cow_id}
      {:ok, cow_id} -> {:ok, cow_id}
      error -> error
    end
  end

  defp cow_id_from_payload(attrs, payload) do
    cond do
      id = map_get(attrs, :cow_id) -> {:ok, id}
      id = map_get(payload, :cow_id) -> {:ok, id}
      id = dig(payload, [:cow, :id]) -> {:ok, id}
      tag = map_get(attrs, :cow_tag) -> fetch_cow_id_by_tag(tag)
      tag = map_get(payload, :cow_tag) -> fetch_cow_id_by_tag(tag)
      tag = dig(payload, [:cow, :tag_id]) -> fetch_cow_id_by_tag(tag)
      true -> {:ok, nil}
    end
  end

  defp fetch_cow_id_by_tag(tag) when is_binary(tag) do
    case Inventory.get_cow_by_tag(tag) do
      nil -> {:error, {:unknown_cow_tag, tag}}
      cow -> {:ok, cow.id}
    end
  end

  defp fetch_cow_id_by_tag(_), do: {:ok, nil}

  defp build_reading_attrs(reading_params, device, cow_id) do
    reading_params
    |> Map.put_new("timestamp", DateTime.utc_now())
    |> Map.put("device_id", device.id)
    |> maybe_put_cow_id(cow_id)
    |> Map.update("data", %{}, fn current -> current || %{} end)
    |> Map.put_new(
      "source",
      Map.get(reading_params, "source") || Map.get(reading_params, :source) ||
        default_source(device)
    )
  end

  defp maybe_put_cow_id(attrs, nil), do: attrs
  defp maybe_put_cow_id(attrs, cow_id), do: Map.put(attrs, "cow_id", cow_id)

  defp default_source(%Device{hardware_type: nil}), do: "ear_tag"
  defp default_source(%Device{hardware_type: hardware_type}), do: hardware_type

  defp maybe_put_last_seen(attrs, payload) do
    case dig(payload, [:reading, :timestamp]) do
      nil -> attrs
      timestamp -> Map.put_new(attrs, "last_seen_at", timestamp)
    end
  end

  defp maybe_post_process({:ok, reading}, _payload) do
    {:ok, post_ingest_hooks(reading)}
  end

  defp maybe_post_process(other, _payload), do: other

  defp post_ingest_hooks(reading) do
    reading
    |> Repo.preload([:cow, :device])
    |> maybe_track_zone()
    |> GeofenceEnforcer.check()
    |> maybe_run_analysis()
  end

  defp maybe_track_zone(%SensorReading{cow_id: nil} = reading), do: reading
  defp maybe_track_zone(%SensorReading{zone_id: nil} = reading), do: reading

  defp maybe_track_zone(%SensorReading{} = reading) do
    farm_id = reading.cow && reading.cow.farm_id
    timestamp = reading.timestamp || DateTime.utc_now()

    case Operations.track_zone_transition(reading.cow_id, reading.zone_id, timestamp, farm_id) do
      {:ok, _event} -> reading
      {:error, _reason} -> reading
    end
  end

  defp maybe_run_analysis(%SensorReading{cow_id: nil} = reading), do: reading
  defp maybe_run_analysis(%SensorReading{latitude: nil} = reading), do: reading
  defp maybe_run_analysis(%SensorReading{longitude: nil} = reading), do: reading

  defp maybe_run_analysis(%SensorReading{} = reading) do
    entered_at =
      case Operations.current_grazing_event_for_cow(reading.cow_id) do
        nil -> reading.timestamp || DateTime.utc_now()
        %{entered_at: value} -> value
      end

    analysis =
      Operations.run_daily_analysis(
        reading.cow_id,
        reading.latitude,
        reading.longitude,
        reading.zone_id,
        entered_at
      )

    persist_analysis(reading, normalize_analysis(analysis))
  end

  defp persist_analysis(reading, analysis) do
    data = Map.put(reading.data || %{}, "analysis", analysis)

    case SensorReading.changeset(reading, %{data: data}) |> Repo.update() do
      {:ok, updated} -> Repo.preload(updated, [:cow, :device])
      {:error, _changeset} -> reading
    end
  end

  defp normalize_analysis(%{rotation: rotation, carbon: carbon, coach: coach} = map) do
    base = %{
      "rotation" => normalize_tuple(rotation),
      "carbon" => carbon,
      "coach" => normalize_tuple(coach)
    }

    case Map.get(map, :credit) do
      nil -> base
      credit -> Map.put(base, "credit", normalize_tuple(credit))
    end
  end

  defp normalize_analysis(other), do: other

  defp normalize_tuple({:ok, %Alert{} = alert}) do
    %{
      "status" => "alert",
      "alert_id" => alert.id,
      "type" => alert.type,
      "message" => alert.message
    }
  end

  defp normalize_tuple({status, detail}) when status in [:ok, :error] do
    %{
      "status" => Atom.to_string(status),
      "detail" => format_detail(detail)
    }
  end

  defp normalize_tuple(other), do: other

  defp format_detail(detail) when is_atom(detail), do: Atom.to_string(detail)
  defp format_detail(%{message: message}), do: message
  defp format_detail(detail), do: detail

  defp parse_window_minutes(params) do
    params
    |> map_get(:window_minutes)
    |> parse_integer(60)
  end

  defp parse_integer(nil, default), do: default

  defp parse_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> default
    end
  end

  defp parse_integer(value, _default) when is_integer(value) and value > 0, do: value
  defp parse_integer(_value, default), do: default

  defp group_key(%SensorReading{cow_id: cow_id}) when not is_nil(cow_id), do: {:cow, cow_id}
  defp group_key(%SensorReading{device_id: device_id}), do: {:device, device_id}

  defp cow_id_from_group({:cow, cow_id}), do: cow_id
  defp cow_id_from_group(_), do: nil

  defp build_summary({:cow, _} = _key, entries, alerts_map, window_minutes) do
    last = List.last(entries)
    cow_id = last.cow_id

    %{
      entity: "cow",
      window_minutes: window_minutes,
      cow: cow_payload(last.cow),
      device: device_payload(last.device),
      last_reading_at: last.timestamp,
      last_coordinates: coordinates(last),
      avg_speed_mps: avg_speed(entries),
      behavior_counts: behavior_counts(entries),
      battery_level: last.battery_level,
      analysis_snapshot: Map.get(last.data || %{}, "analysis"),
      alerts: alerts_map |> Map.get(cow_id, []) |> Enum.map(&alert_payload/1)
    }
  end

  defp build_summary({:device, _}, entries, _alerts_map, window_minutes) do
    last = List.last(entries)

    %{
      entity: "device",
      window_minutes: window_minutes,
      cow: cow_payload(last.cow),
      device: device_payload(last.device),
      last_reading_at: last.timestamp,
      last_coordinates: coordinates(last),
      avg_speed_mps: avg_speed(entries),
      behavior_counts: behavior_counts(entries),
      battery_level: last.battery_level,
      analysis_snapshot: Map.get(last.data || %{}, "analysis"),
      alerts: []
    }
  end

  defp coordinates(%SensorReading{latitude: lat, longitude: long, zone_id: zone_id}) do
    %{
      latitude: lat,
      longitude: long,
      zone_id: zone_id
    }
  end

  defp avg_speed(entries) do
    entries
    |> Enum.map(& &1.speed_mps)
    |> Enum.filter(&is_number/1)
    |> case do
      [] -> nil
      speeds -> Enum.sum(speeds) / length(speeds)
    end
  end

  defp behavior_counts(entries) do
    Enum.reduce(entries, %{}, fn reading, acc ->
      label = reading.behavior_label || reading.activity

      if label do
        Map.update(acc, label, 1, &(&1 + 1))
      else
        acc
      end
    end)
  end

  defp alert_payload(%Alert{} = alert) do
    %{
      id: alert.id,
      type: alert.type,
      message: alert.message,
      is_resolved: alert.is_resolved,
      inserted_at: alert.inserted_at
    }
  end

  defp cow_payload(nil), do: nil

  defp cow_payload(cow) do
    %{
      id: cow.id,
      tag_id: cow.tag_id,
      name: cow.name,
      farm_id: cow.farm_id
    }
  end

  defp device_payload(nil), do: nil

  defp device_payload(device) do
    %{
      id: device.id,
      serial: device.serial,
      hardware_type: device.hardware_type,
      status: device.status,
      last_seen_at: device.last_seen_at
    }
  end

  defp map_get(map, key) when is_map(map) and is_atom(key) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp map_get(_map, _key), do: nil

  defp dig(nil, _path), do: nil
  defp dig(value, []), do: value

  defp dig(map, [key | rest]) when is_map(map) do
    map
    |> map_get(key)
    |> dig(rest)
  end

  defp dig(_value, _path), do: nil

  defp preload_device({:ok, device}), do: {:ok, Repo.preload(device, [:cow, :farm])}
  defp preload_device(other), do: other

  defp preload_reading({:ok, reading}), do: {:ok, Repo.preload(reading, [:cow, :device])}
  defp preload_reading(other), do: other

  defp normalize_transaction({:ok, result}), do: {:ok, result}
  defp normalize_transaction({:error, reason}), do: {:error, reason}
end
