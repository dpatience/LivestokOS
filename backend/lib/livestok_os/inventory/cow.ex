defmodule LivestokOs.Inventory.Cow do
  use Ecto.Schema
  import Ecto.Changeset

  alias LivestokOs.Inventory.Farm
  alias LivestokOs.Telemetry.{Device, SensorReading}

  schema "cows" do
    field :tag_id, :string
    field :name, :string
    field :breed, :string
    field :birth_date, :date
    field :status, :string
    field :health_score, :float, default: 100.0
    field :current_state, :string, default: "unknown"

    belongs_to :farm, Farm
    has_many :sensor_readings, SensorReading
    has_many :devices, Device

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(cow, attrs) do
    cow
    |> cast(attrs, [:tag_id, :name, :breed, :birth_date, :status, :farm_id, :health_score, :current_state])
    |> validate_required([:tag_id, :name, :breed, :birth_date, :status])
    |> assoc_constraint(:farm)
  end
end
