Config = Config or {}

-- Feather Audit is still a scaffold. These defaults do not enable ingestion,
-- persistence, search, or notification delivery.
Config.Development = {
    startupMessage = true
}

-- External delivery is opt-in. Secrets must be resolved from a protected
-- server-side source in a future phase; never place webhook URLs here.
Config.Notifications = {
    enabled = false,
    destinations = {},
    rules = {}
}
