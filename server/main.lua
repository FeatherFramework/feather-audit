exports('GetHealth', function()
    return FeatherAudit.GetHealth()
end)

exports('GetCapabilities', function()
    return FeatherAudit.GetCapabilities()
end)

exports('Ingest', function(event)
    local sourceResource = GetInvokingResource()
    return FeatherAuditIngestion.Ingest(event, sourceResource)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    FeatherAudit.SetState(FeatherAuditConstants.lifecycle.starting, false, 'database_starting')
    if Config.Development.startupMessage then
        print('[feather-audit] Starting migrations and ingestion foundation.')
    end
end)

MySQL.ready(function()
    local configOk, configProblem = FeatherAuditConfig.Validate()
    if not configOk then
        FeatherAudit.SetDatabaseState(false, 0, configProblem)
        FeatherAudit.SetState(FeatherAuditConstants.lifecycle.unavailable, false, 'configuration_invalid')
        print(('[feather-audit] Configuration invalid: %s'):format(tostring(configProblem)))
        return
    end
    local ok, migrationOk, detail = pcall(FeatherAuditMigrations.Run)
    if not ok or not migrationOk then
        local reason = ok and detail or tostring(migrationOk)
        FeatherAudit.SetDatabaseState(false, 0, reason)
        FeatherAudit.SetState(FeatherAuditConstants.lifecycle.unavailable, false, 'migration_failed')
        print(('[feather-audit] Database migration failed: %s'):format(tostring(reason)))
        return
    end

    FeatherAudit.SetDatabaseState(true, detail)
    FeatherAudit.SetState(FeatherAuditConstants.lifecycle.ready, true, nil)
    print(('[feather-audit] Ready with %d migration(s); ingestion v1 enabled.'):format(detail))
end)
