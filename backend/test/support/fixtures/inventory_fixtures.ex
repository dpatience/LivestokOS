defmodule LivestokOs.InventoryFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `LivestokOs.Inventory` context.
  """

  @doc """
  Generate a farm.
  """
  def farm_fixture(attrs \\ %{}) do
    {:ok, farm} =
      attrs
      |> Enum.into(%{
        location: "some location",
        name: "some name",
        type: "pasture_grazing"
      })
      |> LivestokOs.Inventory.create_farm()

    farm
  end

  @doc """
  Generate a cow.
  """
  def cow_fixture(attrs \\ %{}) do
    {:ok, cow} =
      attrs
      |> Enum.into(%{
        birth_date: ~D[2026-01-26],
        breed: "some breed",
        name: "some name",
        status: "some status",
        tag_id: "some tag_id"
      })
      |> LivestokOs.Inventory.create_cow()

    cow
  end
end
