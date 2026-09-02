# Feather Audit Event Contract v1

**Contract name:** `audit_event.v1`  
**Contract version:** `1`  
**Status:** Draft decision baseline for A1 implementation

## Envelope

```lua
{
    contractVersion = 1,
    eventId = '01J...',
    eventType = 'economy.transfer.completed',
    eventVersion = 1,
    occurredAt = '2026-09-02T18:24:31.123Z',
    sourceResource = 'feather-economy',
    sourceInstance = 'frontier-1',
    invokingResource = 'bcc-shops',
    correlationId = 'order-221',
    causationId = 'request-220',
    actor = {
        type = 'character',
        id = 'character-uuid',
        accountId = 'account-uuid',
        displayName = 'James'
    },
    targets = {
        { type = 'account', id = 'account-1', role = 'debit' },
        { type = 'account', id = 'account-2', role = 'credit' }
    },
    references = {
        { resource = 'bcc-shops', type = 'shop_order', id = 'order-221' }
    },
    result = 'success',
    reasonCode = 'shop_purchase',
    summary = 'Transfer completed',
    context = {
        amount = 50001029912,
        currency = 'dollars'
    },
    sensitivityClass = 'internal',
    retentionClass = 'financial'
}
```

The Lua shape is the producer contract. Audit storage may normalize it into multiple tables. Storage columns are not a public producer API.

## Required fields

| Field | Type | Requirement |
|---|---|---|
| `contractVersion` | positive integer | Must equal a supported common-envelope version; v1 requires `1` |
| `eventId` | string | Producer-generated, durable, never reused within the deduplication scope |
| `eventType` | string | Registered lowercase namespaced fact |
| `eventVersion` | positive integer | Version of the registered event-type payload |
| `occurredAt` | string | UTC RFC 3339 timestamp with `Z`; fractional seconds recommended |
| `sourceResource` | string | Authoritative producer; must match verified runtime invoker registration |
| `sourceInstance` | string | Configured server/world instance identifier |
| `actor` | object | Typed actor, including `system` when no person initiated the operation |
| `targets` | array | May be empty only when the event schema explicitly permits it |
| `references` | array | May be empty |
| `result` | enum | `success`, `failed`, `denied`, or `cancelled` |
| `reasonCode` | string | Stable machine-readable reason; use `unspecified` only when schema permits |
| `summary` | string | Bounded non-authoritative display text; may be empty when schema permits |
| `context` | object | Schema-registered keys only; may be empty |
| `sensitivityClass` | enum | `public`, `internal`, `restricted`, or `sealed` |
| `retentionClass` | enum | `operational`, `administrative`, `security`, `financial`, or `legal` |

Optional fields are `invokingResource`, `correlationId`, and `causationId`. An event-type schema may make any optional field required.

## Naming rules

### Event type

Use lowercase dot-separated facts:

```text
<domain>.<subject>.<action-or-lifecycle>
```

Examples:

- `economy.transfer.completed`
- `economy.adjustment.denied`
- `inventory.item.granted`
- `admin.player.banned`
- `authority.assignment.revoked`
- `audit.export.requested`

The final component may express lifecycle, while `result` independently records the outcome. Do not encode IDs, amounts, display names, or version numbers in the event type.

### Reason codes and roles

`reasonCode`, target `role`, and registered context keys use lowercase snake case. They are stable API values, not translated messages.

### Resource names

Resource identifiers use the actual lowercase Cfx resource name. Audit verifies `sourceResource` against the invoking resource rather than trusting the payload.

## Identity rules

### Event ID and deduplication

- IDs are opaque ASCII strings matching `^[A-Za-z0-9][A-Za-z0-9._:-]*$`.
- Length is 1–128 bytes; UUID or ULID is recommended for new producers.
- The producer creates the ID before or while inserting the outbox row and persists it with that row.
- Audit deduplicates on `(sourceResource, sourceInstance, eventId)`.
- A retry uses the identical ID and byte-equivalent canonical event content.
- Reusing an accepted ID with different canonical content is quarantined as `event_identity_conflict`.
- Legacy imports may use deterministic IDs such as `legacy-action:<row-id>` when source and instance scopes prevent collision.

Audit assigns a separate internal `auditEventId` when accepted. Duplicate responses return the original internal ID.

### Correlation and causation

- `correlationId` identifies the complete cross-resource workflow and should be propagated unchanged.
- `causationId` identifies the immediately preceding request, command, or event when known.
- Both are opaque ASCII strings of 1–128 bytes using the event-ID character set.
- Correlation does not imply transaction atomicity or global ordering.
- A producer must not invent a new correlation ID when a valid upstream one was supplied.

### Actor

Allowed v1 actor types:

- `account`
- `character`
- `staff`
- `organization`
- `resource`
- `system`

`actor.type` and `actor.id` are required. `system` uses a stable configured ID such as `retention-worker`, never a blank actor. Optional `accountId`, `characterId`, `resource`, and `displayName` are allowed only by the registered event schema.

Actor snapshots describe identity observed at event time; they do not grant authority and are not used to resolve current identity.

### Targets

Allowed base target types are `account`, `character`, `organization`, `resource`, `transaction`, `item_instance`, `inventory`, `case`, `warrant`, `policy`, `assignment`, `audit_event`, and `destination`. Event schemas may register additional namespaced types.

Each target requires `type`, `id`, and `role`. Optional `resource` and `displayName` require schema permission.

### References

Each reference requires `resource`, `type`, and `id`. References locate authoritative or related records; Audit does not copy their authoritative state.

## V1 limits

Limits are measured after UTF-8 encoding and before persistence.

| Item | Limit |
|---|---:|
| Complete canonical event payload | 32 KiB |
| `context` canonical payload | 16 KiB |
| Summary | 256 bytes |
| Event/resource/type/reason/role keys | 128 bytes each |
| Display-name snapshot | 128 bytes |
| Identifier/correlation/reference values | 128 bytes each |
| Targets | 16 |
| References | 16 |
| Context keys across all levels | 64 |
| Context nesting below `context` | 4 levels |
| Array values inside registered context | 32 elements |

Strings must be valid UTF-8 and contain no NUL bytes or unapproved control characters. The validator rejects NaN, infinity, functions, userdata, threads, cycles, sparse arrays, and mixed array/object tables.

All v1 numeric values are safe JSON integers between `-9,007,199,254,740,991` and `9,007,199,254,740,991`. Domains represent exact decimal values, including money, as integer minor units or another documented integer scale. Floating-point values are rejected so canonical content is stable across runtimes.

Event schemas may set smaller limits but cannot exceed the common v1 limits.

## Time rules

- `occurredAt` is UTC RFC 3339 and ends in `Z`.
- Fractional seconds up to millisecond precision are retained in v1.
- Audit adds `ingestedAt`; producers do not supply it.
- Events more than five minutes ahead of Audit time are accepted with a `producer_clock_ahead` health warning up to a hard limit of 24 hours.
- Events more than 24 hours in the future are quarantined as `occurred_at_future`.
- Old events are permitted for backlog recovery and approved imports and are measured as ingestion lag; age alone is not a validation failure.
- Search ordering uses `(occurredAt, auditEventId)` where event chronology is requested and `(ingestedAt, auditEventId)` for stable ingestion views. Audit does not claim a total causal order across producers.

## Context schemas

Every event type/version has a registered context schema owned by its producer domain. A schema defines:

- Required and optional context keys.
- Scalar type, numeric bounds, string bounds, and enum values.
- Field sensitivity and whether a field may be searched, exported, or evaluated by alert rules.
- Safe display and external-notification projection rules.
- Required actor, target, reference, correlation, and retention behavior.

Unknown context keys are rejected by default. A schema may explicitly declare `unknownFieldPolicy = 'strip'` only for a compatibility window; stripped field names are reported without their values. `allow` is not a valid v1 policy.

## Versioning and compatibility

- `contractVersion` changes only for an incompatible envelope change.
- `eventVersion` changes when one event type changes its registered fields or semantics.
- Adding an optional context field may use the same event version only when old validators are defined to reject or strip it safely; otherwise increment the version.
- Removing, renaming, narrowing, or changing the meaning of a field requires a new event version.
- Audit may support multiple event versions concurrently. Unsupported versions are quarantined, never guessed.
- Producers must publish fixtures for every supported event version.
- Stored events are not rewritten merely because a newer event version exists.

## Validation and ingestion outcomes

Validation order:

1. Verify server-only invocation and producer allowlist.
2. Verify source resource and instance binding.
3. Enforce raw request and common-envelope size limits.
4. Parse and validate the common envelope.
5. Resolve the registered event type/version schema.
6. Validate actor, targets, references, context, sensitivity, and retention.
7. Scan prohibited fields and values without reproducing them in diagnostics.
8. Canonicalize and evaluate deduplication identity.
9. Persist the accepted event atomically.

Results:

| Result | Meaning |
|---|---|
| `accepted` | New event was durably stored |
| `duplicate` | Identical event identity/content was already stored |
| `retryable_rejection` | Temporary dependency, capacity, or transaction failure |
| `quarantined` | Permanent contract, identity, schema, or policy violation |

Stable quarantine reason codes include `producer_not_allowed`, `source_mismatch`, `instance_mismatch`, `payload_too_large`, `contract_unsupported`, `event_schema_unknown`, `event_version_unsupported`, `field_invalid`, `context_unknown_field`, `prohibited_content`, `occurred_at_future`, and `event_identity_conflict`.

Diagnostics identify bounded field paths and stable codes but never echo detected secrets or complete rejected payloads.

## Canonicalization requirements

The A1 canonical serializer uses UTF-8 JSON with lexicographically sorted object keys, contiguous arrays, JSON escaping for control characters, lowercase `true`/`false`/`null`, and base-10 safe integers without leading zeroes. Zero is always serialized as `0`. Floating point, NaN, infinity, sparse/mixed tables, cycles, non-string object keys, invalid UTF-8, and unsupported Lua values are rejected.

Empty Lua tables are ambiguous, so envelope `targets` and `references` are schema-forced arrays while `actor` and `context` are objects. Registered context schemas similarly declare every nested object and array. Timestamps retain the validated RFC 3339 string supplied by the producer; Audit does not silently rewrite event content.

Canonical serialization is implemented in `shared/contract/canonical.lua`. Integrity hashing remains unavailable until A2 selects and implements the hash primitive and persistence boundary.
