defmodule LivestokOs.Reproduction.LactationRecord do
  @moduledoc """
  Records a single milking session yield for a cow.

  # TODO: wire to milking-parlor/robot integration endpoint
  Currently accepts manual entry only (`source: "manual"`).
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias LivestokOs.Inventory.{Cow, Farm}

  schema "lactation_records" do
    field :milking_date, :date
    field :yield_liters, :float
    field :fat_pct, :float
    field :protein_pct, :float
    field :source, :string, default: "manual"

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
      :milking_date,
      :yield_liters,
      :fat_pct,
      :protein_pct,
      :source
    ])
    |> validate_required([:cow_id, :farm_id, :milking_date, :yield_liters])
    |> validate_number(:yield_liters, greater_than_or_equal_to: 0.0)
    |> validate_number(:fat_pct, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 100.0)
    |> validate_number(:protein_pct, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 100.0)
    |> assoc_constraint(:cow)
    |> assoc_constraint(:farm)
  end
end
