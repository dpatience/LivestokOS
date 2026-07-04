defmodule LivestokOs.Operations.GrazingCoach do
  @moduledoc """
  The "Active Intervention Layer" — monitors pasture quality and triggers
  methane-risk alerts with 24-hour deduplication.
  """
  import Ecto.Query, warn: false
  alias LivestokOs.Repo
  alias LivestokOs.Operations.Alert
  alias LivestokOs.Satellite

  @dedup_window_hours 24

  @doc """
  Checks NDVI at the cow's location. If grass is dry (NDVI < 0.3),
  creates a METHANE_RISK alert unless one already exists within the
  deduplication window.
  """
  def check_methane_risk(cow_id, lat, long) do
    {:ok, ndvi} = Satellite.get_current_ndvi(lat, long)

    if ndvi < 0.3 do
      if recent_alert_exists?(cow_id, "METHANE_RISK") do
        {:ok, :alert_already_active}
      else
        create_methane_alert(cow_id, ndvi)
      end
    else
      {:ok, :safe_grazing}
    end
  end

  defp recent_alert_exists?(cow_id, type) do
    cutoff = DateTime.utc_now() |> DateTime.add(-@dedup_window_hours * 3600, :second)

    from(a in Alert,
      where:
        a.cow_id == ^cow_id and
          a.type == ^type and
          a.is_resolved == false and
          a.inserted_at >= ^cutoff
    )
    |> Repo.exists?()
  end

  defp create_methane_alert(cow_id, ndvi) do
    %Alert{}
    |> Alert.changeset(%{
      cow_id: cow_id,
      type: "METHANE_RISK",
      message:
        "Pasture quality low (NDVI: #{ndvi}). Methane risk high. Deploy Molasses Lick Blocks immediately.",
      is_resolved: false
    })
    |> Repo.insert()
  end
end
