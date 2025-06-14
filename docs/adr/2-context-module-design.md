# adr/2: Context Module Design

Date: 2025-06-14

## Context
Need to define Phoenix context modules for business logic around apps, deployments, and infrastructure management.

## Decision

### Context Structure
- `D9s.Apps` - app and release management
- `D9s.Deployments` - deployment orchestration and tracking
- `D9s.Infra` - destinations and server management

### Error Handling
- Bang functions for expected success: `D9s.Apps.get_app!/1` (raises on not found)
- Tuple returns for uncertain operations: `{:ok, app} | {:error, changeset}`
- Raise exception only for programming errors

### Code Standards
- All public functions must have `@spec` annotations
- Use proper type definitions: `App.t()`, `Release.t()`, etc.
- Include comprehensive `@doc` with examples

### Context Boundaries
- Apps context owns app/release lifecycle
- Deployments context orchestrates across apps/infra
- Infra context manages deployment targets

## Consequences
- Clear separation of concerns
- Standard Phoenix patterns for consistency
- Each context has focused responsibility
- Easy to test and maintain

## Resources
- [Phoenix Contexts Guide](https://hexdocs.pm/phoenix/contexts.html)
- [Hexpm context organization](https://github.com/hexpm/hexpm/tree/main/lib/hexpm)
- [Ecto changeset patterns](https://hexdocs.pm/ecto/Ecto.Changeset.html)
