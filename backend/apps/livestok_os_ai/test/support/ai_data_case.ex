defmodule LivestokOs.AI.DataCase do
  @moduledoc """
  Test case template for AI app tests that need database access.
  """
  use ExUnit.CaseTemplate

  using do
    quote do
      alias LivestokOs.Repo
      import Ecto.Query
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(LivestokOs.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    :ok
  end
end
