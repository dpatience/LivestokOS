defmodule LivestokOs.Repo.Migrations.RestructureLivestokOs do
  use Ecto.Migration

  def change do
    # ── 1. Remove vehicle_id FK from devices FIRST ──────────────────────
    alter table(:devices) do
      remove :vehicle_id, references(:vehicles), default: nil
    end

    # ── 2. Drop removed tables ──────────────────────────────────────────
    drop_if_exists table(:passport_scans)
    drop_if_exists table(:carbon_credits)
    drop_if_exists table(:passports)
    drop_if_exists table(:batches)
    drop_if_exists table(:vehicles)

    # ── 3. Add farm_id to users for multi-tenancy ───────────────────────
    alter table(:users) do
      add :farm_id, references(:farms, on_delete: :nilify_all)
    end

    create index(:users, [:farm_id])

    # ── 4. Add farm_id to devices ───────────────────────────────────────
    alter table(:devices) do
      add :farm_id, references(:farms, on_delete: :delete_all)
    end

    create index(:devices, [:farm_id])

    # ── 4. Add farm_id to alerts ────────────────────────────────────────
    alter table(:alerts) do
      add :farm_id, references(:farms, on_delete: :delete_all)
      add :severity, :string, default: "warning"
    end

    create index(:alerts, [:farm_id])

    # ── 5. Add farm_id to geofences ─────────────────────────────────────
    alter table(:geofences) do
      add :farm_id, references(:farms, on_delete: :delete_all)
    end

    create index(:geofences, [:farm_id])

    # ── 6. Add farm_id to sensor_readings ───────────────────────────────
    alter table(:sensor_readings) do
      add :farm_id, references(:farms, on_delete: :delete_all)
    end

    create index(:sensor_readings, [:farm_id])

    # ── 7. Cow state_logs for Digital Twin persistence ──────────────────
    create table(:cow_state_logs) do
      add :cow_id, references(:cows, on_delete: :delete_all), null: false
      add :farm_id, references(:farms, on_delete: :delete_all), null: false
      add :from_state, :string
      add :to_state, :string, null: false
      add :occurred_at, :utc_datetime, null: false
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:cow_state_logs, [:cow_id])
    create index(:cow_state_logs, [:farm_id])
    create index(:cow_state_logs, [:occurred_at])

    # ── 8. Satellite records for historical NDVI / carbon data ──────────
    create table(:satellite_records) do
      add :farm_id, references(:farms, on_delete: :delete_all), null: false
      add :zone_id, :string
      add :ndvi_score, :float
      add :carbon_metric, :float
      add :soil_health, :float
      add :image_url, :string
      add :captured_at, :utc_datetime, null: false
      add :source, :string, default: "sentinel-2"
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:satellite_records, [:farm_id])
    create index(:satellite_records, [:captured_at])

    # ── 9. LoRaWAN gateway registrations ────────────────────────────────
    create table(:lora_gateways) do
      add :farm_id, references(:farms, on_delete: :delete_all), null: false
      add :gateway_eui, :string, null: false
      add :name, :string
      add :status, :string, default: "online"
      add :last_seen_at, :utc_datetime
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:lora_gateways, [:gateway_eui])
    create index(:lora_gateways, [:farm_id])

    # ── 10. Add health_score and current_state to cows ──────────────────
    alter table(:cows) do
      add :health_score, :float, default: 100.0
      add :current_state, :string, default: "unknown"
    end
  end
end
