Config = Config or {}

-- Feather Audit is still a scaffold. These defaults do not enable ingestion,
-- persistence, search, or notification delivery.
Config.Development = {
    startupMessage = true,
    -- Enables server-console-only smoke commands and the internal smoke
    -- producer. Keep false on production servers.
    smokeCommands = false
}

-- Stable identity for this server/world. Every producer outbox must persist the
-- same value. Changing it creates a new deduplication scope.
Config.SourceInstance = 'default'

-- Server-only producer registrations. Payload sourceResource is checked against
-- the actual invoking resource and these event prefixes/versions.
Config.Producers = {
    -- ['feather-economy'] = {
    --     enabled = true,
    --     sourceInstance = 'default',
    --     eventPrefixes = { 'economy.' },
    --     versions = { [1] = true },
    --     maxPerMinute = 600
    -- }
}

Config.Ingestion = {
    defaultMaxPerMinute = 300
}

-- External delivery is opt-in. Secrets must be resolved from a protected
-- server-side source in a future phase; never place webhook URLs here.
Config.Notifications = {
    enabled = false,
    destinations = {},
    rules = {}
}
