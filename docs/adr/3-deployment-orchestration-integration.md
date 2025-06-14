# adr/3: Deployment Orchestration Integration

Date: 2025-06-14

## Context

Need to define how D9s.Deployments, D9s.Apps, and D9s.Infra contexts integrate for deployment orchestration. Key considerations:

- **Varied deployment methods** - AWS ASG + Kamal, AWS ECS, Kubernetes, etc.
- **Server state synchronization** - Different cloud provider APIs
- **Web layer exposure** - Dashboard vs JSON API functionality
- **Async processing** - Oban job integration
- **Error handling** - Cross-context error propagation

## Decision

### 1. Adapter Behaviors

**Deployment Adapter Behavior:**
```elixir
defmodule D9s.Deployments.Adapter do
  @callback deploy(destination :: Destination.t(), release :: Release.t(), opts :: keyword()) ::
    {:ok, job_data :: map()} | {:error, term()}
  
  @callback rollback(destination :: Destination.t(), deployment :: Deployment.t(), opts :: keyword()) ::
    {:ok, job_data :: map()} | {:error, term()}
  
  @callback cancel(destination :: Destination.t(), deployment :: Deployment.t(), opts :: keyword()) ::
    {:ok, job_data :: map()} | {:error, term()}

  # Handle newly discovered servers - VM adapters deploy, orchestrated adapters no-op
  @callback handle_new_servers(destination :: Destination.t(), release :: Release.t(), new_servers :: [Server.t()]) ::
    :ok | {:error, term()}
end
```

**Server Sync Adapter Behavior:**
```elixir
defmodule D9s.Infra.DestinationSync do
  @callback child_spec(destination :: Destination.t()) :: Supervisor.child_spec()
  @callback start_link(destination :: Destination.t()) :: {:ok, pid()} | {:error, term()}
end
```

### 2. Context Integration Flow

**Deployment Flow:**
1. `D9s.Deployments.deploy_release/2` validates via `D9s.Infra.get_destination!/1`
2. Creates deployment record with "pending" status
3. Enqueues Oban job with adapter-specific data
4. Oban worker calls appropriate adapter based on `destination.adapter_type`
5. Updates deployment status throughout process

**Server Sync Flow:**

**Supervision Tree Structure:**
```elixir
# D9s.Application
children = [
  D9s.Repo,
  D9s.Infra.DestinationSyncSupervisor,
  # ... other children
]

# D9s.Infra.DestinationSyncSupervisor starts workers for each destination
def init(_) do
  destinations = D9s.Infra.list_all_destinations()

  children = Enum.map(destinations, fn dest ->
    adapter_module = adapter_for_type(dest.adapter_type)
    adapter_module.child_spec(dest)
  end)

  DynamicSupervisor.init(strategy: :one_for_one, children: children)
end
```

**Adapter Implementation:**
Each adapter GenServer internally chooses sync strategy:
- **AWS ASG/K8s**: Server discovery + health monitoring via events/polling
- **Traditional Kamal**: Health monitoring of static servers via ping checks
- **ECS**: Task discovery + health monitoring via AWS API

**Startup Flow:**
1. `ServerSyncSupervisor` queries database for all destinations
2. Starts adapter GenServer for each destination with `:permanent` restart policy
3. Each GenServer performs initial sync then begins appropriate monitoring strategy
4. New servers trigger Oban jobs which call `adapter.handle_new_servers/3`

**Dynamic Destination Management:**
- New destinations → start GenServer worker via DynamicSupervisor
- Deleted destinations → stop GenServer worker via DynamicSupervisor  
- Updated destinations → restart GenServer worker
- Crashed workers → DynamicSupervisor auto-restart with destination data

**Runtime Events:**
```elixir
# Adapter GenServers enqueue Oban jobs for server changes
def handle_info({:server_added, server_data}, state) do
  D9s.Infra.ServerEventWorker.new(%{
    destination_id: state.destination_id,
    event_type: "server_added", 
    server_data: server_data
  }) |> Oban.insert()
  {:noreply, state}
end
```

### 3. Oban Job Structure

**Deployment Job:**
```elixir
defmodule D9s.Deployments.DeploymentWorker do
  use Oban.Worker, queue: :deployments, max_attempts: 3

  def perform(%Oban.Job{args: %{"deployment_id" => id}}) do
    # Load deployment with preloaded associations
    # Determine adapter from destination.adapter_type
    # Call adapter.deploy/3 - actual deployment execution
    # Update deployment status
  end
end
```

**Server Event Processing Job:**
```elixir
defmodule D9s.Infra.ServerEventWorker do
  use Oban.Worker, queue: :server_events

  def perform(%Oban.Job{args: %{"destination_id" => id, "event_type" => type, "server_data" => data}}) do
    # Process server added/removed/updated events
    # Update database records
    # Trigger handle_new_servers/3 for deployments
    # Enqueued by adapter GenServers when events occur
  end
end
```

**Division of Responsibilities:**
- **GenServers**: Maintain connections, event streams, health monitoring
- **Oban**: Execute deployments, process database updates, handle retries

### 4. Web Layer Exposure

**Dashboard (LiveView):**
- `D9s.Deployments.list_deployments/0` - recent deployments table
- `D9s.Deployments.get_deployment!/1` - deployment detail view
- `D9s.Infra.list_destinations_for_app/1` - app deployment targets
- `D9s.Infra.list_servers_for_destination/1` - server health status

**JSON API:**
- `POST /api/apps/:id/deployments` → `D9s.Deployments.deploy_release/2`
- `GET /api/deployments/:id` → `D9s.Deployments.get_deployment!/1`
- `PUT /api/deployments/:id/rollback` → `D9s.Deployments.rollback_deployment/1`
- `PUT /api/deployments/:id/cancel` → `D9s.Deployments.cancel_deployment/1`
- `GET /api/destinations/:id/servers` → `D9s.Infra.list_servers_for_destination/1`

### 5. Error Handling Strategy

**Cross-Context Errors:**
- `D9s.Deployments` validates destination exists via `D9s.Infra`
- Return structured error tuples: `{:error, :destination_not_found}`
- Oban jobs handle adapter failures with retries
- Store error messages in deployment records

**Adapter Failures:**
- Timeout errors → retry with exponential backoff
- Authentication errors → mark deployment as failed immediately
- Resource errors → retry with server sync first

## Consequences

**Benefits:**
- **Clear separation of concerns** - Deployment orchestration logic separated from cloud-specific implementation details
- **Pluggable architecture** - Adding new cloud providers requires only new adapter modules
- **Consistent error handling** - All adapters return standard `{:ok, result} | {:error, reason}` tuples for predictable error flows
- **Defined web boundaries** - Clear API contracts between contexts and web layer prevent tight coupling
- **Fault tolerance** - GenServer supervision and Oban retries handle adapter failures gracefully

**Trade-offs:**
- **Additional complexity** - Multiple behavior modules and supervision trees vs simpler monolithic approach
- **Coordination overhead** - GenServer state + Oban job coordination requires careful design to avoid race conditions:
  - Server disappears before deployment - GenServer discovers new server, enqueues Oban job, but ASG scales down before job runs
  - Duplicate deployments - Multiple sync cycles discover same "new" server before database updates
  - State drift - GenServer memory vs database state becomes inconsistent during concurrent updates
- **Job serialization** - Need to serialize Oban jobs per destination to prevent conflicts, but Oban Pro's chaining feature unavailable in open source (alternatives: unique jobs, database locks, idempotent operations)
- **Context boundaries** - Deployments context calls through Infra context for destination data, maintaining proper encapsulation over direct table access
- **Learning curve** - Project contributors must understand adapter pattern, GenServer supervision, and Oban job processing

**Implementation Priority:**
1. Implement D9s.Infra basic functions first to unblock Deployments context
2. Create minimal adapter behaviors to establish plugin architecture
3. Build AWS ASG + Kamal adapter as MVP proof-of-concept
4. Add Oban job processing for production reliability
5. Expose web layer endpoints for user interaction

## Resources

- [Elixir Behaviours](https://elixirschool.com/en/lessons/advanced/behaviours)
- [Oban Job Processing](https://hexdocs.pm/oban/Oban.html)
- [DynamicSupervisor](https://hexdocs.pm/elixir/DynamicSupervisor.html)
- [GenServer](https://hexdocs.pm/elixir/GenServer.html)
