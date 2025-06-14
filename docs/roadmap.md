# Development Roadmap

## Strategic Vision

### Goals
- **Multi-cloud deployment platform** supporting AWS, Hetzner, DigitalOcean via pluggable adapters
- **Kamal-first approach** for container orchestration while remaining adapter-agnostic
- **Developer self-service** for deployments without infrastructure team bottlenecks
- **Operational visibility** into deployment health and server states

### Success Metrics
- Deploy to production in <5 minutes with zero downtime
- Support 10+ applications across 3+ environments per app
- 99.9% deployment success rate
- Real-time deployment status and rollback capability

### Market Position
- Simplified deployment orchestration for teams (supports both VM-based and Kubernetes deployments)
- Bridge between simple deployment scripts and enterprise orchestration
- Kamal + multi-cloud = simplified container deployments

### Planned Adapters
- **AWS ASG + Kamal** (MVP) - Deploy containers to EC2 instances in autoscaling groups using Kamal
- **AWS ECS** - Deploy via Amazon's container service using AWS ECS SDK/API
- **Kubernetes** - Deploy to any Kubernetes cluster using kubectl/Kubernetes API
- **Hetzner + Kamal** - Deploy to Hetzner Cloud VMs using Kamal
- **AWS EC2 + Kamal** - Deploy to EC2 instances matching certain tags using Kamal
- **DigitalOcean + Kamal** - Deploy to DigitalOcean droplets using Kamal

## Phase Priorities

### MVP (3-4 weeks)
Single app, AWS ASG + Kamal, basic UI

### V1 (2-3 months)
Multi-app, multiple adapters, production-ready

### V2 (6 months)
Advanced monitoring, deployment analytics, team features

## Milestones

### MVP (Week 4)
Single app deployment to AWS ASG via Kamal

### Beta (Week 8)
Multi-app support, basic monitoring

### V1 (Week 12)
Production-ready with rollbacks, health checks

## Implementation
See `docs/adr/` for technical decisions and architecture details.
