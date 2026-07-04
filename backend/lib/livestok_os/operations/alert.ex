defmodule LivestokOs.Operations.Alert do
  use Ecto.Schema
  import Ecto.Changeset

  schema "alerts" do
    field :type, :string
    field :message, :string
    field :is_resolved, :boolean, default: false
    field :severity, :string, default: "warning"
    field :cow_id, :id
    field :farm_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(alert, attrs) do
    alert
    |> cast(attrs, [:type, :message, :is_resolved, :cow_id, :farm_id, :severity])
    |> validate_required([:type, :message, :is_resolved])
    |> validate_inclusion(:severity, ~w(info warning critical))
  end
end
