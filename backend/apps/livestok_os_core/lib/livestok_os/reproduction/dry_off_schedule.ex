defmodule LivestokOs.Reproduction.DryOffSchedule do
  @moduledoc """
  Schedules the dry-off date for a cow approaching calving.

  `scheduled_dry_off_date` = `expected_calving_date - 60 days`.
  Source: standard 60-day dry period; verify with herd vet before adjusting.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias LivestokOs.Inventory.{Cow, Farm}
  alias LivestokOs.Reproduction.Gestation

  @statuses [:scheduled, :completed]

  schema "dry_off_schedules" do
    field :scheduled_dry_off_date, :date
    field :actual_dry_off_date, :date
    field :status, Ecto.Enum, values: @statuses, default: :scheduled

    belongs_to :cow, Cow
    belongs_to :farm, Farm
    belongs_to :gestation, Gestation

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(schedule, attrs) do
    schedule
    |> cast(attrs, [
      :cow_id,
      :farm_id,
      :gestation_id,
      :scheduled_dry_off_date,
      :actual_dry_off_date,
      :status
    ])
    |> validate_required([:cow_id, :farm_id, :gestation_id, :scheduled_dry_off_date])
    |> validate_inclusion(:status, @statuses)
    |> assoc_constraint(:cow)
    |> assoc_constraint(:farm)
    |> assoc_constraint(:gestation)
  end
end
