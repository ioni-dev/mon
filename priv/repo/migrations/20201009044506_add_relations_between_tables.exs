defmodule Mon.Repo.Migrations.AddRelationsBetweenTables do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :organization_uuid, references(:organizations, type: :uuid, column: :uuid, on_delete: :delete_all), null: false
      create unique_index(:users, [:email, :company_uuid])

    end

    alter table(:vehicle_types) do
      add :vehicle_uuid, references(:vehicles, type: :uuid, column: :uuid, on_delete: :delete_all), null: false
    end

    alter table(:vehicles) do
      add :organization_uuid, references(:organizations, type: :uuid, column: :uuid, on_delete: :delete_all), null: false
    end
  end
end
