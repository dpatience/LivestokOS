defmodule LivestokOs.AI.LLMClient do
  @moduledoc """
  HTTP client for chat and embedding APIs.

  Provider-agnostic via `LivestokOs.AI.LLMConfig`: set `LLM_API_KEY` and
  `LLM_API_BASE_URL` for any OpenAI-compatible endpoint, or `LLM_API_STYLE=anthropic`
  for Anthropic's Messages API (chat only).

  All calls run through `LivestokOs.AI.TaskSupervisor` with a 30-second timeout.

  ## Injectable for testing

      Application.get_env(:livestok_os_ai, :llm_client, LivestokOs.AI.LLMClient)
  """

  alias LivestokOs.AI.LLMConfig

  @timeout 30_000
  @anthropic_version "2023-06-01"

  @doc """
  Sends a chat completion request to the configured provider.

  ## Options
  - `:model` — model name (default from `LLMConfig.chat_model/0`)
  - `:temperature` — sampling temperature (default: `0.55`)
  - `:max_tokens` — max tokens in response (default: `2048`)
  """
  def chat_completion(messages, opts \\ []) do
    unless LLMConfig.configured?() do
      {:error, :llm_not_configured}
    else
      case LLMConfig.api_style() do
        "anthropic" -> anthropic_chat(messages, opts)
        _ -> openai_chat(messages, opts)
      end
    end
  end

  @doc """
  Generates an embedding vector for the given text.
  Returns `{:ok, [float]}` on success. Not available for Anthropic style.
  """
  def embed(text) do
    cond do
      not LLMConfig.configured?() ->
        {:error, :not_configured}

      LLMConfig.api_style() == "anthropic" ->
        {:error, :embeddings_not_supported}

      true ->
        body = %{
          model: LLMConfig.embed_model(),
          input: text
        }

        supervised_request(fn ->
          Req.post(
            "#{LLMConfig.base_url()}/embeddings",
            json: body,
            headers: openai_auth_headers(),
            receive_timeout: @timeout
          )
        end)
        |> handle_embed_response()
    end
  end

  defp openai_chat(messages, opts) do
    model = Keyword.get(opts, :model, LLMConfig.chat_model())
    temperature = Keyword.get(opts, :temperature, 0.55)
    max_tokens = Keyword.get(opts, :max_tokens, 2048)

    body = %{
      model: model,
      messages: messages,
      temperature: temperature,
      max_tokens: max_tokens
    }

    supervised_request(fn ->
      Req.post(
        "#{LLMConfig.base_url()}/chat/completions",
        json: body,
        headers: openai_auth_headers(),
        receive_timeout: @timeout
      )
    end)
    |> handle_openai_chat_response()
  end

  defp anthropic_chat(messages, opts) do
    model = Keyword.get(opts, :model, LLMConfig.chat_model())
    max_tokens = Keyword.get(opts, :max_tokens, 2048)
    temperature = Keyword.get(opts, :temperature, 0.55)

    {system, chat_messages} = split_anthropic_messages(messages)

    body =
      %{
        model: model,
        max_tokens: max_tokens,
        temperature: temperature,
        messages: chat_messages
      }
      |> maybe_put_system(system)

    supervised_request(fn ->
      Req.post(
        "#{LLMConfig.base_url()}/messages",
        json: body,
        headers: anthropic_auth_headers(),
        receive_timeout: @timeout
      )
    end)
    |> handle_anthropic_chat_response()
  end

  defp split_anthropic_messages(messages) do
    {system_parts, chat} =
      Enum.split_with(messages, fn m -> Map.get(m, "role") == "system" or Map.get(m, :role) == "system" end)

    system =
      system_parts
      |> Enum.map(fn m -> Map.get(m, "content") || Map.get(m, :content) end)
      |> Enum.reject(&is_nil/1)
      |> Enum.join("\n\n")

    chat_messages =
      Enum.flat_map(chat, fn m ->
        role = normalize_role(m)
        content = Map.get(m, "content") || Map.get(m, :content)

        case role do
          "user" -> [%{"role" => "user", "content" => content}]
          "assistant" -> [%{"role" => "assistant", "content" => content}]
          _ -> []
        end
      end)

    {system, chat_messages}
  end

  defp normalize_role(m) do
    (Map.get(m, "role") || Map.get(m, :role) || "user")
    |> to_string()
  end

  defp maybe_put_system(body, ""), do: body
  defp maybe_put_system(body, system), do: Map.put(body, :system, system)

  defp supervised_request(fun) do
    task =
      Task.Supervisor.async_nolink(
        LivestokOs.AI.TaskSupervisor,
        fun,
        shutdown: @timeout + 1_000
      )

    case Task.yield(task, @timeout) || Task.shutdown(task) do
      {:ok, result} -> result
      nil -> {:error, :timeout}
      {:exit, reason} -> {:error, {:task_exit, reason}}
    end
  end

  defp handle_openai_chat_response({:ok, %Req.Response{status: 200, body: body}}) do
    content =
      body
      |> Map.get("choices", [])
      |> List.first(%{})
      |> get_in(["message", "content"])

    {:ok, content}
  end

  defp handle_openai_chat_response({:ok, %Req.Response{status: status, body: body}}) do
    {:error, {:api_error, status, body}}
  end

  defp handle_openai_chat_response({:error, :timeout}), do: {:error, :llm_unavailable}
  defp handle_openai_chat_response({:error, reason}), do: {:error, {:llm_unavailable, reason}}

  defp handle_anthropic_chat_response({:ok, %Req.Response{status: 200, body: body}}) do
    content =
      body
      |> Map.get("content", [])
      |> Enum.find_value("", fn
        %{"type" => "text", "text" => text} -> text
        _ -> nil
      end)

    {:ok, content}
  end

  defp handle_anthropic_chat_response({:ok, %Req.Response{status: status, body: body}}) do
    {:error, {:api_error, status, body}}
  end

  defp handle_anthropic_chat_response({:error, :timeout}), do: {:error, :llm_unavailable}
  defp handle_anthropic_chat_response({:error, reason}), do: {:error, {:llm_unavailable, reason}}

  defp handle_embed_response({:ok, %Req.Response{status: 200, body: body}}) do
    embedding =
      body
      |> Map.get("data", [])
      |> List.first(%{})
      |> Map.get("embedding")

    {:ok, embedding}
  end

  defp handle_embed_response({:ok, %Req.Response{status: status, body: body}}) do
    {:error, {:api_error, status, body}}
  end

  defp handle_embed_response({:error, :timeout}), do: {:error, :embedding_unavailable}
  defp handle_embed_response({:error, reason}), do: {:error, {:embedding_unavailable, reason}}

  defp openai_auth_headers do
    [
      {"authorization", "Bearer #{LLMConfig.api_key()}"},
      {"content-type", "application/json"}
    ]
  end

  defp anthropic_auth_headers do
    [
      {"x-api-key", LLMConfig.api_key()},
      {"anthropic-version", @anthropic_version},
      {"content-type", "application/json"}
    ]
  end
end
