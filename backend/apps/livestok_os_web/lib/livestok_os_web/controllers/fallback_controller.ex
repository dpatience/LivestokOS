defmodule LivestokOsWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use LivestokOsWeb, :controller

  # This clause handles errors returned by Ecto's insert/update/delete.
  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: LivestokOsWeb.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end

  # This clause handles invalid credentials on login.
  def call(conn, {:error, :invalid_credentials}) do
    conn
    |> put_status(:unauthorized)
    |> put_view(json: LivestokOsWeb.ErrorJSON)
    |> render(:"401")
  end

  # This clause handles unauthorized access.
  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:forbidden)
    |> put_view(json: LivestokOsWeb.ErrorJSON)
    |> render(:"403")
  end

  # This clause is an example of how to handle resources that cannot be found.
  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(html: LivestokOsWeb.ErrorHTML, json: LivestokOsWeb.ErrorJSON)
    |> render(:"404")
  end
end
