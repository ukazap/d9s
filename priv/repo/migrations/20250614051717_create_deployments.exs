defmodule D9s.Repo.Migrations.CreateDeployments do
  use Ecto.Migration

  def change do
    create table(:deployments) do
      add :release_id, references(:releases, on_delete: :delete_all), null: false
      add :destination_id, references(:destinations, on_delete: :delete_all), null: false
      add :status, :string, null: false, default: "pending"
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :error_message, :text
      add :deployment_metadata, :map, null: false, default: %{}
      add :oban_job_id, :integer

      timestamps(type: :utc_datetime)
    end

    create index(:deployments, [:release_id])
    create index(:deployments, [:destination_id])
    create index(:deployments, [:status])
  end
end
