defmodule LivestokOs.AI.LLMClient do
  @moduledoc """
  HTTP client for OpenAI-compatible chat completion and embedding APIs.

  Reads `OPENAI_API_KEY` and `OPENAI_API_BASE_URL` from application config
  (wired from env vars in `config/runtime.exs`).

  All calls are executed through `LivestokOs.AI.TaskSupervisor` with a
  30-second timeout to prevent slow/failing external calls from crashing
  the request process.

  ## Injectable for testing

      Application.get_env(:livestok_os_ai, :llm_client, LivestokOs.AI.LLMClient)
  """

  @timeout 30_000

  @doc """
  Sends a chat completion request to the configured OpenAI-compatible API.

  ## Options
  - `:model` — model name (default: `"gpt-4o"`)
  - `:temperature` — sampling temperature (default: `0.3`)
  - `:max_tokens` — max tokens in response (default: `2048`)
  """
  def chat_completion(messages, opts \\ []) do
    model = Keyword.get(opts, :model, "gpt-4o")
    temperature = Keyword.get(opts, :temperature, 0.3)
    max_tokens = Keyword.get(opts, :max_tokens, 2048)

    body = %{
      model: model,
      messages: messages,
      temperature: temperature,
      max_tokens: max_tokens
    }

    supervised_request(fn ->
      Req.post(
        "#{base_url()}/chat/completions",
        json: body,
        headers: auth_headers(),
        receive_timeout: @timeout
      )
    end)
    |> handle_chat_response()
  end

  @doc """
  Generates an embedding vector for the given text using `text-embedding-3-small`.
  Returns `{:ok, [float]}` on success.
  """
  def embed(text) do
    body = %{
      model: "text-embedding-3-small",
      input: text
    }

    supervised_request(fn ->
      Req.post(
        "#{base_url()}/embeddings",
        json: body,
        headers: auth_headers(),
        receive_timeout: @timeout
      )
    end)
    |> handle_embed_response()
  end

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

  defp handle_chat_response({:ok, %Req.Response{status: 200, body: body}}) do
    content =
      body
      |> Map.get("choices", [])
      |> List.first(%{})
      |> get_in(["message", "content"])

    {:ok, content}
  end

  defp handle_chat_response({:ok, %Req.Response{status: status, body: body}}) do
    {:error, {:api_error, status, body}}
  end

  defp handle_chat_response({:error, :timeout}) do
    {:error, :llm_unavailable}
  end

  defp handle_chat_response({:error, reason}) do
    {:error, {:llm_unavailable, reason}}
  end

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

  defp handle_embed_response({:error, :timeout}) do
    {:error, :embedding_unavailable}
  end

  defp handle_embed_response({:error, reason}) do
    {:error, {:embedding_unavailable, reason}}
  end

  defp api_key do
    Application.get_env(:livestok_os_ai, :openai_api_key)
  end

  defp base_url do
    Application.get_env(:livestok_os_ai, :openai_base_url, "https://api.openai.com/v1")
  end

  defp auth_headers do
    [{"authorization", "Bearer #{api_key()}"}, {"content-type", "application/json"}]
  end
end
