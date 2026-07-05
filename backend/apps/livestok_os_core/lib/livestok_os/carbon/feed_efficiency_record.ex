defmodule LivestokOs.Carbon.FeedEfficiencyRecord do
  @moduledoc """
  Feed Efficiency Index per animal.

  Feed Efficiency Index = deadweight_kg / cumulative_grazing_hours

  Higher index = better feed conversion (better performer).
  Lower index = culling candidate.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias LivestokOs.Inventory.{Cow, Farm}

  schema "feed_efficiency_records" do
    field :calculated_at, :utc_datetime
    field :deadweight_kg, :float
    field :cumulative_grazing_hours, :float
    field :feed_efficiency_index, :float

    belongs_to :cow, Cow
    belongs_to :farm, Farm

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(record, attrs) do
    record
    |> cast(attrs, [
      :cow_id,
      :farm_id,
      :calculated_at,
      :deadweight_kg,
      :cumulative_grazing_hours,
      :feed_efficiency_index
    ])
    |> validate_required([
      :cow_id,
      :farm_id,
      :calculated_at,
      :deadweight_kg,
      :cumulative_grazing_hours,
      :feed_efficiency_index
    ])
    |> validate_number(:deadweight_kg, greater_than: 0.0)
    |> validate_number(:cumulative_grazing_hours, greater_than: 0.0)
    |> validate_number(:feed_efficiency_index, greater_than_or_equal_to: 0.0)
    |> assoc_constraint(:cow)
    |> assoc_constraint(:farm)
  end
end
