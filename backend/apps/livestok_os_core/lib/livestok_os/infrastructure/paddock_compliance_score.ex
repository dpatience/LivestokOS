defmodule LivestokOs.Infrastructure.PaddockComplianceScore do
  use Ecto.Schema
  import Ecto.Changeset

  alias LivestokOs.Infrastructure.Geofence
  alias LivestokOs.Inventory.Farm

  schema "paddock_compliance_scores" do
    field :period_start, :utc_datetime
    field :period_end, :utc_datetime
    field :prescribed_rotations, :integer
    field :actual_rotations, :integer, default: 0
    field :compliance_score, :float, default: 0.0

    belongs_to :paddock, Geofence, foreign_key: :paddock_id
    belongs_to :farm, Farm

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(score, attrs) do
    score
    |> cast(attrs, [
      :paddock_id,
      :farm_id,
      :period_start,
      :period_end,
      :prescribed_rotations,
      :actual_rotations,
      :compliance_score
    ])
    |> validate_required([:paddock_id, :farm_id, :period_start, :period_end, :prescribed_rotations])
    |> validate_number(:prescribed_rotations, greater_than: 0)
    |> validate_number(:actual_rotations, greater_than_or_equal_to: 0)
    |> validate_number(:compliance_score, greater_than_or_equal_to: 0.0)
    |> assoc_constraint(:paddock)
    |> assoc_constraint(:farm)
    |> compute_score()
  end

  defp compute_score(changeset) do
    actual = get_field(changeset, :actual_rotations) || 0
    prescribed = get_field(changeset, :prescribed_rotations) || 0

    if prescribed > 0 do
      score = min(1.0, actual / prescribed)
      put_change(changeset, :compliance_score, Float.round(score, 4))
    else
      changeset
    end
  end
end
