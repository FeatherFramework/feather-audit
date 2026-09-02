FeatherAudit = FeatherAudit or {}

local state = {
    status = FeatherAuditConstants.lifecycle.scaffold,
    ready = false,
    reason = FeatherAuditResults.notImplemented,
    startedAt = os.time()
}

function FeatherAudit.GetHealth()
    return {
        resource = FeatherAuditConstants.resourceName,
        version = GetResourceMetadata(GetCurrentResourceName(), 'version', 0),
        contractVersion = FeatherAuditConstants.contractVersion,
        status = state.status,
        ready = state.ready,
        reason = state.reason,
        startedAt = state.startedAt
    }
end

function FeatherAudit.GetCapabilities()
    return {
        contractVersion = FeatherAuditConstants.contractVersion,
        scaffold = true,
        ingestion = false,
        search = false,
        correlation = false,
        retention = false,
        redaction = false,
        integrity = false,
        notifications = false,
        exports = false
    }
end
