defmodule D9s.JobTrains.Advancement do
  @moduledoc """
  Handles train advancement when jobs complete.
  """

  import Ecto.Query
  alias D9s.Repo
  alias D9s.JobTrains.{LocomotiveJob, TrainJob}

  @doc """
  Advance the locomotive queue for a train.

  Called when current locomotive completes successfully. Deletes the
  current locomotive and its train job entry, then makes the next
  waiting job available.

  ## Examples

      iex> D9s.JobTrains.Advancement.advance("dest_123", 42)
      {:ok, :ok}
  """
  @spec advance(String.t(), integer()) :: :ok | {:error, term()}
  def advance(train_id, finished_oban_job_id) do
    Repo.transact(fn ->
      with :ok <- detach_locomotive(train_id, finished_oban_job_id),
           next_oban_job <- find_next_oban_job(train_id) do
        attach_new_locomotive(train_id, next_oban_job)
      end
    end)
  end

  defp detach_locomotive(train_id, finished_oban_job_id) do
    Repo.delete_all(from c in LocomotiveJob, where: c.train_id == ^train_id)
    Repo.delete_all(from tj in TrainJob, where: tj.oban_job_id == ^finished_oban_job_id)

    :ok
  end

  defp find_next_oban_job(train_id) do
    from(tj in TrainJob,
      join: j in Oban.Job,
      on: tj.oban_job_id == j.id,
      where: tj.train_id == ^train_id and j.state == "unavailable",
      order_by: [asc: j.id],
      limit: 1,
      select: j
    )
    |> Repo.one()
  end

  defp attach_new_locomotive(_train_id, nil), do: :ok

  defp attach_new_locomotive(train_id, next_oban_job) do
    with {:ok, _} <- Ecto.Changeset.change(next_oban_job, state: "available") |> Repo.update(),
         loco <- %LocomotiveJob{train_id: train_id, oban_job_id: next_oban_job.id},
         {:ok, _} <- Repo.insert(loco) do
      :ok
    end
  end
end
