defmodule D9s.JobTrains.CleanupWorker do
  @moduledoc """
  Periodic cleanup for orphaned locomotives.

  Advances trains when jobs are in terminal states (cancelled/discarded)
  based on worker configuration.
  """

  require Logger
  use Oban.Worker, queue: :cleanup

  import Ecto.Query
  alias D9s.Repo
  alias D9s.JobTrains.{LocomotiveJob, TrainJob}

  @impl Oban.Worker
  def perform(_) do
    Logger.info("Job train cleanup in progress...")
    cleanup_orphaned_locomotives()
    cleanup_orphaned_train_jobs()
    Logger.info("Job train cleanup done.")
    :ok
  end

  defp cleanup_orphaned_locomotives do
    orphaned_locomotives =
      from c in LocomotiveJob,
        join: j in Oban.Job,
        on: c.oban_job_id == j.id,
        where: j.state in ["cancelled", "discarded"],
        select: {j.worker, c.train_id, j.state, c.oban_job_id}

    for {worker, train_id, oban_job_state, oban_job_id} <- Repo.all(orphaned_locomotives) do
      with worker_config <- safe_get_worker_config(worker),
           true <- should_advance?(oban_job_state, worker_config) do
        D9s.JobTrains.Advancement.advance(train_id, oban_job_id)
      end
    end
  end

  defp safe_get_worker_config(worker) do
    try do
      worker_module = String.to_existing_atom(worker)
      worker_module.locomotive_config()
    rescue
      # Unknown worker module, advance anyway
      ArgumentError -> %{on_cancelled: :advance, on_discarded: :advance}
    end
  end

  defp should_advance?("cancelled", %{on_cancelled: :advance}), do: true
  defp should_advance?("discarded", %{on_discarded: :advance}), do: true
  defp should_advance?(_, _), do: false

  defp cleanup_orphaned_train_jobs do
    # Get orphaned train job IDs first
    orphaned_ids =
      from tj in TrainJob,
        left_join: j in Oban.Job,
        on: tj.oban_job_id == j.id,
        where: is_nil(j.id),
        select: tj.oban_job_id

    job_ids = Repo.all(orphaned_ids)

    # Delete by IDs (SQLite doesn't support JOINs in DELETE)
    if job_ids != [] do
      Repo.delete_all(from tj in TrainJob, where: tj.oban_job_id in ^job_ids)
    end
  end
end
