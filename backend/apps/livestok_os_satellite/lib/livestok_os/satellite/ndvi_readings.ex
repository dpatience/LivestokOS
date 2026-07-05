defmodule LivestokOs.Satellite.NdviReadings do
  @moduledoc """
  Context for querying NDVI readings per paddock.

  This is the primary interface used by Stage 4 carbon math and Stage 6
  grass recovery to access satellite data.
  """

  import Ecto.Query, warn: false
  alias LivestokOs.Repo
  alias LivestokOs.Satellite.NdviReading

  @doc """
  Returns the most recent NDVI reading for a paddock.

  Returns:
  - `{:ok, %NdviReading{}}` — fresh reading found
  - `{:error, :stale}` — reading exists but `is_stale = true`
  - `{:error, :no_data}` — no reading exists for this paddock
  """
  def latest_ndvi_for_paddock(paddock_id) do
    reading =
      from(r in NdviReading,
        where: r.paddock_id == ^paddock_id,
        order_by: [desc: r.captured_at],
        limit: 1
      )
      |> Repo.one()

    case reading do
      nil -> {:error, :no_data}
      %NdviReading{is_stale: true} -> {:error, :stale}
      %NdviReading{} = r -> {:ok, r}
    end
  end

  @doc """
  Enqueues an NdviJob for every active keep_in paddock in a farm.
  Called by a scheduler or admin action.
  """
  def enqueue_farm_ndvi_jobs(farm_id) do
    alias LivestokOs.Infrastructure.Geofence

    paddocks =
      Repo.all(
        from(g in Geofence,
          where:
            g.farm_id == ^farm_id and
              g.is_active == true and
              g.enforcement_scope == "keep_in"
        )
      )

    Enum.each(paddocks, fn paddock ->
      %{paddock_id: paddock.id, farm_id: farm_id}
      |> LivestokOs.Satellite.NdviJob.new()
      |> Oban.insert()
    end)
  end
end
