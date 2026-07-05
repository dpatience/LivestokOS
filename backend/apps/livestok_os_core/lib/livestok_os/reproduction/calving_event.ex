defmodule LivestokOs.Reproduction.CalvingEvent do
  @moduledoc """
  Records a calving event (birth) for a dam cow.

  Recording a calving event via `Reproduction.record_calving_event/1` will
  automatically update the associated `Gestation` record and create a
  calving-complete alert with `:critical` priority.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias LivestokOs.Inventory.{Cow, Farm}

  @difficulties [:easy, :assisted, :veterinary]

  schema "calving_events" do
    field :occurred_at, :utc_datetime
    field :birth_weight_kg, :float
    field :difficulty, Ecto.Enum, values: @difficulties, default: :easy
    field :notes, :string

    belongs_to :cow, Cow
    belongs_to :farm, Farm
    belongs_to :calf, Cow, foreign_key: :calf_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :cow_id,
      :farm_id,
      :occurred_at,
      :calf_id,
      :birth_weight_kg,
      :difficulty,
      :notes
    ])
    |> validate_required([:cow_id, :farm_id, :occurred_at, :difficulty])
    |> validate_inclusion(:difficulty, @difficulties)
    |> validate_number(:birth_weight_kg, greater_than: 0.0)
    |> assoc_constraint(:cow)
    |> assoc_constraint(:farm)
  end
end
