defmodule LivestokOs.AI.MockLLMClient do
  @moduledoc """
  Mock LLM client for tests. Returns deterministic responses
  without making external HTTP calls.
  """

  @embedding List.duplicate(0.1, 1536)

  def chat_completion(_messages, _opts \\ []) do
    {:ok, "Mock veterinary assistant response based on provided data."}
  end

  def embed(_text) do
    {:ok, @embedding}
  end

  def mock_embedding, do: @embedding
end
