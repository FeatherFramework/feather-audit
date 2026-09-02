# Feather Audit Producer Requirements

**Contract phase:** A0  
**Status:** Draft decision baseline for A1 producer kit

## Producer eligibility

Only explicitly registered server resources may ingest events. Registration defines:

- Exact Cfx resource name.
- Allowed event-type prefixes and event versions.
- Expected source instance.
- Per-event and throughput limits.
- Schema owner and operational contact.
- Whether legacy import is allowed.

Audit verifies runtime invoking-resource identity. `sourceResource` in the payload is an assertion to compare, not an authentication mechanism. Client network events must never reach the ingestion function directly or through a pass-through server handler.

## Required mutation pattern

For every material domain mutation:

1. Validate input and authorization in the authoritative domain.
2. Begin the domain database transaction.
3. Apply and verify the authoritative state change.
4. Construct the registered Audit event from trusted server-side facts.
5. Insert the immutable event into the producer outbox in the same transaction.
6. Commit the transaction.
7. Publish asynchronously after commit.

If the state change commits but its outbox event does not, the producer is non-conforming. An in-memory queue, `TriggerEvent`, post-commit callback, console log, or direct Discord webhook is not a durable outbox.

Read-only security events that have no domain mutation still require durable local recording before asynchronous publication. The producer must define the authoritative durable operation with which the event is committed.

## Minimum outbox record

```text
audit_outbox
  outbox_id
  event_id
  contract_version
  payload
  state
  attempt_count
  next_attempt_at
  lease_owner
  lease_expires_at
  created_at
  last_attempt_at
  delivered_at
  audit_event_id
  last_result_code
```

Required states are `pending`, `leased`, `delivered`, and `quarantined`. A lease that expires before acknowledgement returns to eligible pending work. Publisher concurrency must use database-safe leasing rather than assuming one process or thread.

The payload and event ID are immutable after domain commit. Correcting a quarantined event requires an explicit remediation procedure; ordinary retry does not edit it in place.

## Publisher behavior

- Deliver only committed outbox rows.
- Use bounded batches and leases.
- Preserve event ID and canonical content across retries.
- Treat `accepted` and `duplicate` as delivered.
- Retry `retryable_rejection` with exponential backoff and jitter.
- Stop automatic retries for `quarantined`, retain the row, and expose an operator alert.
- Persist returned `auditEventId` when the domain needs stable evidence linking.
- Never delete a row merely because a request timed out; its outcome may be unknown and safe retry is required.
- Retain delivered rows for a configurable verification window before pruning.
- Expose pending count, oldest pending age, attempt count, quarantine count, and last successful delivery.

Suggested v1 retry defaults for the A1 producer kit are a 1-second initial delay, doubling to a 5-minute maximum, full jitter, and no fixed attempt limit for retryable failures. Operators must be able to pause replay without deleting backlog.

## Source and instance binding

- `sourceResource` equals the registered invoking resource.
- `sourceInstance` comes from stable server configuration shared with Audit, not player input or an arbitrary per-start random value.
- A renamed resource is a producer identity migration, not a transparent cosmetic change.
- `invokingResource` identifies an upstream resource that requested the domain operation; it does not replace the verified source.
- The producer obtains upstream identity server-side when possible and never trusts a client-provided invoking-resource string.

## Event construction

- Generate the event ID before inserting the outbox row.
- Generate `occurredAt` from server UTC at the point the authoritative outcome becomes known.
- Propagate an existing correlation ID across the workflow; create one at the entry point only when none exists.
- Record the immediate causation ID when known.
- Resolve actor and targets from authoritative server identity and repository results.
- Use stable result and reason codes.
- Include only registered, bounded context fields.
- Apply at least the schema's minimum sensitivity and use its exact retention class. Retention classes are policy categories rather than an ordered scale; changing one requires a reviewed schema revision.
- Never place translated UI text, complete request payloads, or secrets in context.

## Event selection

Producers emit significant facts, not every internal step. Mandatory v1 families are:

| Producer | Required families |
|---|---|
| Admin | Staff mutations; denied/blocked high-risk actions; case evidence attachment changes |
| Authority | Assignment, grant, revoke, policy revision, bootstrap, and break-glass changes |
| Economy | Transfer, issuance, destruction, adjustment, and material reconciliation outcomes |
| Inventory | Privileged inspection, grant, removal, destruction, and adjustment outcomes |
| Justice | Sealed access and material case/warrant/charge/sentence lifecycle changes |
| Audit | Sensitive access, export, redaction, integrity, rule/destination changes, break-glass use, and manual delivery retry |

Routine reads, movement telemetry, UI navigation, successful permission checks, and internal implementation steps are excluded unless a registered security or investigation requirement says otherwise.

Each producer must maintain an event matrix listing event type/version, trigger boundary, actor, targets, references, context fields, minimum classifications, and fixtures before onboarding.

## Failure behavior

- Audit unavailable: commit the domain transaction and outbox; publisher retries later.
- Audit slow: publisher respects timeout and retries without holding domain transaction locks.
- Invalid event: quarantine without undoing an already committed domain operation.
- Producer outbox unavailable: fail the domain mutation because durable audit commitment cannot be made for a mandatory event.
- Backlog pressure: continue authoritative work while local durable capacity remains safe; expose health and apply an operator-defined circuit breaker before storage exhaustion.
- Notification provider unavailable: no producer action; provider delivery is downstream of accepted Audit storage.

## Schema ownership and change process

- The authoritative domain owns its event semantics and fixtures.
- Audit owns the common envelope, registration, validation policy, and projection.
- A schema change is reviewed by both owners.
- Unsupported producer versions must be discovered before deployment through conformance tests and capability checks.
- Producers do not query Audit tables or depend on Audit storage layout.
- Producers do not use Audit search results to make authoritative business decisions.

## Conformance gate

A producer is not production-ready until automated tests prove:

- Mutation and outbox insertion share one transaction.
- A crash after commit and before publish loses no event.
- Duplicate and concurrent delivery create one Audit record.
- Timeout followed by retry is safe.
- Lease expiry returns work to the queue.
- Permanent invalid events stop retrying and remain inspectable.
- Backlog survives resource and database restart.
- Event fixtures pass the registered contract validator.
- Actor/source identity cannot be replaced by client input.
- Secrets and oversized context are rejected before persistence.

Live RedM/MySQL restart checks may remain marked pending while no test server is available, but they cannot be reported as passed or waived for production release.
