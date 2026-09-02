exports('GetHealth', function()
    return FeatherAudit.GetHealth()
end)

exports('GetCapabilities', function()
    return FeatherAudit.GetCapabilities()
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if Config.Development.startupMessage then
        print('[feather-audit] Development scaffold started; auditing is not implemented or ready.')
    end
end)
