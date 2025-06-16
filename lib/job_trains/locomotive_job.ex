defmodule JobTrains.LocomotiveJob do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:train_id, :string, []}
  schema "locomotive_jobs" do
    field :oban_job_id, :integer
  end

  def changeset(locomotive, attrs) do
    locomotive
    |> cast(attrs, [:train_id, :oban_job_id])
    |> validate_required([:train_id, :oban_job_id])
    |> unique_constraint(:train_id)
  end
end
