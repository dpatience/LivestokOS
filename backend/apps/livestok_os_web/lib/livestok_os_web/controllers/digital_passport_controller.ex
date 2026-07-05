defmodule LivestokOsWeb.DigitalPassportController do
  use LivestokOsWeb, :controller

  alias LivestokOs.DigitalPassport

  action_fallback LivestokOsWeb.FallbackController

  @doc """
  GET /api/farms/:farm_id/cows/:cow_id/digital_passport

  Generates and returns a cryptographically signed digital passport for a
  single animal. Generation is performed synchronously in this request; for
  high-throughput deployments consider moving to an async job.
  """
  def show(conn, %{"farm_id" => farm_id, "cow_id" => cow_id}) do
    with {:ok, passport} <- DigitalPassport.generate(String.to_integer(farm_id), String.to_integer(cow_id)) do
      json(conn, %{data: passport})
    end
  end
end
