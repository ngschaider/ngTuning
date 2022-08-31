fx_version 'cerulean'

games { 
	'gta5' 
}

name 'ngTuning'
author 'Niklas Gschaider <niklas.gschaider@gschaider-systems.at>'
description 'A script to edit wheels of vehicles'
version 'v1.0.0'

dependencies {
	"es_extended",
}

client_scripts {
	'@NativeUI/NativeUI.lua',
	'@es_extended/locale.lua',
	"locales/de.lua",
	"config.lua",
	"client.lua",
}

server_scripts {
	'@mysql-async/lib/MySQL.lua',
	'@es_extended/locale.lua',
	"locales/de.lua",
	"config.lua",
	"server.lua",
}