defmodule LivestokOs.Ingest.Producer do
  @moduledoc """
  Bounded, backpressured GenStage producer for the Broadway ingestion pipeline.

  The LoRaWAN gateway HTTP handler pushes validated reading messages into this
  queue via `push/1` or `push_many/1`. Broadway pulls them on demand,
  preserving backpressure end-to-end. The queue is bounded at `@max_queue_size`;
  excess pushes are dropped with a warning so upstream callers are never blocked
  indefinitely.

  This module is started internally by Broadway — do NOT start it as a
  standalone child. Use `Broadway.producer_names/1` (wrapped by the push
  helpers) to locate the running producer process.
  """
  use GenStage

  require Logger

  @max_queue_size 10_000
  @pipeline LivestokOs.Ingest.Pipeline

  def push(message, pipeline \\ @pipeline) do
    cast_to_producer(pipeline, {:push, message})
  end

  def push_many(messages, pipeline \\ @pipeline) when is_list(messages) do
    cast_to_producer(pipeline, {:push_many, messages})
  end

  def queue_size(pipeline \\ @pipeline) do
    call_producer(pipeline, :queue_size)
  end

  @impl true
  def init(_opts) do
    {:producer, %{queue: :queue.new(), demand: 0, size: 0}}
  end

  @impl true
  def handle_cast({:push, _msg}, %{size: size} = state) when size >= @max_queue_size do
    Logger.warning("Ingest producer queue full (#{@max_queue_size}), dropping message")
    {:noreply, [], state}
  end

  def handle_cast({:push, msg}, state) do
    state = %{state | queue: :queue.in(msg, state.queue), size: state.size + 1}
    dispatch(state)
  end

  def handle_cast({:push_many, msgs}, state) do
    available = max(@max_queue_size - state.size, 0)
    to_add = Enum.take(msgs, available)

    if length(msgs) > available do
      Logger.warning(
        "Ingest producer queue near full, dropped #{length(msgs) - available} messages"
      )
    end

    queue = Enum.reduce(to_add, state.queue, &:queue.in(&1, &2))
    state = %{state | queue: queue, size: state.size + length(to_add)}
    dispatch(state)
  end

  @impl true
  def handle_call(:queue_size, _from, state) do
    {:reply, state.size, [], state}
  end

  @impl true
  def handle_demand(incoming, state) when incoming > 0 do
    dispatch(%{state | demand: state.demand + incoming})
  end

  # ── internal ─────────────────────────────────────────────────────────

  defp dispatch(%{demand: 0} = state), do: {:noreply, [], state}
  defp dispatch(%{size: 0} = state), do: {:noreply, [], state}

  defp dispatch(state) do
    {events, queue, taken} = dequeue(state.queue, state.demand, [], 0)

    {:noreply, events,
     %{state | queue: queue, demand: state.demand - taken, size: state.size - taken}}
  end

  defp dequeue(queue, 0, acc, count), do: {Enum.reverse(acc), queue, count}

  defp dequeue(queue, n, acc, count) do
    case :queue.out(queue) do
      {{:value, item}, rest} -> dequeue(rest, n - 1, [item | acc], count + 1)
      {:empty, q} -> {Enum.reverse(acc), q, count}
    end
  end

  defp cast_to_producer(pipeline, msg) do
    case Broadway.producer_names(pipeline) do
      [producer | _] -> GenStage.cast(producer, msg)
      [] -> Logger.warning("No Broadway producer found for #{inspect(pipeline)}")
    end
  end

  defp call_producer(pipeline, msg) do
    case Broadway.producer_names(pipeline) do
      [producer | _] -> GenStage.call(producer, msg)
      [] -> 0
    end
  end
end
