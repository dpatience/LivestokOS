defmodule LivestokOs.Telemetry.Device do
  use Ecto.Schema
  import Ecto.Changeset

  alias LivestokOs.Inventory.Cow
  alias LivestokOs.Inventory.Farm
  alias LivestokOs.Telemetry.SensorReading

  schema "devices" do
    field :serial, :string
    field :hardware_type, :string
    field :firmware_version, :string
    field :status, :string, default: "online"
    field :last_seen_at, :utc_datetime
    field :metadata, :map, default: %{}

    belongs_to :cow, Cow
    belongs_to :farm, Farm

    has_many :sensor_readings, SensorReading

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(device, attrs) do
    device
    |> cast(attrs, [
      :serial,
      :hardware_type,
      :firmware_version,
      :status,
      :last_seen_at,
      :metadata,
      :cow_id,
      :farm_id
    ])
    |> validate_required([:serial, :hardware_type])
    |> unique_constraint(:serial)
    |> assoc_constraint(:cow)
    |> assoc_constraint(:farm)
  end
end
