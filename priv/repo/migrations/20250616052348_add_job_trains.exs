defmodule D9s.Repo.Migrations.AddJobTrains do
  use Ecto.Migration

  def change do
    # Create locomotive_jobs table
    create table(:locomotive_jobs, primary_key: false) do
      add :train_id, :string, primary_key: true
      add :oban_job_id, :bigint, null: false
    end

    # Create train_jobs table for fast membership tracking
    create table(:train_jobs, primary_key: false) do
      add :train_id, :string, null: false
      add :oban_job_id, :bigint, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:train_jobs, [:train_id, :oban_job_id])
  end
end
