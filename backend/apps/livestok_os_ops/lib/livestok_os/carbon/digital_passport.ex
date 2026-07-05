defmodule LivestokOs.DigitalPassport do
  @moduledoc """
  Cryptographically signed digital passport per animal.

  Passport content:
  - Behavioral history (state logs)
  - GPS/rotation log (grazing events)
  - Accumulated carbon credit (sum of carbon sequestration records for the farm)
  - Feed efficiency index (latest record for the cow)
  - Hash-chain reference (latest ledger entry for the farm)

  Signing uses `farm.passport_signing_key` (Ed25519 raw private key bytes).
  When no per-farm key is set, the document is generated but NOT signed (a
  `signature: nil` field is included so consumers can detect unsigned passports).

  # TODO: generate per-farm keypair at onboarding

  ## Generation
  Passport generation is always triggered on-request (not continuously).
  It runs as a supervised `Task` so it never blocks ingestion or coaching.

  # Future stage: mass-balance QR + retail verification (Section 5.3)
  """

  import Ecto.Query, warn: false
  alias LivestokOs.Repo
  alias LivestokOs.Inventory
  alias LivestokOs.Telemetry.CowStateLog
  alias LivestokOs.Operations.GrazingEvent
  alias LivestokOs.Carbon.{CarbonSequestrationRecord, FeedEfficiencyRecord, CarbonLedgerEntry}

  require Logger

  @doc """
  Generates a digital passport for `cow_id` on `farm_id`.

  Runs synchronously when called directly. Use `generate_async/3` for
  non-blocking generation from the web layer.

  Returns `{:ok, passport_map}` where `passport_map` is a JSON-serialisable
  map with a `:signature` field (hex string or nil).
  """
  def generate(farm_id, cow_id) do
    farm = Inventory.get_farm!(farm_id)
    cow = Inventory.get_cow!(cow_id)

    state_logs = recent_state_logs(cow_id, farm_id)
    grazing_events = recent_grazing_events(cow_id, farm_id)
    carbon_credit = total_carbon_credit(farm_id)
    feed_efficiency = latest_feed_efficiency(cow_id, farm_id)
    ledger_ref = latest_ledger_ref(farm_id)

    passport = %{
      version: "1.0",
      generated_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      farm: %{id: farm.id, name: farm.name, grazing_mode: farm.grazing_mode},
      cow: %{id: cow.id, tag_id: cow.tag_id, name: cow.name, breed: cow.breed},
      behavioral_history: state_logs,
      rotation_log: grazing_events,
      accumulated_carbon_credit_tco2e: carbon_credit,
      feed_efficiency_index: feed_efficiency,
      ledger_reference: ledger_ref
    }

    signed_passport = sign_passport(passport, farm.passport_signing_key)
    {:ok, signed_passport}
  end

  @doc """
  Generates a digital passport asynchronously under a supervised Task.

  The result is sent to `reply_to` pid as `{:passport_result, result}`.
  Must be called under a supervisor that supports Task children — typically
  the `Task.Supervisor` in `livestok_os_ops` or `livestok_os_core`.
  """
  def generate_async(farm_id, cow_id, reply_to) do
    Task.Supervisor.start_child(
      LivestokOsOps.TaskSupervisor,
      fn ->
        result = generate(farm_id, cow_id)
        send(reply_to, {:passport_result, result})
      end,
      restart: :temporary
    )
  end

  # ---------------------------------------------------------------------------

  defp recent_state_logs(cow_id, farm_id) do
    cutoff = DateTime.utc_now() |> DateTime.add(-90 * 86_400, :second)

    from(l in CowStateLog,
      where: l.cow_id == ^cow_id and l.farm_id == ^farm_id and l.occurred_at >= ^cutoff,
      order_by: [desc: l.occurred_at],
      limit: 100
    )
    |> Repo.all()
    |> Enum.map(fn l ->
      %{
        from: l.from_state,
        to: l.to_state,
        occurred_at: DateTime.to_iso8601(l.occurred_at)
      }
    end)
  end

  defp recent_grazing_events(cow_id, farm_id) do
    cutoff = DateTime.utc_now() |> DateTime.add(-90 * 86_400, :second)

    from(e in GrazingEvent,
      where: e.cow_id == ^cow_id and e.farm_id == ^farm_id and e.entered_at >= ^cutoff,
      order_by: [desc: e.entered_at],
      limit: 100
    )
    |> Repo.all()
    |> Enum.map(fn e ->
      %{
        zone_id: e.zone_id,
        entered_at: DateTime.to_iso8601(e.entered_at),
        left_at: if(e.left_at, do: DateTime.to_iso8601(e.left_at))
      }
    end)
  end

  defp total_carbon_credit(farm_id) do
    from(r in CarbonSequestrationRecord,
      where: r.farm_id == ^farm_id,
      select: coalesce(sum(r.carbon_tco2e), 0.0)
    )
    |> Repo.one()
  end

  defp latest_feed_efficiency(cow_id, farm_id) do
    from(r in FeedEfficiencyRecord,
      where: r.cow_id == ^cow_id and r.farm_id == ^farm_id,
      order_by: [desc: r.calculated_at],
      limit: 1,
      select: r.feed_efficiency_index
    )
    |> Repo.one()
  end

  defp latest_ledger_ref(farm_id) do
    entry =
      from(e in CarbonLedgerEntry,
        where: e.farm_id == ^farm_id,
        order_by: [desc: e.inserted_at, desc: e.id],
        limit: 1
      )
      |> Repo.one()

    if entry do
      %{entry_id: entry.id, chain_hash: entry.chain_hash, inserted_at: DateTime.to_iso8601(entry.inserted_at)}
    else
      nil
    end
  end

  defp sign_passport(passport, nil) do
    # No per-farm signing key configured; passport is unsigned.
    # TODO: generate per-farm keypair at onboarding
    Map.put(passport, :signature, nil)
  end

  defp sign_passport(passport, signing_key) when is_binary(signing_key) do
    # Canonicalise the passport body (without the signature field) and sign.
    body = Jason.encode!(Map.delete(passport, :signature))

    try do
      signature =
        :crypto.sign(:eddsa, :sha256, body, [signing_key, :ed25519])
        |> Base.encode16(case: :lower)

      Map.put(passport, :signature, signature)
    rescue
      e ->
        Logger.warning("[DigitalPassport] Signing failed: #{inspect(e)}. Returning unsigned passport.")
        Map.put(passport, :signature, nil)
    end
  end
end
