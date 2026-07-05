defmodule LivestokOs.Infrastructure.RotationEvent do
  use Ecto.Schema
  import Ecto.Changeset

  alias LivestokOs.Infrastructure.Geofence
  alias LivestokOs.Inventory.Farm

  schema "rotation_events" do
    field :occurred_at, :utc_datetime
    field :centroid_lat, :float
    field :centroid_lng, :float

    belongs_to :paddock, Geofence, foreign_key: :paddock_id
    belongs_to :farm, Farm

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:paddock_id, :farm_id, :occurred_at, :centroid_lat, :centroid_lng])
    |> validate_required([:paddock_id, :farm_id, :occurred_at, :centroid_lat, :centroid_lng])
    |> assoc_constraint(:paddock)
    |> assoc_constraint(:farm)
  end
end
