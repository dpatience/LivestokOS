defmodule LivestokOsWeb.BiogasRecordController do
  use LivestokOsWeb, :controller

  alias LivestokOs.ZeroGrazing
  alias LivestokOs.ZeroGrazing.BiogasRecord

  action_fallback LivestokOsWeb.FallbackController

  def index(conn, params) do
    biogas_records = ZeroGrazing.list_biogas_records(params)
    render(conn, :index, biogas_records: biogas_records)
  end

  def create(conn, %{"biogas_record" => br_params}) do
    with {:ok, %BiogasRecord{} = br} <- ZeroGrazing.create_biogas_record(br_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/biogas_records/#{br}")
      |> render(:show, biogas_record: br)
    end
  end

  def show(conn, %{"id" => id}) do
    br = ZeroGrazing.get_biogas_record!(id)
    render(conn, :show, biogas_record: br)
  end

  def update(conn, %{"id" => id, "biogas_record" => br_params}) do
    br = ZeroGrazing.get_biogas_record!(id)

    with {:ok, %BiogasRecord{} = br} <- ZeroGrazing.update_biogas_record(br, br_params) do
      render(conn, :show, biogas_record: br)
    end
  end

  def delete(conn, %{"id" => id}) do
    br = ZeroGrazing.get_biogas_record!(id)

    with {:ok, %BiogasRecord{}} <- ZeroGrazing.delete_biogas_record(br) do
      send_resp(conn, :no_content, "")
    end
  end
end
