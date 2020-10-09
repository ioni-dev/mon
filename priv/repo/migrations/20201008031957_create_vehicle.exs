defmodule Mon.Repo.Migrations.CreateVehicle do
  use Ecto.Migration

  def change do
    execute("CREATE TYPE vehicle_type AS ENUM ('Motorcycle', 'Sport utility truck', 'Pickup truck', 'Panel van truck', 'Tow truck', 'Box truck',
    'Van', 'Cutaway van', 'Semi-trailer truck')")

    execute("CREATE TYPE bodywork AS ENUM ('Container', 'Closed', 'Open', 'Refrigerated', 'Sliding Canvas', 'Tippers',
    'Livestock transport', 'Cutaway van', 'Flatbed truck', 'Stake bed truck')")

    execute("CREATE TYPE payload_type AS ENUM ('Pharmaceutical and/or Surgical', 'Dangerous substances or Dangerous waste', 'Food products', 'General')")

    execute("CREATE TYPE operation_type AS ENUM ('Local', 'First mile', 'Last mile', 'Metropolitan', 'National')")

    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    create table(:vehicles, primary_key: false) do
      add :uuid, :uuid, primary_key: true
      add :type, :vehicle_type, null: false
      add :body_frame, :bodywork, null: false
      add :plate, :string, null: false
      add :payload_type, :payload_type, null: false
      add :operation_type, :operation_type, null: false
      add :certificate_of_title, {:array, :map}, null: false
      add :insurance, :string, null: false
      add :inspection_sticker, :string , null: false
      add :photos, {:array, :map}, null: false
      add :trailer_plate, :string, null: false
      add :trailer_photo, :string, null: true
      add :trailer_certificate_of_title, {:array, :map}, null: true
      add :owner_email, :citext, null: false
      add :owner_address, :string, null: false
      add :owner_id_number, :string, null: true
      add :owner_phone, :string, null: false
      add :owner_taxpayer_id, :map, null: true
      add :owner_identification, {:array, :map}, null: true
      timestamps(type: :utc_datetime)
    end
  end
end
