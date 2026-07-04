defmodule LivestokOs.Telemetry.SensorReading do
  use Ecto.Schema
  import Ecto.Changeset

  alias LivestokOs.Inventory.Cow
  alias LivestokOs.Telemetry.Device

  schema "sensor_readings" do
    field :timestamp, :utc_datetime
    field :latitude, :float
    field :longitude, :float
    field :activity, :string
    field :data, :map
    field :behavior_label, :string
    field :behavior_confidence, :float
    field :speed_mps, :float
    field :battery_level, :float
    field :source, :string, default: "ear_tag"
    field :zone_id, :string

    belongs_to :cow, Cow
    belongs_to :device, Device

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(sensor_reading, attrs) do
    sensor_reading
    |> cast(attrs, [
      :timestamp,
      :latitude,
      :longitude,
      :activity,
      :data,
      :behavior_label,
      :behavior_confidence,
      :speed_mps,
      :battery_level,
      :source,
      :zone_id,
      :cow_id,
      :device_id
    ])
    |> validate_required([:timestamp, :latitude, :longitude, :activity, :source])
    |> assoc_constraint(:cow)
    |> assoc_constraint(:device)
  end
end
