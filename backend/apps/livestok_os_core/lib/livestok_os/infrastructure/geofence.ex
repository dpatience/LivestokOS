defmodule LivestokOs.Infrastructure.Geofence do
  use Ecto.Schema
  import Ecto.Changeset

  alias LivestokOs.Infrastructure.GeofenceEvent

  schema "geofences" do
    field :name, :string
    field :enforcement_scope, :string
    field :geometry, :map
    field :is_active, :boolean, default: true
    field :description, :string
    field :farm_id, :id
    # Farmer-provided at onboarding.
    # TODO: wire to farmer onboarding flow
    field :soil_type_factor, :float
    field :soil_classification, :string

    has_many :events, GeofenceEvent

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(geofence, attrs) do
    geofence
    |> cast(attrs, [
      :name,
      :enforcement_scope,
      :geometry,
      :is_active,
      :description,
      :farm_id,
      :soil_type_factor,
      :soil_classification
    ])
    |> validate_required([:name, :enforcement_scope, :geometry])
  end
end
