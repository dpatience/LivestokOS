defmodule LivestokOs.Infrastructure.LoraGateway do
  @moduledoc """
  Schema for LoRaWAN gateway devices registered to a farm.
  Each farm has one or more gateways that receive collar data
  and forward it to the Phoenix API.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias LivestokOs.Inventory.Farm

  schema "lora_gateways" do
    field :gateway_eui, :string
    field :name, :string
    field :status, :string, default: "online"
    field :last_seen_at, :utc_datetime
    field :metadata, :map, default: %{}

    belongs_to :farm, Farm

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(gateway, attrs) do
    gateway
    |> cast(attrs, [:gateway_eui, :name, :status, :last_seen_at, :metadata, :farm_id])
    |> validate_required([:gateway_eui, :farm_id])
    |> unique_constraint(:gateway_eui)
    |> assoc_constraint(:farm)
  end
end
