# adr/6: Business Logic vs Utility Namespaces

Date: 2025-06-16

## Context
Current codebase places all modules under `D9s.*`, including utilities like `D9s.JobTrains`. Need clear namespace boundaries.

## Decision

**`D9s.*` namespace for business logic only:**
- `D9s.Apps`, `D9s.Deployments`, `D9s.Infra`, `D9s.Repo`

**Top-level modules for utilities:**
- `JobTrains.*` (was `D9s.JobTrains.*`)
- `Adapters.*`, `Metrics.*`, `Events.*` (future)

## Consequences
- Clear domain/utility separation
- Utility modules can be extracted as libraries
- Migrate `D9s.JobTrains.*` → `JobTrains.*`
