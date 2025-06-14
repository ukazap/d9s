defmodule D9s.Repo.Migrations.CreateDestinations do
  use Ecto.Migration

  def change do
    create table(:destinations) do
      add :app_id, references(:apps, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :adapter_type, :string, null: false
      add :adapter_config, :map, null: false, default: %{}
      add :env_variables, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:destinations, [:app_id, :name])
    create index(:destinations, [:app_id])
  end
end
