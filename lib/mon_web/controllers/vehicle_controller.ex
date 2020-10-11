defmodule MonWeb.VehicleController do
  use MonWeb, :controller

  alias Mon.Transportation
  alias Mon.Transportation.Vehicle

  action_fallback MonWeb.FallbackController

  def index(conn, _params) do
    vehicles = Transportation.list_vehicles()
    render(conn, "index.json", vehicles: vehicles)
  end

  def create(conn, %{"vehicle" => vehicle_params}) do
    with {:ok, %Vehicle{} = vehicle} <- Transportation.create_vehicle(vehicle_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.vehicle_path(conn, :show, vehicle))
      |> render("show.json", vehicle: vehicle)
    end
  end

  def show(conn, %{"id" => id}) do
    vehicle = Transportation.get_vehicle!(id)
    render(conn, "show.json", vehicle: vehicle)
  end

  def update(conn, %{"id" => id, "vehicle" => vehicle_params}) do
    vehicle = Transportation.get_vehicle!(id)

    with {:ok, %Vehicle{} = vehicle} <- Transportation.update_vehicle(vehicle, vehicle_params) do
      render(conn, "show.json", vehicle: vehicle)
    end
  end

  def delete(conn, %{"id" => id}) do
    vehicle = Transportation.get_vehicle!(id)

    with {:ok, %Vehicle{}} <- Transportation.delete_vehicle(vehicle) do
      send_resp(conn, :no_content, "")
    end
  end
end
