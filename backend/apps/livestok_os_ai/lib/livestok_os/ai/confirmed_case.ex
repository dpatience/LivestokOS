defmodule LivestokOs.AI.ConfirmedCase do
  @moduledoc """
  Schema for vet-confirmed case memory entries.

  `confirmed_at` being `nil` means the case is unconfirmed (stored from an
  LLM response but not yet validated by a vet). Only confirmed cases
  (where `confirmed_at IS NOT NULL`) are returned by similarity searches.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "confirmed_cases" do
    field :farm_id, :id
    field :cow_id, :id
    field :situation_embedding, Pgvector.Ecto.Vector
    field :situation_summary, :string
    field :case_history_snapshot, :map, default: %{}
    field :assistant_answer, :string
    field :confirmed_by_user_id, :integer
    field :confirmed_at, :utc_datetime
    field :similarity_threshold, :float, default: 0.92

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(record, attrs) do
    record
    |> cast(attrs, [
      :farm_id,
      :cow_id,
      :situation_embedding,
      :situation_summary,
      :case_history_snapshot,
      :assistant_answer,
      :confirmed_by_user_id,
      :confirmed_at,
      :similarity_threshold
    ])
    |> validate_required([:farm_id, :cow_id, :situation_summary])
  end
end
