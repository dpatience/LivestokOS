defmodule LivestokOs.Operations.Alert do
  @moduledoc """
  Alert schema representing a farm-level operational notification.

  ## Severity Score

  `severity_score` is a **virtual field** (not stored in the database).
  It is computed at the application layer from `type` using the table
  below.  We chose a virtual field rather than a DB column because:

  1. Severity ordering is a business-logic concern that can change without
     migrations.
  2. The alert `type` is already stored and is the single source of truth.
  3. Query-time sorting is performed in Elixir (alerts per farm are
     bounded in practice) or via `Ecto.Query.fragment/1` when needed.

  ### Severity Score Reference

  | type                   | score |
  |------------------------|-------|
  | calving_imminent       | 100   |
  | heat_stress            |  90   |
  | bms_command            |  85   |
  | overdue_gestation      |  80   |
  | estrus_proxy           |  70   |
  | geofence_breach        |  60   |
  | ndvi_lick_block        |  50   |
  | HEALTH_RISK            |  45   |
  | METHANE_RISK           |  40   |
  | shade_water_alert      |  40   |
  | OVERGRAZING            |  35   |
  | grazing_recommendation |  20   |
  | general_info           |  10   |
  | (unknown)              |   0   |
  """

  use Ecto.Schema
  import Ecto.Changeset

  @priority_values ~w(low medium high critical)

  @severity_scores %{
    "calving_imminent" => 100,
    "heat_stress" => 90,
    "bms_command" => 85,
    "overdue_gestation" => 80,
    "estrus_proxy" => 70,
    "geofence_breach" => 60,
    "ndvi_lick_block" => 50,
    "HEALTH_RISK" => 45,
    "METHANE_RISK" => 40,
    "shade_water_alert" => 40,
    "OVERGRAZING" => 35,
    "grazing_recommendation" => 20,
    "general_info" => 10
  }

  schema "alerts" do
    field :type, :string
    field :message, :string
    field :is_resolved, :boolean, default: false
    field :severity, :string, default: "warning"
    field :priority, :string, default: "medium"
    field :cow_id, :id
    field :farm_id, :id

    # Virtual — computed from :type at the application layer; not stored in DB.
    field :severity_score, :integer, virtual: true

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(alert, attrs) do
    alert
    |> cast(attrs, [:type, :message, :is_resolved, :cow_id, :farm_id, :severity, :priority])
    |> validate_required([:type, :message, :is_resolved])
    |> validate_inclusion(:severity, ~w(info warning critical))
    |> validate_inclusion(:priority, @priority_values)
  end

  @doc """
  Populates the virtual `severity_score` field from the alert's `type`.
  Call this after loading alerts from the DB.
  """
  def with_severity_score(%__MODULE__{} = alert) do
    %{alert | severity_score: score_for_type(alert.type)}
  end

  @doc "Returns the numeric severity score for a given alert type string."
  def score_for_type(type) when is_binary(type) do
    Map.get(@severity_scores, type, 0)
  end

  def score_for_type(_), do: 0
end
