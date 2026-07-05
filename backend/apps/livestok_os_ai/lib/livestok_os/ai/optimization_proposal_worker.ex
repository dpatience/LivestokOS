defmodule LivestokOs.AI.OptimizationProposalWorker do
  @moduledoc """
  Monthly Oban worker that observes farm performance data and proposes
  algorithm weight adjustments for the GrazingCoach.

  ## What it does

  1. Fetches the last 30 days of NDVI readings and rotation events for
     every active farm.
  2. Builds a data snapshot (min / mean / max NDVI per paddock, average
     days-between-rotations) and sends it to the LLM with the current
     algorithm weights.
  3. The LLM reasons about seasonal patterns and suggests updated weights
     **only if the data supports it**.
  4. Writes a Markdown proposal file to `priv/ai_proposals/` and raises
     an `Alert` record so the developer / agronomist is notified.

  ## Guardrails

  The worker does NOT modify `GrazingCoach` or any other module directly.
  It produces a read-only proposal for human review.  The reviewer must
  verify the maths and merge the change manually.
  """

  use Oban.Worker, queue: :research, max_attempts: 2

  import Ecto.Query, warn: false

  alias LivestokOs.Repo
  alias LivestokOs.Inventory.Farm
  alias LivestokOs.Satellite.NdviReading
  alias LivestokOs.Infrastructure.RotationEvent
  alias LivestokOs.Operations.Alert

  require Logger

  # Current GrazingCoach weights (mirrored here for the LLM prompt).
  # Keep in sync with GrazingCoach module constants.
  @current_weights %{ndvi: 0.4, rest: 0.3, recovery: 0.3}

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    farms = Repo.all(from f in Farm, select: [:id, :name, :grazing_mode])

    Enum.each(farms, fn farm ->
      case build_and_write_proposal(farm) do
        {:ok, path} ->
          Logger.info("[OptimizationProposal] Proposal written for farm #{farm.id}: #{path}")
          notify_reviewer(farm, path)

        {:skip, reason} ->
          Logger.debug("[OptimizationProposal] Skipped farm #{farm.id}: #{reason}")

        {:error, reason} ->
          Logger.warning(
            "[OptimizationProposal] Failed for farm #{farm.id}: #{inspect(reason)}"
          )
      end
    end)

    :ok
  end

  # ---- Private ----

  defp build_and_write_proposal(farm) do
    snapshot = build_data_snapshot(farm.id)

    if snapshot.paddock_count == 0 do
      {:skip, :no_paddocks}
    else
      case llm_client().chat_completion(proposal_prompt(farm, snapshot), max_tokens: 1024) do
        {:ok, proposal_text} ->
          path = write_proposal_file(farm, snapshot, proposal_text)
          {:ok, path}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp build_data_snapshot(farm_id) do
    since = DateTime.add(DateTime.utc_now(), -30, :day)

    ndvi_rows =
      Repo.all(
        from r in NdviReading,
          where: r.farm_id == ^farm_id and r.captured_at >= ^since,
          select: %{paddock_id: r.paddock_id, ndvi_score: r.ndvi_score}
      )

    rotation_rows =
      Repo.all(
        from r in RotationEvent,
          where: r.farm_id == ^farm_id and r.occurred_at >= ^since,
          select: %{paddock_id: r.paddock_id, occurred_at: r.occurred_at}
      )

    ndvi_by_paddock =
      Enum.group_by(ndvi_rows, & &1.paddock_id, & &1.ndvi_score)

    paddock_stats =
      Map.new(ndvi_by_paddock, fn {pid, scores} ->
        sorted = Enum.sort(scores)
        n = length(sorted)
        mean = Enum.sum(sorted) / max(n, 1)

        {pid,
         %{
           min: List.first(sorted),
           max: List.last(sorted),
           mean: Float.round(mean, 3),
           readings: n
         }}
      end)

    rotation_intervals =
      rotation_rows
      |> Enum.group_by(& &1.paddock_id, & &1.occurred_at)
      |> Enum.map(fn {_pid, timestamps} ->
        sorted = Enum.sort(timestamps, DateTime)
        intervals = compute_intervals_days(sorted)
        if intervals == [], do: nil, else: Enum.sum(intervals) / length(intervals)
      end)
      |> Enum.reject(&is_nil/1)

    avg_rotation_interval =
      if rotation_intervals == [],
        do: nil,
        else: Float.round(Enum.sum(rotation_intervals) / length(rotation_intervals), 1)

    %{
      paddock_count: map_size(paddock_stats),
      paddock_stats: paddock_stats,
      avg_rotation_interval_days: avg_rotation_interval,
      observation_window_days: 30
    }
  end

  defp compute_intervals_days([_]), do: []
  defp compute_intervals_days([]), do: []

  defp compute_intervals_days(timestamps) do
    timestamps
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [a, b] -> DateTime.diff(b, a, :day) end)
    |> Enum.filter(&(&1 > 0))
  end

  defp proposal_prompt(farm, snapshot) do
    month_name = Date.utc_today() |> Calendar.strftime("%B %Y")

    data_block =
      snapshot.paddock_stats
      |> Enum.map(fn {pid, s} ->
        "  Paddock #{pid}: min=#{s.min} mean=#{s.mean} max=#{s.max} (#{s.readings} readings)"
      end)
      |> Enum.join("\n")

    rotation_line =
      if snapshot.avg_rotation_interval_days,
        do: "Average rotation interval: #{snapshot.avg_rotation_interval_days} days",
        else: "No rotation events recorded in this window"

    current_weights_text =
      "ndvi_weight=#{@current_weights.ndvi}, " <>
        "rest_weight=#{@current_weights.rest}, " <>
        "recovery_weight=#{@current_weights.recovery}"

    [
      %{
        role: "system",
        content: """
        You are a precision-livestock-farming algorithm advisor reviewing grazing data.
        Your job is to propose WEIGHT ADJUSTMENTS to the GrazingCoach ranking formula:

            paddock_score = (ndvi × ndvi_weight)
                          + (rest × rest_weight)
                          + (recovery × recovery_weight)

        Current weights: #{current_weights_text}
        All weights must remain in (0, 1) and sum to 1.0.

        Rules:
        - Only propose a change if the data clearly supports it.
        - If the data is insufficient or weights are already appropriate, say so explicitly.
        - Do NOT suggest changes to source code.
        - Format your output as Markdown with sections:
            ## Observed Pattern
            ## Proposed Adjustment (or: No Adjustment Recommended)
            ## Reasoning
            ## Suggested New Weights (table)
        """
      },
      %{
        role: "user",
        content: """
        Farm: #{farm.name} (id: #{farm.id}) — #{month_name}
        Observation window: #{snapshot.observation_window_days} days
        Paddocks with data: #{snapshot.paddock_count}

        NDVI readings per paddock (30-day window):
        #{data_block}

        #{rotation_line}

        Please produce a concise optimization proposal.
        """
      }
    ]
  end

  defp write_proposal_file(farm, _snapshot, proposal_text) do
    priv_dir = :code.priv_dir(:livestok_os_ai)
    proposals_dir = Path.join(priv_dir, "ai_proposals")
    File.mkdir_p!(proposals_dir)

    today = Date.utc_today()
    stamp = Calendar.strftime(today, "%Y_%m")
    safe_name = String.replace(farm.name, ~r/[^\w\s-]/, "") |> String.replace(" ", "_")
    filename = "Optimization_Proposal_#{stamp}_#{safe_name}.md"
    path = Path.join(proposals_dir, filename)

    content = """
    # Optimization Proposal — #{farm.name} — #{Calendar.strftime(today, "%B %Y")}

    > **Auto-generated by `OptimizationProposalWorker`.**
    > This file is a *proposal only*. No code or weights have been changed.
    > Review the reasoning below, validate the maths, then update
    > `LivestokOs.AI.GrazingCoach` manually if you agree.

    **Generated:** #{DateTime.utc_now() |> DateTime.to_iso8601()}
    **Farm ID:** #{farm.id}

    ---

    #{proposal_text}
    """

    File.write!(path, content)
    path
  end

  defp notify_reviewer(farm, path) do
    filename = Path.basename(path)

    %Alert{}
    |> Alert.changeset(%{
      farm_id: farm.id,
      type: "AI_OPTIMIZATION_PROPOSAL",
      message:
        "GrazingCoach optimization proposal ready for review: #{filename}. " <>
          "See priv/ai_proposals/ — no weights have been changed.",
      is_resolved: false,
      severity: "info",
      priority: "low"
    })
    |> Repo.insert()
  end

  defp llm_client do
    Application.get_env(:livestok_os_ai, :llm_client, LivestokOs.AI.LLMClient)
  end
end
