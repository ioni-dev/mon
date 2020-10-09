defmodule Mon.Repo.Migrations.CreateClientsAuthTables do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    create table(:clients, primary_key: false) do
      add :uuid, :uuid, primary_key: true
      add :email, :citext, null: false
      add :name, :string, null: false
      add :first_name, :string, null: false
      add :last_name, :string, null: false
      add :cellphone, :string, null: false
      add :birthday, :date, null: false
      add :city, :string, null: false
      add :country, :string, null: false
      add :hashed_password, :string, null: false
      add :confirmed_at, :naive_datetime
      timestamps()
    end

    create unique_index(:clients, [:email])

    create table(:clients_tokens, primary_key: false) do
      add :uuid, :uuid, primary_key: true
      add :client_uuid, references(:clients, type: :uuid, column: :uuid, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      timestamps(updated_at: false)
    end

    create index(:clients_tokens, [:client_uuid])
    create unique_index(:clients_tokens, [:context, :token])
  end
end
