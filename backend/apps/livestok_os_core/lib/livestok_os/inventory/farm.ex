defmodule LivestokOs.Inventory.Farm do
  use Ecto.Schema
  import Ecto.Changeset

  alias LivestokOs.Inventory.Cow

  @grazing_modes [:pasture, :zero_grazing, :mixed]

  schema "farms" do
    field :name, :string
    field :location, :string
    field :grazing_mode, Ecto.Enum, values: @grazing_modes, default: :pasture
    # TODO: set agronomically validated default — currently nil means no threshold
    field :ndvi_alert_threshold, :float
    # TODO: generate per-farm keypair at onboarding
    field :passport_signing_key, :binary

    has_many :cows, Cow

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(farm, attrs) do
    farm
    |> cast(attrs, [:name, :location, :grazing_mode, :ndvi_alert_threshold, :passport_signing_key])
    |> validate_required([:name, :location])
    |> validate_inclusion(:grazing_mode, @grazing_modes)
  end

  def pasture_grazing?(farm), do: farm.grazing_mode in [:pasture, :mixed]
  def zero_grazing?(farm), do: farm.grazing_mode in [:zero_grazing, :mixed]
end
