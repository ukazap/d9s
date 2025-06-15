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
  def advance(train_id, oban_job_id) do
    Repo.transact(fn ->
      with locomotive <- get_current_locomotive(train_id, oban_job_id),
           {_, _} <- detach_locomotive(locomotive),
           next_oban_job <- find_next_oban_job(train_id) do
        attach_new_locomotive(next_oban_job, train_id)
      end
    end)
  end

  defp get_current_locomotive(train_id, oban_job_id) do
    %LocomotiveJob{train_id: train_id, oban_job_id: oban_job_id}
  end

  defp detach_locomotive(%{train_id: train_id, oban_job_id: oban_job_id}) do
    loco_count = Repo.delete_all(from c in LocomotiveJob, where: c.train_id == ^train_id)
    train_count = Repo.delete_all(from tj in TrainJob, where: tj.oban_job_id == ^oban_job_id)

    {loco_count, train_count}
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

  defp attach_new_locomotive(nil, _train_id), do: :ok

  defp attach_new_locomotive(oban_job, train_id) do
    with {:ok, _} <- Ecto.Changeset.change(oban_job, state: "available") |> Repo.update(),
         {:ok, _} <-
           Repo.insert(%LocomotiveJob{train_id: train_id, oban_job_id: oban_job.id}) do
      :ok
    end
  end
end
