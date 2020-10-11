defmodule MonWeb.Vehicle_typeController do
  use MonWeb, :controller

  alias Mon.Transportation
  alias Mon.Transportation.Vehicle_type

  action_fallback MonWeb.FallbackController

  def index(conn, _params) do
    vehicle_types = Transportation.list_vehicle_types()
    render(conn, "index.json", vehicle_types: vehicle_types)
  end

  def create(conn, %{"vehicle_type" => vehicle_type_params}) do
    with {:ok, %Vehicle_type{} = vehicle_type} <- Transportation.create_vehicle_type(vehicle_type_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.vehicle_type_path(conn, :show, vehicle_type))
      |> render("show.json", vehicle_type: vehicle_type)
    end
  end

  def show(conn, %{"id" => id}) do
    vehicle_type = Transportation.get_vehicle_type!(id)
    render(conn, "show.json", vehicle_type: vehicle_type)
  end

  def update(conn, %{"id" => id, "vehicle_type" => vehicle_type_params}) do
    vehicle_type = Transportation.get_vehicle_type!(id)

    with {:ok, %Vehicle_type{} = vehicle_type} <- Transportation.update_vehicle_type(vehicle_type, vehicle_type_params) do
      render(conn, "show.json", vehicle_type: vehicle_type)
    end
  end

  def delete(conn, %{"id" => id}) do
    vehicle_type = Transportation.get_vehicle_type!(id)

    with {:ok, %Vehicle_type{}} <- Transportation.delete_vehicle_type(vehicle_type) do
      send_resp(conn, :no_content, "")
    end
  end
end
