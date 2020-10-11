defmodule MonWeb.Vehicle_typeControllerTest do
  use MonWeb.ConnCase

  alias Mon.Transportation
  alias Mon.Transportation.Vehicle_type

  @create_attrs %{

  }
  @update_attrs %{

  }
  @invalid_attrs %{}

  def fixture(:vehicle_type) do
    {:ok, vehicle_type} = Transportation.create_vehicle_type(@create_attrs)
    vehicle_type
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all vehicle_types", %{conn: conn} do
      conn = get(conn, Routes.vehicle_type_path(conn, :index))
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create vehicle_type" do
    test "renders vehicle_type when data is valid", %{conn: conn} do
      conn = post(conn, Routes.vehicle_type_path(conn, :create), vehicle_type: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.vehicle_type_path(conn, :show, id))

      assert %{
               "id" => id
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.vehicle_type_path(conn, :create), vehicle_type: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update vehicle_type" do
    setup [:create_vehicle_type]

    test "renders vehicle_type when data is valid", %{conn: conn, vehicle_type: %Vehicle_type{id: id} = vehicle_type} do
      conn = put(conn, Routes.vehicle_type_path(conn, :update, vehicle_type), vehicle_type: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, Routes.vehicle_type_path(conn, :show, id))

      assert %{
               "id" => id
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, vehicle_type: vehicle_type} do
      conn = put(conn, Routes.vehicle_type_path(conn, :update, vehicle_type), vehicle_type: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete vehicle_type" do
    setup [:create_vehicle_type]

    test "deletes chosen vehicle_type", %{conn: conn, vehicle_type: vehicle_type} do
      conn = delete(conn, Routes.vehicle_type_path(conn, :delete, vehicle_type))
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, Routes.vehicle_type_path(conn, :show, vehicle_type))
      end
    end
  end

  defp create_vehicle_type(_) do
    vehicle_type = fixture(:vehicle_type)
    %{vehicle_type: vehicle_type}
  end
end
