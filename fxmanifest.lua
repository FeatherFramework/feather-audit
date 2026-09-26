fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'feather-audit'
description 'Cross-domain audit, investigation, and operator alerting for Feather Framework'
author 'BCC Scripts'
version '0.1.0-dev'

shared_scripts {
    'config.lua',
    'shared/constants.lua',
    'shared/results.lua',
    'shared/contract/canonical.lua',
    'shared/contract/registry.lua',
    'shared/contract/validator.lua',
    'schemas/audit/smoke_ingested_v1.lua'
}

server_scripts {
    '@feather-mysql/lib/DB.lua',
    'server/core/runtime.lua',
    'server/core/config.lua',
    'server/database/migrations.lua',
    'server/repositories/events.lua',
    'server/repositories/quarantine.lua',
    'server/ingestion/rate_limit.lua',
    'server/ingestion/service.lua',
    'server/services/smoke.lua',
    'server/main.lua'
}

dependencies {
    'feather-mysql',
    'feather-core'
}

server_only 'yes'
