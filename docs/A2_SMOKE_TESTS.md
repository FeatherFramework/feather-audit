# A2 Secure Ingestion Smoke Tests

**Phases:** A1-A2  
**Status:** Ready to run; not yet executed  
**Environment required:** RedM server, `oxmysql`, MySQL/MariaDB test database

## Preparation

1. Back up the test database.
2. Start `oxmysql` and `feather-core` before `feather-audit`.
3. Set a stable test value such as `Config.SourceInstance = 'local-dev-1'`.
4. Set `Config.Development.smokeCommands = true`.
5. Keep external notifications disabled.
6. Start `feather-audit` and confirm the console reports one applied/known migration and ingestion v1 ready.

The smoke commands are server-console-only. None require a connected or loaded player, and none should be entered in a player's F8 console. Do not expose them to players and disable them again after testing.

## Command matrix

| Command | Phase | Run from | Player loaded? | Expected result |
| --- | --- | --- | --- | --- |
| `AuditContractSmokeTest` | A1 | Server console | No | `done 7/7 passed` |
| `AuditDependencySmokeTest` | A2 | Server console | No | `done 4/4 passed` |
| `AuditHealthSmokeTest` | A2 | Server console | No | `done 4/4 passed` |
| `AuditMigrationSmokeTest` | A2 | Server console | No | `done 7/7 passed` |
| `AuditIngestionSmokeTest` | A2 | Server console | No | `done 11/11 passed` |
| `AuditProducerQueueSmokeTest` | A1-A2 fixture | Server console | No | Reports an atomic domain/outbox commit and its producer event ID |
| `AuditProducerPublishSmokeTest` | A1-A2 fixture | Server console | No | Reports `accepted` and an `auditEventId` |
| `AuditProducerReplaySmokeTest` | A1-A2 fixture | Server console | No | Reports `duplicate`, the same `auditEventId`, and `PASS` |
| `AuditProducerStatusSmokeTest` | A1-A2 fixture | Server console | No | Reports the fixture as delivered |

An optional offline suite can be run from a local shell with `lua tests/run.lua`; it needs neither RedM nor a player and should end with `PASS 6 specifications`. A Lua 5.4 interpreter is required.

## Required commands

Run in this order:

```text
AuditContractSmokeTest
AuditDependencySmokeTest
AuditHealthSmokeTest
AuditMigrationSmokeTest
AuditIngestionSmokeTest
```

Expected totals:

- `AuditContractSmokeTest`: 7/7.
- `AuditDependencySmokeTest`: 4/4.
- `AuditHealthSmokeTest`: 4/4.
- `AuditMigrationSmokeTest`: 7/7.
- `AuditIngestionSmokeTest`: 11/11.

The ingestion smoke test creates two `operational` test events: the main fixture and an intentionally old/out-of-order fixture. It also creates quarantine records for an identity conflict, unknown context field, unsupported event version, prohibited webhook-like content, and oversized context. It does not delete existing records or store rejected raw payloads.

## Restart verification

1. Run `AuditIngestionSmokeTest` once and retain its console output.
2. Restart only `feather-audit`.
3. Run `AuditDependencySmokeTest`, `AuditHealthSmokeTest`, and `AuditMigrationSmokeTest` again.
4. Confirm the migration ledger remains one row and no checksum error appears.
5. Confirm prior smoke rows remain in `feather_audit_events` and `feather_audit_quarantine`.

The built-in command generates a new producer event ID each run. Use the durable producer fixture below for exact cross-restart replay of one event identity.

## Durable producer fixture

The test-only resource at `tests/resources/feather-audit-smoke-producer` commits a fixture domain row and outbox row in the same MySQL transaction. Install/ensure that resource only on the test server.

Set its `SmokeConfig.sourceInstance` to the same value as Audit, then add this temporary Audit registration:

```lua
Config.Producers['feather-audit-smoke-producer'] = {
    enabled = true,
    sourceInstance = 'local-dev-1',
    eventPrefixes = { 'audit.smoke.' },
    versions = { [1] = true },
    maxPerMinute = 60
}
```

Run:

```text
AuditProducerQueueSmokeTest
```

Restart `feather-audit-smoke-producer` before publishing to prove the pending outbox survives resource restart. Then run:

```text
AuditProducerPublishSmokeTest
AuditProducerReplaySmokeTest
AuditProducerStatusSmokeTest
```

Expected results:

- Queue reports an atomic commit.
- First publish reports `accepted`.
- Replay reports `duplicate` with the same `auditEventId` and passes.
- Status shows the fixture as delivered.

To verify invoker rejection, temporarily remove/disable the registration, restart Audit, queue a new fixture, and publish it. The publish command must report `quarantined:producer_not_allowed`, while Audit must not create a quarantine database row for that unregistered caller. Restore the registration before the durable replay test.

## Manual database inspection

Verify:

```sql
SELECT id, checksum, applied_at
FROM feather_audit_schema_migrations;

SELECT audit_event_id, source_resource, source_instance, producer_event_id,
       event_type, result, sensitivity_class, retention_class,
       occurred_at, ingested_at, integrity_hash
FROM feather_audit_events
WHERE source_resource = 'feather-audit-smoke'
ORDER BY ingested_at DESC
LIMIT 10;

SELECT source_resource, producer_event_id, rejection_code, rejection_path,
       occurrence_count, state, last_seen_at
FROM feather_audit_quarantine
WHERE source_resource = 'feather-audit-smoke'
ORDER BY last_seen_at DESC
LIMIT 10;
```

Confirm:

- Exactly one event exists for each `(source_resource, source_instance, producer_event_id)`.
- The event has two target/reference child expectations appropriate to the fixture: one target and zero references.
- `integrity_hash` contains 64 hexadecimal characters.
- Quarantine rows contain codes and paths but no raw rejected payload or webhook-like secret.
- Restarting Audit does not change the stored canonical payload or integrity hash.

## Failure exercises

These require temporary test-only configuration changes:

1. Set an invalid empty `SourceInstance`; Audit must remain unavailable with `configuration_invalid` and must not expose ready ingestion.
2. Restore the instance and restart; Audit must become ready.
3. Lower the smoke producer rate limit in `server/ingestion/service.lua` only on a disposable branch or use a temporary registered producer limit, then confirm excess requests return `retryable_rejection` with `producer_rate_limited` rather than entering quarantine.
4. Temporarily alter the recorded migration checksum in a disposable database and restart. Audit must remain unavailable with a checksum mismatch. Restore the database afterward; never change the migration source checksum to accommodate drift.

## Gate

Do not start A3 until:

- All five built-in command suites pass.
- Migration rerun and resource restart pass.
- Stored hash comparison passes.
- A registered real producer can call the `Ingest` export while an unregistered resource is rejected.
- A producer outbox retry across restart resolves to the same `auditEventId`.
- Any runtime or SQL incompatibility discovered during testing is corrected and the complete suite is rerun.
