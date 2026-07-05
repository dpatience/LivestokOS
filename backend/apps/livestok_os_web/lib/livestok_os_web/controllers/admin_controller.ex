defmodule LivestokOsWeb.AdminController do
  use LivestokOsWeb, :controller

  import Ecto.Query

  alias LivestokOs.{CarbonLedger, Repo, Telemetry}
  alias LivestokOs.Carbon.CarbonLedgerEntry
  alias LivestokOs.Inventory
  alias LivestokOs.Operations.Alert
  alias LivestokOs.Telemetry.{Device, SensorReading}
  alias LivestokOs.Telemetry.StateHistory

  action_fallback LivestokOsWeb.FallbackController

  @doc "GET /api/admin/farms — List all farms (super_admin only)"
  def list_farms(conn, params) do
    with :ok <- require_admin(conn) do
      farms = Inventory.list_farms(params)
      json(conn, %{data: Enum.map(farms, &serialize_farm/1)})
    end
  end

  @doc "DELETE /api/admin/cows/:cow_id/history — Reset cow historical data"
  def reset_cow_history(conn, %{"cow_id" => cow_id}) do
    with :ok <- require_admin(conn) do
      cow_id = String.to_integer(cow_id)
      {deleted, _} = StateHistory.clear_cow_history(cow_id)
      json(conn, %{data: %{deleted_records: deleted}})
    end
  end

  @doc "DELETE /api/admin/farms/:farm_id/telemetry — Reset farm telemetry"
  def reset_farm_telemetry(conn, %{"farm_id" => farm_id}) do
    with :ok <- require_admin(conn) do
      farm_id = String.to_integer(farm_id)
      {cow_deleted, _} = StateHistory.clear_farm_history(farm_id)

      import Ecto.Query

      {readings_deleted, _} =
        from(r in LivestokOs.Telemetry.SensorReading, where: r.farm_id == ^farm_id)
        |> LivestokOs.Repo.delete_all()

      {satellite_deleted, _} =
        from(r in LivestokOs.Satellite.SatelliteRecord, where: r.farm_id == ^farm_id)
        |> LivestokOs.Repo.delete_all()

      json(conn, %{
        data: %{
          state_logs_deleted: cow_deleted,
          sensor_readings_deleted: readings_deleted,
          satellite_records_deleted: satellite_deleted
        }
      })
    end
  end

  defp require_admin(conn) do
    user = Guardian.Plug.current_resource(conn)

    if user.role == "super_admin" do
      :ok
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Super admin access required"})
      |> halt()
    end
  end

  defp serialize_farm(farm) do
    device_stats = device_stats_for_farm(farm.id)
    alert_count = unresolved_alert_count(farm.id)

    %{
      id: farm.id,
      name: farm.name,
      grazing_mode: farm.grazing_mode,
      location: farm.location,
      unresolved_alerts: alert_count,
      devices_total: device_stats.total,
      devices_online: device_stats.online
    }
  end

  @online_threshold_hours 24

  def list_devices(conn, params) do
    with :ok <- require_admin(conn) do
      limit = parse_limit(params["limit"], 500)
      devices = Telemetry.list_devices(%{"limit" => limit})
      json(conn, %{data: Enum.map(devices, &serialize_admin_device/1)})
    end
  end

  def ledger(conn, %{"farm_id" => farm_id}) do
    with :ok <- require_admin(conn) do
      farm_id = String.to_integer(farm_id)

      chain_status =
        case CarbonLedger.verify_chain(farm_id) do
          {:ok, :chain_valid} -> "valid"
          {:ok, :empty_chain} -> "empty"
          {:error, :chain_broken, _entry} -> "broken"
        end

      entries =
        from(e in CarbonLedgerEntry,
          where: e.farm_id == ^farm_id,
          order_by: [asc: e.inserted_at, asc: e.id]
        )
        |> Repo.all()
        |> Enum.map(&serialize_ledger_entry/1)

      json(conn, %{data: %{chain_status: chain_status, entries: entries}})
    end
  end

  defp device_stats_for_farm(farm_id) do
    devices = from(d in Device, where: d.farm_id == ^farm_id) |> Repo.all()
    online_cutoff = DateTime.utc_now() |> DateTime.add(-@online_threshold_hours * 3600, :second)

    online =
      Enum.count(devices, fn d ->
        d.last_seen_at && DateTime.compare(d.last_seen_at, online_cutoff) != :lt
      end)

    %{total: length(devices), online: online}
  end

  defp unresolved_alert_count(farm_id) do
    from(a in Alert, where: a.farm_id == ^farm_id and a.is_resolved == false)
    |> Repo.aggregate(:count)
  end

  defp serialize_admin_device(device) do
    battery = latest_battery_for_device(device.id)

    %{
      id: device.id,
      serial: device.serial,
      hardware_type: device.hardware_type,
      status: device.status,
      last_seen_at: device.last_seen_at,
      farm_id: device.farm_id,
      farm_name: device.farm && device.farm.name,
      battery_level: battery,
      paired: not is_nil(device.cow),
      cow: cow_summary(device.cow)
    }
  end

  defp latest_battery_for_device(device_id) do
    from(r in SensorReading,
      where: r.device_id == ^device_id and not is_nil(r.battery_level),
      order_by: [desc: r.timestamp],
      limit: 1,
      select: r.battery_level
    )
    |> Repo.one()
  end

  defp serialize_ledger_entry(entry) do
    %{
      id: entry.id,
      record_type: entry.record_type,
      record_id: entry.record_id,
      content_hash: entry.content_hash,
      previous_hash: entry.previous_hash,
      chain_hash: entry.chain_hash,
      inserted_at: entry.inserted_at
    }
  end

  defp cow_summary(nil), do: nil

  defp cow_summary(cow) do
    %{id: cow.id, tag_id: cow.tag_id, name: cow.name}
  end

  defp parse_limit(nil, default), do: default

  defp parse_limit(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {n, _} when n > 0 -> min(n, 500)
      _ -> default
    end
  end

  defp parse_limit(value, _default) when is_integer(value) and value > 0, do: min(value, 500)
  defp parse_limit(_value, default), do: default
end
