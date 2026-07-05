defmodule LivestokOs.AI.CaseMemoryTest do
  use LivestokOs.AI.DataCase

  alias LivestokOs.AI.CaseMemory
  alias LivestokOs.Inventory.{Farm, Cow}

  @similar_embedding List.duplicate(0.1, 1536)
  @dissimilar_embedding Enum.map(1..1536, fn i -> if rem(i, 2) == 0, do: 0.9, else: -0.9 end)

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

  describe "search_confirmed/3" do
    test "returns confirmed case matching similar embedding" do
      farm = create_farm()
      cow = create_cow(farm.id)

      {:ok, case_record} =
        CaseMemory.store_unconfirmed(%{
          farm_id: farm.id,
          cow_id: cow.id,
          situation_summary: "Cow showing reduced appetite and low activity",
          situation_embedding: @similar_embedding,
          assistant_answer: "Check for ketosis indicators"
        })

      {:ok, _} = CaseMemory.confirm_case(case_record.id, 1)

      results = CaseMemory.search_confirmed(@similar_embedding, farm.id)
      assert length(results) >= 1
      assert hd(results).situation_summary =~ "reduced appetite"
    end

    test "does not return unconfirmed cases" do
      farm = create_farm()
      cow = create_cow(farm.id)

      {:ok, _} =
        CaseMemory.store_unconfirmed(%{
          farm_id: farm.id,
          cow_id: cow.id,
          situation_summary: "Unconfirmed case",
          situation_embedding: @similar_embedding,
          assistant_answer: "Unverified answer"
        })

      results = CaseMemory.search_confirmed(@similar_embedding, farm.id)
      assert results == []
    end

    test "does not return dissimilar embeddings" do
      farm = create_farm()
      cow = create_cow(farm.id)

      {:ok, case_record} =
        CaseMemory.store_unconfirmed(%{
          farm_id: farm.id,
          cow_id: cow.id,
          situation_summary: "Completely different case",
          situation_embedding: @dissimilar_embedding,
          assistant_answer: "Different answer"
        })

      {:ok, _} = CaseMemory.confirm_case(case_record.id, 1)

      results = CaseMemory.search_confirmed(@similar_embedding, farm.id)
      assert results == []
    end
  end

  describe "confirm_case/2" do
    test "sets confirmed_at and confirmed_by_user_id" do
      farm = create_farm()
      cow = create_cow(farm.id)

      {:ok, case_record} =
        CaseMemory.store_unconfirmed(%{
          farm_id: farm.id,
          cow_id: cow.id,
          situation_summary: "Test case",
          situation_embedding: @similar_embedding
        })

      assert is_nil(case_record.confirmed_at)

      {:ok, confirmed} = CaseMemory.confirm_case(case_record.id, 42)
      assert not is_nil(confirmed.confirmed_at)
      assert confirmed.confirmed_by_user_id == 42
    end
  end
end
