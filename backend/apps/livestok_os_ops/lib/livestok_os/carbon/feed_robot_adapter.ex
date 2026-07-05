defmodule LivestokOs.FeedRobot.Adapter do
  @moduledoc """
  Behaviour for feed-robot integration.

  Implementations are responsible for communicating with the physical
  feed-robot controller to trigger precision inhibitor dosing.

  # TODO: wire to vendor API — stub only
  """

  @doc """
  Triggers an inhibitor dose for a cow on the feed robot.

  `cow_id`  — the cow to dose.
  `params`  — map with at minimum `:inhibitor_type` and `:dose_mg`.

  Returns `:ok` on success or `{:error, reason}` on failure.
  """
  @callback trigger_dose(cow_id :: integer(), params :: map()) ::
              :ok | {:error, term()}
end

defmodule LivestokOs.FeedRobot.StubAdapter do
  @moduledoc """
  Stub feed-robot adapter for testing and development.

  Logs the dose request and returns :ok without contacting any real hardware.
  Replace with the vendor-specific adapter in production.

  # TODO: wire to vendor API — stub only
  """
  @behaviour LivestokOs.FeedRobot.Adapter

  require Logger

  @impl true
  def trigger_dose(cow_id, params) do
    Logger.info(
      "[FeedRobot.StubAdapter] trigger_dose cow=#{cow_id} params=#{inspect(params)}"
    )

    :ok
  end
end
