defmodule LivestokOs.Reproduction.Gestation do
  @moduledoc """
  Tracks an active or completed gestation for a female cow.

  `expected_calving_date` is computed as `conception_date + 283 days`
  (standard Bos taurus gestation length — see `Reproduction.expected_calving_date/1`).
  This constant is breed-specific; mark as configurable per breed if extending to
  non-Bos-taurus herds.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias LivestokOs.Inventory.{Cow, Farm}
  alias LivestokOs.Reproduction.BreedingRecord

  @statuses [:active, :calved, :lost]

  schema "gestation_records" do
    field :conception_date, :date
    field :expected_calving_date, :date
    field :actual_calving_date, :date
    field :status, Ecto.Enum, values: @statuses, default: :active

    belongs_to :cow, Cow
    belongs_to :farm, Farm
    belongs_to :breeding_record, BreedingRecord

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(gestation, attrs) do
    gestation
    |> cast(attrs, [
      :cow_id,
      :farm_id,
      :breeding_record_id,
      :conception_date,
      :expected_calving_date,
      :actual_calving_date,
      :status
    ])
    |> validate_required([:cow_id, :farm_id, :breeding_record_id, :conception_date,
                          :expected_calving_date])
    |> validate_inclusion(:status, @statuses)
    |> assoc_constraint(:cow)
    |> assoc_constraint(:farm)
    |> assoc_constraint(:breeding_record)
  end
end
