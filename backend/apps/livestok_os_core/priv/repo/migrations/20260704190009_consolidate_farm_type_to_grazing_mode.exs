defmodule LivestokOs.Repo.Migrations.ConsolidateFarmTypeToGrazingMode do
  use Ecto.Migration

  def up do
    # Backfill grazing_mode from the legacy type column.
    # Mapping: "pasture_grazing" → "pasture", "zero_grazing" → "zero_grazing".
    # Any other value (NULL or unknown) keeps the existing grazing_mode default "pasture".
    execute """
    UPDATE farms
    SET grazing_mode = CASE type
      WHEN 'pasture_grazing' THEN 'pasture'
      WHEN 'zero_grazing'    THEN 'zero_grazing'
      ELSE grazing_mode
    END
    WHERE type IS NOT NULL;
    """

    alter table(:farms) do
      remove :type
    end
  end

  def down do
    alter table(:farms) do
      add :type, :string
    end

    # Restore type from grazing_mode on rollback.
    execute """
    UPDATE farms
    SET type = CASE grazing_mode
      WHEN 'pasture'      THEN 'pasture_grazing'
      WHEN 'zero_grazing' THEN 'zero_grazing'
      ELSE 'pasture_grazing'
    END;
    """
  end
end
