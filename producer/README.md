# Feather Audit Producer Kit

The producer kit constructs and validates `audit_event.v1` records and manages the transport-independent outbox state machine. It is pure Lua so a domain can commit locally while `feather-audit` is stopped or absent.

## Dependency order

Load these files into the producer resource in order:

```text
shared/constants.lua
shared/results.lua
shared/contract/canonical.lua
shared/contract/registry.lua
shared/contract/validator.lua
producer/event_id.lua
producer/event_builder.lua
producer/outbox.lua
owned event schemas
```

For now, producers should vendor a reviewed version of those files. Referencing live Audit exports for event construction or outbox insertion is prohibited because it would make authoritative mutations depend on Audit availability. A future framework contract package may replace vendoring.

## Repository adapter

`FeatherAuditProducerOutbox.Create` requires a repository with:

- `insert(transaction, row)` — insert into the producer's outbox using the caller's existing domain transaction.
- `lease(batchSize, owner, expiresAt, now)` — atomically claim eligible rows and reclaim expired leases.
- `markDelivered(row, auditEventId, result, now)`.
- `markRetry(row, nextAttemptAt, resultCode, attemptCount)`.
- `markQuarantined(row, resultCode, now)`.

The kit deliberately does not provide a generic `oxmysql` repository yet. Each domain's transaction wrapper must be understood and tested before an adapter can honestly guarantee that the domain mutation and outbox insert share one transaction.

## Transport adapter

The transport provides `ingest(event, canonicalPayload)` and returns:

```lua
{ result = 'accepted', auditEventId = '...' }
{ result = 'duplicate', auditEventId = '...' }
{ result = 'retryable_rejection', code = '...' }
{ result = 'quarantined', code = '...' }
```

Timeouts and thrown errors are treated as retryable because Audit may have committed before the acknowledgement was lost.

The initial Cfx transport implementation calls:

```lua
local result = exports['feather-audit']:Ingest(event)
```

Audit independently canonicalizes and validates the event; it does not trust the producer's supplied canonical payload. See [Ingestion API](../docs/INGESTION_API.md).

## Transaction rule

Call `Enqueue` with the active domain transaction before that transaction commits. Do not call it after commit, from an in-memory event handler, or as a replacement for a durable outbox.

See [Producer Requirements](../docs/PRODUCER_REQUIREMENTS.md) and [Event Contract](../docs/EVENT_CONTRACT.md) for the normative rules.
