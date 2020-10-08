defmodule Mon.Repo.Migrations.CreateVehicle do
  use Ecto.Migration

  def change do
    execute("CREATE TYPE vehicle_type AS ENUM ('Motorcycle', 'Sport utility truck', 'Pickup truck', 'Panel van truck', 'Tow truck', 'Box truck',
    'Van', 'Cutaway van', 'Semi-trailer truck')")

    execute("CREATE TYPE bodywork AS ENUM ('Container', 'Closed', 'Open', 'Refrigerated', 'Sliding Canvas', 'Tippers',
    'Livestock transport', 'Cutaway van', 'Flatbed truck', 'Stake bed truck')")

    execute("CREATE TYPE payload_type AS ENUM ('Pharmaceutical and/or Surgical', 'Dangerous substances or Dangerous waste', 'Food products', 'General')")

    execute("CREATE TYPE operation_type AS ENUM ('Local', 'First mile', 'Last mile', 'Metropolitan', 'National')")

    create table(:vehicles, primary_key: false) do
      add :uuid, :uuid, primary_key: true
      add :type, :vehicle_type, null: false
      add :body_frame, :bodywork, null: false
      add :plate, :string, null: false
      add :payload_type, :payload_type, null: false
      add :operation_type, :operation_type, null: false
      # Todo: add to user(employee) certifications | satellital certification | tarjeta de propiedad del vehiculo |
      add :address, :string, null: false
      add :contact_info, :map, null: false
      timestamps(type: :utc_datetime)
    end
  end
end
