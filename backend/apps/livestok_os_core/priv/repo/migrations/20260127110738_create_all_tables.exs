defmodule LivestokOs.Repo.Migrations.CreateAllTables do
  use Ecto.Migration

  def change do
    # ── Users ──────────────────────────────────────────────────────────
    create table(:users) do
      add :email, :string
      add :name, :string
      add :password_hash, :string
      add :role, :string

      timestamps(type: :utc_datetime)
    end

    # ── Farms ──────────────────────────────────────────────────────────
    create table(:farms) do
      add :name, :string
      add :type, :string
      add :location, :string

      timestamps(type: :utc_datetime)
    end

    # ── Cows ───────────────────────────────────────────────────────────
    create table(:cows) do
      add :tag_id, :string
      add :name, :string
      add :breed, :string
      add :birth_date, :date
      add :status, :string
      add :farm_id, references(:farms, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:cows, [:farm_id])

    # ── Vehicles ───────────────────────────────────────────────────────
    create table(:vehicles) do
      add :name, :string, null: false
      add :plate_number, :string
      add :status, :string, null: false, default: "active"
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:vehicles, [:plate_number], where: "plate_number IS NOT NULL")

    # ── Devices ────────────────────────────────────────────────────────
    create table(:devices) do
      add :serial, :string, null: false
      add :hardware_type, :string, null: false
      add :firmware_version, :string
      add :status, :string, null: false, default: "online"
      add :last_seen_at, :utc_datetime
      add :metadata, :map, default: %{}

      add :cow_id, references(:cows, on_delete: :nilify_all)
      add :vehicle_id, references(:vehicles, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:devices, [:serial])
    create index(:devices, [:cow_id])
    create index(:devices, [:vehicle_id])

    # ── Sensor Readings ────────────────────────────────────────────────
    create table(:sensor_readings) do
      add :timestamp, :utc_datetime
      add :latitude, :float
      add :longitude, :float
      add :activity, :string
      add :data, :map
      add :cow_id, references(:cows, on_delete: :nothing)
      add :device_id, references(:devices, on_delete: :nilify_all)
      add :behavior_label, :string
      add :behavior_confidence, :float
      add :speed_mps, :float
      add :battery_level, :float
      add :source, :string, default: "ear_tag", null: false
      add :zone_id, :string

      timestamps(type: :utc_datetime)
    end

    create index(:sensor_readings, [:cow_id])
    create index(:sensor_readings, [:device_id])
    create index(:sensor_readings, [:timestamp])
    create index(:sensor_readings, [:zone_id])

    # ── Grazing Events ─────────────────────────────────────────────────
    create table(:grazing_events) do
      add :zone_id, :string
      add :entered_at, :utc_datetime
      add :left_at, :utc_datetime
      add :farm_id, references(:farms, on_delete: :nothing)
      add :cow_id, references(:cows, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:grazing_events, [:farm_id])
    create index(:grazing_events, [:cow_id])

    # ── Alerts ─────────────────────────────────────────────────────────
    create table(:alerts) do
      add :type, :string
      add :message, :string
      add :is_resolved, :boolean, default: false, null: false
      add :cow_id, references(:cows, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:alerts, [:cow_id])

    # ── Batches ────────────────────────────────────────────────────────
    create table(:batches) do
      add :processor_name, :string
      add :weight_kg, :float
      add :processed_at, :utc_datetime
      add :live_weight_kg, :float
      add :processed_weight_kg, :float
      add :harvested_at, :utc_datetime
      add :status, :string, default: "draft", null: false
      add :processor_location, :string
      add :mass_balance_limit_kg, :float
      add :carbon_intensity, :float
      add :lot_number, :string
      add :input_animals, :integer
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:batches, [:status])
    create index(:batches, [:lot_number])

    # ── Passports ──────────────────────────────────────────────────────
    create table(:passports) do
      add :unique_hash, :string
      add :carbon_score, :float
      add :is_verified, :boolean, default: false, null: false
      add :batch_id, references(:batches, on_delete: :nothing)
      add :serial_number, :string
      add :qr_token, :string
      add :qr_signature, :string
      add :status, :string, default: "draft", null: false
      add :issued_at, :utc_datetime
      add :expires_at, :utc_datetime
      add :scan_count, :integer, default: 0, null: false
      add :last_scanned_at, :utc_datetime
      add :metadata, :map, default: %{}
      add :batch_share_kg, :float
      add :cow_id, references(:cows, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:passports, [:batch_id])
    create unique_index(:passports, [:serial_number], where: "serial_number IS NOT NULL")
    create unique_index(:passports, [:qr_token], where: "qr_token IS NOT NULL")
    create index(:passports, [:cow_id])
    create index(:passports, [:status])

    # ── Passport Scans ─────────────────────────────────────────────────
    create table(:passport_scans) do
      add :passport_id, references(:passports, on_delete: :delete_all), null: false
      add :device_id, references(:devices, on_delete: :nilify_all)
      add :qr_token, :string, null: false
      add :scan_hash, :string, null: false
      add :status, :string, null: false, default: "ok"
      add :duplicate, :boolean, default: false, null: false
      add :scanned_at, :utc_datetime, null: false
      add :location, :map
      add :payload, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:passport_scans, [:passport_id])
    create index(:passport_scans, [:device_id])
    create unique_index(:passport_scans, [:scan_hash])
    create index(:passport_scans, [:qr_token])

    # ── Carbon Credits ─────────────────────────────────────────────────
    create table(:carbon_credits) do
      add :tons, :float, null: false
      add :methodology, :string
      add :vintage_year, :integer
      add :status, :string, default: "pending", null: false
      add :serial_number, :string
      add :issued_at, :utc_datetime
      add :retired_at, :utc_datetime
      add :metadata, :map, default: %{}

      add :passport_id, references(:passports, on_delete: :nilify_all)
      add :batch_id, references(:batches, on_delete: :nilify_all)
      add :cow_id, references(:cows, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:carbon_credits, [:passport_id])
    create index(:carbon_credits, [:batch_id])
    create index(:carbon_credits, [:cow_id])
    create index(:carbon_credits, [:status])
    create unique_index(:carbon_credits, [:serial_number], where: "serial_number IS NOT NULL")

    # ── Geofences ──────────────────────────────────────────────────────
    create table(:geofences) do
      add :name, :string, null: false
      add :enforcement_scope, :string, null: false
      add :geometry, :map, null: false
      add :is_active, :boolean, default: true, null: false
      add :description, :text

      timestamps(type: :utc_datetime)
    end

    # ── Geofence Events ────────────────────────────────────────────────
    create table(:geofence_events) do
      add :event_type, :string, null: false
      add :occurred_at, :utc_datetime, null: false
      add :payload, :map, default: %{}

      add :geofence_id, references(:geofences, on_delete: :delete_all), null: false
      add :device_id, references(:devices, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:geofence_events, [:geofence_id])
    create index(:geofence_events, [:device_id])
    create index(:geofence_events, [:occurred_at])

    # ── Feed Events ────────────────────────────────────────────────────
    create table(:feed_events) do
      add :cow_id, references(:cows, on_delete: :delete_all), null: false
      add :farm_id, references(:farms, on_delete: :delete_all)
      add :feed_type, :string, null: false
      add :quantity_kg, :float, null: false
      add :dry_matter_pct, :float
      add :protein_pct, :float
      add :inhibitor_added, :boolean, default: false
      add :fed_at, :utc_datetime, null: false
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:feed_events, [:cow_id])
    create index(:feed_events, [:farm_id])
    create index(:feed_events, [:fed_at])

    # ── Biogas Records ─────────────────────────────────────────────────
    create table(:biogas_records) do
      add :farm_id, references(:farms, on_delete: :delete_all), null: false
      add :volume_m3, :float, null: false
      add :methane_pct, :float
      add :source, :string, default: "manure"
      add :captured_at, :utc_datetime, null: false
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:biogas_records, [:farm_id])
    create index(:biogas_records, [:captured_at])

    # ── Inhibitor Doses ────────────────────────────────────────────────
    create table(:inhibitor_doses) do
      add :cow_id, references(:cows, on_delete: :delete_all), null: false
      add :inhibitor_type, :string, null: false
      add :dose_mg, :float, null: false
      add :administered_at, :utc_datetime, null: false
      add :effectiveness_pct, :float
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:inhibitor_doses, [:cow_id])
    create index(:inhibitor_doses, [:administered_at])
  end
end
