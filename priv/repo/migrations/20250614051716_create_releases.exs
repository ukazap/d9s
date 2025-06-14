defmodule D9s.Repo.Migrations.CreateReleases do
  use Ecto.Migration

  def change do
    create table(:releases) do
      add :app_id, references(:apps, on_delete: :delete_all), null: false
      add :version, :string, null: false
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:releases, [:app_id, :version])
    create index(:releases, [:app_id])
  end
end
