defmodule Mon.Repo.Migrations.CreateUsersAuthTables do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    create table(:users, primary_key: false) do
      add :uuid, :uuid, primary_key: true
      add :name, :string, size: 40, null: false
      add :email, :citext, null: false
      add :hashed_password, :string, null: false
      add :confirmed_at, :naive_datetime
      add :email_verified, :boolean, null: false, default: false
      add :active, :boolean, null: false, default: true
      add :last_logged_in, :utc_datetime, [null: false, default: fragment("current_date")]
      add :pic, :string
      add :company_uuid, :uuid
      # add :company_uuid, references(:companies, type: :uuid, column: :uuid, on_delete: :delete_all), null: false
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
    create unique_index(:users, [:email, :company_uuid])

  end
end
