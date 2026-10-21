for _, eventType in ipairs({ 'access.grant.created', 'access.grant.revoked' }) do
    assert(FeatherAuditSchemaRegistry.Register({
        eventType = eventType, eventVersion = 1,
        actorTypes = { character = true, system = true },
        minimumTargets = 3, minimumSensitivity = 'restricted', retentionClass = 'security',
        readProjection = { target_type = 'internal', capability = 'internal', status = 'internal', revision = 'internal' },
        context = { type = 'object', fields = {
            target_type = { type = 'string', required = true, maxBytes = 64 },
            capability = { type = 'string', required = true, maxBytes = 64 },
            status = { type = 'string', required = true, maxBytes = 16 },
            revision = { type = 'integer', required = true, minimum = 1, maximum = 9007199254740991 },
            target_epoch = { type = 'integer', required = true, minimum = 1, maximum = 9007199254740991 },
            grantee_type = { type = 'string', required = true, maxBytes = 16 },
            valid_from = { type = 'integer', required = true, minimum = 0, maximum = 9007199254740991 },
            valid_until = { type = 'integer', required = true, minimum = 1, maximum = 9007199254740991 },
            role_ids = { type = 'array', required = true, maxItems = 32,
                items = { type = 'string', maxBytes = 64 } },
            requestor_resource = { type = 'string', required = true, maxBytes = 100 },
            reason_code = { type = 'string', required = true, maxBytes = 64 },
            provenance_type = { type = 'string', required = true, maxBytes = 64 },
        } },
    }))
end
