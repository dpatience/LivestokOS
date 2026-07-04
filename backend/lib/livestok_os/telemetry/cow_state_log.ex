defmodule LivestokOs.Telemetry.CowStateLog do
  @moduledoc """
  Persisted record of a cow's behavioral state transition.
  Each time the Digital Twin GenServer detects a state change
  (e.g., Resting → Grazing → Ruminating), a CowStateLog row
  is inserted with precise timestamps for historical graphing.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias LivestokOs.Inventory.{Cow, Farm}

  schema "cow_state_logs" do
    field :from_state, :string
    field :to_state, :string
    field :occurred_at, :utc_datetime
    field :metadata, :map, default: %{}

    belongs_to :cow, Cow
    belongs_to :farm, Farm

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(log, attrs) do
    log
    |> cast(attrs, [:from_state, :to_state, :occurred_at, :metadata, :cow_id, :farm_id])
    |> validate_required([:to_state, :occurred_at, :cow_id, :farm_id])
    |> assoc_constraint(:cow)
    |> assoc_constraint(:farm)
  end
end
