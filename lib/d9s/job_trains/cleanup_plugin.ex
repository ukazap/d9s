defmodule D9s.JobTrains.CleanupPlugin do
  @moduledoc """
  Oban plugin for periodic cleanup of stuck job trains.
  """

  @behaviour Oban.Plugin

  require Logger
  import Ecto.Query
  alias D9s.Repo
  alias D9s.JobTrains.{LocomotiveJob, TrainJob}

  @default_interval :timer.minutes(5)

  def cleanup_now do
    Logger.debug("Cleaning up job trains...")
    delete_records_missing_oban_jobs(LocomotiveJob)
    delete_records_missing_oban_jobs(TrainJob)
    unstuck_trains()
    Logger.debug("Cleaned up job trains.")
  end

  @impl Oban.Plugin
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl Oban.Plugin
  def validate(opts) do
    with {:ok, [interval: interval]} <- Keyword.validate(opts, interval: @default_interval),
         true <- is_integer(interval) && interval >= @default_interval do
      :ok
    else
      _ -> {:error, "interval must be integer >= #{@default_interval}"}
    end
  end

  use GenServer

  @impl GenServer
  def init(opts) do
    cleanup_now()
    interval = Keyword.get(opts, :interval, @default_interval)
    schedule_cleanup(interval)
    {:ok, interval}
  end

  @impl GenServer
  def handle_info(:cleanup, interval) do
    cleanup_now()
    schedule_cleanup(interval)
    {:noreply, interval}
  end

  defp schedule_cleanup(interval) do
    Process.send_after(self(), :cleanup, interval)
  end

  defp unstuck_trains do
    stuck_trains =
      from c in LocomotiveJob,
        join: j in Oban.Job,
        on: c.oban_job_id == j.id,
        where: j.state in ["cancelled", "discarded"],
        select: {c.train_id, j.worker, j.state, c.oban_job_id}

    for {train_id, oban_worker, oban_job_state, oban_job_id} <- Repo.all(stuck_trains) do
      with worker_config <- safe_get_worker_config(oban_worker),
           true <- should_advance?(oban_job_state, worker_config) do
        D9s.JobTrains.Advancement.advance(train_id, oban_job_id)
      end
    end
  end

  defp safe_get_worker_config(oban_worker) do
    try do
      worker_module = String.to_existing_atom(oban_worker)
      worker_module.locomotive_config()
    rescue
      ArgumentError -> %{on_cancelled: :advance, on_discarded: :advance}
    end
  end

  defp should_advance?("cancelled", %{on_cancelled: :advance}), do: true
  defp should_advance?("discarded", %{on_discarded: :advance}), do: true
  defp should_advance?(_, _), do: false

  defp delete_records_missing_oban_jobs(schema) do
    record_ids =
      from s in schema,
        left_join: j in Oban.Job,
        on: s.oban_job_id == j.id,
        where: is_nil(j.id),
        select: s.oban_job_id

    job_ids = Repo.all(record_ids)

    if job_ids != [] do
      Repo.delete_all(from s in schema, where: s.oban_job_id in ^job_ids)
    end
  end
end
