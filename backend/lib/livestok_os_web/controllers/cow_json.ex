defmodule LivestokOsWeb.CowJSON do
  alias LivestokOs.Inventory.Cow

  @doc """
  Renders a list of cows.
  """
  def index(%{cows: cows}) do
    %{data: for(cow <- cows, do: data(cow))}
  end

  @doc """
  Renders a single cow.
  """
  def show(%{cow: cow}) do
    %{data: data(cow)}
  end

  defp data(%Cow{} = cow) do
    %{
      id: cow.id,
      name: cow.name,
      age: calculate_age(cow.birth_date),
      breed: cow.breed,
      # placeholder, assuming average weight
      weight: 500,
      healthStatus: cow.status
    }
  end

  defp calculate_age(birth_date) do
    today = Date.utc_today()
    (Date.diff(today, birth_date) / 365) |> trunc()
  end

  @doc """
  Renders the analysis result for the frontend.
  """
  def analysis(%{result: result}) do
    %{
      status: "success",
      data: %{
        # "regenerative_verified" or "overgrazing_detected"
        rotation_status: result.rotation,
        carbon_impact: %{
          tons_sequestered: result.carbon.carbon_added,
          ndvi_grass_health: result.carbon.ndvi_snapshot
        },
        # "safe_grazing" or creates an alert
        grazing_coach: result.coach
      }
    }
  end
end
