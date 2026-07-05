defmodule LivestokOs.User do
  use Ecto.Schema
  import Ecto.Changeset

  alias LivestokOs.Inventory.Farm

  schema "users" do
    field :email, :string
    field :name, :string
    field :password_hash, :string
    field :role, :string
    field :password, :string, virtual: true

    belongs_to :farm, Farm

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :password, :role])
    |> validate_required([:email, :name, :password, :role])
    |> validate_inclusion(:role, ~w(super_admin farm_owner farm_worker))
    |> unique_constraint(:email)
    |> validate_format(:email, ~r/@/)
    |> validate_length(:password, min: 6)
    |> hash_password()
  end

  def admin?(user), do: user.role == "super_admin"
  def farm_scoped?(user), do: user.role in ~w(farm_owner farm_worker)

  defp hash_password(changeset) do
    case get_change(changeset, :password) do
      nil ->
        changeset

      password ->
        put_change(changeset, :password_hash, LivestokOs.Password.hash(password))
    end
  end
end
