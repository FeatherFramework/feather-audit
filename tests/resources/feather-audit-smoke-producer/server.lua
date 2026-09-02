local RESOURCE = GetCurrentResourceName()

local function consoleOnly(source, command)
    if source == 0 then return true end
    print(('[%s] server console only'):format(command))
    return false
end

local function eventFor(operationId, eventId)
    return {
        contractVersion = 1,
        eventId = eventId,
        eventType = 'audit.smoke.ingested',
        eventVersion = 1,
        occurredAt = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        sourceResource = RESOURCE,
        sourceInstance = SmokeConfig.sourceInstance,
        actor = { type = 'system', id = 'durable-producer-smoke' },
        targets = {
            { type = 'resource', id = RESOURCE, role = 'subject' }
        },
        references = {},
        result = 'success',
        reasonCode = 'smoke_test',
        summary = 'Durable producer smoke event',
        context = { sequence = 1, message = ('Operation %s'):format(operationId) },
        sensitivityClass = 'internal',
        retentionClass = 'operational'
    }
end

local function publishOne()
    local row = MySQL.single.await([[SELECT outbox_id AS outboxId, event_id AS eventId,
        payload_json AS payloadJson, attempt_count AS attemptCount,
        audit_event_id AS auditEventId
        FROM feather_audit_smoke_outbox WHERE state = 'pending'
        ORDER BY outbox_id ASC LIMIT 1]])
    if not row then return false, 'no_pending_row' end

    local event = json.decode(row.payloadJson)
    local ok, result = pcall(function() return exports['feather-audit']:Ingest(event) end)
    if not ok or type(result) ~= 'table' then
        MySQL.update.await([[UPDATE feather_audit_smoke_outbox
            SET attempt_count = attempt_count + 1, last_result_code = 'transport_failure'
            WHERE outbox_id = ?]], { row.outboxId })
        return false, 'transport_failure'
    end
    if result.result == 'accepted' or result.result == 'duplicate' then
        MySQL.update.await([[UPDATE feather_audit_smoke_outbox
            SET state = 'delivered', attempt_count = attempt_count + 1,
                audit_event_id = ?, last_result_code = ?, delivered_at = CURRENT_TIMESTAMP(3)
            WHERE outbox_id = ?]], { result.auditEventId, result.result, row.outboxId })
        local identityStable = not row.auditEventId or row.auditEventId == result.auditEventId
        return identityStable, ('%s auditEventId=%s'):format(result.result, tostring(result.auditEventId))
    end
    if result.result == 'quarantined' then
        MySQL.update.await([[UPDATE feather_audit_smoke_outbox
            SET state = 'quarantined', attempt_count = attempt_count + 1, last_result_code = ?
            WHERE outbox_id = ?]], { result.code, row.outboxId })
        return false, 'quarantined:' .. tostring(result.code)
    end
    MySQL.update.await([[UPDATE feather_audit_smoke_outbox
        SET attempt_count = attempt_count + 1, last_result_code = ? WHERE outbox_id = ?]],
        { result.code or 'retryable_rejection', row.outboxId })
    return false, 'retryable:' .. tostring(result.code)
end

MySQL.ready(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS feather_audit_smoke_domain (
        operation_id CHAR(36) NOT NULL,
        state VARCHAR(32) NOT NULL,
        created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
        PRIMARY KEY (operation_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS feather_audit_smoke_outbox (
        outbox_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
        operation_id CHAR(36) NOT NULL,
        event_id VARCHAR(128) NOT NULL,
        payload_json LONGTEXT NOT NULL,
        state VARCHAR(32) NOT NULL DEFAULT 'pending',
        attempt_count INT UNSIGNED NOT NULL DEFAULT 0,
        audit_event_id CHAR(36) NULL,
        last_result_code VARCHAR(128) NULL,
        created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
        delivered_at DATETIME(3) NULL,
        PRIMARY KEY (outbox_id),
        UNIQUE KEY uq_faso_event (event_id),
        CONSTRAINT fk_faso_operation FOREIGN KEY (operation_id)
            REFERENCES feather_audit_smoke_domain (operation_id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])
    print(('[%s] Durable producer smoke fixture ready.'):format(RESOURCE))
end)

RegisterCommand('AuditProducerQueueSmokeTest', function(source)
    local command = 'AuditProducerQueueSmokeTest'
    if not consoleOnly(source, command) then return end
    local operationId = tostring(MySQL.scalar.await('SELECT UUID()'))
    local eventId = 'producer-smoke:' .. operationId
    local payload = json.encode(eventFor(operationId, eventId))
    local committed = MySQL.transaction.await({
        {
            query = 'INSERT INTO feather_audit_smoke_domain (operation_id, state) VALUES (?, ?)',
            values = { operationId, 'committed' }
        },
        {
            query = [[INSERT INTO feather_audit_smoke_outbox
                (operation_id, event_id, payload_json) VALUES (?, ?, ?)]],
            values = { operationId, eventId, payload }
        }
    })
    print(('[%s] %s operationId=%s eventId=%s'):format(command,
        committed and 'PASS queued atomically' or 'FAIL transaction rolled back', operationId, eventId))
end, true)

RegisterCommand('AuditProducerPublishSmokeTest', function(source)
    local command = 'AuditProducerPublishSmokeTest'
    if not consoleOnly(source, command) then return end
    local ok, detail = publishOne()
    print(('[%s] %s %s'):format(command, ok and 'PASS' or 'FAIL', tostring(detail)))
end, true)

RegisterCommand('AuditProducerReplaySmokeTest', function(source)
    local command = 'AuditProducerReplaySmokeTest'
    if not consoleOnly(source, command) then return end
    local row = MySQL.single.await([[SELECT outbox_id AS outboxId FROM feather_audit_smoke_outbox
        WHERE state = 'delivered' ORDER BY outbox_id DESC LIMIT 1]])
    if not row then return print(('[%s] FAIL no delivered fixture'):format(command)) end
    MySQL.update.await([[UPDATE feather_audit_smoke_outbox SET state = 'pending', delivered_at = NULL
        WHERE outbox_id = ?]], { row.outboxId })
    local ok, detail = publishOne()
    print(('[%s] %s %s'):format(command, ok and 'PASS' or 'FAIL', tostring(detail)))
end, true)

RegisterCommand('AuditProducerStatusSmokeTest', function(source)
    local command = 'AuditProducerStatusSmokeTest'
    if not consoleOnly(source, command) then return end
    local rows = MySQL.query.await([[SELECT state, COUNT(*) AS count
        FROM feather_audit_smoke_outbox GROUP BY state]]) or {}
    for _, row in ipairs(rows) do
        print(('[%s] state=%s count=%s'):format(command, row.state, row.count))
    end
end, true)
