local function printChecks(command, checks)
    local passed = 0
    for _, check in ipairs(checks) do
        if check[2] then passed = passed + 1 end
        print(('[%s] %s %s'):format(command, check[2] and 'PASS' or 'FAIL', check[1]))
    end
    print(('[%s] done %d/%d passed'):format(command, passed, #checks))
end

local function enabled(source, command)
    if source ~= 0 then return false end
    if Config.Development.smokeCommands then return true end
    print(('[%s] disabled; set Config.Development.smokeCommands = true on a test server'):format(command))
    return false
end

local function smokeEvent(eventId, sequence, summary)
    return {
        contractVersion = 1,
        eventId = eventId,
        eventType = 'audit.smoke.ingested',
        eventVersion = 1,
        occurredAt = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        sourceResource = 'feather-audit-smoke',
        sourceInstance = Config.SourceInstance,
        actor = { type = 'system', id = 'console-smoke' },
        targets = {
            { type = 'resource', id = 'feather-audit', role = 'subject' }
        },
        references = {},
        result = 'success',
        reasonCode = 'smoke_test',
        summary = summary or 'Audit ingestion smoke event',
        context = { sequence = sequence, message = 'Safe test fixture' },
        sensitivityClass = 'internal',
        retentionClass = 'operational'
    }
end

RegisterCommand('AuditContractSmokeTest', function(source)
    local command = 'AuditContractSmokeTest'
    if not enabled(source, command) then return end

    local schema = FeatherAuditSchemaRegistry.Get('audit.smoke.ingested', 1)
    local canonicalA = FeatherAuditCanonical.Encode({ zebra = 2, alpha = 1 }, { type = 'object' })
    local canonicalB = FeatherAuditCanonical.Encode({ alpha = 1, zebra = 2 }, { type = 'object' })
    local valid = FeatherAuditValidator.Validate(smokeEvent('smoke:contract-valid', 1), {
        nowEpoch = os.time(),
        sourceResource = 'feather-audit-smoke',
        sourceInstance = Config.SourceInstance
    })
    local mismatch = FeatherAuditValidator.Validate(smokeEvent('smoke:contract-source', 2), {
        nowEpoch = os.time(),
        sourceResource = 'different-resource',
        sourceInstance = Config.SourceInstance
    })
    local prohibitedEvent = smokeEvent('smoke:contract-secret', 3)
    prohibitedEvent.summary = 'https://discord.com/api/webhooks/123/not-a-real-secret'
    local prohibited = FeatherAuditValidator.Validate(prohibitedEvent, {
        nowEpoch = os.time(),
        sourceResource = 'feather-audit-smoke',
        sourceInstance = Config.SourceInstance
    })
    local sparseEvent = smokeEvent('smoke:contract-sparse', 4)
    sparseEvent.targets[3] = { type = 'resource', id = 'gap', role = 'subject' }
    local sparse = FeatherAuditValidator.Validate(sparseEvent, {
        nowEpoch = os.time(),
        sourceResource = 'feather-audit-smoke',
        sourceInstance = Config.SourceInstance
    })
    local futureEvent = smokeEvent('smoke:contract-future', 5)
    futureEvent.occurredAt = '2099-01-01T00:00:00Z'
    local future = FeatherAuditValidator.Validate(futureEvent, {
        nowEpoch = os.time(),
        sourceResource = 'feather-audit-smoke',
        sourceInstance = Config.SourceInstance
    })

    printChecks(command, {
        { 'smoke event schema registered', schema ~= nil },
        { 'canonical object ordering is deterministic', canonicalA ~= nil and canonicalA == canonicalB },
        { 'valid registered event accepted by contract', valid.ok == true },
        { 'source mismatch rejected', mismatch.ok == false and mismatch.code == FeatherAuditResults.sourceMismatch },
        { 'prohibited webhook content rejected', prohibited.ok == false and prohibited.code == FeatherAuditResults.prohibitedContent },
        { 'sparse target array rejected', sparse.ok == false and sparse.code == FeatherAuditResults.fieldInvalid },
        { 'event beyond clock-skew limit rejected', future.ok == false and future.code == FeatherAuditResults.occurredAtFuture }
    })
end, true)

RegisterCommand('AuditDependencySmokeTest', function(source)
    local command = 'AuditDependencySmokeTest'
    if not enabled(source, command) then return end

    local databaseCallOk, databaseValue = pcall(function()
        return DB.value('SELECT 1')
    end)
    local currentResource = GetCurrentResourceName()
    printChecks(command, {
        { 'oxmysql resource started', GetResourceState('oxmysql') == 'started' },
        { 'feather-core resource started', GetResourceState('feather-core') == 'started' },
        { 'feather-audit resource started', GetResourceState(currentResource) == 'started' },
        { 'database responds to SELECT 1', databaseCallOk and tonumber(databaseValue) == 1 }
    })
end, true)

RegisterCommand('AuditMigrationSmokeTest', function(source)
    local command = 'AuditMigrationSmokeTest'
    if not enabled(source, command) then return end
    local requiredTables = {
        'feather_audit_schema_migrations', 'feather_audit_events',
        'feather_audit_targets', 'feather_audit_references',
        'feather_audit_quarantine', 'feather_audit_access_events'
    }
    local checks = {}
    for _, tableName in ipairs(requiredTables) do
        local count = tonumber(DB.value([[SELECT COUNT(*) FROM information_schema.TABLES
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?]], tableName)) or 0
        checks[#checks + 1] = { tableName .. ' exists', count == 1 }
    end
    local ledger = tonumber(DB.value(
        'SELECT COUNT(*) FROM feather_audit_schema_migrations')) or 0
    checks[#checks + 1] = { 'migration ledger has one row', ledger == 1 }
    printChecks(command, checks)
end, true)

RegisterCommand('AuditIngestionSmokeTest', function(source)
    local command = 'AuditIngestionSmokeTest'
    if not enabled(source, command) then return end
    if not FeatherAudit.GetHealth().ready then
        return print(('[%s] FAIL Audit is not ready'):format(command))
    end

    local uuid = tostring(DB.value('SELECT UUID()'))
    local eventId = 'smoke:' .. uuid
    local original = smokeEvent(eventId, 1)
    local accepted = FeatherAuditIngestion.Ingest(original, 'feather-audit-smoke')
    local duplicate = FeatherAuditIngestion.Ingest(original, 'feather-audit-smoke')
    local conflictEvent = smokeEvent(eventId, 1, 'Changed content under reused identity')
    local conflict = FeatherAuditIngestion.Ingest(conflictEvent, 'feather-audit-smoke')
    local invalidEvent = smokeEvent('smoke:' .. tostring(DB.value('SELECT UUID()')), 2)
    invalidEvent.context.unknownField = true
    local invalid = FeatherAuditIngestion.Ingest(invalidEvent, 'feather-audit-smoke')
    local unknownVersionEvent = smokeEvent('smoke:' .. tostring(DB.value('SELECT UUID()')), 3)
    unknownVersionEvent.eventVersion = 2
    local unknownVersion = FeatherAuditIngestion.Ingest(unknownVersionEvent, 'feather-audit-smoke')
    local prohibitedEvent = smokeEvent('smoke:' .. tostring(DB.value('SELECT UUID()')), 4)
    prohibitedEvent.summary = 'https://discord.com/api/webhooks/123/not-a-real-secret'
    local prohibited = FeatherAuditIngestion.Ingest(prohibitedEvent, 'feather-audit-smoke')
    local oversizedEvent = smokeEvent('smoke:' .. tostring(DB.value('SELECT UUID()')), 5)
    oversizedEvent.context.padding_a = string.rep('a', 9000)
    oversizedEvent.context.padding_b = string.rep('b', 9000)
    local oversized = FeatherAuditIngestion.Ingest(oversizedEvent, 'feather-audit-smoke')
    local oldEvent = smokeEvent('smoke:' .. tostring(DB.value('SELECT UUID()')), 6)
    oldEvent.occurredAt = '2020-01-01T00:00:00Z'
    local oldAccepted = FeatherAuditIngestion.Ingest(oldEvent, 'feather-audit-smoke')

    local row = accepted.auditEventId and DB.one([[SELECT canonical_payload AS canonicalPayload,
        integrity_hash AS integrityHash FROM feather_audit_events
        WHERE audit_event_id = ? LIMIT 1]], accepted.auditEventId) or nil
    local matchingHash = row and DB.value('SELECT SHA2(?, 256)', row.canonicalPayload)
    local eventCount = tonumber(DB.value([[SELECT COUNT(*) FROM feather_audit_events
        WHERE source_resource = ? AND source_instance = ? AND producer_event_id = ?]],
        'feather-audit-smoke', Config.SourceInstance, eventId)) or 0

    printChecks(command, {
        { 'new event accepted', accepted.result == 'accepted' and type(accepted.auditEventId) == 'string' },
        { 'identical retry is duplicate', duplicate.result == 'duplicate'
            and duplicate.auditEventId == accepted.auditEventId },
        { 'same identity with changed content quarantined', conflict.result == 'quarantined'
            and conflict.code == FeatherAuditResults.eventIdentityConflict },
        { 'unknown context field quarantined', invalid.result == 'quarantined'
            and invalid.code == FeatherAuditResults.contextUnknownField },
        { 'unsupported event version quarantined', unknownVersion.result == 'quarantined'
            and unknownVersion.code == FeatherAuditResults.eventVersionUnsupported },
        { 'prohibited content quarantined', prohibited.result == 'quarantined'
            and prohibited.code == FeatherAuditResults.prohibitedContent },
        { 'oversized context quarantined', oversized.result == 'quarantined'
            and oversized.code == FeatherAuditResults.payloadTooLarge },
        { 'old out-of-order event accepted', oldAccepted.result == 'accepted' },
        { 'one durable event for producer identity', eventCount == 1 },
        { 'stored SHA-256 matches canonical payload', row and row.integrityHash == matchingHash },
        { 'quarantine contains open records', FeatherAuditQuarantineRepository.CountOpen() >= 5 }
    })
end, true)

RegisterCommand('AuditHealthSmokeTest', function(source)
    local command = 'AuditHealthSmokeTest'
    if not enabled(source, command) then return end
    local health, capabilities = FeatherAudit.GetHealth(), FeatherAudit.GetCapabilities()
    printChecks(command, {
        { 'resource ready', health.ready == true and health.status == 'ready' },
        { 'database ready', health.database and health.database.ready == true },
        { 'ingestion advertised', capabilities.ingestion == true },
        { 'search not advertised before A3', capabilities.search == false }
    })
end, true)
