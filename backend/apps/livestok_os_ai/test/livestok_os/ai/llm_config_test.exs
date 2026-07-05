defmodule LivestokOs.AI.LLMConfigTest do
  use ExUnit.Case, async: false

  alias LivestokOs.AI.LLMConfig

  setup do
    on_exit(fn ->
      for key <-
            ~w(LLM_API_KEY LLM_API_BASE_URL LLM_API_STYLE LLM_CHAT_MODEL LLM_THINKING_MODEL OPENAI_API_KEY CURSOR_API_KEY CURSOR_API_BASE_URL) do
        System.delete_env(key)
      end
    end)

    :ok
  end

  test "configured? is false without a real key" do
    refute LLMConfig.configured?()
  end

  test "reads LLM_API_KEY first" do
    System.put_env("LLM_API_KEY", "sk-test-key")
    System.put_env("OPENAI_API_KEY", "sk-other")

    assert LLMConfig.api_key() == "sk-test-key"
    assert LLMConfig.configured?()
  end

  test "falls back to legacy OPENAI and CURSOR keys" do
    System.put_env("CURSOR_API_KEY", "cursor-key")

    assert LLMConfig.api_key() == "cursor-key"
  end

  test "base_url normalizes trailing slash and agents suffix" do
    System.put_env("LLM_API_BASE_URL", "https://api.example.com/v1/agents/")

    assert LLMConfig.base_url() == "https://api.example.com/v1"
  end

  test "anthropic style disables embeddings" do
    System.put_env("LLM_API_KEY", "sk-ant-test")
    System.put_env("LLM_API_STYLE", "anthropic")

    refute LLMConfig.embeddings_available?()
  end

  test "chat_configured? is false for Cursor Agents-only URL" do
    System.put_env("CURSOR_API_KEY", "crsr_test_key")
    System.put_env("CURSOR_API_BASE_URL", "https://api.cursor.com/v1/agents")

    assert LLMConfig.configured?()
    refute LLMConfig.chat_configured?()
  end

  test "thinking_model prefers LLM_THINKING_MODEL" do
    System.put_env("LLM_THINKING_MODEL", "meta/llama-3-70b-instruct")
    System.put_env("LLM_CHAT_MODEL", "gpt-4o-mini")

    assert LLMConfig.thinking_model() == "meta/llama-3-70b-instruct"
  end
end
