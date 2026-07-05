defmodule LivestokOs.AI.ConsultSessionTest do
  use LivestokOs.AI.DataCase

  alias LivestokOs.AI.ConsultSession
  alias LivestokOs.Inventory.{Farm, Cow}

  defp create_farm do
    {:ok, farm} =
      Repo.insert(Farm.changeset(%Farm{}, %{name: "Test Farm", location: "Nairobi"}))

    farm
  end

  defp create_cow(farm_id) do
    {:ok, cow} =
      Repo.insert(
        Cow.changeset(%Cow{}, %{
          tag_id: "COW-#{System.unique_integer([:positive])}",
          name: "Bessie",
          breed: "Holstein",
          birth_date: ~D[2020-01-01],
          status: "active",
          farm_id: farm_id
        })
      )

    cow
  end

  describe "session lifecycle" do
    test "start_session, send_message, and get_history" do
      farm = create_farm()
      cow = create_cow(farm.id)

      assert {:ok, session_id} = ConsultSession.start_session(cow.id, farm.id, 1)
      assert is_binary(session_id)

      assert {:ok, %{response: response}} =
               ConsultSession.send_message(session_id, "What is this cow's recent activity?")

      assert is_binary(response)

      history = ConsultSession.get_history(session_id)
      assert is_list(history)
      assert length(history) == 2

      [user_msg, assistant_msg] = history
      assert user_msg.role == :user
      assert assistant_msg.role == :assistant
    end

    test "returns error for nonexistent session" do
      assert {:error, :session_not_found} =
               ConsultSession.send_message("nonexistent", "hello")
    end
  end
end
