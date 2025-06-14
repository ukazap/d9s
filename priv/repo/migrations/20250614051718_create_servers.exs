defmodule D9s.Repo.Migrations.CreateServers do
  use Ecto.Migration

  def change do
    create table(:servers) do
      add :destination_id, references(:destinations, on_delete: :delete_all), null: false
      add :instance_id, :string, null: false
      add :status, :string, null: false, default: "unknown"
      add :metadata, :map, null: false, default: %{}
      add :last_seen_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:servers, [:destination_id, :instance_id])
    create index(:servers, [:destination_id])
    create index(:servers, [:status])
  end
end
