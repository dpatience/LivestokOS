defmodule LivestokOs.Repo.Migrations.PostgisAndGeofenceEventsFarmId do
  use Ecto.Migration

  def up do
    # Enable PostGIS — required for ST_Contains polygon boundary checks.
    # Wrapped in an anonymous DO block so the migration succeeds gracefully on
    # systems where the PostGIS package is not yet installed; the boundary column
    # and GIST index are also skipped in that case.
    execute """
    DO $$
    BEGIN
      CREATE EXTENSION IF NOT EXISTS postgis;
      -- Only add geometry columns when PostGIS is available.
      BEGIN
        ALTER TABLE geofences ADD COLUMN IF NOT EXISTS boundary geometry(Polygon, 4326);
        CREATE INDEX IF NOT EXISTS geofences_boundary_gist ON geofences USING GIST(boundary);
      EXCEPTION WHEN OTHERS THEN
        -- Geometry column requires PostGIS; will be added once PostGIS is installed.
        NULL;
      END;
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'PostGIS not available: %. Skipping extension + geometry column.', SQLERRM;
    END $$;
    """

    # Add farm_id to geofence_events for multi-tenant farm scoping.
    alter table(:geofence_events) do
      add_if_not_exists :farm_id, references(:farms, on_delete: :delete_all)
    end

    create_if_not_exists index(:geofence_events, [:farm_id])
  end

  def down do
    drop_if_exists index(:geofence_events, [:farm_id])

    alter table(:geofence_events) do
      remove :farm_id
    end

    execute "DROP INDEX IF EXISTS geofences_boundary_gist"
    execute "ALTER TABLE geofences DROP COLUMN IF EXISTS boundary"
    # Use CASCADE because other PostGIS objects may depend on the extension.
    execute "DROP EXTENSION IF EXISTS postgis CASCADE"
  end
end
