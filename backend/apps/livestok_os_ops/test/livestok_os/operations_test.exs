defmodule LivestokOs.OperationsTest do
  use LivestokOs.DataCase

  alias LivestokOs.Operations

  describe "grazing_events" do
    alias LivestokOs.Operations.GrazingEvent

    import LivestokOs.OperationsFixtures
    import LivestokOs.InventoryFixtures

    @invalid_attrs %{zone_id: nil, entered_at: nil, left_at: nil}

    test "list_grazing_events/0 returns all grazing_events" do
      grazing_event = grazing_event_fixture()
      assert Operations.list_grazing_events() == [grazing_event]
    end

    test "get_grazing_event!/1 returns the grazing_event with given id" do
      grazing_event = grazing_event_fixture()
      assert Operations.get_grazing_event!(grazing_event.id) == grazing_event
    end

    test "create_grazing_event/1 with valid data creates a grazing_event" do
      cow = cow_fixture()

      valid_attrs = %{
        zone_id: "some zone_id",
        entered_at: ~U[2026-01-26 11:09:00Z],
        left_at: ~U[2026-01-26 11:09:00Z],
        cow_id: cow.id
      }

      assert {:ok, %GrazingEvent{} = grazing_event} = Operations.create_grazing_event(valid_attrs)
      assert grazing_event.zone_id == "some zone_id"
      assert grazing_event.entered_at == ~U[2026-01-26 11:09:00Z]
      assert grazing_event.left_at == ~U[2026-01-26 11:09:00Z]
      assert grazing_event.cow_id == cow.id
    end

    test "create_grazing_event/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Operations.create_grazing_event(@invalid_attrs)
    end

    test "update_grazing_event/2 with valid data updates the grazing_event" do
      grazing_event = grazing_event_fixture()

      update_attrs = %{
        zone_id: "some updated zone_id",
        entered_at: ~U[2026-01-27 11:09:00Z],
        left_at: ~U[2026-01-27 11:09:00Z]
      }

      assert {:ok, %GrazingEvent{} = grazing_event} =
               Operations.update_grazing_event(grazing_event, update_attrs)

      assert grazing_event.zone_id == "some updated zone_id"
      assert grazing_event.entered_at == ~U[2026-01-27 11:09:00Z]
      assert grazing_event.left_at == ~U[2026-01-27 11:09:00Z]
    end

    test "update_grazing_event/2 with invalid data returns error changeset" do
      grazing_event = grazing_event_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Operations.update_grazing_event(grazing_event, @invalid_attrs)

      assert grazing_event == Operations.get_grazing_event!(grazing_event.id)
    end

    test "delete_grazing_event/1 deletes the grazing_event" do
      grazing_event = grazing_event_fixture()
      assert {:ok, %GrazingEvent{}} = Operations.delete_grazing_event(grazing_event)
      assert_raise Ecto.NoResultsError, fn -> Operations.get_grazing_event!(grazing_event.id) end
    end

    test "change_grazing_event/1 returns a grazing_event changeset" do
      grazing_event = grazing_event_fixture()
      assert %Ecto.Changeset{} = Operations.change_grazing_event(grazing_event)
    end
  end

  describe "alerts" do
    alias LivestokOs.Operations.Alert

    import LivestokOs.OperationsFixtures

    @invalid_attrs %{message: nil, type: nil, is_resolved: nil}

    test "list_alerts/0 returns all unresolved alerts" do
      alert = alert_fixture(%{is_resolved: false})
      assert Operations.list_alerts() == [alert]
    end

    test "get_alert!/1 returns the alert with given id" do
      alert = alert_fixture()
      assert Operations.get_alert!(alert.id) == alert
    end

    test "create_alert/1 with valid data creates a alert" do
      valid_attrs = %{message: "some message", type: "some type", is_resolved: true}

      assert {:ok, %Alert{} = alert} = Operations.create_alert(valid_attrs)
      assert alert.message == "some message"
      assert alert.type == "some type"
      assert alert.is_resolved == true
    end

    test "create_alert/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Operations.create_alert(@invalid_attrs)
    end

    test "update_alert/2 with valid data updates the alert" do
      alert = alert_fixture()

      update_attrs = %{
        message: "some updated message",
        type: "some updated type",
        is_resolved: false
      }

      assert {:ok, %Alert{} = alert} = Operations.update_alert(alert, update_attrs)
      assert alert.message == "some updated message"
      assert alert.type == "some updated type"
      assert alert.is_resolved == false
    end

    test "update_alert/2 with invalid data returns error changeset" do
      alert = alert_fixture()
      assert {:error, %Ecto.Changeset{}} = Operations.update_alert(alert, @invalid_attrs)
      assert alert == Operations.get_alert!(alert.id)
    end

    test "delete_alert/1 deletes the alert" do
      alert = alert_fixture()
      assert {:ok, %Alert{}} = Operations.delete_alert(alert)
      assert_raise Ecto.NoResultsError, fn -> Operations.get_alert!(alert.id) end
    end

    test "change_alert/1 returns a alert changeset" do
      alert = alert_fixture()
      assert %Ecto.Changeset{} = Operations.change_alert(alert)
    end
  end
end
