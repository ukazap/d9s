# adr/0: Architecture Decision Records

Date: 2025-06-14

## Context
Need lightweight process for documenting design decisions and architecture in D9s project.

## Decision
Use Architecture Decision Records (ADRs) stored in `docs/adr/` with simple numbering (0, 1, 2...). All merged ADRs are considered accepted.

### Template
```markdown
# adr/N: Title

Date: YYYY-MM-DD

## Context
Problem being solved

## Decision
What we're doing

## Consequences
Trade-offs and implications

## Resources
Literatures and/or web links
```

### Notation and Linking

Use `adr/N` notation to refer to other ADR, e.g.

```markdown
Please refer to [adr/0](adr/0-architecture-decision-records.md) for ADR template.
```

Always use `adr/N` notation in all communication channels: never write "ADR 0" or "ADR/0", always "adr/0".

## Consequences
- Simple, established pattern
- Stored in version control with code
- Easy to reference and search
- No process overhead

## Resources

- <https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions.html>
- <https://adr.github.io/>
