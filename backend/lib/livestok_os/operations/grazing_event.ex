defmodule LivestokOs.Operations.GrazingEvent do
  use Ecto.Schema
  import Ecto.Changeset

  alias LivestokOs.Inventory.Cow

  schema "grazing_events" do
    field :zone_id, :string
    field :entered_at, :utc_datetime
    field :left_at, :utc_datetime
    field :farm_id, :id

    belongs_to :cow, Cow

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(grazing_event, attrs) do
    grazing_event
    |> cast(attrs, [:zone_id, :entered_at, :left_at, :farm_id, :cow_id])
    |> validate_required([:zone_id, :entered_at, :cow_id])
    |> assoc_constraint(:cow)
  end
end
