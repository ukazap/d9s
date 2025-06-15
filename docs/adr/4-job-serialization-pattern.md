# ~~adr/4: Job Serialization Using GenServer Message Coordination~~

**Superseded by [adr/5](5-database-backed-job-serialization.md)**

Date: 2025-06-15

## Context

Need to serialize Oban jobs per resource to prevent conflicts and race conditions. This addresses the job serialization challenge identified in [adr/3](3-deployment-orchestration-integration.md), where the lack of Oban Pro's chaining feature in open source required an alternative coordination mechanism.

Key requirements:

- **Multiple jobs targeting same resource** must execute sequentially, not concurrently
- **Job retries** should maintain their position in the queue
- **Open source Oban limitation** - Pro version's job chaining feature unavailable

### Problem Scenarios

1. **Concurrent updates**: Job 1 updates resource A, fails and retries. Job 2 also updates resource A and starts executing before Job 1 retry completes → both jobs running simultaneously
2. **Race conditions**: Multiple jobs attempting to modify same resource
3. **State inconsistency**: Resource state becoming inconsistent due to concurrent updates

### Rejected Alternatives

- **Database job chains**: Complex cleanup and state synchronization between Oban jobs and chain tables
- **State-based coordination**: Jobs check database state before executing - complex deadlock scenarios
- **Dynamic queue partitioning**: Requires queue configuration management and doesn't scale
- **Database locking**: Pessimistic locking adds complexity and performance overhead

## Decision

Implement **GenServer Message Coordination** using PartitionSupervisor for routing and database-persisted message queues:

### Architecture

```
Event → PartitionSupervisor → GenServer → serialized_jobs → Oban Job
```

**Components:**
- **PartitionSupervisor**: Routes messages by `serialization_key` to correct GenServer
- **Stateless GenServers**: Process messages sequentially per partition
- **serialized_jobs table**: Persistent message queue
- **Oban integration**: GenServer enqueues jobs only when queue head is free

### Schema Design

```sql
CREATE TABLE serialized_jobs (
  id INTEGER PRIMARY KEY,
  serialization_key VARCHAR NOT NULL,
  oban_args JSON NOT NULL,
  oban_job_id BIGINT,
  oban_worker VARCHAR NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_serialized_jobs_serialization_key ON serialized_jobs(serialization_key, id);
```

### API

Sample worker:

```elixir
defmodule HelloWorker do
  use Oban.Worker, queue: :mailers

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"name" => name}}) do
    greet(name)
    :ok
  end
end
```

Using regular Oban:

```elixir
%{name: "Alice"}
|> HelloWorker.new()
|> Oban.insert()
```

Using new job serialization API:

```elixir
defmodule D9.JobSerialization.Completion do
  defmacro __using__(_opts) do
    quote do
      def perform(%Oban.Job{meta: %{"serialized_job_id" => _id}} = job) do
        case super(job) do
          :ok -> 
            D9.JobSerialization.acknowledge(job.meta)
            :ok
          {:ok, _} = success ->
            D9.JobSerialization.acknowledge(job.meta)
            success
          error -> error
        end
      end
      
      def perform(job), do: super(job)
      defoverridable perform: 1
    end
  end
end

defmodule HelloWorker do
  use Oban.Worker, queue: :mailers
  use D9.JobSerialization.Completion

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"name" => name}}) do
    greet(name)
    :ok
  end
end

%{name: "Alice"}
|> HelloWorker.new()
|> D9.JobSerialization.insert(serialization_key: "inbox_123")
```

Workers using `D9.JobSerialization.Completion` automatically acknowledge on successful completion.

### Implementation Pattern

**Message Processing:**
1. Insert message into serialized_jobs table with oban_job_id = NULL via `D9.JobSerialization.insert/2`
2. `D9.JobSerialization.insert/2` also cast event to GenServer via PartitionSupervisor using `serialization_key` as partition key
3. GenServer checks for first pending message without assigned job
4. If found, enqueue Oban job and update message with oban_job_id

**Job Execution:**
1. Oban worker processes job normally
2. On completion, worker deletes corresponding pending_message record via `D9.JobSerialization.acknowledge/1`
3. `D9.JobSerialization.acknowledge/1` also signals GenServer to check for next pending message
4. GenServer processes next message in queue if available

**GenServer Logic:**
```elixir
# signal from D9.JobSerialization.insert/2 or D9.JobSerialization.acknowledge/1
def handle_cast({:check_next_message, serialization_key}, state) do
  maybe_enqueue_next_job(serialization_key)
  {:noreply, state}
end

defp maybe_enqueue_next_job(serialization_key) do
  case get_first_pending_message(serialization_key) do
    %{id: id, oban_args: oban_args, oban_job_id: nil, oban_worker: oban_worker} ->
      oban_worker = String.to_existing_atom(oban_worker)
      meta = %{serialized_job_id: id, serialization_key: serialization_key}

      D9.Repo.transact(fn ->
        with {:ok, job} <- oban_worker.new(oban_args, meta: meta) |> Oban.insert(),
             :ok <- insert_oban_job_id_into_serialized_job_table(id, job.id) do
          {:ok, job}
        end
      end)
    %{oban_job_id: _job_id} -> 
      :ok  # First message already has job, wait
    nil -> 
      :ok  # No messages
  end
end
```

**`:check_next_message` signaling:**

```elixir
# Signal GenServer to check next message
GenServer.cast(
  {:via, PartitionSupervisor, {D9.JobSerialization.Supervisor, serialization_key}}, 
  {:check_next_message, serialization_key}
)
end
```

**Orphaned Message Cleanup:**
```elixir
defmodule OrphanedMessageCleanup do
  use Oban.Worker, queue: :cleanup
  
  def perform(_) do
    orphaned_inboxes = """
      SELECT DISTINCT pm.serialization_key 
      FROM serialized_jobs pm
      WHERE pm.oban_job_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM oban_jobs 
        WHERE id = pm.oban_job_id
        AND state IN ('available', 'executing', 'retryable', 'scheduled')
      )
    """

    for {serialization_key} <- Repo.query!(orphaned_inboxes).rows do
      signal_check_next_message(serialization_key)
    end
  end

  def cleanup_on_startup do
    Process.sleep(1000)  # Let Oban start first
    perform(%{})
  end
end
```

**Key SQL Queries:**
```sql
-- Get first pending message (O(log n) with index)
SELECT id, oban_args, oban_job_id, oban_worker FROM serialized_jobs
WHERE serialization_key = ?
ORDER BY id
LIMIT 1;

-- Update message with job ID after enqueueing
UPDATE serialized_jobs
SET oban_job_id = ?
WHERE id = ?;
```

### Naming Convention

`serialization_key` should be resource/noun based instead of action/verb based because we need to serialize heterogeneous messages targeting the same resource. For example, deployment, rollback, and server sync operations for destination 123 should all be serialized in the same queue to prevent conflicts.

- Destinations: `"dest_{destination_id}"`
- Applications: `"app_{app_id}"`
- Servers: `"server_{server_id}"`

## Consequences

### Benefits

- **Natural serialization** - GenServer message queue provides ordering per partition
- **Stateless GenServers** - crash-safe, no internal state to lose
- **Database-persisted queues** - survives application restarts
- **Simple coordination** - no complex database locking or job chaining
- **Automatic routing** - PartitionSupervisor handles message distribution
- **Clean separation** - event handling separate from job execution
- **Observable** - can monitor serialized_jobs table for queue depth

### Trade-offs

- **Additional GenServers** - more processes to supervise
- **Message table growth** - requires cleanup of processed messages
- **Extra indirection** - events go through GenServer before Oban
- **Partitioning design** - must choose `serialization_key` carefully for load distribution
- **Single instance only** - approach won't work across multiple BEAM instances, but acceptable since D9s runs standalone

### Edge Cases Handled

- **GenServer crashes**: PartitionSupervisor restarts, serialized_jobs persist
- **Application restarts**: Messages survive in database, processing resumes
- **Job failures**: Failed jobs retry normally, message stays in queue until success
- **Job completion signaling**: Workers notify GenServer to process next message
- **Orphaned messages**: Periodic cleanup handles discarded/cancelled jobs that leave pending messages
- **Startup cleanup**: Application startup triggers orphaned message cleanup
- **Duplicate events**: GenServer processes sequentially, natural deduplication

### Performance Characteristics

- **Message routing**: O(1) via PartitionSupervisor hash
- **Queue operations**: O(1) INSERT, O(log n) SELECT with index
- **Memory overhead**: Minimal - stateless GenServers
- **Cleanup cost**: Single DELETE per completed job

## Resources

- [PartitionSupervisor Documentation](https://hexdocs.pm/elixir/PartitionSupervisor.html)
- [GenServer Documentation](https://hexdocs.pm/elixir/GenServer.html)
- [Oban Documentation](https://hexdocs.pm/oban/Oban.html)
