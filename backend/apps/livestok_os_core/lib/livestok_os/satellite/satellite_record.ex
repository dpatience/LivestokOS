defmodule LivestokOs.Satellite.SatelliteRecord do
  @moduledoc """
  Persisted satellite data snapshots for a farm zone.
  Stores NDVI scores, carbon metrics, soil health, and image URLs
  for time-series environmental analysis.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias LivestokOs.Inventory.Farm

  schema "satellite_records" do
    field :zone_id, :string
    field :ndvi_score, :float
    field :carbon_metric, :float
    field :soil_health, :float
    field :image_url, :string
    field :captured_at, :utc_datetime
    field :source, :string, default: "sentinel-2"
    field :metadata, :map, default: %{}

    belongs_to :farm, Farm

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(record, attrs) do
    record
    |> cast(attrs, [
      :zone_id,
      :ndvi_score,
      :carbon_metric,
      :soil_health,
      :image_url,
      :captured_at,
      :source,
      :metadata,
      :farm_id
    ])
    |> validate_required([:captured_at, :farm_id])
    |> assoc_constraint(:farm)
  end
end
