defmodule LivestokOs.ZeroGrazing.BiogasRecord do
  use Ecto.Schema
  import Ecto.Changeset

  alias LivestokOs.Inventory.Farm

  schema "biogas_records" do
    field :volume_m3, :float
    field :methane_pct, :float
    field :source, :string, default: "manure"
    field :captured_at, :utc_datetime
    field :metadata, :map, default: %{}

    belongs_to :farm, Farm

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(biogas_record, attrs) do
    biogas_record
    |> cast(attrs, [:volume_m3, :methane_pct, :source, :captured_at, :metadata, :farm_id])
    |> validate_required([:volume_m3, :captured_at, :farm_id])
    |> validate_number(:volume_m3, greater_than: 0.0)
    |> assoc_constraint(:farm)
  end
end
