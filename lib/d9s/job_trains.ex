defmodule D9s.JobTrains do
  @moduledoc """
  Database-backed job serialization using the locomotive train pattern.

  Jobs targeting the same resource (train_id) execute sequentially.
  One job acts as the "locomotive" while others queue behind it.
  """

  alias D9s.Repo
  alias D9s.JobTrains.{LocomotiveJob, TrainJob}

  @doc """
  Enqueue a job changeset in the specified train.

  If no locomotive exists for the train, this job becomes the locomotive.
  Otherwise, it waits in queue.

  ## Examples

      iex> changeset = MyWorker.new(%{id: 123})
      iex> D9s.JobTrains.insert(changeset, "dest_123")
      {:ok, %Oban.Job{}}
  """
  @spec insert(Ecto.Changeset.t(), String.t()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def insert(oban_job_changeset, train_id) do
    Repo.transact(fn ->
      with updated_changeset <- add_train_meta(oban_job_changeset, train_id),
           {:ok, oban_job} <- Oban.insert(updated_changeset),
           {:ok, _train_job} <- create_train_job(oban_job.id, train_id),
           result <- attempt_to_set_locomotive(oban_job, train_id) do
        result
      end
    end)
  end

  defp add_train_meta(changeset, train_id) do
    current_meta = Ecto.Changeset.get_field(changeset, :meta) || %{}
    updated_meta = Map.put(current_meta, "train_id", train_id)

    changeset
    |> Ecto.Changeset.put_change(:meta, updated_meta)
    |> Ecto.Changeset.put_change(:state, "unavailable")
  end

  defp create_train_job(oban_job_id, train_id) do
    Repo.insert(%TrainJob{
      oban_job_id: oban_job_id,
      train_id: train_id
    })
  end

  defp attempt_to_set_locomotive(oban_job, train_id) do
    locomotive_changeset =
      LocomotiveJob.changeset(%LocomotiveJob{}, %{
        train_id: train_id,
        oban_job_id: oban_job.id
      })

    case Repo.insert(locomotive_changeset) do
      {:ok, _} ->
        # First in train, make oban job available immediately
        case Ecto.Changeset.change(oban_job, state: "available") |> Repo.update() do
          {:ok, updated_job} -> {:ok, updated_job}
          error -> error
        end

      {:error, _changeset} ->
        # There's already locomotive, oban job stay unavailable
        {:ok, oban_job}
    end
  end
end
