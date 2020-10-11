defmodule Mon.Repo.Migrations.CreateClientsAuthTables do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    create table(:clients, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :citext, unique: true, null: false
      add :hashed_password, :string, null: false
      add :confirmed_at, :naive_datetime
      add :name, :string, null: false
      add :first_name, :string, null: false
      add :last_name, :string, null: false
      add :cellphone, :string, null: false
      add :birthday, :date, null: false
      add :city, :string, null: false
      add :country, :string, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:clients, [:email])

    create table(:clients_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :client_id, references(:clients, type: :binary_id, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:clients_tokens, [:client_id])
    create unique_index(:clients_tokens, [:context, :token])
  end
end
