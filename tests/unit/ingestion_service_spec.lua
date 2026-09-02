local Assert = _G.TestAssert
local Fixtures = _G.TestFixtures

Config.SourceInstance = 'test-1'
Config.Producers = {
    ['feather-economy'] = {
        enabled = true,
        sourceInstance = 'test-1',
        eventPrefixes = { 'economy.' },
        versions = { [1] = true },
        maxPerMinute = 10
    }
}

local metrics, quarantined = {}, {}
FeatherAudit = {
    GetHealth = function() return { ready = true } end,
    IncrementMetric = function(name) metrics[name] = (metrics[name] or 0) + 1 end
}
FeatherAuditQuarantineRepository = {
    Record = function(source, _, rejection)
        quarantined[#quarantined + 1] = { source = source, code = rejection.code }
    end
}
FeatherAuditEventRepository = {
    Accept = function() return 'accepted', 'audit-test-1' end
}

dofile('server/ingestion/rate_limit.lua')
dofile('server/ingestion/service.lua')

local event = Fixtures.validTransfer({ occurredAt = os.date('!%Y-%m-%dT%H:%M:%SZ') })
local accepted = FeatherAuditIngestion.Ingest(event, 'feather-economy')
Assert.equal(FeatherAuditConstants.results.accepted, accepted.result)
Assert.equal('audit-test-1', accepted.auditEventId)

local denied = FeatherAuditIngestion.Ingest(event, 'unregistered-resource')
Assert.equal(FeatherAuditConstants.results.quarantined, denied.result)
Assert.equal(FeatherAuditResults.producerNotAllowed, denied.code)
Assert.equal(0, #quarantined, 'unregistered producers must not write quarantine rows')
