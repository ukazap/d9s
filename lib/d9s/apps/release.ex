defmodule D9s.Apps.Release do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "releases" do
    field :version, :string
    field :metadata, :map

    belongs_to :app, D9s.Apps.App
    has_many :deployments, D9s.Deployments.Deployment

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(release, attrs) do
    release
    |> cast(attrs, [:version, :metadata, :app_id])
    |> validate_required([:version, :app_id])
    |> unique_constraint([:app_id, :version])
    |> foreign_key_constraint(:app_id)
  end
end
