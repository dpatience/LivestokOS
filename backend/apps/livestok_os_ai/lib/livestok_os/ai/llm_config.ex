defmodule LivestokOs.AI.LLMConfig do
  @moduledoc """
  Provider-agnostic LLM configuration.

  Set **`LLM_API_KEY`** and **`LLM_API_BASE_URL`** for any OpenAI-compatible
  provider (OpenAI, OpenRouter, Ollama, Azure OpenAI, Together, etc.).

  Legacy env names (`OPENAI_*`, `CURSOR_*`, `ANTHROPIC_*`) are accepted as
  fallbacks so existing `.env` files keep working.

  ## API styles

  - `openai` (default) — `/chat/completions` + `/embeddings`
  - `anthropic` — `/v1/messages` (chat only; vector search falls back to keywords)

  **Note:** Cursor's Agents API (`api.cursor.com/v1/agents`) is not chat-compatible.
  Point `LLM_API_BASE_URL` at an OpenAI-compatible endpoint instead.
  """

  @default_openai_base "https://api.openai.com/v1"
  @default_anthropic_base "https://api.anthropic.com/v1"

  def api_key do
    pick([
      env("LLM_API_KEY"),
      env("OPENAI_API_KEY"),
      env("ANTHROPIC_API_KEY"),
      env("CURSOR_API_KEY"),
      app(:llm_api_key)
    ])
  end

  def base_url do
    raw =
      pick([
        env("LLM_API_BASE_URL"),
        env("OPENAI_API_BASE_URL"),
        env("ANTHROPIC_API_BASE_URL"),
        env("CURSOR_API_BASE_URL"),
        app(:llm_api_base_url)
      ])

    normalize_base_url(raw || default_base_for_style())
  end

  def api_style do
    (pick([env("LLM_API_STYLE"), app(:llm_api_style)]) || "openai")
    |> String.downcase()
  end

  def chat_model do
    pick([env("LLM_CHAT_MODEL"), app(:llm_chat_model)]) ||
      case api_style() do
        "anthropic" -> "claude-sonnet-4-20250514"
        _ -> "gpt-4o"
      end
  end

  @doc """
  Model used for vet consult reasoning (OpenAI-compatible `/chat/completions`).

  Set `LLM_THINKING_MODEL` to your Crusoe / OpenRouter / NIM slug. Falls back to
  `LLM_CHAT_MODEL`, then a sensible default for OpenAI-style providers.
  """
  def thinking_model do
    pick([
      env("LLM_THINKING_MODEL"),
      app(:llm_thinking_model),
      env("LLM_CHAT_MODEL"),
      app(:llm_chat_model)
    ]) || default_thinking_model()
  end

  def embed_model do
    pick([env("LLM_EMBED_MODEL"), app(:llm_embed_model)]) || "text-embedding-3-small"
  end

  def configured? do
    key = api_key()
    is_binary(key) and String.trim(key) != "" and not placeholder?(key)
  end

  @doc """
  True when consult can call a chat/reasoning model (not Cursor Agents-only URLs).
  """
  def chat_configured? do
    configured?() and not cursor_agents_only?()
  end

  @doc "Plain-language hint when consult cannot reach a reasoning model."
  def consult_setup_hint do
    cond do
      not configured?() ->
        "Set LLM_API_KEY and LLM_API_BASE_URL (OpenAI-compatible chat endpoint) plus LLM_THINKING_MODEL in backend/.env, then restart the server."

      cursor_agents_only?() ->
        "CURSOR_API_BASE_URL points at the Agents API, which cannot answer consult chat. Set LLM_API_BASE_URL to an OpenAI-compatible endpoint (Crusoe, OpenRouter, NIM, Ollama) and LLM_THINKING_MODEL to your reasoning model slug."

      true ->
        "Check LLM_API_BASE_URL and LLM_THINKING_MODEL — the reasoning model could not be reached."
    end
  end

  def embeddings_available? do
    configured?() and api_style() != "anthropic"
  end

  defp default_thinking_model do
    case api_style() do
      "anthropic" -> chat_model()
      _ -> "meta/llama-3-70b-instruct"
    end
  end

  defp cursor_agents_only? do
    raw =
      pick([
        env("LLM_API_BASE_URL"),
        env("CURSOR_API_BASE_URL"),
        app(:llm_api_base_url)
      ])

    is_binary(raw) and String.contains?(String.downcase(raw), "/agents")
  end

  defp default_base_for_style do
    if api_style() == "anthropic", do: @default_anthropic_base, else: @default_openai_base
  end

  defp normalize_base_url(url) when is_binary(url) do
    url
    |> String.trim()
    |> String.trim_trailing("/")
    |> String.replace(~r{/agents$}, "")
  end

  defp normalize_base_url(_), do: @default_openai_base

  defp placeholder?(key) do
    String.match?(key, ~r/CHANGE_ME|^sk-CHANGE/i)
  end

  defp env(name), do: System.get_env(name)
  defp app(key), do: Application.get_env(:livestok_os_ai, key)

  defp pick([]), do: nil

  defp pick([nil | rest]), do: pick(rest)
  defp pick(["" | rest]), do: pick(rest)
  defp pick([val | _]), do: val
end
