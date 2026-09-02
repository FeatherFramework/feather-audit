# Audit Ingestion API v1

**Export:** `Ingest`  
**Transport name:** `audit.ingest.v1`  
**Availability:** Server only

## Registration

Audit accepts only exact invoking resources registered in `Config.Producers`. A registration limits source instance, event-type prefixes, event versions, and requests per minute.

```lua
Config.Producers = {
    ['feather-economy'] = {
        enabled = true,
        sourceInstance = 'frontier-1',
        eventPrefixes = { 'economy.' },
        versions = { [1] = true },
        maxPerMinute = 600
    }
}
```

The corresponding event schemas must also be loaded by Audit. Registration alone does not allow an unknown event type.

## Call

```lua
local response = exports['feather-audit']:Ingest(event)
```

Audit obtains the invoking resource from the Cfx runtime. It does not accept a caller-supplied producer identity argument. Never wrap this export in a client-accessible network event.

## Responses

```lua
{
    result = 'accepted',
    auditEventId = 'database UUID',
    warnings = {}
}

{
    result = 'duplicate',
    auditEventId = 'original database UUID',
    warnings = {}
}

{
    result = 'retryable_rejection',
    code = 'audit_not_ready | producer_rate_limited | database_error | quarantine_unavailable',
    warnings = {}
}

{
    result = 'quarantined',
    auditEventId = 'present only for an identity conflict with an existing event',
    code = 'stable rejection code',
    path = '$.bounded.field.path',
    warnings = {}
}
```

The producer marks `accepted` and `duplicate` as delivered. It retries `retryable_rejection` with backoff. It stops automatic retry and alerts operators for `quarantined`.

Thrown export errors or timeouts are treated as retryable because Audit may have committed before acknowledgement was lost.

## Security behavior

- Unregistered resources are rejected without creating quarantine rows.
- A registered caller cannot claim another `sourceResource` or unexpected `sourceInstance`.
- Event type/version must be permitted by both registration and a loaded schema.
- Quarantine stores identity and bounded diagnostics, never the raw rejected payload.
- No notification provider runs during A2 ingestion.
