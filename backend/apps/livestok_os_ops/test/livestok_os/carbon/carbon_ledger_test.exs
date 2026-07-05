defmodule LivestokOs.CarbonLedgerTest do
  @moduledoc """
  Tests for the append-only hash-chain ledger.

  Critical test: inserts 3 entries, tampers the middle row's chain_hash
  directly via Ecto (bypassing the ledger API), then calls verify_chain/1
  and asserts {:error, :chain_broken} at the tampered row.
  """

  use LivestokOs.DataCase

  alias LivestokOs.CarbonLedger
  alias LivestokOs.Carbon.CarbonLedgerEntry
  alias LivestokOs.Inventory

  setup do
    {:ok, farm} =
      Inventory.create_farm(%{
        name: "Ledger Test Farm #{System.unique_integer([:positive])}",
        location: "Test",
        grazing_mode: :pasture
      })

    %{farm: farm}
  end

  describe "append/2 and verify_chain/1" do
    test "empty chain returns {:ok, :empty_chain}", %{farm: farm} do
      assert {:ok, :empty_chain} = CarbonLedger.verify_chain(farm.id)
    end

    test "single entry chain is valid", %{farm: farm} do
      {:ok, _entry} =
        CarbonLedger.append(farm.id, %{
          record_type: "carbon_sequestration",
          record_id: 1,
          content_hash: CarbonLedger.content_hash(%{carbon_tco2e: 2.0})
        })

      assert {:ok, :chain_valid} = CarbonLedger.verify_chain(farm.id)
    end

    test "three-entry chain is valid when untampered", %{farm: farm} do
      for i <- 1..3 do
        {:ok, _} =
          CarbonLedger.append(farm.id, %{
            record_type: "carbon_sequestration",
            record_id: i,
            content_hash: CarbonLedger.content_hash(%{carbon_tco2e: i * 1.0})
          })
      end

      assert {:ok, :chain_valid} = CarbonLedger.verify_chain(farm.id)
    end

    test "tampered middle row is detected: verify_chain returns {:error, :chain_broken}",
         %{farm: farm} do
      entries =
        for i <- 1..3 do
          {:ok, entry} =
            CarbonLedger.append(farm.id, %{
              record_type: "carbon_sequestration",
              record_id: i,
              content_hash: CarbonLedger.content_hash(%{carbon_tco2e: i * 1.0})
            })

          entry
        end

      # Tamper the middle entry's chain_hash directly via Ecto (bypassing ledger).
      middle_entry = Enum.at(entries, 1)

      Repo.update_all(
        from(e in CarbonLedgerEntry, where: e.id == ^middle_entry.id),
        set: [chain_hash: "tampered_hash_value"]
      )

      # The chain should now be broken at the middle entry.
      assert {:error, :chain_broken, broken_entry} = CarbonLedger.verify_chain(farm.id)
      assert broken_entry.id == middle_entry.id
    end

    test "first entry uses 'genesis' as previous_hash", %{farm: farm} do
      {:ok, entry} =
        CarbonLedger.append(farm.id, %{
          record_type: "carbon_sequestration",
          record_id: 99,
          content_hash: CarbonLedger.content_hash(%{carbon_tco2e: 3.0})
        })

      assert entry.previous_hash == "genesis"
    end

    test "subsequent entry uses previous entry's chain_hash as previous_hash", %{farm: farm} do
      {:ok, first} =
        CarbonLedger.append(farm.id, %{
          record_type: "carbon_sequestration",
          record_id: 1,
          content_hash: CarbonLedger.content_hash(%{carbon_tco2e: 1.0})
        })

      {:ok, second} =
        CarbonLedger.append(farm.id, %{
          record_type: "carbon_sequestration",
          record_id: 2,
          content_hash: CarbonLedger.content_hash(%{carbon_tco2e: 2.0})
        })

      assert second.previous_hash == first.chain_hash
    end
  end
end
