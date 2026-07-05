defmodule LivestokOsWeb.FarmJSON do
  alias LivestokOs.Inventory.Farm

  @doc """
  Renders a list of farms.
  """
  def index(%{farms: farms}) do
    %{data: for(farm <- farms, do: data(farm))}
  end

  @doc """
  Renders a single farm.
  """
  def show(%{farm: farm}) do
    %{data: data(farm)}
  end

  defp data(%Farm{} = farm) do
    %{
      id: farm.id,
      name: farm.name,
      grazing_mode: farm.grazing_mode,
      location: farm.location
    }
  end
end
