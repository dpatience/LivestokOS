defmodule LivestokOs.Carbon.AbattoirRecord do
  @moduledoc """
  Deadweight record from slaughter. Used to compute Feed Efficiency Index.

  # TODO: wire to abattoir integration endpoint
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias LivestokOs.Inventory.{Cow, Farm}

  schema "abattoir_records" do
    field :recorded_at, :utc_datetime
    field :deadweight_kg, :float

    belongs_to :cow, Cow
    belongs_to :farm, Farm

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(record, attrs) do
    record
    |> cast(attrs, [:cow_id, :farm_id, :recorded_at, :deadweight_kg])
    |> validate_required([:cow_id, :farm_id, :recorded_at, :deadweight_kg])
    |> validate_number(:deadweight_kg, greater_than: 0.0)
    |> assoc_constraint(:cow)
    |> assoc_constraint(:farm)
  end
end
