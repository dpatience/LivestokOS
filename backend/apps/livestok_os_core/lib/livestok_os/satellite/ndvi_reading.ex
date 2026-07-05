defmodule LivestokOs.Satellite.NdviReading do
  @moduledoc """
  Per-paddock NDVI score captured from satellite imagery.

  `is_stale` is set to true when `captured_at` is older than 6 days
  (expected Sentinel-2 revisit cycle is 5 days + 1 day buffer).
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias LivestokOs.Infrastructure.Geofence
  alias LivestokOs.Inventory.Farm

  @stale_days 6

  schema "ndvi_readings" do
    field :captured_at, :utc_datetime
    field :ndvi_score, :float
    field :is_stale, :boolean, default: false

    belongs_to :paddock, Geofence, foreign_key: :paddock_id
    belongs_to :farm, Farm

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(reading, attrs) do
    reading
    |> cast(attrs, [:paddock_id, :farm_id, :captured_at, :ndvi_score, :is_stale])
    |> validate_required([:paddock_id, :farm_id, :captured_at, :ndvi_score])
    |> validate_number(:ndvi_score, greater_than_or_equal_to: -1.0, less_than_or_equal_to: 1.0)
    |> assoc_constraint(:paddock)
    |> assoc_constraint(:farm)
  end

  @doc "Returns the number of days after which a reading is considered stale."
  def stale_after_days, do: @stale_days
end
