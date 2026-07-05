defmodule LivestokOsWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use LivestokOsWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint LivestokOsWeb.Endpoint

      use LivestokOsWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import LivestokOsWeb.ConnCase
    end
  end

  setup tags do
    LivestokOs.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Authenticates a test connection by creating a user and attaching a JWT token.
  Returns the conn with Authorization header set.
  """
  def authenticate(conn) do
    user =
      case LivestokOs.Accounts.get_user_by_email("test@livestok.os") do
        nil ->
          {:ok, farm} =
            LivestokOs.Inventory.create_farm(%{
              name: "Test Farm",
              location: "Test Location"
            })

          {:ok, user} =
            LivestokOs.Accounts.create_user_with_farm(
              %{
                email: "test@livestok.os",
                name: "Test User",
                password: "password123",
                role: "farm_owner"
              },
              farm.id
            )

          user

        user ->
          user
      end

    {:ok, token, _claims} = LivestokOs.Guardian.encode_and_sign(user)

    conn
    |> Plug.Conn.put_req_header("authorization", "Bearer #{token}")
  end
end
