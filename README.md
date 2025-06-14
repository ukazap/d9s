# D9s

D9s is a Phoenix-based deployment orchestration platform that manages application deployments across multiple environments and cloud providers using pluggable adapters.

## What it does

- **Multi-application management** - Deploy multiple apps to different environments
- **Adapter-based deployments** - Pluggable support for AWS, Kubernetes, Hetzner, DigitalOcean
- **Kamal-first approach** - Simplified container orchestration without Kubernetes complexity
- **Real-time monitoring** - Track deployment status, server health, and rollbacks
- **Background processing** - Asynchronous deployments with Oban job queues

## Project Status

**Early development** - MVP targeting AWS ASG + Kamal adapter.

Current focus: Core data models, basic web interface, first deployment adapter.

## Documentation

- **[Development Roadmap](docs/roadmap.md)** - Strategic vision, goals, planned features
- **[Architecture Decision Records](docs/adr/0-architecture-decision-records.md)** - Technical design decisions

## Development

**Setup:**
```bash
mix setup
mix phx.server
# Visit localhost:4000
```

**Tech stack:** Phoenix LiveView, Ecto, Oban, Tailwind

## Contributing

Humans and AIs, attention!

1. Read this README.md completely
2. Review [docs/roadmap.md](docs/roadmap.md) for strategic context
3. Study architecture decision records within `docs/adr/` directory
4. Propose new features/changes as ADRs first
5. Wait for ADR approval before implementing

**No direct implementation without documented decisions.**
