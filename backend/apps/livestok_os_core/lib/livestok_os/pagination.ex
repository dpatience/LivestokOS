defmodule LivestokOs.Pagination do
  @moduledoc """
  Shared offset-based pagination helpers.

  Usage in contexts:

      import LivestokOs.Pagination

      def list_items(opts \\\\ %{}) do
        Item
        |> paginate(opts)
        |> Repo.all()
      end

  Accepts `limit` (default 50, max 200) and `offset` (default 0) from params.
  """

  import Ecto.Query

  @default_limit 50
  @max_limit 200

  @doc """
  Applies limit/offset to an Ecto query based on params map.
  Accepts atom or string keys.
  """
  def paginate(query, opts \\ %{}) do
    limit = get_int(opts, :limit, @default_limit) |> min(@max_limit) |> max(1)
    offset = get_int(opts, :offset, 0) |> max(0)

    query
    |> limit(^limit)
    |> offset(^offset)
  end

  @doc """
  Builds pagination metadata for a response.
  """
  def pagination_meta(opts, count) do
    limit = get_int(opts, :limit, @default_limit) |> min(@max_limit) |> max(1)
    offset = get_int(opts, :offset, 0) |> max(0)

    %{
      limit: limit,
      offset: offset,
      total: count,
      has_more: offset + limit < count
    }
  end

  defp get_int(map, key, default) do
    val = Map.get(map, key) || Map.get(map, Atom.to_string(key))
    parse_int(val, default)
  end

  defp parse_int(nil, default), do: default
  defp parse_int(v, _) when is_integer(v), do: v

  defp parse_int(v, default) when is_binary(v) do
    case Integer.parse(v) do
      {i, _} -> i
      :error -> default
    end
  end

  defp parse_int(_, default), do: default
end
