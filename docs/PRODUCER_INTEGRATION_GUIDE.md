# Building a Feather Resource for Audit Integration

**Audience:** Authors of any server-side Feather resource that owns authoritative state  
**Status:** Pre-production guidance for the A1/A2 Audit contract  
**Goal:** Make a resource Audit-ready without making its normal operation depend on `feather-audit` being online

This guide is domain-neutral. The examples use placeholder names such as `your-resource` and `domain.subject.completed`; replace them with facts owned by the resource being built.

## The design rule

The resource owns the authoritative operation. Feather Audit owns a durable, searchable projection of significant facts about that operation.

```text
Trusted server request
  -> authorize and validate in the domain
  -> begin one domain database transaction
  -> write authoritative domain state
  -> write immutable Audit event to the domain's outbox
  -> commit
  -> publish the outbox asynchronously
  -> Feather Audit validates, deduplicates, and stores
```

The domain mutation and outbox insertion must commit in the same database transaction. Calling an Audit export, Discord webhook, Lua event, or in-memory queue after the domain commit is not a substitute for the outbox.

If Audit is stopped, unavailable, or not installed yet, committed outbox rows remain local and are delivered later. Audit availability must not be part of the authoritative gameplay transaction.

## What to build now

An Audit-ready resource needs these boundaries:

- A server-only service that owns each authoritative mutation.
- A repository transaction that can write domain state and an outbox row atomically.
- A domain-owned Audit event matrix and versioned schemas.
- An immutable producer outbox table.
- A leased background publisher with retry/backoff.
- Health information for pending, oldest, delivered, and quarantined rows.
- Offline contract fixtures and live restart/replay smoke tests.

Do not add a client event that accepts an arbitrary Audit payload. Client input may request a domain action, but the server constructs the event from authorized identities and committed repository results.

## Step 1: Create an event matrix

Choose significant domain facts rather than logging every function call. Start with state changes, privileged operations, denied high-risk requests, and security-relevant configuration changes.

Maintain a table like this in the producer's documentation:

| Event type/version | Authoritative trigger | Actor | Targets | References | Context | Classification |
| --- | --- | --- | --- | --- | --- | --- |
| `domain.subject.completed@1` | Domain mutation commits | Trusted account/character/system identity | Stable IDs affected by the mutation | Related authoritative records | Small registered facts only | Minimum sensitivity and exact retention class |

For every row, answer:

1. What exact committed fact does the event assert?
2. Which repository result proves it happened?
3. Which values came from trusted server state rather than client input?
4. Which stable IDs let staff find the authoritative records later?
5. Which fields are safe to store, search, export, or eventually send externally?
6. What fixture proves the schema accepts valid input and rejects invalid input?

Use lowercase fact names such as `<domain>.<subject>.<action-or-lifecycle>`. Keep display sentences in `summary`; do not put names, IDs, amounts, or versions in the event type.

## Step 2: Define the schema before emitting

Every event type and version needs a reviewed schema. Unknown context keys are rejected. The schema defines bounded field types, required values, actor constraints, target requirements, minimum sensitivity, and the exact retention class.

Use stable identifiers in `actor`, `targets`, and `references`. Display names are optional snapshots, not identities. Exact decimal values should use documented integer units because the v1 contract rejects floating-point values.

Never include:

- Passwords, tokens, cookies, authorization headers, private keys, or webhook URLs.
- Complete incoming requests or arbitrary metadata tables.
- Unbounded text, translated UI strings, or client-provided identity claims.
- Data merely because it might be useful someday.

Coordinate the schema with the Audit maintainer. The producer owns the meaning and fixtures; Audit owns envelope validation, registration, storage, and safe projections.

## Step 3: Vendor and pin the producer contract

Until Feather ships a shared contract package, vendor a reviewed, pinned copy of the required producer files into the domain resource. Record the source Audit version or commit in the producer repository.

Load them in this order:

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

Do not load these files from the installed `feather-audit` resource and do not use Audit exports to construct or enqueue local events. That would prevent the domain from committing safely while Audit is offline. Treat contract upgrades as reviewed dependency upgrades and run producer conformance tests before deploying them.

## Step 4: Add the domain-owned outbox

The producer owns its outbox table and migration. At minimum, persist:

```text
outbox_id, event_id, contract_version, payload, state,
attempt_count, next_attempt_at, lease_owner, lease_expires_at,
created_at, last_attempt_at, delivered_at, audit_event_id,
last_result_code
```

Required states are `pending`, `leased`, `delivered`, and `quarantined`.

Important invariants:

- `event_id` and payload become immutable when the domain transaction commits.
- Leasing must be database-safe when multiple workers run.
- An expired lease becomes eligible for delivery again.
- Delivered rows remain for a configurable verification period.
- A quarantined row remains inspectable and is not silently rewritten or deleted.
- A timed-out request remains retryable because Audit may have committed before the response was lost.

Use the resource's real transaction abstraction. Do not introduce a generic adapter until a test proves the authoritative mutation and outbox insertion share the same database transaction.

## Step 5: Enqueue at the authoritative boundary

The shape below is illustrative; adapt it to the resource's repository API:

```lua
local function performOperation(command, trustedActor)
    return Repository.Transaction(function(transaction)
        local result = Repository.ApplyMutation(transaction, command)

        local event, validation = FeatherAuditProducerEvent.Build({
            eventType = 'domain.subject.completed',
            eventVersion = 1,
            sourceResource = GetCurrentResourceName(),
            sourceInstance = Config.SourceInstance,
            actor = trustedActor,
            targets = buildTargetsFrom(result),
            references = buildReferencesFrom(result),
            result = 'success',
            reasonCode = 'authorized_operation',
            summary = 'Domain operation completed',
            context = buildRegisteredContextFrom(result),
            sensitivityClass = 'internal',
            retentionClass = 'operational'
        })
        if not event then error(('invalid Audit event: %s'):format(validation.code)) end

        -- AuditOutbox is an instance returned by FeatherAuditProducerOutbox.Create.
        local outboxRow, enqueueError = AuditOutbox.Enqueue(transaction, event, validation)
        if not outboxRow then
            local detail = type(enqueueError) == 'table' and enqueueError.code or enqueueError
            error(('Audit outbox insert failed: %s'):format(tostring(detail)))
        end
        return result
    end)
end
```

Generate and persist the event ID once. A retry of delivery uses the same event ID and byte-equivalent canonical content. A new corrective domain action creates a new event rather than modifying an old outbox payload.

If an event is mandatory and the outbox insert fails, roll back the domain mutation. If the shared transaction commits, return the domain result without waiting for Audit delivery.

## Step 6: Publish asynchronously

The publisher leases bounded batches after commit and calls the server-only export:

```lua
local response = exports['feather-audit']:Ingest(event)
```

Handle outcomes as follows:

| Outcome | Producer action |
| --- | --- |
| `accepted` | Mark delivered and store `auditEventId` |
| `duplicate` | Mark delivered and store the returned original `auditEventId` |
| `retryable_rejection` | Persist the code and schedule exponential backoff with jitter |
| `quarantined` | Stop automatic retries, retain the row, and expose operator attention |
| Export missing, throws, or times out | Treat as retryable; never assume it was not committed |

The publisher may check whether `feather-audit` is started before attempting delivery, but the producer should not declare `feather-audit` as a hard runtime dependency. Discord and other notification providers are downstream Audit concerns; producers never call them as part of Audit delivery.

## Step 7: Register the producer with Audit

Audit must explicitly allow the exact Cfx resource name, source instance, event prefix, versions, and rate limit:

```lua
Config.Producers['your-resource'] = {
    enabled = true,
    sourceInstance = 'frontier-1',
    eventPrefixes = { 'domain.' },
    versions = { [1] = true },
    maxPerMinute = 300
}
```

The same stable `SourceInstance` value must be configured on both sides. Changing the resource name or instance is an identity migration because Audit deduplicates by source resource, source instance, and producer event ID.

Registration is not a schema. Audit must also load the reviewed event schemas before events can be accepted. Deploy registration/schema support before or with the producer; otherwise valid local rows safely accumulate until support is available.

## Step 8: Expose producer health

At minimum, operators should be able to inspect:

- Pending row count and oldest pending age.
- Active/expired leases and attempt counts.
- Last successful delivery time.
- Delivered and quarantined counts.
- Last bounded result code without raw payload or secret output.

A growing backlog is not automatically data loss—the outbox is doing its job—but it must be visible before local storage is exhausted.

## Step 9: Test before production

### Offline tests

No RedM server or loaded player should be required to verify:

- Valid fixtures pass their registered schemas.
- Unknown fields, invalid identities, sparse arrays, oversized values, and prohibited content fail.
- Canonical content is deterministic.
- Event IDs remain stable across retries.
- Publisher state transitions handle accepted, duplicate, retryable, quarantine, timeout, and lease expiry.

### Live server tests

These are server-console tests; a connected or character-loaded player is not required unless the domain's own command explicitly tests a player workflow.

| Scenario | Action | Expected result |
| --- | --- | --- |
| Atomic commit | Run a test mutation | Domain row and outbox row both exist, or neither exists |
| Audit absent | Stop Audit and run the mutation | Domain commits, outbox remains pending, no event is lost |
| Resource restart | Queue, restart producer, inspect status | Pending row survives and becomes eligible |
| First delivery | Start Audit and publish | Response is `accepted`; row becomes delivered |
| Lost acknowledgement | Replay identical committed event | Response is `duplicate` with the same `auditEventId` |
| Invalid permanent event | Publish a controlled invalid fixture | Row becomes quarantined and stops automatic retry |
| Temporary database/Audit failure | Interrupt dependency and restore it | Row retries later without blocking or duplication |
| Lease recovery | Stop publisher after leasing | Expired lease becomes eligible and delivers once |
| Unregistered producer | Remove test registration and publish | Audit rejects it; no raw rejected payload is stored |
| Restart durability | Restart Audit and producer | Accepted event, hash, outbox state, and identity remain stable |

Never mark these tests passed based only on unit tests or code inspection.

## Suggested producer layout

```text
your-resource/
|- docs/
|  |- AUDIT_EVENT_MATRIX.md
|  `- AUDIT_TESTS.md
|- server/
|  |- audit/
|  |  |- publisher.lua
|  |  `- repository.lua
|  |- database/migrations/
|  `- services/
|- vendor/feather-audit-contract/
|  |- VERSION
|  |- shared/
|  `- producer/
|- schemas/
|  `- domain/
`- tests/
   |- fixtures/
   `- audit/
```

Names may follow the resource's conventions; preserving the ownership and transaction boundaries matters more than matching this directory layout.

## Readiness checklist

- [ ] Significant event families and exclusions are documented.
- [ ] Every emitted type/version has a reviewed schema and fixtures.
- [ ] Actor and affected IDs come from trusted server/repository state.
- [ ] Domain mutation and outbox insertion share one proven transaction.
- [ ] Payload and event ID remain immutable after commit.
- [ ] Publisher uses bounded database leases, retry/backoff, and durable outcomes.
- [ ] Audit downtime does not block or lose authoritative committed work.
- [ ] No client can submit an arbitrary Audit event.
- [ ] No secrets, webhook URLs, or unbounded payloads can enter the event.
- [ ] Producer health and quarantine are operator-visible.
- [ ] Audit registration and reviewed schemas are deployed.
- [ ] Offline, restart, replay, failure, and live ingestion tests pass.

## Related documents

- [Event Contract v1](EVENT_CONTRACT.md)
- [Producer Requirements](PRODUCER_REQUIREMENTS.md)
- [Ingestion API v1](INGESTION_API.md)
- [Producer Kit](../producer/README.md)
- [Audit smoke tests](A2_SMOKE_TESTS.md)
- Test-only durable reference resource: `tests/resources/feather-audit-smoke-producer`
