# Demo database seeds for LivestokOS hackathon / local development.
#
# Run:  mix setup   (or mix run apps/livestok_os_core/priv/repo/seeds.exs)
#
# Idempotent — safe to re-run; skips records that already exist.

defmodule LivestokOs.DemoSeeds do
  @moduledoc false

  import Ecto.Query

  alias LivestokOs.Repo
  alias LivestokOs.{Accounts, Inventory, Reproduction, User}
  alias LivestokOs.AI.{ConfirmedCase, ResearchArticle}
  alias LivestokOs.CarbonLedger
  alias LivestokOs.Infrastructure.{Geofence, RotationEvent}
  alias LivestokOs.Inventory.Cow
  alias LivestokOs.Operations.{Alert, GrazingEvent}
  alias LivestokOs.Satellite.NdviReading
  alias LivestokOs.Telemetry.{CowStateLog, Device, SensorReading}
  alias LivestokOs.ZeroGrazing.{FeedEvent, InhibitorDose}

  @admin_email "admin@livestok.os"
  @owner_email "owner@demo.farm"
  @worker_email "worker@demo.farm"
  @zg_owner_email "owner@zerograzedemo.farm"

  @demo_password "demo123"
  @admin_password "admin123"

  @pasture_farm_name "Rwanda Hills Demo"
  @zero_grazing_farm_name "Nairobi Zero Graze Demo"

  @placeholder_embedding Pgvector.new(List.duplicate(0.05, 1536))

  def run! do
    IO.puts("\n=== LivestokOS demo seeds ===\n")

    admin = ensure_admin()
    pasture_farm = ensure_farm(@pasture_farm_name, :pasture, "Kigali, Rwanda")
    zg_farm = ensure_farm(@zero_grazing_farm_name, :zero_grazing, "Nairobi, Kenya")

    owner = ensure_farm_user(@owner_email, "Demo Farm Owner", "farm_owner", pasture_farm.id)
    worker = ensure_farm_user(@worker_email, "Demo Farm Worker", "farm_worker", pasture_farm.id)
    zg_owner = ensure_farm_user(@zg_owner_email, "Zero Graze Owner", "farm_owner", zg_farm.id)

    pasture_cows = seed_pasture_herd(pasture_farm)
    zg_cows = seed_zero_grazing_herd(zg_farm)

    paddocks = seed_paddocks(pasture_farm)
    seed_ndvi_and_rotations(pasture_farm, paddocks)
    seed_devices_and_telemetry(pasture_farm, pasture_cows, paddocks)
    seed_alerts(pasture_farm, pasture_cows, paddocks)
    seed_reproduction(pasture_farm, pasture_cows)
    seed_zero_grazing_data(zg_farm, zg_cows)
    seed_ai_demo(pasture_farm, pasture_cows, admin)
    seed_carbon_ledger(pasture_farm)

    print_summary(admin, owner, worker, zg_owner, pasture_farm, zg_farm, pasture_cows, zg_cows)
  end

  # ---------------------------------------------------------------------------
  # Users & farms
  # ---------------------------------------------------------------------------

  defp ensure_admin do
    case Repo.get_by(User, email: @admin_email) do
      %User{} = user ->
        IO.puts("ℹ️  Super admin exists: #{user.email}")
        user

      nil ->
        {:ok, user} =
          Accounts.create_user(%{
            "email" => @admin_email,
            "name" => "Super Admin",
            "password" => @admin_password,
            "role" => "super_admin"
          })

        IO.puts("✅ Super admin: #{user.email}")
        user
    end
  end

  defp ensure_farm_user(email, name, role, farm_id) do
    case Repo.get_by(User, email: email) do
      %User{} = user ->
        if user.farm_id != farm_id do
          user
          |> Ecto.Changeset.change(farm_id: farm_id)
          |> Repo.update!()
        end

        IO.puts("ℹ️  User exists: #{email}")
        user

      nil ->
        {:ok, user} =
          Accounts.create_user_with_farm(
            %{
              "email" => email,
              "name" => name,
              "password" => @demo_password,
              "role" => role
            },
            farm_id
          )

        IO.puts("✅ User: #{email} (#{role})")
        user
    end
  end

  defp ensure_farm(name, grazing_mode, location) do
    case Repo.get_by(LivestokOs.Inventory.Farm, name: name) do
      %{} = farm ->
        IO.puts("ℹ️  Farm exists: #{name}")
        farm

      nil ->
        {:ok, farm} =
          Inventory.create_farm(%{
            name: name,
            grazing_mode: grazing_mode,
            location: location,
            ndvi_alert_threshold: 0.35
          })

        IO.puts("✅ Farm: #{name}")
        farm
    end
  end

  # ---------------------------------------------------------------------------
  # Herds
  # ---------------------------------------------------------------------------

  defp seed_pasture_herd(farm) do
    specs = [
      %{tag_id: "COW-DEMO-001", name: "Imena", breed: "Ankole", sex: :female, status: "active",
        birth_date: ~D[2021-03-15], current_state: "grazing", health_score: 92.0},
      %{tag_id: "COW-DEMO-002", name: "Umutoni", breed: "Holstein", sex: :female, status: "active",
        birth_date: ~D[2020-08-01], current_state: "ruminating", health_score: 88.0},
      %{tag_id: "COW-DEMO-003", name: "Keza", breed: "Jersey", sex: :female, status: "active",
        birth_date: ~D[2022-01-20], current_state: "idle", health_score: 95.0},
      %{tag_id: "COW-DEMO-004", name: "Muhizi", breed: "Ankole", sex: :male, status: "active",
        birth_date: ~D[2019-11-10], current_state: "grazing", health_score: 90.0},
      %{tag_id: "COW-DEMO-005", name: "Amahoro", breed: "Holstein", sex: :female, status: "watch",
        birth_date: ~D[2020-05-22], current_state: "resting", health_score: 76.0},
      %{tag_id: "COW-DEMO-006", name: "Inka", breed: "Ankole", sex: :female, status: "active",
        birth_date: ~D[2023-06-01], current_state: "grazing", health_score: 97.0}
    ]

    Enum.map(specs, &ensure_cow(farm.id, &1))
  end

  defp seed_zero_grazing_herd(farm) do
    specs = [
      %{tag_id: "COW-ZG-001", name: "Baraka", breed: "Holstein", sex: :female, status: "active",
        birth_date: ~D[2020-02-14], current_state: "ruminating", health_score: 91.0},
      %{tag_id: "COW-ZG-002", name: "Neema", breed: "Jersey", sex: :female, status: "active",
        birth_date: ~D[2021-07-08], current_state: "idle", health_score: 89.0},
      %{tag_id: "COW-ZG-003", name: "Tumaini", breed: "Holstein", sex: :female, status: "active",
        birth_date: ~D[2019-12-30], current_state: "resting", health_score: 85.0}
    ]

    Enum.map(specs, &ensure_cow(farm.id, &1))
  end

  defp ensure_cow(farm_id, attrs) do
    case Repo.get_by(Cow, tag_id: attrs.tag_id) do
      %Cow{} = cow ->
        cow

      nil ->
        {:ok, cow} = Inventory.create_cow(Map.put(attrs, :farm_id, farm_id))
        cow
    end
  end

  # ---------------------------------------------------------------------------
  # Paddocks & satellite
  # ---------------------------------------------------------------------------

  defp seed_paddocks(farm) do
    [
      {"Paddock A - North Hill", -1.944, 30.061, 180.0},
      {"Paddock B - Valley", -1.948, 30.066, 150.0},
      {"Paddock C - East Ridge", -1.941, 30.070, 200.0}
    ]
    |> Enum.map(fn {name, lat, lng, radius} ->
      case Repo.get_by(Geofence, name: name, farm_id: farm.id) do
        %Geofence{} = g ->
          g

        nil ->
          {:ok, g} =
            %Geofence{}
            |> Geofence.changeset(%{
              name: name,
              enforcement_scope: "keep_in",
              geometry: %{
                "type" => "circle",
                "center_lat" => lat,
                "center_lng" => lng,
                "radius_m" => radius
              },
              is_active: true,
              description: "Demo paddock for field rotation",
              farm_id: farm.id,
              soil_classification: "volcanic",
              soil_type_factor: 1.1
            })
            |> Repo.insert()

          g
      end
    end)
  end

  defp seed_ndvi_and_rotations(farm, [paddock_a, paddock_b, paddock_c | _]) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    for {paddock, score, days_ago} <- [
          {paddock_a, 0.68, 2},
          {paddock_b, 0.42, 1},
          {paddock_c, 0.55, 3}
        ] do
      exists? =
        from(r in NdviReading, where: r.paddock_id == ^paddock.id, limit: 1)
        |> Repo.exists?()

      unless exists? do
        captured_at = DateTime.add(now, -days_ago * 86_400, :second)

        %NdviReading{}
        |> NdviReading.changeset(%{
          paddock_id: paddock.id,
          farm_id: farm.id,
          captured_at: captured_at,
          ndvi_score: score,
          is_stale: false
        })
        |> Repo.insert!()
      end
    end

    unless rotation_exists?(farm.id) do
      ts = DateTime.add(now, -5 * 86_400, :second)

      %RotationEvent{}
      |> RotationEvent.changeset(%{
        paddock_id: paddock_a.id,
        farm_id: farm.id,
        occurred_at: ts,
        centroid_lat: -1.944,
        centroid_lng: 30.061
      })
      |> Repo.insert!()
    end

    IO.puts("✅ NDVI readings + rotation events")
  end

  defp rotation_exists?(farm_id) do
    from(r in RotationEvent, where: r.farm_id == ^farm_id, limit: 1) |> Repo.exists?()
  end

  # ---------------------------------------------------------------------------
  # Devices & telemetry
  # ---------------------------------------------------------------------------

  defp seed_devices_and_telemetry(farm, cows, [paddock_a, paddock_b, _paddock_c | _]) do
    zone_ids = [to_string(paddock_a.id), to_string(paddock_b.id)]

    Enum.with_index(cows, 1)
    |> Enum.each(fn {cow, idx} ->
      serial = "COLLAR-DEMO-#{String.pad_leading(Integer.to_string(idx), 3, "0")}"

      device =
        case Repo.get_by(Device, serial: serial) do
          %Device{} = d ->
            d

          nil ->
            {:ok, d} =
              %Device{}
              |> Device.changeset(%{
                serial: serial,
                hardware_type: "ear_tag",
                firmware_version: "2.4.1",
                status: "online",
                last_seen_at: DateTime.utc_now() |> DateTime.truncate(:second),
                cow_id: cow.id,
                farm_id: farm.id,
                metadata: %{"demo" => true}
              })
              |> Repo.insert()

            d
        end

      seed_sensor_readings(farm, cow, device, Enum.at(zone_ids, rem(idx - 1, 2)))
      seed_state_logs(farm, cow)
    end)

    IO.puts("✅ Collar devices, sensor readings, state logs")
  end

  defp seed_sensor_readings(farm, cow, device, zone_id) do
    exists? =
      from(r in SensorReading, where: r.device_id == ^device.id, limit: 1)
      |> Repo.exists?()

    if exists? do
      :ok
    else
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      for hours_ago <- [0, 2, 6, 12, 24] do
        ts = DateTime.add(now, -hours_ago * 3600, :second)
        {lat, lng} = jitter_coords(-1.945 + rem(cow.id, 3) * 0.001, 30.062)

        %SensorReading{}
        |> SensorReading.changeset(%{
          timestamp: ts,
          latitude: lat,
          longitude: lng,
          activity: Enum.random(["low", "moderate", "high"]),
          behavior_label: Enum.random(["grazing", "ruminating", "idle", "resting"]),
          behavior_confidence: 0.85,
          speed_mps: 0.4,
          battery_level: 78.0 + rem(cow.id, 15),
          source: "ear_tag",
          zone_id: zone_id,
          cow_id: cow.id,
          device_id: device.id,
          farm_id: farm.id,
          data: %{"demo" => true}
        })
        |> Repo.insert!()
      end
    end
  end

  defp seed_state_logs(farm, cow) do
    exists? =
      from(l in CowStateLog, where: l.cow_id == ^cow.id, limit: 1)
      |> Repo.exists?()

    if exists? do
      :ok
    else
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      transitions = [{"unknown", "grazing"}, {"grazing", "ruminating"}, {"ruminating", "idle"}]

      Enum.with_index(transitions, 1)
      |> Enum.each(fn {{from, to}, idx} ->
        %CowStateLog{}
        |> CowStateLog.changeset(%{
          from_state: from,
          to_state: to,
          occurred_at: DateTime.add(now, -idx * 7200, :second),
          cow_id: cow.id,
          farm_id: farm.id,
          metadata: %{"demo" => true}
        })
        |> Repo.insert!()
      end)
    end
  end

  defp jitter_coords(lat, lng) do
    {lat + :rand.uniform() * 0.002 - 0.001, lng + :rand.uniform() * 0.002 - 0.001}
  end

  # ---------------------------------------------------------------------------
  # Alerts & grazing
  # ---------------------------------------------------------------------------

  defp seed_alerts(farm, cows, [paddock_a, paddock_b, _ | _]) do
    unless alert_demo_exists?(farm.id) do
      [imena, _umutoni, _keza, _muhizi, amahoro, _inka] = cows

      alerts = [
        %{
          type: "grazing_recommendation",
          message:
            "Paddock B NDVI is 0.42 — consider rotating the herd from North Hill within 48 hours.",
          is_resolved: false,
          severity: "info",
          priority: "medium",
          farm_id: farm.id,
          cow_id: nil
        },
        %{
          type: "estrus_proxy",
          message: "Imena shows elevated activity — possible heat. Worth a visual check today.",
          is_resolved: false,
          severity: "warning",
          priority: "high",
          farm_id: farm.id,
          cow_id: imena.id
        },
        %{
          type: "geofence_breach",
          message: "Amahoro briefly left Paddock A boundary yesterday evening — resolved at gate.",
          is_resolved: false,
          severity: "warning",
          priority: "medium",
          farm_id: farm.id,
          cow_id: amahoro.id
        },
        %{
          type: "ndvi_lick_block",
          message: "Paddock B grass recovery is below target — lick block placement recommended.",
          is_resolved: false,
          severity: "info",
          priority: "low",
          farm_id: farm.id,
          cow_id: nil
        }
      ]

      Enum.each(alerts, fn attrs ->
        %Alert{} |> Alert.changeset(attrs) |> Repo.insert!()
      end)

      now = DateTime.utc_now() |> DateTime.truncate(:second)

      %GrazingEvent{}
      |> GrazingEvent.changeset(%{
        cow_id: imena.id,
        farm_id: farm.id,
        zone_id: to_string(paddock_a.id),
        entered_at: DateTime.add(now, -6 * 3600, :second),
        left_at: now
      })
      |> Repo.insert!()

      %GrazingEvent{}
      |> GrazingEvent.changeset(%{
        cow_id: amahoro.id,
        farm_id: farm.id,
        zone_id: to_string(paddock_b.id),
        entered_at: DateTime.add(now, -12 * 3600, :second),
        left_at: DateTime.add(now, -2 * 3600, :second)
      })
      |> Repo.insert!()
    end

    IO.puts("✅ Alerts + grazing events")
  end

  defp alert_demo_exists?(farm_id) do
    from(a in Alert,
      where: a.farm_id == ^farm_id and a.type == "grazing_recommendation",
      limit: 1
    )
    |> Repo.exists?()
  end

  # ---------------------------------------------------------------------------
  # Reproduction
  # ---------------------------------------------------------------------------

  defp seed_reproduction(farm, cows) do
    imena = Enum.find(cows, &(&1.tag_id == "COW-DEMO-001"))
    keza = Enum.find(cows, &(&1.tag_id == "COW-DEMO-003"))

    unless breeding_exists?(imena.id) do
      {:ok, breeding} =
        Reproduction.create_breeding_record(%{
          cow_id: imena.id,
          farm_id: farm.id,
          insemination_date: Date.add(Date.utc_today(), -120),
          method: :ai,
          sire_reference: "BULL-REF-4421",
          outcome: :confirmed_pregnant,
          confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      {:ok, _gestation} = Reproduction.create_gestation(breeding)
    end

    unless lactation_exists?(keza.id) do
      Reproduction.create_lactation_record(%{
        cow_id: keza.id,
        farm_id: farm.id,
        milking_date: Date.add(Date.utc_today(), -1),
        yield_liters: 18.5,
        fat_pct: 4.2,
        protein_pct: 3.5,
        source: "manual"
      })
    end

    IO.puts("✅ Breeding, gestation, lactation records")
  end

  defp breeding_exists?(cow_id) do
    from(b in LivestokOs.Reproduction.BreedingRecord, where: b.cow_id == ^cow_id, limit: 1)
    |> Repo.exists?()
  end

  defp lactation_exists?(cow_id) do
    from(l in LivestokOs.Reproduction.LactationRecord, where: l.cow_id == ^cow_id, limit: 1)
    |> Repo.exists?()
  end

  defp feed_event_exists?(cow_id) do
    from(f in FeedEvent, where: f.cow_id == ^cow_id, limit: 1) |> Repo.exists?()
  end

  # ---------------------------------------------------------------------------
  # Zero grazing
  # ---------------------------------------------------------------------------

  defp seed_zero_grazing_data(farm, cows) do
    baraka = Enum.find(cows, &(&1.tag_id == "COW-ZG-001"))

    unless feed_event_exists?(baraka.id) do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      %FeedEvent{}
      |> FeedEvent.changeset(%{
        cow_id: baraka.id,
        farm_id: farm.id,
        feed_type: "TMR",
        quantity_kg: 22.0,
        dry_matter_pct: 48.0,
        protein_pct: 16.5,
        inhibitor_added: true,
        fed_at: DateTime.add(now, -4 * 3600, :second),
        notes: "Morning ration with methane inhibitor"
      })
      |> Repo.insert!()

      %InhibitorDose{}
      |> InhibitorDose.changeset(%{
        cow_id: baraka.id,
        inhibitor_type: "3-NOP",
        dose_mg: 150.0,
        administered_at: DateTime.add(now, -4 * 3600, :second),
        effectiveness_pct: 28.0,
        notes: "Feed robot auto-dose"
      })
      |> Repo.insert!()
    end

    IO.puts("✅ Zero-grazing feed + inhibitor doses")
  end

  # ---------------------------------------------------------------------------
  # AI oversight demo
  # ---------------------------------------------------------------------------

  defp seed_ai_demo(farm, cows, admin) do
    unless research_exists?() do
      articles = [
        %{
          title: "Mastitis detection in pasture-based dairy herds",
          authors: "Nguyen et al.",
          source: "Vet Journal Demo",
          url: "https://example.com/mastitis-pasture",
          published_date: ~D[2024-06-01],
          abstract_summary:
            "Early mastitis signs include reduced rumination, elevated activity at milking, and udder sensitivity. Physical exam confirms diagnosis.",
          embedding: @placeholder_embedding
        },
        %{
          title: "Heat stress mitigation for tropical cattle",
          authors: "Kamau & Osei",
          source: "Livestock Climate Review",
          url: "https://example.com/heat-stress",
          published_date: ~D[2023-11-15],
          abstract_summary:
            "Shade, water access, and rotation timing reduce heat stress. Monitor respiration rate and drooling during hot afternoons.",
          embedding: @placeholder_embedding
        }
      ]

      Enum.each(articles, fn attrs ->
        %ResearchArticle{} |> ResearchArticle.changeset(attrs) |> Repo.insert!()
      end)
    end

    amahoro = Enum.find(cows, &(&1.tag_id == "COW-DEMO-005"))

    unless confirmed_case_exists?(farm.id) do
      %ConfirmedCase{}
      |> ConfirmedCase.changeset(%{
        farm_id: farm.id,
        cow_id: amahoro.id,
        situation_summary:
          "Cow off feed for 24h with reduced activity but normal temperature. Similar case last season after paddock change.",
        case_history_snapshot: %{
          "feed_events" => 0,
          "recent_states" => ["resting", "idle"],
          "demo" => true
        },
        assistant_answer:
          "We saw this pattern before when grass quality dropped after rotation. Log appetite, check rumen fill, and call the vet if she skips a second meal.",
        situation_embedding: @placeholder_embedding,
        confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second),
        confirmed_by_user_id: admin.id
      })
      |> Repo.insert!()
    end

    IO.puts("✅ AI research corpus + confirmed case memory")
  end

  defp research_exists? do
    from(a in ResearchArticle, limit: 1) |> Repo.exists?()
  end

  defp confirmed_case_exists?(farm_id) do
    from(c in ConfirmedCase,
      where: c.farm_id == ^farm_id and not is_nil(c.confirmed_at),
      limit: 1
    )
    |> Repo.exists?()
  end

  # ---------------------------------------------------------------------------
  # Carbon ledger (admin)
  # ---------------------------------------------------------------------------

  defp seed_carbon_ledger(farm) do
    case CarbonLedger.verify_chain(farm.id) do
      {:ok, :empty_chain} ->
        for i <- 1..3 do
          CarbonLedger.append(farm.id, %{
            record_type: "demo_sequestration",
            record_id: i,
            content_hash: CarbonLedger.content_hash(%{demo: true, seq: i, farm_id: farm.id})
          })
        end

        IO.puts("✅ Carbon ledger entries")

      _ ->
        IO.puts("ℹ️  Carbon ledger already seeded")
    end
  end

  # ---------------------------------------------------------------------------
  # Summary
  # ---------------------------------------------------------------------------

  defp print_summary(admin, owner, worker, zg_owner, pasture_farm, zg_farm, pasture_cows, zg_cows) do
    IO.puts("""

    === Demo ready ===

    ADMIN APP (super_admin):
      Email:    #{admin.email}
      Password: #{@admin_password}

    FARM APP — pasture demo (#{pasture_farm.name}):
      Owner:    #{owner.email}  / #{@demo_password}
      Worker:   #{worker.email} / #{@demo_password}
      Cows:     #{length(pasture_cows)} tagged COW-DEMO-001 … 006
      Paddocks: 3 geofences with NDVI + rotation data
      Alerts:   4 open alerts for inbox demo

    FARM APP — zero grazing (#{zg_farm.name}):
      Owner:    #{zg_owner.email} / #{@demo_password}
      Cows:     #{length(zg_cows)} tagged COW-ZG-001 … 003

    Vet consult: pick Imena or Amahoro — they have history + a confirmed case pattern.
    """)
  end
end

:rand.seed(:exsss, {System.system_time(:millisecond), 0, 0})
LivestokOs.DemoSeeds.run!()
