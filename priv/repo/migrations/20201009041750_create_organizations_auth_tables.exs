defmodule Mon.Repo.Migrations.CreateOrganizationsAuthTables do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""
    execute("CREATE TYPE countries AS ENUM ('Uruguay')")

    create table(:organizations, primary_key: false) do
      add :uuid, :uuid, primary_key: true
      add :email, :citext, null: false
      add :hashed_password, :string, null: false
      add :confirmed_at, :naive_datetime
      add :name, :string, null: false
      add :taxpayer_id, :string, null: false
      add :country, :countries, null: false, default: "Uruguay"
      add :cellphone, :string, null: false
      add :montly_deliveries, :integer, null: false
      add :website, :string, null: false
      timestamps()
    end

    create unique_index(:organizations, [:email])

    create table(:organizations_tokens, primary_key: false) do
      add :uuid, :uuid, primary_key: true
      add :organization_uuid, references(:organizations, type: :uuid, column: :uuid, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      timestamps(updated_at: false)
    end

    create index(:organizations_tokens, [:organization_uuid])
    create unique_index(:organizations_tokens, [:context, :token])

    alter table(:users) do
      modify :organization_uuid, references(:organizations, type: :uuid, column: :uuid, on_delete: :delete_all), null: false
    end

    alter table(:vehicle_types) do
      add :vehicle_uuid, references(:vehicles, type: :uuid, column: :uuid, on_delete: :delete_all), null: false
    end

    alter table(:vehicles) do
      add :organization_uuid, references(:organizations, type: :uuid, column: :uuid, on_delete: :delete_all), null: false
      add :user_uuid, references(:users, type: :uuid, column: :uuid, on_delete: :delete_all), null: false
      
    end

  
  end
end
