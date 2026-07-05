defmodule LivestokOsWeb.AuthController do
  use LivestokOsWeb, :controller

  alias LivestokOs.{Accounts, Inventory, Repo}
  alias LivestokOs.Guardian

  action_fallback LivestokOsWeb.FallbackController

  def register(conn, %{"user" => user_params, "farm" => farm_params}) do
    Repo.transaction(fn ->
      with {:ok, farm} <- Inventory.create_farm(farm_params),
           {:ok, user} <- Accounts.create_user_with_farm(user_params, farm.id) do
        {user, farm}
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
    |> case do
      {:ok, {user, _farm}} ->
        {:ok, token, _claims} = Guardian.encode_and_sign(user)

        conn
        |> put_status(:created)
        |> render(:user, user: user, token: token)

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def register(conn, %{"user" => user_params}) do
    with {:ok, user} <- Accounts.create_user(user_params) do
      {:ok, token, _claims} = Guardian.encode_and_sign(user)

      conn
      |> put_status(:created)
      |> render(:user, user: user, token: token)
    end
  end

  def login(conn, %{"email" => email, "password" => password}) do
    with {:ok, user} <- Accounts.authenticate_user(email, password),
         {:ok, token, _claims} <- Guardian.encode_and_sign(user) do
      conn
      |> put_status(:ok)
      |> render(:user, user: user, token: token)
    end
  end
end
