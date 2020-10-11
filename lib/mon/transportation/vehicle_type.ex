defmodule Mon.Transportation.Vehicle_type do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "vehicle_types" do

    timestamps()
  end

  @doc false
  def changeset(vehicle_type, attrs) do
    vehicle_type
    |> cast(attrs, [])
    |> validate_required([])
  end
end
