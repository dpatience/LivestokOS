defmodule LivestokOs.Telemetry.DailyReadingSummary do
  @moduledoc """
  Aggregated daily summary of sensor readings for a single cow.

  Created by the Downsampler when detailed readings age past the retention
  window. Preserves aggregate statistics for historical queries while
  freeing storage consumed by raw per-reading rows.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias LivestokOs.Inventory.{Cow, Farm}

  schema "daily_reading_summaries" do
    field :date, :date
    field :reading_count, :integer
    field :avg_latitude, :float
    field :avg_longitude, :float
    field :avg_speed_mps, :float
    field :avg_battery_level, :float
    field :behavior_counts, :map, default: %{}

    belongs_to :cow, Cow
    belongs_to :farm, Farm

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(summary, attrs) do
    summary
    |> cast(attrs, [
      :date,
      :reading_count,
      :avg_latitude,
      :avg_longitude,
      :avg_speed_mps,
      :avg_battery_level,
      :behavior_counts,
      :cow_id,
      :farm_id
    ])
    |> validate_required([:date, :reading_count, :cow_id, :farm_id])
    |> unique_constraint([:cow_id, :date])
    |> assoc_constraint(:cow)
    |> assoc_constraint(:farm)
  end
end
