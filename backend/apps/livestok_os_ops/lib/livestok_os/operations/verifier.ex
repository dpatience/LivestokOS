defmodule LivestokOs.Operations.Verifier do
  @moduledoc """
  Regenerative-grazing verification engine.

  Zone-aware: queries actual grazing events grouped by zone to determine
  whether rotation thresholds are met.
  """
  import Ecto.Query, warn: false
  alias LivestokOs.Repo
  alias LivestokOs.Operations.GrazingEvent
  alias LivestokOs.Satellite

  @carbon_base_rate 0.05
  @max_days_per_zone 2

  @doc """
  Verifies that a cow has been rotating zones properly.

  Checks the most recent grazing events grouped by zone. If any zone has been
  grazed for more than `@max_days_per_zone` consecutive days, returns an
  overgrazing error with details.
  """
  def verify_rotation(cow_id, _current_zone_id, entered_at) do
    since = DateTime.to_date(entered_at)

    events =
      from(e in GrazingEvent,
        where: e.cow_id == ^cow_id and e.entered_at >= ^since,
        order_by: [asc: e.entered_at]
      )
      |> Repo.all()

    case events do
      [] ->
        # No events recorded – treat as compliant (new cow)
        {:ok, :regenerative_verified}

      events ->
        overgrazing_zones =
          events
          |> Enum.group_by(& &1.zone_id)
          |> Enum.filter(fn {_zone, zone_events} ->
            days = zone_days(zone_events)
            days > @max_days_per_zone
          end)
          |> Enum.map(fn {zone_id, zone_events} ->
            %{zone_id: zone_id, days: zone_days(zone_events)}
          end)

        if overgrazing_zones == [] do
          {:ok, :regenerative_verified}
        else
          {:error, {:overgrazing_detected, overgrazing_zones}}
        end
    end
  end

  @doc """
  Calculates the daily carbon credit yield for a cow at a given coordinate,
  factoring in NDVI and soil quality.
  """
  def calculate_daily_carbon_credit(cow_id, lat, long) do
    {:ok, ndvi} = Satellite.get_current_ndvi(lat, long)
    soil_factor = Satellite.get_soil_factor(lat, long)

    grass_growth_factor = if ndvi > 0.5, do: 1.2, else: 0.8
    daily_carbon_tons = @carbon_base_rate * soil_factor * grass_growth_factor

    %{
      cow_id: cow_id,
      carbon_added: daily_carbon_tons,
      ndvi_snapshot: ndvi
    }
  end

  # ---------------------------------------------------------------------------

  defp zone_days(zone_events) do
    zone_events
    |> Enum.flat_map(fn e ->
      start_date = DateTime.to_date(e.entered_at)
      end_date = if e.left_at, do: DateTime.to_date(e.left_at), else: Date.utc_today()
      Date.range(start_date, end_date) |> Enum.to_list()
    end)
    |> Enum.uniq()
    |> length()
  end
end
