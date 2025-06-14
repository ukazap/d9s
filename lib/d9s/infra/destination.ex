defmodule D9s.Infra.Destination do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "destinations" do
    field :name, :string
    field :adapter_type, :string
    field :adapter_config, :map
    field :env_variables, :map

    belongs_to :app, D9s.Apps.App
    has_many :deployments, D9s.Deployments.Deployment
    has_many :servers, D9s.Infra.Server

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(destination, attrs) do
    destination
    |> cast(attrs, [:name, :adapter_type, :adapter_config, :env_variables, :app_id])
    |> validate_required([:name, :adapter_type, :adapter_config, :app_id])
    |> unique_constraint([:app_id, :name])
    |> foreign_key_constraint(:app_id)
  end
end
