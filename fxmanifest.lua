fx_version 'adamant'

game 'gta5'

server_scripts{
    '@async/async.lua',
    '@mysql-async/lib/MySQL.lua',
    'config.lua',
    'locales/en.lua',
    'server.lua'
}

client_scripts{
    '@es_extended/locale.lua',
    'config.lua',
    'locales/en.lua',
    'client.lua',
}

files{

}

dependencies{
    'mysql-async',
    'async'
}

