# Feather Audit

Feather Audit is the cross-domain audit, investigation, and operator-alerting service for the Feather Framework. It will store a normalized, append-only projection of significant events emitted by Feather resources without replacing the authoritative records owned by those resources.

> [!IMPORTANT]
> This resource is currently a development scaffold. Audit ingestion, database migrations, search, retention, Discord delivery, and producer outboxes are not implemented yet. Do not use it as production evidence or assume that starting the resource captures events.

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

The initial scaffold provides:

- A RedM `fxmanifest.lua`.
- Safe default configuration with external delivery disabled.
- Shared contract and lifecycle constants.
- Server-side runtime state.
- `GetHealth` and `GetCapabilities` exports that accurately report the resource as an unimplemented scaffold.
- The intended source directory layout for the phased build.

The scaffold does **not** create tables, register ingestion/search APIs, accept events, or send notifications.

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
4. Review the startup message. Until the first implementation phases are complete, health intentionally reports `scaffold` and `ready = false`.

Starting the scaffold does not enable auditing and does not modify the database.

## Configuration

Safe development defaults live in `config.lua`. External notifications are disabled, and no webhook secret belongs in that file.

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
|- shared/
|  |- constants.lua
|  `- results.lua
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

## Security

- Never place Discord webhook URLs, HTTP signing secrets, credentials, or tokens in source-controlled configuration.
- Never expose ingestion or management functions as client-trusted mutation events.
- Never allow arbitrary payloads or arbitrary outbound messages.
- Treat logs and console output as potentially observable; redact sensitive values before writing them.
- Keep all durable Audit table access behind server repositories and versioned APIs.

## Documentation

- [Feather Audit Master Plan](../feather-framework-docs/feather-audit/Feather_Audit_Master_Plan.md)
- [Framework Build and Load Order](../feather-framework-docs/Feather_Release_Build_and_Load_Order.md)

Feather Audit is under active development. Test all future phases on a private server before production use.
