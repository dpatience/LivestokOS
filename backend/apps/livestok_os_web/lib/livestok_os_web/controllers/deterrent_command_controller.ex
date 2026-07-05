defmodule LivestokOsWeb.DeterrentCommandController do
  @moduledoc """
  Collar firmware polling endpoints for virtual-fence deterrent commands.

  ## LoRaWAN downlink note
  The current LoRaWAN setup is **uplink-only** — the server cannot push
  commands down to collars. Firmware must therefore poll:

      GET /api/farms/:farm_id/cows/:cow_id/pending_deterrent_commands

  and acknowledge commands via:

      POST /api/farms/:farm_id/cows/:cow_id/deterrent_commands/:id/acknowledge

  All queries are scoped to `farm_id` to enforce multi-tenant isolation.
  """
  use LivestokOsWeb, :controller

  alias LivestokOs.Infrastructure.DeterrentCommands

  action_fallback LivestokOsWeb.FallbackController

  @doc "Lists unacknowledged deterrent commands for a cow (farm-scoped)."
  def pending(conn, %{"farm_id" => farm_id, "cow_id" => cow_id}) do
    farm_id = String.to_integer(farm_id)
    cow_id = String.to_integer(cow_id)
    commands = DeterrentCommands.list_pending(cow_id, farm_id)
    render(conn, :index, commands: commands)
  end

  @doc "Marks a deterrent command as acknowledged by the firmware."
  def acknowledge(conn, %{"farm_id" => farm_id, "id" => id}) do
    farm_id = String.to_integer(farm_id)
    id = String.to_integer(id)

    with {:ok, command} <- DeterrentCommands.acknowledge(id, farm_id) do
      render(conn, :show, command: command)
    end
  end
end
