# adr/1: Database Schema Design

Date: 2025-06-14

## Context
Need core data models for deployment orchestration system managing apps, releases, deployments across multiple cloud providers.

## Decision

### Core Tables
- **Apps**: `id, name, description`
- **Destinations**: `id, app_id, name, adapter_type, adapter_config, env_variables`
- **Releases**: `id, app_id, version, metadata`
- **Deployments**: `id, release_id, destination_id, status, timestamps, oban_job_id`
- **Servers**: `id, destination_id, instance_id, status, metadata, last_seen_at`

### Key Decisions
- Auto-increment integer primary keys (simple, SQLite-friendly, adequate for single-instance deployment)
- JSON for flexible configuration (adapter_config, env_variables, metadata)
- Simple status enums vs state machines
- Unique constraints: app names, destination names per app, instance_ids per destination

## Consequences
- **Integer PKs**: Simpler debugging, better SQLite performance, can migrate to UUIDs later
- **JSON fields**: Adapter-specific config without schema changes, flexible metadata storage
- **Status enums**: Clear validation rules, easier debugging than state machines
- **Unique constraints**: Prevent duplicate app names, destination names, instance IDs
