defmodule LivestokOs.Inventory do
  @moduledoc """
  The Inventory context.
  """

  import Ecto.Query, warn: false
  import LivestokOs.Pagination
  alias LivestokOs.Repo

  alias LivestokOs.Inventory.Farm

  @doc """
  Returns the list of farms.

  ## Examples

      iex> list_farms()
      [%Farm{}, ...]

  """
  def list_farms(opts \\ %{}) do
    Farm
    |> paginate(opts)
    |> Repo.all()
  end

  @doc """
  Gets a single farm.

  Raises `Ecto.NoResultsError` if the Farm does not exist.

  ## Examples

      iex> get_farm!(123)
      %Farm{}

      iex> get_farm!(456)
      ** (Ecto.NoResultsError)

  """
  def get_farm!(id), do: Repo.get!(Farm, id)

  @doc """
  Creates a farm.

  ## Examples

      iex> create_farm(%{field: value})
      {:ok, %Farm{}}

      iex> create_farm(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_farm(attrs) do
    %Farm{}
    |> Farm.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a farm.

  ## Examples

      iex> update_farm(farm, %{field: new_value})
      {:ok, %Farm{}}

      iex> update_farm(farm, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_farm(%Farm{} = farm, attrs) do
    farm
    |> Farm.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a farm.

  ## Examples

      iex> delete_farm(farm)
      {:ok, %Farm{}}

      iex> delete_farm(farm)
      {:error, %Ecto.Changeset{}}

  """
  def delete_farm(%Farm{} = farm) do
    Repo.delete(farm)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking farm changes.

  ## Examples

      iex> change_farm(farm)
      %Ecto.Changeset{data: %Farm{}}

  """
  def change_farm(%Farm{} = farm, attrs \\ %{}) do
    Farm.changeset(farm, attrs)
  end

  alias LivestokOs.Inventory.Cow

  @doc """
  Returns the list of cows.

  ## Examples

      iex> list_cows()
      [%Cow{}, ...]

  """
  def list_cows(opts \\ %{}) do
    Cow
    |> paginate(opts)
    |> Repo.all()
  end

  @doc """
  Gets a single cow.

  Raises `Ecto.NoResultsError` if the Cow does not exist.

  ## Examples

      iex> get_cow!(123)
      %Cow{}

      iex> get_cow!(456)
      ** (Ecto.NoResultsError)

  """
  def get_cow!(id), do: Repo.get!(Cow, id)

  def get_cow_by_tag(tag) when is_binary(tag) do
    Repo.get_by(Cow, tag_id: tag)
  end

  @doc """
  Creates a cow.

  ## Examples

      iex> create_cow(%{field: value})
      {:ok, %Cow{}}

      iex> create_cow(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_cow(attrs) do
    %Cow{}
    |> Cow.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a cow.

  ## Examples

      iex> update_cow(cow, %{field: new_value})
      {:ok, %Cow{}}

      iex> update_cow(cow, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_cow(%Cow{} = cow, attrs) do
    cow
    |> Cow.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a cow.

  ## Examples

      iex> delete_cow(cow)
      {:ok, %Cow{}}

      iex> delete_cow(cow)
      {:error, %Ecto.Changeset{}}

  """
  def delete_cow(%Cow{} = cow) do
    Repo.delete(cow)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking cow changes.

  ## Examples

      iex> change_cow(cow)
      %Ecto.Changeset{data: %Cow{}}

  """
  def change_cow(%Cow{} = cow, attrs \\ %{}) do
    Cow.changeset(cow, attrs)
  end
end
