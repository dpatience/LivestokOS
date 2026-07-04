defmodule LivestokOs.Inventory.Farm do
  use Ecto.Schema
  import Ecto.Changeset

  alias LivestokOs.Inventory.Cow

  schema "farms" do
    field :name, :string
    field :type, :string
    field :location, :string

    has_many :cows, Cow

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(farm, attrs) do
    farm
    |> cast(attrs, [:name, :type, :location])
    |> validate_required([:name, :type, :location])
    |> validate_inclusion(:type, ~w(zero_grazing pasture_grazing))
  end

  def pasture_grazing?(farm), do: farm.type == "pasture_grazing"
  def zero_grazing?(farm), do: farm.type == "zero_grazing"
end
