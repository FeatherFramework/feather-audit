fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'feather-audit-smoke-producer'
description 'Test-only durable producer fixture for Feather Audit'
author 'Feather Framework'
version '0.1.0-test'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config.lua',
    'server.lua'
}

dependencies {
    'oxmysql',
    'feather-audit'
}

server_only 'yes'
