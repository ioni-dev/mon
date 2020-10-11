defmodule Mon.Transportation do
  @moduledoc """
  The Transportation context.
  """

  import Ecto.Query, warn: false
  alias Mon.Repo

  alias Mon.Transportation.Vehicle

  @doc """
  Returns the list of vehicles.

  ## Examples

      iex> list_vehicles()
      [%Vehicle{}, ...]

  """
  def list_vehicles do
    Repo.all(Vehicle)
  end

  @doc """
  Gets a single vehicle.

  Raises `Ecto.NoResultsError` if the Vehicle does not exist.

  ## Examples

      iex> get_vehicle!(123)
      %Vehicle{}

      iex> get_vehicle!(456)
      ** (Ecto.NoResultsError)

  """
  def get_vehicle!(id), do: Repo.get!(Vehicle, id)

  @doc """
  Creates a vehicle.

  ## Examples

      iex> create_vehicle(%{field: value})
      {:ok, %Vehicle{}}

      iex> create_vehicle(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_vehicle(attrs \\ %{}) do
    %Vehicle{}
    |> Vehicle.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a vehicle.

  ## Examples

      iex> update_vehicle(vehicle, %{field: new_value})
      {:ok, %Vehicle{}}

      iex> update_vehicle(vehicle, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_vehicle(%Vehicle{} = vehicle, attrs) do
    vehicle
    |> Vehicle.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a vehicle.

  ## Examples

      iex> delete_vehicle(vehicle)
      {:ok, %Vehicle{}}

      iex> delete_vehicle(vehicle)
      {:error, %Ecto.Changeset{}}

  """
  def delete_vehicle(%Vehicle{} = vehicle) do
    Repo.delete(vehicle)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking vehicle changes.

  ## Examples

      iex> change_vehicle(vehicle)
      %Ecto.Changeset{data: %Vehicle{}}

  """
  def change_vehicle(%Vehicle{} = vehicle, attrs \\ %{}) do
    Vehicle.changeset(vehicle, attrs)
  end

  alias Mon.Transportation.Vehicle_type

  @doc """
  Returns the list of vehicle_types.

  ## Examples

      iex> list_vehicle_types()
      [%Vehicle_type{}, ...]

  """
  def list_vehicle_types do
    Repo.all(Vehicle_type)
  end

  @doc """
  Gets a single vehicle_type.

  Raises `Ecto.NoResultsError` if the Vehicle type does not exist.

  ## Examples

      iex> get_vehicle_type!(123)
      %Vehicle_type{}

      iex> get_vehicle_type!(456)
      ** (Ecto.NoResultsError)

  """
  def get_vehicle_type!(id), do: Repo.get!(Vehicle_type, id)

  @doc """
  Creates a vehicle_type.

  ## Examples

      iex> create_vehicle_type(%{field: value})
      {:ok, %Vehicle_type{}}

      iex> create_vehicle_type(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_vehicle_type(attrs \\ %{}) do
    %Vehicle_type{}
    |> Vehicle_type.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a vehicle_type.

  ## Examples

      iex> update_vehicle_type(vehicle_type, %{field: new_value})
      {:ok, %Vehicle_type{}}

      iex> update_vehicle_type(vehicle_type, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_vehicle_type(%Vehicle_type{} = vehicle_type, attrs) do
    vehicle_type
    |> Vehicle_type.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a vehicle_type.

  ## Examples

      iex> delete_vehicle_type(vehicle_type)
      {:ok, %Vehicle_type{}}

      iex> delete_vehicle_type(vehicle_type)
      {:error, %Ecto.Changeset{}}

  """
  def delete_vehicle_type(%Vehicle_type{} = vehicle_type) do
    Repo.delete(vehicle_type)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking vehicle_type changes.

  ## Examples

      iex> change_vehicle_type(vehicle_type)
      %Ecto.Changeset{data: %Vehicle_type{}}

  """
  def change_vehicle_type(%Vehicle_type{} = vehicle_type, attrs \\ %{}) do
    Vehicle_type.changeset(vehicle_type, attrs)
  end
end
