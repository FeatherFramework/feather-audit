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
    'shared/results.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/core/runtime.lua',
    'server/main.lua'
}

dependencies {
    'oxmysql',
    'feather-core'
}

server_only 'yes'
