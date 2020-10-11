defmodule Mon.Repo.Migrations.CreateDriversAuthTables do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""
    execute("CREATE TYPE references_type AS ENUM ('Facebook', 'Referred', 'Instagram')")

    create table(:drivers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :citext, unique: true, null: false
      add :hashed_password, :string, null: false
      add :confirmed_at, :naive_datetime
      add :name, :string, size: 40, null: false
      add :first_name, :string, size: 40, null: false
      add :last_name, :string, size: 40, null: false
      add :cellphone, :string, null: false
      add :address, :string, null: false
      add :city, :string, null: false
      add :country, :string, null: false
      add :profile_pic, :string, null: false
      add :id_photos, :map, null: false
      add :driver_license, :map, null: false
      add :date_of_birth, :date, null: false
      add :years_of_experience, :integer, null: false
      add :ways_of_reference, :references_type , null: true
      add :active, :boolean, null: false, default: true
      add :last_logged_in, :utc_datetime, [null: false, default: fragment("current_date")]
      add :certifications, {:array, :map}, null: false
      add :emergency_contact, :map, null: false
      add :work_reference, {:array, :map}, null: false
      add :referred_contact, {:array, :map}, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:drivers, [:email])

    create table(:drivers_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :driver_id, references(:drivers, type: :binary_id, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:drivers_tokens, [:driver_id])
    create unique_index(:drivers_tokens, [:context, :token])
  end
end
