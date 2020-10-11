defmodule MonWeb.Vehicle_typeView do
  use MonWeb, :view
  alias MonWeb.Vehicle_typeView

  def render("index.json", %{vehicle_types: vehicle_types}) do
    %{data: render_many(vehicle_types, Vehicle_typeView, "vehicle_type.json")}
  end

  def render("show.json", %{vehicle_type: vehicle_type}) do
    %{data: render_one(vehicle_type, Vehicle_typeView, "vehicle_type.json")}
  end

  def render("vehicle_type.json", %{vehicle_type: vehicle_type}) do
    %{id: vehicle_type.id}
  end
end
