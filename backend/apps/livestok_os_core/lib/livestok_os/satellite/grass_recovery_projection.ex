defmodule LivestokOs.Satellite.GrassRecoveryProjection do
  @moduledoc """
  Grass recovery projection per paddock, combining NDVI data with
  weather forecasts (precipitation / temperature).

  `weather_source` identifies the forecast provider used (e.g. "open_meteo",
  "mock"). Open-Meteo (https://api.open-meteo.com) is the intended production
  provider — free, no auth required. Integration is stubbed via the
  `LivestokOs.Satellite.WeatherProvider` behaviour until the real endpoint
  shape is verified.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias LivestokOs.Infrastructure.Geofence
  alias LivestokOs.Inventory.Farm

  schema "grass_recovery_projections" do
    field :projected_at, :utc_datetime
    field :days_to_recovery, :integer
    field :confidence, :float
    field :weather_source, :string

    belongs_to :paddock, Geofence, foreign_key: :paddock_id
    belongs_to :farm, Farm

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(projection, attrs) do
    projection
    |> cast(attrs, [
      :paddock_id,
      :farm_id,
      :projected_at,
      :days_to_recovery,
      :confidence,
      :weather_source
    ])
    |> validate_required([:paddock_id, :farm_id, :projected_at, :days_to_recovery, :confidence])
    |> validate_number(:days_to_recovery, greater_than_or_equal_to: 0)
    |> validate_number(:confidence, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> assoc_constraint(:paddock)
    |> assoc_constraint(:farm)
  end
end
