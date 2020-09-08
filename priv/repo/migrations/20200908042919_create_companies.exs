defmodule Mon.Repo.Migrations.CreateCompanies do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""
    
    create table(:companies, primary_key: false) do
      add :uuid, :uuid, primary_key: true
      add :name, :string, size: 40, null: false
      add :email, :citext, null: false
      add :active, :boolean, null: false, default: true
      add :pic, :string
      add :website, :string, null: true
      add :address, :string, null: false
      add :contact_info, :map, null: false
      add :industry_type, :string, null: false
      timestamps(type: :utc_datetime)
    end
  end
end
