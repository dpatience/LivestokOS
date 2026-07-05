defmodule LivestokOsWeb.AuthJSON do
  @doc """
  Renders a user with token.
  """
  def user(%{user: user, token: token}) do
    %{
      data: %{
        id: user.id,
        email: user.email,
        name: user.name,
        role: user.role,
        farm_id: user.farm_id
      },
      token: token
    }
  end
end
