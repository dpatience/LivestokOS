defmodule LivestokOs.Carbon.MethaneAvoidanceCredit do
  @moduledoc """
  Mass-balance methane avoidance credit per farm per period.

  Formula (Stage 4B):
    methane_avoided_kg = slurry_volume_m3 × methane_yield_factor
    credit_tco2e       = methane_avoided_kg × (1/1000) × (GWP_CH4 = 28)

  # TODO: source empirically derived yield factor for herd's TMR composition
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias LivestokOs.Inventory.Farm

  schema "methane_avoidance_credits" do
    field :period_start, :utc_datetime
    field :period_end, :utc_datetime
    field :slurry_volume_m3, :float
    field :methane_yield_factor, :float
    field :methane_avoided_kg, :float
    field :credit_tco2e, :float

    belongs_to :farm, Farm

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(credit, attrs) do
    credit
    |> cast(attrs, [
      :farm_id,
      :period_start,
      :period_end,
      :slurry_volume_m3,
      :methane_yield_factor,
      :methane_avoided_kg,
      :credit_tco2e
    ])
    |> validate_required([
      :farm_id,
      :period_start,
      :period_end,
      :slurry_volume_m3,
      :methane_yield_factor,
      :methane_avoided_kg,
      :credit_tco2e
    ])
    |> validate_number(:slurry_volume_m3, greater_than: 0.0)
    |> validate_number(:methane_yield_factor, greater_than: 0.0)
    |> validate_number(:methane_avoided_kg, greater_than_or_equal_to: 0.0)
    |> validate_number(:credit_tco2e, greater_than_or_equal_to: 0.0)
    |> assoc_constraint(:farm)
  end
end
