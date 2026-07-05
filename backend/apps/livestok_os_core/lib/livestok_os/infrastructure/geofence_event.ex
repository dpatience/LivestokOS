defmodule LivestokOs.Infrastructure.GeofenceEvent do
  use Ecto.Schema
  import Ecto.Changeset

  alias LivestokOs.Infrastructure.Geofence
  alias LivestokOs.Telemetry.Device

  schema "geofence_events" do
    field :event_type, :string
    field :occurred_at, :utc_datetime
    field :payload, :map, default: %{}
    field :farm_id, :id

    belongs_to :geofence, Geofence
    belongs_to :device, Device

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(geofence_event, attrs) do
    geofence_event
    |> cast(attrs, [:event_type, :occurred_at, :payload, :geofence_id, :device_id, :farm_id])
    |> validate_required([:event_type, :occurred_at, :geofence_id, :device_id])
    |> assoc_constraint(:geofence)
    |> assoc_constraint(:device)
  end
end
