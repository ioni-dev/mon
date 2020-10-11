defmodule Mon.Repo.Migrations.CreateVehicleTypes do
  use Ecto.Migration

  def change do
    execute("CREATE TYPE us_truck_class AS ENUM ('Class 1', 'Class 2a', 'Class 2b' , 'Class 3', 'Class 4',
    'Class 5', 'Class 6', 'Class 7', 'Class 8')")

    execute("CREATE TYPE duty_classification AS ENUM ('Light truck', 'Light/Medium truck', 'Medium truck', 'Heavy truck' )")

    execute("CREATE TYPE weight_range AS ENUM ('0–6,000 pounds', '6,001–8,500 pounds', '8,501–10,000 pounds', '10,001–14,000 pounds',
    '14,001–16,000 pounds', '16,001–19,500 pounds', '19,501–26,000 pounds', '26,001–33,000 pounds', '33,001+ pounds')")

    create table(:vehicle_types, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :us_gvwr_class, :us_truck_class, null: false
      add :duty_classification, :duty_classification, null: false
      add :weight_limit, :weight_range, null: false
      timestamps(type: :utc_datetime)
    end

  end
end
