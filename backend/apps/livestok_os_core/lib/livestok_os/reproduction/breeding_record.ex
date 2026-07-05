defmodule LivestokOs.Reproduction.BreedingRecord do
  @moduledoc """
  Records an insemination or natural breeding event for a female cow.

  `outcome` starts as `:pending` and is updated to `:confirmed_pregnant`
  or `:failed` once pregnancy check results are known.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias LivestokOs.Inventory.{Cow, Farm}

  @methods [:ai, :natural]
  @outcomes [:pending, :confirmed_pregnant, :failed]

  schema "breeding_records" do
    field :insemination_date, :date
    field :method, Ecto.Enum, values: @methods, default: :ai
    field :sire_reference, :string
    field :outcome, Ecto.Enum, values: @outcomes, default: :pending
    field :confirmed_at, :utc_datetime

    belongs_to :cow, Cow
    belongs_to :farm, Farm
    belongs_to :sire, Cow, foreign_key: :sire_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(record, attrs) do
    record
    |> cast(attrs, [
      :cow_id,
      :farm_id,
      :insemination_date,
      :method,
      :sire_id,
      :sire_reference,
      :outcome,
      :confirmed_at
    ])
    |> validate_required([:cow_id, :farm_id, :insemination_date, :method])
    |> validate_inclusion(:method, @methods)
    |> validate_inclusion(:outcome, @outcomes)
    |> assoc_constraint(:cow)
    |> assoc_constraint(:farm)
  end
end
