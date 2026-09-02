# A1 Contract and Producer Kit Status

**Phase:** A1  
**Status:** Implemented for static review; execution and live durability gates pending

## Implemented

- `audit_event.v1` constants and stable result codes.
- Deterministic canonical JSON for schema-described Lua values.
- Registered event-type/version schema registry.
- Common envelope, identity, classification, time, context, size, and prohibited-content validation.
- UUIDv4-form event-ID generator for uniqueness, not security.
- Producer event builder with injected clock/ID functions for deterministic tests.
- Storage- and transport-adapter outbox state machine with leasing outcomes, retry/backoff, duplicate acknowledgement, quarantine, and delivery marking.
- Reference Economy transfer schema clearly marked as requiring Economy owner review.
- Unit specifications for canonicalization, validation, and event construction.
- An in-memory failure harness simulating receiver commit followed by lost acknowledgement and safe duplicate replay.
- A server-console contract smoke command covering schema registration, canonical ordering, accepted input, source binding, prohibited content, sparse arrays, and clock skew.
- A test-only MySQL producer fixture that atomically commits a domain record and outbox record, then publishes and replays the same event identity across a resource restart.

The producer modules are pure Lua and intentionally not loaded from the Audit `fxmanifest.lua`. A domain must vendor/version the kit or use a future shared contract package so constructing its local outbox event never depends on the running Audit resource.

## Not yet verified

- The specifications have not executed because no Lua interpreter is installed in the current workspace.
- The RedM/MySQL smoke suites have not yet been run on a live test server.
- The in-memory harness does not prove MySQL transaction atomicity, row leasing, restart durability, or process-crash recovery.
- No production domain has reviewed or adopted a registered schema.
- The A2 hash and ingestion implementation is present but remains live-test pending.

## Gate remaining

A1 is not complete for production until:

1. All offline specifications execute successfully under Lua 5.4.
2. A real producer repository adapter commits a domain mutation and outbox row in one MySQL transaction.
3. A forced process/resource stop after commit and before acknowledgement is replayed after restart.
4. The receiver returns one durable event and duplicate retries resolve to the same `auditEventId`.
5. At least one authoritative domain owner approves its event schema and fixtures.

The exact commands, execution location, player requirement, and expected results are tracked in `docs/A2_SMOKE_TESTS.md`.
