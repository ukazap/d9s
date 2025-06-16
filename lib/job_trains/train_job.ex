defmodule JobTrains.TrainJob do
  use Ecto.Schema

  @primary_key false
  schema "train_jobs" do
    field :train_id, :string
    field :oban_job_id, :integer

    timestamps(type: :utc_datetime)
  end
end
