defmodule LivestokOs.AI.LocalResponderTest do
  use ExUnit.Case, async: true

  alias LivestokOs.AI.LocalResponder

  defp empty_retrieval do
    %{
      case_history: %{summary: %{total_events: 0}, timeline: []},
      confirmed_cases: [],
      sources: []
    }
  end

  test "greets farmers in plain language" do
    classified = []

    assert {:ok, %{response: response}} =
             LocalResponder.respond("hello there", empty_retrieval(), classified)

    assert response =~ "veterinary assistant"
  end

  test "returns needs_llm guidance when no local context and not a greeting" do
    assert {:ok, %{response: response, insufficient_data: true}} =
             LocalResponder.respond("why is she off feed?", empty_retrieval(), [])

    assert response =~ "reasoning model"
  end
end
