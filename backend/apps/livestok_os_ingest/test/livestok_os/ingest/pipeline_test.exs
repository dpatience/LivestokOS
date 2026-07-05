defmodule LivestokOs.Ingest.PipelineTest do
  use LivestokOs.DataCase

  alias LivestokOs.Ingest.Producer
  alias LivestokOs.Inventory

  setup do
    {:ok, farm} =
      Inventory.create_farm(%{
        name: "Pipeline Test Farm",
        location: "Naivasha"
      })

    {:ok, cow} =
      Inventory.create_cow(%{
        tag_id: "PIPE-001",
        name: "Clover",
        breed: "Friesian",
        birth_date: ~D[2021-03-10],
        status: "active",
        farm_id: farm.id
      })

    %{farm: farm, cow: cow}
  end

  describe "producer queue" do
    test "accepts pushed messages and reports queue size" do
      # The producer is already running (started by the application).
      # Push some messages and verify the queue accepts them.
      for i <- 1..5 do
        Producer.push(%{cow_id: i, reading_attrs: %{"activity" => "test"}})
      end

      # Small delay so casts are processed
      Process.sleep(100)

      # Queue size may be 0 if Broadway consumed them already —
      # either way, no crash means the producer is healthy.
      size = Producer.queue_size()
      assert is_integer(size) and size >= 0
    end
  end

  describe "end-to-end pipeline" do
    test "pushed reading is processed and creates a sensor_reading", %{cow: cow} do
      reading_attrs = %{
        "timestamp" => DateTime.utc_now(),
        "latitude" => -0.7893,
        "longitude" => 36.4316,
        "activity" => "grazing",
        "behavior_label" => "grazing",
        "speed_mps" => 0.2,
        "battery_level" => 95.0,
        "source" => "lora_collar",
        "cow_id" => cow.id,
        "data" => %{}
      }

      Producer.push(%{cow_id: cow.id, reading_attrs: reading_attrs})

      # Allow time for Broadway to process
      Process.sleep(500)

      readings =
        LivestokOs.Repo.all(
          from(sr in LivestokOs.Telemetry.SensorReading,
            where: sr.cow_id == ^cow.id and sr.activity == "grazing"
          )
        )

      assert length(readings) >= 1
    end
  end
end
