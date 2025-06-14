defmodule D9s.Deployments.Deployment do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "deployments" do
    field :status, :string, default: "pending"
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime
    field :error_message, :string
    field :deployment_metadata, :map
    field :oban_job_id, :integer

    belongs_to :release, D9s.Apps.Release
    belongs_to :destination, D9s.Infra.Destination

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(deployment, attrs) do
    deployment
    |> cast(attrs, [
      :status,
      :started_at,
      :completed_at,
      :error_message,
      :deployment_metadata,
      :oban_job_id,
      :release_id,
      :destination_id
    ])
    |> validate_required([:release_id, :destination_id])
    |> validate_inclusion(:status, ["pending", "deploying", "deployed", "failed", "rolled_back"])
    |> foreign_key_constraint(:release_id)
    |> foreign_key_constraint(:destination_id)
  end
end
