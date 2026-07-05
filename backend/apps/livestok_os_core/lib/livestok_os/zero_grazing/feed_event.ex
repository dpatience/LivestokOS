defmodule LivestokOs.ZeroGrazing.FeedEvent do
  use Ecto.Schema
  import Ecto.Changeset

  alias LivestokOs.Inventory.{Cow, Farm}

  schema "feed_events" do
    field :feed_type, :string
    field :quantity_kg, :float
    field :dry_matter_pct, :float
    field :protein_pct, :float
    field :inhibitor_added, :boolean, default: false
    field :fed_at, :utc_datetime
    field :notes, :string

    belongs_to :cow, Cow
    belongs_to :farm, Farm

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(feed_event, attrs) do
    feed_event
    |> cast(attrs, [
      :feed_type,
      :quantity_kg,
      :dry_matter_pct,
      :protein_pct,
      :inhibitor_added,
      :fed_at,
      :notes,
      :cow_id,
      :farm_id
    ])
    |> validate_required([:feed_type, :quantity_kg, :fed_at, :cow_id])
    |> validate_number(:quantity_kg, greater_than: 0.0)
    |> assoc_constraint(:cow)
    |> assoc_constraint(:farm)
  end
end
