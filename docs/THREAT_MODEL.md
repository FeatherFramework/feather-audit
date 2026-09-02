# Feather Audit Threat Model

**Contract phase:** A0  
**Status:** Draft decision baseline for team approval  
**Applies to:** `feather-audit` v1

## Security objective

Feather Audit must preserve trustworthy, reviewable evidence that significant operations occurred without becoming an authority for the underlying domain state. It must limit who can write, read, export, redact, configure, and externally deliver that evidence.

Audit improves detection and investigation. It cannot prove that a fully compromised server, database administrator, or host operating system reported the truth.

## Assets to protect

- Event identity, producer identity, content, ordering metadata, and integrity metadata.
- Actor, target, reference, correlation, and reason information.
- Restricted and sealed fields.
- Search, event-detail, export, redaction, integrity, and break-glass access history.
- Producer allowlists and event-schema registrations.
- Alert rules, destinations, delivery state, and provider credentials.
- Retention, archive, backup, and redaction state.
- Availability of ingestion and the ability to recover producer backlog.

Authoritative balances, item ownership, bans, warrants, and other domain state are not Audit assets. Their owning domains remain responsible for them.

## Trust boundaries

1. **Client to server:** clients are untrusted. No client may directly ingest an Audit event or manage Audit policy.
2. **Producing resource to Audit:** server resources are authenticated by runtime invoking-resource identity and an explicit allowlist. Payload identity alone is not trusted.
3. **Audit to database:** the database is a durability dependency. Only Audit repositories may access Audit-owned tables through supported code paths.
4. **Staff to protected APIs:** identity and capabilities must be resolved server-side. UI visibility is never authorization.
5. **Audit to external providers:** Discord, HTTP endpoints, email, and similar systems are less trusted than Audit storage and receive only an external-safe projection.
6. **Operator and host boundary:** server owners and database/host administrators are operationally trusted but remain in the threat model for mistakes, credential exposure, and detectable tampering.

## Threat actors and required controls

### Compromised or malicious client

Threats:

- Fabricating events or actor identity.
- Calling management or search operations without permission.
- Supplying oversized, deeply nested, or secret-bearing payloads.

Controls:

- No network-registered ingestion mutation.
- Server-only exports and server-side authorization.
- Schema allowlists, size/depth limits, bounded strings, and prohibited-field/value checks.
- Client input is never copied wholesale into event context.

### Buggy, outdated, or malicious server resource

Threats:

- Claiming another producer identity.
- Emitting invalid, misleading, duplicated, or excessive events.
- Smuggling secrets or unrestricted payloads into context.
- Using Audit as an arbitrary webhook relay.

Controls:

- Verify runtime invoker against configured producer registration and declared `source_resource`.
- Register allowed event-type prefixes and versions per producer.
- Per-producer rate and payload limits.
- Deduplicate on `(source_resource, source_instance, event_id)`.
- Quarantine permanent contract violations and alert operators.
- External deliveries arise only from operator-owned rules over accepted events.

Audit cannot determine whether an allowlisted producer truthfully represented its own authoritative operation. Domain code review and producer conformance tests remain required.

### Careless or malicious staff member

Threats:

- Searching players without a legitimate purpose.
- Exporting, sharing, or correlating restricted information.
- Weakening alert rules, destinations, retention, or redaction policy.
- Abusing break-glass access.

Controls:

- Narrow Authority capabilities and server-side field redaction.
- Reason-required sensitive access and exports where policy requires it.
- Non-recursive access events for sensitive searches, details, exports, integrity operations, and break-glass use.
- Revisioned, attributable policy changes.
- Time-limited break-glass access with prominent operator notification.
- Fail closed for sensitive reads when identity or Authority is unavailable.

### External provider or leaked provider credential

Threats:

- Discord or webhook content becoming public.
- Deleted or edited notifications being mistaken for evidence.
- A leaked URL being used to spam a destination.
- Provider response bodies or errors leaking secrets into logs.

Controls:

- Audit storage is always authoritative over provider delivery.
- Secrets stay in a protected server-side source and are never returned by APIs.
- Destination sensitivity ceilings and external-safe templates.
- Mention restrictions, formatting escaping, message-size limits, rate limits, and bounded diagnostics.
- Credential rotation and provider-disable runbooks.
- Provider failure never blocks Audit ingestion or a domain transaction.

### Database tampering or accidental modification

Threats:

- Editing or deleting events.
- Altering indexes or redaction state.
- Restoring an incomplete backup and replaying events incorrectly.

Controls:

- Audit-owned repositories and no supported direct-table consumers.
- Canonical per-record hashes, scheduled verification, and protected results.
- Attributable redaction transitions rather than silent mutation.
- Backup, restore, reconciliation, and outbox replay procedures.
- Future signed checkpoints if the approved threat model requires evidence outside the database trust boundary.

Per-record hashes detect changes but do not protect against an administrator who can alter both content and hashes. Signed external checkpoints are explicitly deferred.

### Denial of service and storage exhaustion

Threats:

- Event floods, duplicate floods, pathological searches, large exports, or notification storms.
- Audit downtime causing producer backlog growth.

Controls:

- Per-producer limits, bounded payloads, indexed and time-bounded queries, cursor pagination, and asynchronous exports.
- Storage capacity alerts and retention jobs.
- Producer backlog age/count health and controlled replay throughput.
- Notification cooldown, deduplication, coalescing, and dead-letter limits.
- Pause nonessential exports and notifications before ingestion under pressure.

## Security invariants

- A client cannot directly create an Audit event.
- An event is durably accepted before external notification evaluation.
- Audit unavailability does not roll back an authoritative domain mutation whose local transaction and outbox committed.
- Payload-declared source identity never overrides verified invoker identity.
- Unknown or unavailable authorization fails closed for protected reads and management.
- Restricted data is redacted before it reaches a client or external provider.
- Provider credentials never enter events, search results, exports, or ordinary logs.
- Authorized redaction is distinguishable from unexplained tampering.
- Audit is never used to reconstruct or override authoritative domain state.

## Explicit non-goals for v1

- Protection against a fully compromised host that controls resource code, process memory, database, backups, and signing material.
- Behavioral fraud detection or automated punishment.
- Content moderation or retention of general chat messages.
- Full distributed ordering across independent producers.
- External signed checkpoints or immutable third-party evidence custody.
- General analytics and high-frequency gameplay telemetry.

## Approval questions

The A0 gate requires team agreement on these items before production implementation:

1. Is a compromised allowlisted server resource within the v1 prevention boundary, or only detectable through schema/rate controls?
2. Which roles may use break-glass access, and where is its bootstrap authority stored?
3. Does any deployment require signed checkpoints outside the primary database?
4. Which external destinations, if any, may receive `restricted` projections? The proposed v1 default is none.
5. Who owns incident response for quarantine growth, integrity failure, and leaked destination credentials?
