# Feather Audit

Feather Audit is the cross-domain audit, investigation, and operator-alerting service for the Feather Framework. It will store a normalized, append-only projection of significant events emitted by Feather resources without replacing the authoritative records owned by those resources.

> [!IMPORTANT]
> This resource is under active development. A2 database migrations and trusted server ingestion are implemented but have not yet passed live RedM/MySQL smoke tests. Search, retention jobs, redaction, exports, notifications, and production producer onboarding are not implemented. Do not use it as production evidence yet.

## What Feather Audit will do

- Ingest versioned events from trusted server resources.
- Deduplicate retried events and quarantine permanently invalid events.
- Correlate workflows across Economy, Inventory, Admin, Authority, Justice, and other resources.
- Provide permission-controlled search and event detail APIs.
- Apply sensitivity, redaction, retention, archival, and integrity policies.
- Record sensitive Audit searches, exports, redactions, and administrative changes.
- Evaluate operator-defined alert rules after an event is durably stored.
- Send sanitized alerts to configured destinations, with Discord as the first external provider.
- Expose ingestion lag, quarantine, notification delivery, retention, and integrity health.

## What Feather Audit will not do

- Replace Economy balances or transaction ledgers.
- Replace Inventory ownership and movement history.
- Replace Admin reports, moderation cases, warnings, bans, or notes.
- Replace Authority policy or authorization decisions.
- Replace Justice cases, warrants, charges, or sentences.
- Act as a general gameplay event bus, analytics warehouse, chat system, or arbitrary webhook relay.

Authoritative domains commit their state and a durable Audit outbox event in the same database transaction. Audit downtime may delay projection and alerts, but it must not cause a committed domain mutation to be lost or rolled back.

## Current status

The current A2 build provides:

- A RedM `fxmanifest.lua`.
- Safe default configuration with external delivery disabled.
- Shared contract and lifecycle constants.
- Server-side runtime state.
- `GetHealth` and `GetCapabilities` exports with database and ingestion metrics.
- The intended source directory layout for the phased build.
- A1 pure-Lua canonicalization, validation, schema registry, producer event builder, and adapter-based outbox kit.
- Offline specifications and an in-memory lost-acknowledgement/replay harness; execution remains pending until Lua 5.4 is available.
- Ordered MySQL migrations for events, targets, references, quarantine, access records, and the migration ledger.
- Allowlisted server-resource ingestion with invoker/source/instance verification and per-producer rate limits.
- Durable deduplication, identity-conflict quarantine, registered-schema validation, and stored SHA-256 integrity hashes.
- Console-only migration, health, and ingestion smoke commands gated by development configuration.

The resource does **not** yet provide search, correlation views, retention execution, redaction, exports, notifications, or production event schemas. Only registered and configured server producers can ingest.

## Planned architecture

```text
Domain mutation
  -> domain transaction + durable outbox
  -> Audit ingestion and deduplication
  -> Audit database and indexes
  -> search/correlation APIs
  -> optional alert rules
  -> sanitized Discord, console, or HTTP delivery
```

Every accepted event is stored in Audit. Notification rules only add destinations; they never replace database storage.

## Dependencies

- `oxmysql`
- `feather-core`

Future phases will integrate with the framework authority provider for protected search and management operations. Individual producer resources are integrations, not runtime dependencies of Feather Audit.

## Installation for development

1. Place the resource in the server resources directory with the exact name `feather-audit`.
2. Install and start `oxmysql` and `feather-core` first.
3. Add `ensure feather-audit` after those resources in `server.cfg`.
4. Set a stable, installation-specific `Config.SourceInstance` in `config.lua`.
5. Register only reviewed producers and their event prefixes/versions in `Config.Producers`.
6. Review the startup message. Audit becomes ready only after configuration validation and all migrations succeed.

Starting A2 creates Audit-owned tables. Back up the database before testing migrations on an existing installation.

## Configuration

Safe development defaults live in `config.lua`. External notifications are disabled, and no webhook secret belongs in that file.

- `SourceInstance` is a stable server/world identity and part of deduplication. Do not change it casually after producers have emitted events.
- `Producers` allowlists exact server resource names, event prefixes, versions, instance identity, and rate limits.
- `Development.smokeCommands` enables console-only destructive-free smoke fixtures on a test server. Keep it false in production.

The owner-facing notification vocabulary is:

- **Destinations** — named places that may receive an alert.
- **Rules** — conditions that deserve additional attention.
- **When** — readable matching conditions.
- **Send to** — zero or more destinations added after durable Audit storage.

Planned destination types include `discord`, `console`, and `http_webhook`. Secrets will be referenced through a protected secret provider or server environment, never embedded in Audit events, exports, client scripts, or ordinary configuration examples.

## Project structure

```text
feather-audit/
|- config.lua
|- fxmanifest.lua
|- docs/
|  |- THREAT_MODEL.md
|  |- DATA_POLICY.md
|  |- EVENT_CONTRACT.md
|  `- PRODUCER_REQUIREMENTS.md
|- producer/
|  |- event_builder.lua
|  |- event_id.lua
|  `- outbox.lua
|- schemas/
|  `- examples/
|- shared/
|  |- constants.lua
|  |- results.lua
|  `- contract/
|- server/
|  |- core/
|  |  `- runtime.lua
|  |- database/
|  |- ingestion/
|  |- repositories/
|  |- services/
|  |- providers/
|  `- main.lua
`- tests/
```

Expected responsibilities:

- `docs/` — approved threat, data, event, and producer contracts that implementation must follow.
- `producer/` — pure Lua producer helpers designed for versioned vendoring; domain commits do not depend on a running Audit resource.
- `schemas/` — reviewed event-type schemas and non-production reference examples.
- `shared/` — stable contract names, result codes, and non-sensitive shared values.
- `server/core/` — lifecycle, readiness, capability reporting, and dependency adapters.
- `server/database/` — ordered migrations only; no ad hoc schema changes in services.
- `server/ingestion/` — validation, authentication, deduplication, and quarantine.
- `server/repositories/` — the only direct access to Audit-owned tables.
- `server/services/` — search, correlation, retention, redaction, integrity, and alert policy.
- `server/providers/` — replaceable outbound providers such as Discord, console, and signed HTTP.
- `tests/` — contract, repository, failure-state, migration, and integration coverage.

## Development plan

The phased implementation plan is maintained in [Feather Audit Master Plan](../feather-framework-docs/feather-audit/Feather_Audit_Master_Plan.md). Its gates are the source of truth for development order:

1. Decisions and threat model.
2. Contract and producer kit.
3. Secure ingestion foundation.
4. Minimum safe search.
5. Economy and Inventory vertical slice.
6. Feather Admin migration.
7. Outbound alerting and Discord delivery.
8. Remaining mandatory producers.
9. Retention, redaction, archive, and integrity operations.
10. Controlled exports and investigation tooling.
11. Legacy retirement and release.

## Testing status

This initial setup has only static validation available. It has not been started on a RedM server or connected to MySQL. Runtime, database, restart, permission, delivery, and recovery claims must remain unchecked until a suitable development server is available.

When implementation begins, automated tests should cover as much contract and repository behavior as possible without RedM. Live-server checks should be maintained separately and marked pending rather than treated as passed.

Follow [A2 Smoke Tests](docs/A2_SMOKE_TESTS.md) when a RedM/MySQL test server is available. Do not advance to A3 until the required A2 checks pass.

## Security

- Never place Discord webhook URLs, HTTP signing secrets, credentials, or tokens in source-controlled configuration.
- Never expose ingestion or management functions as client-trusted mutation events.
- Never allow arbitrary payloads or arbitrary outbound messages.
- Treat logs and console output as potentially observable; redact sensitive values before writing them.
- Keep all durable Audit table access behind server repositories and versioned APIs.

## Documentation

- [Threat Model](docs/THREAT_MODEL.md)
- [Data and Retention Policy](docs/DATA_POLICY.md)
- [Audit Event Contract v1](docs/EVENT_CONTRACT.md)
- [Producer Requirements](docs/PRODUCER_REQUIREMENTS.md)
- [Generic Producer Integration Guide](docs/PRODUCER_INTEGRATION_GUIDE.md)
- [Producer Kit](producer/README.md)
- [A1 Implementation Status](docs/A1_IMPLEMENTATION_STATUS.md)
- [A2 Smoke Tests](docs/A2_SMOKE_TESTS.md)
- [Ingestion API v1](docs/INGESTION_API.md)
- [Feather Audit Master Plan](../feather-framework-docs/feather-audit/Feather_Audit_Master_Plan.md)
- [Framework Build and Load Order](../feather-framework-docs/Feather_Release_Build_and_Load_Order.md)

Feather Audit is under active development. Test all future phases on a private server before production use.
