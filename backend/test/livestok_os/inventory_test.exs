defmodule LivestokOs.InventoryTest do
  use LivestokOs.DataCase

  alias LivestokOs.Inventory

  describe "farms" do
    alias LivestokOs.Inventory.Farm

    import LivestokOs.InventoryFixtures

    @invalid_attrs %{name: nil, type: nil, location: nil}

    test "list_farms/0 returns all farms" do
      farm = farm_fixture()
      assert Inventory.list_farms() == [farm]
    end

    test "get_farm!/1 returns the farm with given id" do
      farm = farm_fixture()
      assert Inventory.get_farm!(farm.id) == farm
    end

    test "create_farm/1 with valid data creates a farm" do
      valid_attrs = %{name: "some name", type: "pasture_grazing", location: "some location"}

      assert {:ok, %Farm{} = farm} = Inventory.create_farm(valid_attrs)
      assert farm.name == "some name"
      assert farm.type == "pasture_grazing"
      assert farm.location == "some location"
    end

    test "create_farm/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Inventory.create_farm(@invalid_attrs)
    end

    test "update_farm/2 with valid data updates the farm" do
      farm = farm_fixture()

      update_attrs = %{
        name: "some updated name",
        type: "zero_grazing",
        location: "some updated location"
      }

      assert {:ok, %Farm{} = farm} = Inventory.update_farm(farm, update_attrs)
      assert farm.name == "some updated name"
      assert farm.type == "zero_grazing"
      assert farm.location == "some updated location"
    end

    test "update_farm/2 with invalid data returns error changeset" do
      farm = farm_fixture()
      assert {:error, %Ecto.Changeset{}} = Inventory.update_farm(farm, @invalid_attrs)
      assert farm == Inventory.get_farm!(farm.id)
    end

    test "delete_farm/1 deletes the farm" do
      farm = farm_fixture()
      assert {:ok, %Farm{}} = Inventory.delete_farm(farm)
      assert_raise Ecto.NoResultsError, fn -> Inventory.get_farm!(farm.id) end
    end

    test "change_farm/1 returns a farm changeset" do
      farm = farm_fixture()
      assert %Ecto.Changeset{} = Inventory.change_farm(farm)
    end
  end

  describe "cows" do
    alias LivestokOs.Inventory.Cow

    import LivestokOs.InventoryFixtures

    @invalid_attrs %{name: nil, status: nil, tag_id: nil, breed: nil, birth_date: nil}

    test "list_cows/0 returns all cows" do
      cow = cow_fixture()
      assert Inventory.list_cows() == [cow]
    end

    test "get_cow!/1 returns the cow with given id" do
      cow = cow_fixture()
      assert Inventory.get_cow!(cow.id) == cow
    end

    test "create_cow/1 with valid data creates a cow" do
      valid_attrs = %{
        name: "some name",
        status: "some status",
        tag_id: "some tag_id",
        breed: "some breed",
        birth_date: ~D[2026-01-26]
      }

      assert {:ok, %Cow{} = cow} = Inventory.create_cow(valid_attrs)
      assert cow.name == "some name"
      assert cow.status == "some status"
      assert cow.tag_id == "some tag_id"
      assert cow.breed == "some breed"
      assert cow.birth_date == ~D[2026-01-26]
    end

    test "create_cow/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Inventory.create_cow(@invalid_attrs)
    end

    test "update_cow/2 with valid data updates the cow" do
      cow = cow_fixture()

      update_attrs = %{
        name: "some updated name",
        status: "some updated status",
        tag_id: "some updated tag_id",
        breed: "some updated breed",
        birth_date: ~D[2026-01-27]
      }

      assert {:ok, %Cow{} = cow} = Inventory.update_cow(cow, update_attrs)
      assert cow.name == "some updated name"
      assert cow.status == "some updated status"
      assert cow.tag_id == "some updated tag_id"
      assert cow.breed == "some updated breed"
      assert cow.birth_date == ~D[2026-01-27]
    end

    test "update_cow/2 with invalid data returns error changeset" do
      cow = cow_fixture()
      assert {:error, %Ecto.Changeset{}} = Inventory.update_cow(cow, @invalid_attrs)
      assert cow == Inventory.get_cow!(cow.id)
    end

    test "delete_cow/1 deletes the cow" do
      cow = cow_fixture()
      assert {:ok, %Cow{}} = Inventory.delete_cow(cow)
      assert_raise Ecto.NoResultsError, fn -> Inventory.get_cow!(cow.id) end
    end

    test "change_cow/1 returns a cow changeset" do
      cow = cow_fixture()
      assert %Ecto.Changeset{} = Inventory.change_cow(cow)
    end
  end
end
