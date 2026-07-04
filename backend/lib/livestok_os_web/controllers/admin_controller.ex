defmodule LivestokOsWeb.AdminController do
  use LivestokOsWeb, :controller

  import Ecto.Query

  alias LivestokOs.Inventory
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
    %{
      id: farm.id,
      name: farm.name,
      type: farm.type,
      location: farm.location
    }
  end
end
