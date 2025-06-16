defmodule JobTrains do
  @moduledoc """
  Database-Backed Job Serialization per adr/5.

  Ensures jobs targeting the same resource execute sequentially, not concurrently.
  """

  alias JobTrains.{LocomotiveJob, TrainJob}

  @repo Application.compile_env!(:d9s, [JobTrains, :repo])

  @doc """
  Insert a job into a train queue.

  First job becomes locomotive (available), subsequent jobs wait (unavailable).
  """
  @spec insert(Ecto.Changeset.t(), String.t()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def insert(oban_job_changeset, train_id) do
    @repo.transact(fn ->
      with updated_changeset <- add_train_meta(oban_job_changeset, train_id),
           {:ok, oban_job} <- Oban.insert(updated_changeset),
           {:ok, _train_job} <- create_train_job(oban_job.id, train_id) do
        attempt_to_set_locomotive(oban_job, train_id)
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
    %TrainJob{train_id: train_id, oban_job_id: oban_job_id}
    |> @repo.insert()
  end

  defp attempt_to_set_locomotive(oban_job, train_id) do
    locomotive_changeset =
      LocomotiveJob.changeset(%LocomotiveJob{}, %{
        train_id: train_id,
        oban_job_id: oban_job.id
      })

    case @repo.insert(locomotive_changeset) do
      {:ok, _} ->
        case Ecto.Changeset.change(oban_job, state: "available") |> @repo.update() do
          {:ok, updated_job} -> {:ok, updated_job}
          error -> error
        end

      {:error, _changeset} ->
        {:ok, oban_job}
    end
  end
end
