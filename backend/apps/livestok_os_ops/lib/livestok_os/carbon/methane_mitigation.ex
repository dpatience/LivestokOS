defmodule LivestokOs.MethaneMitigation do
  @moduledoc """
  Indoor methane avoidance accounting for :zero_grazing and :mixed farms.

  ## IPCC Tier 2-style methane estimation (Stage 4B)
  Methane Output (kg CH4/day) = activity_level × feed_type_factor × digestion_coefficient

  All emission factors below are PLACEHOLDERS.
  # TODO: replace with verified IPCC Tier 2 emission factors — current values are placeholders

  ## Feature gate
  All entry points check `feature_enabled?(:rfid_inhibitor_dosing, farm)` or
  `grazing_mode in [:zero_grazing, :mixed]`.

  ## Feed-robot integration
  High-emitter flagging is gated by `:rfid_inhibitor_dosing` feature flag.
  The FeedRobot.Adapter callback defines the vendor integration contract.
  """

  import Ecto.Query, warn: false
  alias LivestokOs.Repo
  alias LivestokOs.Carbon.MethaneAvoidanceCredit
  alias LivestokOs.ZeroGrazing.FeedEvent
  alias LivestokOs.Operations
  alias LivestokOs.Inventory

  require Logger

  # ---------------------------------------------------------------------------
  # IPCC Tier 2 emission factors (PLACEHOLDER — replace with verified values)
  # ---------------------------------------------------------------------------

  # TODO: replace with verified IPCC Tier 2 emission factor — current value is a placeholder
  @default_activity_level 1.0

  # TODO: replace with verified IPCC Tier 2 emission factor — current value is a placeholder
  @feed_type_factors %{
    "maize_silage" => 0.055,
    "hay" => 0.065,
    "grass_silage" => 0.058,
    "tmr" => 0.060,
    "concentrate" => 0.040
  }

  # TODO: replace with verified IPCC Tier 2 emission factor — current value is a placeholder
  @default_feed_type_factor 0.060

  # Global Warming Potential for CH4 (AR5 20-year GWP).
  # TODO: replace with verified IPCC Tier 2 emission factor — current value is a placeholder
  @gwp_ch4 84

  # ---------------------------------------------------------------------------
  # Methane estimation
  # ---------------------------------------------------------------------------

  @doc """
  Estimates daily methane output (kg CH4/day) for a cow based on its most
  recent feed event.

  Formula (IPCC Tier 2 approximation):
    Methane Output (kg CH4/day) = activity_level × feed_type_factor × digestion_coefficient

  Returns `{:ok, kg_ch4_per_day}` or `{:error, :no_feed_data}`.
  """
  def estimate_daily_methane(cow_id, farm_id) do
    case latest_feed_event(cow_id, farm_id) do
      nil ->
        {:error, :no_feed_data}

      feed_event ->
        feed_factor = Map.get(@feed_type_factors, feed_event.feed_type, @default_feed_type_factor)
        digestion_coeff = digestion_coefficient(feed_event.dry_matter_pct)

        kg_ch4 = @default_activity_level * feed_factor * digestion_coeff
        {:ok, Float.round(kg_ch4, 6)}
    end
  end

  @doc """
  Identifies high-emitter cows for a farm.

  A cow is flagged as a high emitter when its estimated daily methane output
  exceeds the farm-average by more than one standard deviation.

  Returns a list of `{cow_id, estimated_kg_ch4}` tuples for high emitters,
  farm-scoped.

  Gated by `:rfid_inhibitor_dosing` feature flag.
  """
  def identify_high_emitters(farm) do
    unless Inventory.feature_enabled?(farm, :rfid_inhibitor_dosing) do
      {:error, :feature_disabled}
    else
      cow_ids =
        from(f in FeedEvent,
          where: f.farm_id == ^farm.id,
          distinct: f.cow_id,
          select: f.cow_id
        )
        |> Repo.all()

      estimates =
        cow_ids
        |> Enum.map(fn cow_id ->
          case estimate_daily_methane(cow_id, farm.id) do
            {:ok, kg} -> {cow_id, kg}
            _ -> nil
          end
        end)
        |> Enum.reject(&is_nil/1)

      if length(estimates) < 2 do
        {:ok, []}
      else
        values = Enum.map(estimates, &elem(&1, 1))
        avg = Enum.sum(values) / length(values)
        variance = Enum.sum(Enum.map(values, fn v -> (v - avg) * (v - avg) end)) / length(values)
        std_dev = :math.sqrt(variance)
        threshold = avg + std_dev

        high_emitters = Enum.filter(estimates, fn {_id, kg} -> kg > threshold end)
        {:ok, high_emitters}
      end
    end
  end

  @doc """
  Triggers an inhibitor dose via the FeedRobot adapter for a high-emitter cow.

  Gated by `:rfid_inhibitor_dosing` feature flag. Creates an InhibitorDose
  record and calls the configured feed-robot adapter.
  """
  def trigger_inhibitor_dose(farm, cow_id, inhibitor_type, dose_mg) do
    unless Inventory.feature_enabled?(farm, :rfid_inhibitor_dosing) do
      {:error, :feature_disabled}
    else
      adapter = feed_robot_adapter()

      with :ok <- adapter.trigger_dose(cow_id, %{inhibitor_type: inhibitor_type, dose_mg: dose_mg}) do
        LivestokOs.ZeroGrazing.create_inhibitor_dose(%{
          cow_id: cow_id,
          inhibitor_type: inhibitor_type,
          dose_mg: dose_mg,
          administered_at: DateTime.utc_now(),
          notes: "Auto-triggered by RFID high-emitter detection"
        })
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Biogas mass-balance verification
  # ---------------------------------------------------------------------------

  @doc """
  Calculates and stores a methane avoidance credit from a slurry transfer.

  Logs slurry volume at pen-to-digester transfer points.
  Methane avoidance = slurry_volume_m3 × methane_yield_factor.
  CO2e credit = methane_avoided_kg × GWP_CH4 / 1000 (to tonnes).

  # TODO: source empirically derived yield factor for herd's TMR composition
  """
  def record_methane_avoidance(farm_id, slurry_volume_m3, methane_yield_factor, period_start, period_end) do
    methane_avoided_kg = slurry_volume_m3 * methane_yield_factor
    credit_tco2e = methane_avoided_kg * @gwp_ch4 / 1000.0

    %MethaneAvoidanceCredit{}
    |> MethaneAvoidanceCredit.changeset(%{
      farm_id: farm_id,
      period_start: period_start,
      period_end: period_end,
      slurry_volume_m3: slurry_volume_m3,
      methane_yield_factor: methane_yield_factor,
      methane_avoided_kg: Float.round(methane_avoided_kg, 4),
      credit_tco2e: Float.round(credit_tco2e, 6)
    })
    |> Repo.insert()
  end

  @doc """
  Flags high-emitter animals and creates METHANE_HIGH_EMITTER alerts for each.

  Gated by `:rfid_inhibitor_dosing`. Farm-scoped.
  """
  def flag_high_emitter_alerts(farm) do
    case identify_high_emitters(farm) do
      {:error, reason} ->
        {:error, reason}

      {:ok, []} ->
        :ok

      {:ok, high_emitters} ->
        Enum.each(high_emitters, fn {cow_id, kg_ch4} ->
          unless recent_high_emitter_alert?(farm.id, cow_id) do
            Operations.create_alert(%{
              type: "METHANE_HIGH_EMITTER",
              message:
                "Cow #{cow_id} estimated at #{Float.round(kg_ch4, 3)} kg CH4/day, " <>
                  "above farm average. Consider RFID-triggered inhibitor dose via feed robot.",
              is_resolved: false,
              cow_id: cow_id,
              farm_id: farm.id,
              severity: "warning"
            })
          end
        end)

        :ok
    end
  end

  # ---------------------------------------------------------------------------

  defp latest_feed_event(cow_id, farm_id) do
    from(f in FeedEvent,
      where: f.cow_id == ^cow_id and f.farm_id == ^farm_id,
      order_by: [desc: f.fed_at],
      limit: 1
    )
    |> Repo.one()
  end

  # Digestion coefficient approximated from dry_matter_pct.
  # Higher dry matter → lower digestibility → higher methane per unit.
  # TODO: replace with verified IPCC Tier 2 emission factor — current value is a placeholder
  defp digestion_coefficient(nil), do: 0.65
  defp digestion_coefficient(dm_pct) when dm_pct > 0, do: Float.round(1.0 - dm_pct / 100.0 * 0.5, 3)
  defp digestion_coefficient(_), do: 0.65

  defp recent_high_emitter_alert?(farm_id, cow_id) do
    cutoff = DateTime.utc_now() |> DateTime.add(-24 * 3600, :second)

    from(a in LivestokOs.Operations.Alert,
      where:
        a.farm_id == ^farm_id and
          a.cow_id == ^cow_id and
          a.type == "METHANE_HIGH_EMITTER" and
          a.is_resolved == false and
          a.inserted_at >= ^cutoff
    )
    |> Repo.exists?()
  end

  defp feed_robot_adapter do
    Application.get_env(:livestok_os_ops, :feed_robot_adapter, LivestokOs.FeedRobot.StubAdapter)
  end
end
