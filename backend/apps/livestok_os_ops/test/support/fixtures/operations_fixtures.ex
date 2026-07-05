defmodule LivestokOs.OperationsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `LivestokOs.Operations` context.
  """

  @doc """
  Generate a grazing_event.
  """
  def grazing_event_fixture(attrs \\ %{}) do
    cow = LivestokOs.InventoryFixtures.cow_fixture()

    {:ok, grazing_event} =
      attrs
      |> Enum.into(%{
        entered_at: ~U[2026-01-26 11:09:00Z],
        left_at: ~U[2026-01-26 11:09:00Z],
        zone_id: "some zone_id",
        cow_id: cow.id
      })
      |> LivestokOs.Operations.create_grazing_event()

    grazing_event
  end

  @doc """
  Generate a alert.
  """
  def alert_fixture(attrs \\ %{}) do
    {:ok, alert} =
      attrs
      |> Enum.into(%{
        is_resolved: true,
        message: "some message",
        type: "some type"
      })
      |> LivestokOs.Operations.create_alert()

    alert
  end
end
