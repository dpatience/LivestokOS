defmodule LivestokOs.Carbon.CarbonSequestrationRecord do
  @moduledoc """
  Per-paddock carbon sequestration record for a grazing period.

  Formula (Stage 4A):
    Carbon Sequestered (tCO2e) = soil_type_factor × NDVI_grass_growth_index × rotational_compliance_score

  Applicable only to farms with grazing_mode :pasture or :mixed, gated by
  feature_enabled?(:satellite_ndvi, farm).
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias LivestokOs.Infrastructure.Geofence
  alias LivestokOs.Inventory.Farm

  schema "carbon_sequestration_records" do
    field :period_start, :utc_datetime
    field :period_end, :utc_datetime
    field :soil_type_factor, :float
    field :ndvi_score, :float
    field :compliance_score, :float
    field :carbon_tco2e, :float

    belongs_to :paddock, Geofence, foreign_key: :paddock_id
    belongs_to :farm, Farm

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(record, attrs) do
    record
    |> cast(attrs, [
      :paddock_id,
      :farm_id,
      :period_start,
      :period_end,
      :soil_type_factor,
      :ndvi_score,
      :compliance_score,
      :carbon_tco2e
    ])
    |> validate_required([
      :paddock_id,
      :farm_id,
      :period_start,
      :period_end,
      :soil_type_factor,
      :ndvi_score,
      :compliance_score,
      :carbon_tco2e
    ])
    |> validate_number(:soil_type_factor, greater_than: 0.0)
    |> validate_number(:ndvi_score, greater_than_or_equal_to: -1.0, less_than_or_equal_to: 1.0)
    |> validate_number(:compliance_score, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_number(:carbon_tco2e, greater_than_or_equal_to: 0.0)
    |> assoc_constraint(:paddock)
    |> assoc_constraint(:farm)
  end
end
