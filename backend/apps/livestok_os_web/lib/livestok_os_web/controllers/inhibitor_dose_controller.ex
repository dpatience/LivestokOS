defmodule LivestokOsWeb.InhibitorDoseController do
  use LivestokOsWeb, :controller

  alias LivestokOs.ZeroGrazing
  alias LivestokOs.ZeroGrazing.InhibitorDose

  action_fallback LivestokOsWeb.FallbackController

  def index(conn, params) do
    inhibitor_doses = ZeroGrazing.list_inhibitor_doses(params)
    render(conn, :index, inhibitor_doses: inhibitor_doses)
  end

  def create(conn, %{"inhibitor_dose" => dose_params}) do
    with {:ok, %InhibitorDose{} = dose} <- ZeroGrazing.create_inhibitor_dose(dose_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/inhibitor_doses/#{dose}")
      |> render(:show, inhibitor_dose: dose)
    end
  end

  def show(conn, %{"id" => id}) do
    dose = ZeroGrazing.get_inhibitor_dose!(id)
    render(conn, :show, inhibitor_dose: dose)
  end

  def update(conn, %{"id" => id, "inhibitor_dose" => dose_params}) do
    dose = ZeroGrazing.get_inhibitor_dose!(id)

    with {:ok, %InhibitorDose{} = dose} <- ZeroGrazing.update_inhibitor_dose(dose, dose_params) do
      render(conn, :show, inhibitor_dose: dose)
    end
  end

  def delete(conn, %{"id" => id}) do
    dose = ZeroGrazing.get_inhibitor_dose!(id)

    with {:ok, %InhibitorDose{}} <- ZeroGrazing.delete_inhibitor_dose(dose) do
      send_resp(conn, :no_content, "")
    end
  end
end
