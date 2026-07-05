defmodule LivestokOsWeb.DeterrentCommandJSON do
  alias LivestokOs.Infrastructure.DeterrentCommand

  def index(%{commands: commands}) do
    %{data: Enum.map(commands, &data/1)}
  end

  def show(%{command: command}) do
    %{data: data(command)}
  end

  defp data(%DeterrentCommand{} = cmd) do
    %{
      id: cmd.id,
      cow_id: cmd.cow_id,
      farm_id: cmd.farm_id,
      geofence_id: cmd.geofence_id,
      command_type: cmd.command_type,
      issued_at: cmd.issued_at,
      acknowledged_at: cmd.acknowledged_at,
      payload: cmd.payload
    }
  end
end
