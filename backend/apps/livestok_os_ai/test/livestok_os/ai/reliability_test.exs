defmodule LivestokOs.AI.ReliabilityTest do
  use LivestokOs.AI.DataCase

  describe "Task.Supervisor timeout handling" do
    test "slow task returns nil on yield timeout, does not crash caller" do
      slow_fun = fn ->
        Process.sleep(5_000)
        {:ok, :done}
      end

      task =
        Task.Supervisor.async_nolink(
          LivestokOs.AI.TaskSupervisor,
          slow_fun,
          shutdown: 3_000
        )

      result = Task.yield(task, 1_000) || Task.shutdown(task)

      case result do
        nil -> assert true
        {:exit, _} -> assert true
        {:ok, _} -> flunk("Should have timed out")
      end
    end

    test "AI app supervisor is independent and running" do
      assert Process.whereis(LivestokOsAi.Supervisor) != nil
      assert Process.whereis(LivestokOs.AI.TaskSupervisor) != nil
      assert Process.whereis(LivestokOs.AI.SessionRegistry) != nil
      assert Process.whereis(LivestokOs.AI.SessionSupervisor) != nil
    end

    test "mock LLM client returns structured responses" do
      assert {:ok, response} = LivestokOs.AI.MockLLMClient.chat_completion([])
      assert is_binary(response)

      assert {:ok, embedding} = LivestokOs.AI.MockLLMClient.embed("test")
      assert is_list(embedding)
      assert length(embedding) == 1536
    end
  end
end
