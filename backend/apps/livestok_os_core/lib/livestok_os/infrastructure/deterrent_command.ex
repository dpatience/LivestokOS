defmodule LivestokOs.Infrastructure.DeterrentCommand do
  @moduledoc """
  Represents a firmware command issued to a smart collar when a cow leaves
  its assigned paddock.

  ## LoRaWAN Downlink Note
  The current LoRaWAN setup supports uplinks only (collar → server). There is
  NO downlink capability to push commands directly to collars. Commands are
  therefore exposed via a polling endpoint that collar firmware calls
  periodically:

      GET /api/farms/:farm_id/cows/:cow_id/pending_deterrent_commands

  Firmware acknowledges receipt via:

      POST /api/farms/:farm_id/cows/:cow_id/deterrent_commands/:id/acknowledge
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias LivestokOs.Inventory.{Cow, Farm}
  alias LivestokOs.Infrastructure.Geofence

  schema "deterrent_commands" do
    field :command_type, :string
    field :issued_at, :utc_datetime
    field :acknowledged_at, :utc_datetime
    field :payload, :map, default: %{}

    belongs_to :cow, Cow
    belongs_to :farm, Farm
    belongs_to :geofence, Geofence

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(command, attrs) do
    command
    |> cast(attrs, [
      :cow_id,
      :farm_id,
      :geofence_id,
      :command_type,
      :issued_at,
      :acknowledged_at,
      :payload
    ])
    |> validate_required([:cow_id, :farm_id, :command_type, :issued_at])
    |> assoc_constraint(:cow)
    |> assoc_constraint(:farm)
  end

  @doc "Returns true if this command has been acknowledged by the firmware."
  def acknowledged?(%__MODULE__{acknowledged_at: nil}), do: false
  def acknowledged?(%__MODULE__{}), do: true
end
