defmodule LivestokOs.ZeroGrazing.InhibitorDose do
  use Ecto.Schema
  import Ecto.Changeset

  alias LivestokOs.Inventory.Cow

  schema "inhibitor_doses" do
    field :inhibitor_type, :string
    field :dose_mg, :float
    field :administered_at, :utc_datetime
    field :effectiveness_pct, :float
    field :notes, :string

    belongs_to :cow, Cow

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(inhibitor_dose, attrs) do
    inhibitor_dose
    |> cast(attrs, [
      :inhibitor_type,
      :dose_mg,
      :administered_at,
      :effectiveness_pct,
      :notes,
      :cow_id
    ])
    |> validate_required([:inhibitor_type, :dose_mg, :administered_at, :cow_id])
    |> validate_number(:dose_mg, greater_than: 0.0)
    |> assoc_constraint(:cow)
  end
end
