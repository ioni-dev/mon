defmodule Mon.Repo.Migrations.CreateUsersAuthTables do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""
    execute("CREATE TYPE references_type AS ENUM ('Facebook', 'Referred', 'Instagram')")
    
    create table(:users, primary_key: false) do
      add :uuid, :uuid, primary_key: true
      add :name, :string, size: 40, null: false
      add :first_name, :string, size: 40, null: false
      add :last_name, :string, size: 40, null: false
      add :email, :citext, null: false
      add :cellphone, :string, null: false
      add :address, :string, null: false
      add :city, :string, null: false
      add :country, :string, null: false
      add :profile_pic, :string, null: false
      add :id_photos, :map, null: false
      add :driver_license, :map, null: false
      add :date_of_birth, :date, null: false
      add :years_of_experience, :integer, null: false
      add :ways_of_reference, :references_type , null: false 
      add :hashed_password, :string, null: false
      add :confirmed_at, :naive_datetime
      add :email_verified, :boolean, null: false, default: false
      add :active, :boolean, null: false, default: true
      add :last_logged_in, :utc_datetime, [null: false, default: fragment("current_date")]
      add :certifications, {:array, :map}, null: false
      add :emergency_contact, :map, null: false
      add :work_reference, {:array, :map}, null: false
      add :referred_contact, {:array, :map}, null: false
      add :vehicle_uuid, :uuid, null: false
      timestamps(type: :utc_datetime)
    end

    create table(:users_tokens, primary_key: false) do
      add :uuid, :uuid, primary_key: true
      add :user_uuid, references(:users, type: :uuid, column: :uuid, on_delete: :delete_all), null: false
      add :token, :uuid, null: false
      add :context, :string, null: false
      add :sent_to, :string
      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:users_tokens, [:user_uuid])
    create unique_index(:users_tokens, [:context, :token])

  end
end
