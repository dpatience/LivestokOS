defmodule LivestokOs.Guardian do
  use Guardian, otp_app: :livestok_os

  def subject_for_token(user, _claims) do
    {:ok, to_string(user.id)}
  end

  @doc "Embed extra user info in JWT claims so the frontend can read them."
  def build_claims(claims, user, _opts) do
    claims =
      claims
      |> Map.put("email", user.email)
      |> Map.put("name", user.name)
      |> Map.put("role", user.role)
      |> Map.put("farm_id", user.farm_id)

    {:ok, claims}
  end

  def resource_from_claims(%{"sub" => id}) do
    case LivestokOs.Repo.get(LivestokOs.User, id) do
      nil -> {:error, :resource_not_found}
      user -> {:ok, user}
    end
  end

  def resource_from_claims(_), do: {:error, :invalid_claims}
end
