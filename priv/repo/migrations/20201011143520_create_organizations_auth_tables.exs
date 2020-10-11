defmodule Mon.Repo.Migrations.CreateOrganizationsAuthTables do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""
    execute("CREATE TYPE countries AS ENUM ('Uruguay')")

    create table(:organizations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :citext, unique: true, null: false
      add :hashed_password, :string, null: false
      add :confirmed_at, :naive_datetime
      add :name, :string, null: false
      add :taxpayer_identity, :string, null: false
      add :country, :countries, null: false, default: "Uruguay"
      add :cellphone, :string, null: false
      add :montly_deliveries, :integer, null: false
      add :website, :string, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:organizations, [:email])

    create table(:organizations_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:organizations_tokens, [:organization_id])
    create unique_index(:organizations_tokens, [:context, :token])

    alter table(:drivers) do
      add :organization_id, references(:organizations, type: :binary_id, column: :id, on_delete: :delete_all), null: false
    end

    alter table(:vehicle_types) do
      add :vehicle_id, references(:vehicles, type: :binary_id, column: :id, on_delete: :delete_all), null: false
    end

    alter table(:vehicles) do
      add :organization_id, references(:organizations, type: :binary_id, column: :id, on_delete: :delete_all), null: false
      add :driver_id, references(:drivers, type: :binary_id, column: :id, on_delete: :delete_all), null: false
      
    end

  end
end
