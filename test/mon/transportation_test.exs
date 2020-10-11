defmodule Mon.TransportationTest do
  use Mon.DataCase

  alias Mon.Transportation

  describe "vehicles" do
    alias Mon.Transportation.Vehicle

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def vehicle_fixture(attrs \\ %{}) do
      {:ok, vehicle} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Transportation.create_vehicle()

      vehicle
    end

    test "list_vehicles/0 returns all vehicles" do
      vehicle = vehicle_fixture()
      assert Transportation.list_vehicles() == [vehicle]
    end

    test "get_vehicle!/1 returns the vehicle with given id" do
      vehicle = vehicle_fixture()
      assert Transportation.get_vehicle!(vehicle.id) == vehicle
    end

    test "create_vehicle/1 with valid data creates a vehicle" do
      assert {:ok, %Vehicle{} = vehicle} = Transportation.create_vehicle(@valid_attrs)
    end

    test "create_vehicle/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Transportation.create_vehicle(@invalid_attrs)
    end

    test "update_vehicle/2 with valid data updates the vehicle" do
      vehicle = vehicle_fixture()
      assert {:ok, %Vehicle{} = vehicle} = Transportation.update_vehicle(vehicle, @update_attrs)
    end

    test "update_vehicle/2 with invalid data returns error changeset" do
      vehicle = vehicle_fixture()
      assert {:error, %Ecto.Changeset{}} = Transportation.update_vehicle(vehicle, @invalid_attrs)
      assert vehicle == Transportation.get_vehicle!(vehicle.id)
    end

    test "delete_vehicle/1 deletes the vehicle" do
      vehicle = vehicle_fixture()
      assert {:ok, %Vehicle{}} = Transportation.delete_vehicle(vehicle)
      assert_raise Ecto.NoResultsError, fn -> Transportation.get_vehicle!(vehicle.id) end
    end

    test "change_vehicle/1 returns a vehicle changeset" do
      vehicle = vehicle_fixture()
      assert %Ecto.Changeset{} = Transportation.change_vehicle(vehicle)
    end
  end

  describe "vehicle_types" do
    alias Mon.Transportation.Vehicle_type

    @valid_attrs %{}
    @update_attrs %{}
    @invalid_attrs %{}

    def vehicle_type_fixture(attrs \\ %{}) do
      {:ok, vehicle_type} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Transportation.create_vehicle_type()

      vehicle_type
    end

    test "list_vehicle_types/0 returns all vehicle_types" do
      vehicle_type = vehicle_type_fixture()
      assert Transportation.list_vehicle_types() == [vehicle_type]
    end

    test "get_vehicle_type!/1 returns the vehicle_type with given id" do
      vehicle_type = vehicle_type_fixture()
      assert Transportation.get_vehicle_type!(vehicle_type.id) == vehicle_type
    end

    test "create_vehicle_type/1 with valid data creates a vehicle_type" do
      assert {:ok, %Vehicle_type{} = vehicle_type} = Transportation.create_vehicle_type(@valid_attrs)
    end

    test "create_vehicle_type/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Transportation.create_vehicle_type(@invalid_attrs)
    end

    test "update_vehicle_type/2 with valid data updates the vehicle_type" do
      vehicle_type = vehicle_type_fixture()
      assert {:ok, %Vehicle_type{} = vehicle_type} = Transportation.update_vehicle_type(vehicle_type, @update_attrs)
    end

    test "update_vehicle_type/2 with invalid data returns error changeset" do
      vehicle_type = vehicle_type_fixture()
      assert {:error, %Ecto.Changeset{}} = Transportation.update_vehicle_type(vehicle_type, @invalid_attrs)
      assert vehicle_type == Transportation.get_vehicle_type!(vehicle_type.id)
    end

    test "delete_vehicle_type/1 deletes the vehicle_type" do
      vehicle_type = vehicle_type_fixture()
      assert {:ok, %Vehicle_type{}} = Transportation.delete_vehicle_type(vehicle_type)
      assert_raise Ecto.NoResultsError, fn -> Transportation.get_vehicle_type!(vehicle_type.id) end
    end

    test "change_vehicle_type/1 returns a vehicle_type changeset" do
      vehicle_type = vehicle_type_fixture()
      assert %Ecto.Changeset{} = Transportation.change_vehicle_type(vehicle_type)
    end
  end
end
