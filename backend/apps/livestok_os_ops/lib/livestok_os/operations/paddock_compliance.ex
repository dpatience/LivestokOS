defmodule LivestokOs.Operations.PaddockCompliance do
  @moduledoc """
  Manages paddock rotational compliance scores.

  The compliance score is:
    `min(1.0, actual_rotations / prescribed_rotations)`

  Scores are stored in `paddock_compliance_scores` and recalculated whenever
  a new rotation event arrives. Stage 4 carbon math depends on this value
  being queryable without recomputation.

  ## Period convention
  Each compliance record covers a 28-day grazing period, starting from the
  most recent Monday before the farm's first rotation event (or 28 days ago
  if no events exist). This mirrors standard rotational grazing plans.
  The default prescribed rotations per 28-day period is 4 (one per week).
  """

  import Ecto.Query, warn: false
  alias LivestokOs.Repo
  alias LivestokOs.Infrastructure.{RotationEvent, PaddockComplianceScore}

  @period_days 28
  @default_prescribed 4

  @doc """
  Called whenever a new RotationEvent is persisted. Finds (or creates) the
  compliance record for the current period and increments `actual_rotations`,
  then recomputes the score.
  """
  def on_rotation_event(%RotationEvent{} = event) do
    {period_start, period_end} = current_period(event.occurred_at)

    case get_or_create_score(event.paddock_id, event.farm_id, period_start, period_end) do
      {:ok, score} ->
        new_actual = score.actual_rotations + 1

        score
        |> PaddockComplianceScore.changeset(%{actual_rotations: new_actual})
        |> Repo.update()

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Returns the current compliance score for a paddock in the active period.
  Returns `{:ok, %PaddockComplianceScore{}}` or `{:error, :no_data}`.
  """
  def get_compliance(paddock_id, farm_id) do
    {period_start, period_end} = current_period(DateTime.utc_now())

    case Repo.get_by(PaddockComplianceScore,
           paddock_id: paddock_id,
           farm_id: farm_id,
           period_start: period_start,
           period_end: period_end
         ) do
      nil -> {:error, :no_data}
      score -> {:ok, score}
    end
  end

  # ---------------------------------------------------------------------------

  defp get_or_create_score(paddock_id, farm_id, period_start, period_end) do
    case Repo.get_by(PaddockComplianceScore,
           paddock_id: paddock_id,
           farm_id: farm_id,
           period_start: period_start,
           period_end: period_end
         ) do
      nil ->
        %PaddockComplianceScore{}
        |> PaddockComplianceScore.changeset(%{
          paddock_id: paddock_id,
          farm_id: farm_id,
          period_start: period_start,
          period_end: period_end,
          prescribed_rotations: @default_prescribed,
          actual_rotations: 0
        })
        |> Repo.insert()

      score ->
        {:ok, score}
    end
  end

  defp current_period(anchor) do
    period_start =
      anchor
      |> DateTime.add(-@period_days * 86_400, :second)
      |> DateTime.truncate(:second)

    period_end =
      anchor
      |> DateTime.add(@period_days * 86_400, :second)
      |> DateTime.truncate(:second)

    {period_start, period_end}
  end
end
