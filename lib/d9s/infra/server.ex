defmodule D9s.Infra.Server do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "servers" do
    field :instance_id, :string
    field :status, :string, default: "unknown"
    field :metadata, :map
    field :last_seen_at, :utc_datetime

    belongs_to :destination, D9s.Infra.Destination

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(server, attrs) do
    server
    |> cast(attrs, [:instance_id, :status, :metadata, :last_seen_at, :destination_id])
    |> validate_required([:instance_id, :destination_id])
    |> validate_inclusion(:status, ["unknown", "healthy", "unhealthy", "deploying"])
    |> unique_constraint([:destination_id, :instance_id])
    |> foreign_key_constraint(:destination_id)
  end
end
