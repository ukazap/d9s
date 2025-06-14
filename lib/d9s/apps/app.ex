defmodule D9s.Apps.App do
  use Ecto.Schema
  import Ecto.Changeset

  schema "apps" do
    field :name, :string
    field :description, :string

    has_many :destinations, D9s.Infra.Destination
    has_many :releases, D9s.Apps.Release

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(app, attrs) do
    app
    |> cast(attrs, [:name, :description])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
