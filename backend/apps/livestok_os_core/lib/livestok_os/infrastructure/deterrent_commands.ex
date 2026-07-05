defmodule LivestokOs.Infrastructure.DeterrentCommands do
  @moduledoc """
  Context for managing virtual-fence deterrent commands.

  Commands are issued when a cow leaves its assigned paddock boundary.
  Because the LoRaWAN setup is uplink-only (no downlink capability), commands
  are not pushed to collars; instead, firmware polls:

      GET /api/farms/:farm_id/cows/:cow_id/pending_deterrent_commands

  and acknowledges receipt via:

      POST /api/farms/:farm_id/cows/:cow_id/deterrent_commands/:id/acknowledge

  All queries are scoped to `farm_id` for multi-tenant safety.
  """

  import Ecto.Query, warn: false
  alias LivestokOs.Repo
  alias LivestokOs.Infrastructure.DeterrentCommand

  @doc """
  Creates a deterrent command for a cow that has left its paddock.
  """
  def create_command(attrs) do
    %DeterrentCommand{}
    |> DeterrentCommand.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Lists unacknowledged deterrent commands for a cow, scoped to farm_id.
  Returns commands ordered oldest-first so firmware processes them in order.
  """
  def list_pending(cow_id, farm_id) do
    from(c in DeterrentCommand,
      where:
        c.cow_id == ^cow_id and
          c.farm_id == ^farm_id and
          is_nil(c.acknowledged_at),
      order_by: [asc: c.issued_at]
    )
    |> Repo.all()
  end

  @doc """
  Gets a single command, scoped to farm_id.
  Returns `{:ok, command}` or `{:error, :not_found}`.
  """
  def get_command(id, farm_id) do
    case Repo.get_by(DeterrentCommand, id: id, farm_id: farm_id) do
      nil -> {:error, :not_found}
      cmd -> {:ok, cmd}
    end
  end

  @doc """
  Marks a command as acknowledged by the firmware.
  Returns `{:ok, command}` or `{:error, :not_found}`.
  """
  def acknowledge(id, farm_id) do
    with {:ok, command} <- get_command(id, farm_id) do
      command
      |> DeterrentCommand.changeset(%{acknowledged_at: DateTime.utc_now()})
      |> Repo.update()
    end
  end
end
