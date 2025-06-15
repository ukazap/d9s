# adr/5: Database-Backed Job Serialization

Date: 2025-06-16

## Context

**Supersedes [adr/4](4-job-serialization-pattern.md)** - The GenServer message coordination approach was overly complex for the core requirement of ordering Oban jobs per resource.

Need simpler mechanism to ensure jobs targeting the same resource execute sequentially, not concurrently. Key requirements remain:
- Multiple jobs targeting same resource must execute sequentially
- Job retries should maintain queue position
- Open source Oban limitation (no Pro chaining feature)

Previous GenServer approach had unnecessary complexity:
- PartitionSupervisor routing
- Stateless GenServers for message processing
- Database-persisted message queues
- Complex signaling between components

## Decision

Implement **Locomotive Job Train Pattern** using database-controlled job availability:

### Schema Design

```sql
-- Locomotive locking table
CREATE TABLE locomotive_jobs (
  train_id VARCHAR PRIMARY KEY,
  oban_job_id BIGINT NOT NULL
);

-- Fast train membership tracking
CREATE TABLE train_jobs (
  train_id VARCHAR NOT NULL,
  oban_job_id BIGINT NOT NULL,
  timestamps
);

CREATE UNIQUE INDEX ON train_jobs(train_id, oban_job_id);
```

### Job Enqueuing Pattern

```elixir
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

defp attempt_to_set_locomotive(oban_job, train_id) do
  locomotive_changeset = LocomotiveJob.changeset(%LocomotiveJob{}, %{
    train_id: train_id,
    oban_job_id: oban_job.id
  })

  case Repo.insert(locomotive_changeset) do
    {:ok, _} ->
      case Ecto.Changeset.change(oban_job, state: "available") |> Repo.update() do
        {:ok, updated_job} -> {:ok, updated_job}
        error -> error
      end
    {:error, _changeset} ->
      {:ok, oban_job}
  end
end
```

### Job Completion Pattern

**Worker Implementation:**
```elixir
defmodule D9s.JobTrains.Worker do
  @callback perform_in_train(Oban.Job.t()) :: term()

  defmacro __using__(opts) do
    on_cancelled = Keyword.get(opts, :on_cancelled, :advance)
    on_discarded = Keyword.get(opts, :on_discarded, :advance)
    oban_opts = Keyword.drop(opts, [:on_cancelled, :on_discarded])

    quote do
      use Oban.Worker, unquote(oban_opts)
      @behaviour D9s.JobTrains.Worker

      def perform(%Oban.Job{meta: %{"train_id" => train_id}, id: job_id} = job) when not is_nil(train_id) do
        result = perform_in_train(job)
        D9s.JobTrains.Advancement.advance(train_id, job_id)
        result
      end

      def perform(job), do: perform_in_train(job)

      def locomotive_config do
        %{on_cancelled: unquote(on_cancelled), on_discarded: unquote(on_discarded)}
      end
    end
  end
end

defmodule DeploymentWorker do
  use D9s.JobTrains.Worker, 
    queue: :deployments,
    on_cancelled: :hold,
    on_discarded: :advance

  def perform_in_train(%Oban.Job{args: args}) do
    deploy(args)
  end
end
```

**Train Advancement:**

```elixir
@spec advance(String.t(), integer()) :: :ok | {:error, term()}
def advance(train_id, oban_job_id) do
  Repo.transact(fn ->
    with locomotive <- get_current_locomotive(train_id, oban_job_id),
         {_, _} <- detach_locomotive(locomotive),
         next_oban_job <- find_next_oban_job(train_id),
         result <- attach_new_locomotive(next_oban_job, train_id) do
      result
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
    join: j in Oban.Job, on: tj.oban_job_id == j.id,
    where: tj.train_id == ^train_id and j.state == "unavailable",
    order_by: [asc: j.id],
    limit: 1,
    select: j
  ) |> Repo.one()
end

defp attach_new_locomotive(nil, _train_id), do: :ok

defp attach_new_locomotive(oban_job, train_id) do
  with {:ok, _} <- Ecto.Changeset.change(oban_job, state: "available") |> Repo.update(),
       {:ok, _} <- Repo.insert(%LocomotiveJob{train_id: train_id, oban_job_id: oban_job.id}) do
    :ok
  end
end
```

**Periodic Cleanup:**
```elixir
defmodule D9s.JobTrains.CleanupWorker do
  use Oban.Worker, queue: :cleanup
  
  @impl Oban.Worker
  def perform(_job) do
    cleanup_orphaned_locomotives()
    cleanup_orphaned_train_jobs()
    :ok
  end

  defp cleanup_orphaned_locomotives do
    orphaned_locomotives =
      from c in LocomotiveJob,
        join: j in Oban.Job, on: c.oban_job_id == j.id,
        where: j.state in ["cancelled", "discarded"],
        select: {j.worker, c.train_id, j.state, c.oban_job_id}

    for {worker_module_str, train_id, state, job_id} <- Repo.all(orphaned_locomotives) do
      case safe_get_worker_config(worker_module_str) do
        {:ok, config} ->
          should_advance = case state do
            "cancelled" -> config.on_cancelled == :advance
            "discarded" -> config.on_discarded == :advance
          end
          if should_advance, do: D9s.JobTrains.Advancement.advance(train_id, job_id)
        {:error, _} ->
          D9s.JobTrains.Advancement.advance(train_id, job_id)
      end
    end
  end

  defp cleanup_orphaned_train_jobs do
    orphaned_train_jobs =
      from tj in TrainJob,
        left_join: j in Oban.Job, on: tj.oban_job_id == j.id,
        where: is_nil(j.id)
    Repo.delete_all(orphaned_train_jobs)
  end
end
```

### API Usage

```elixir
# Regular Oban job
%{destination_id: 123, action: "deploy"}
|> DeploymentWorker.new()
|> Oban.insert()

# Train job
%{destination_id: 123, action: "deploy"}
|> DeploymentWorker.new()
|> D9s.JobTrains.insert("dest_123")

# Multiple jobs for same resource will queue
%{destination_id: 123, action: "rollback"}
|> DeploymentWorker.new()
|> D9s.JobTrains.insert("dest_123")  # Waits for deploy
```

### Train ID Convention

Same as [adr/4](4-job-serialization-pattern.md) "Naming Convention", e.g.

- Destinations: `"dest_{destination_id}"`
- Applications: `"app_{app_id}"`
- Servers: `"server_{server_id}"`

## Consequences

### Benefits

- **Pure database solution** - No GenServers or message coordination
- **Crash-safe** - All state persists in database
- **Fast queries** - TrainJob table avoids slow JSON meta queries in SQLite
- **Standard Oban patterns** - Workers nearly identical to regular Oban workers
- **Configurable cleanup** - Per-worker terminal state handling
- **Composable API** - Separate job creation from train insertion

### Trade-offs

- **Additional table** - TrainJob for fast membership tracking
- **Database constraints** - Relies on unique constraint for locomotive acquisition
- **Lock duration** - Failed jobs hold train until resolved (expected behavior)

### Edge Cases Handled

- **Job failures** - Locomotive stays locked, job retries normally
- **Terminal states** - Configurable per worker (advance/hold train)
- **Application restart** - All state persists in database
- **Concurrent enqueuing** - Unique constraint prevents duplicate locomotives
- **Orphaned data** - Periodic cleanup removes stale entries

### Performance Characteristics

- **Enqueue**: O(1) with unique constraint check
- **Advance**: O(log n) with indexed train membership lookup
- **Memory**: Zero additional memory overhead
- **Lock acquisition**: Single INSERT with constraint

## Resources

- [Oban Job States](https://hexdocs.pm/oban/Oban.Job.html#module-states)
- [Ecto Transactions](https://hexdocs.pm/ecto/Ecto.Repo.html#c:transaction/2)
