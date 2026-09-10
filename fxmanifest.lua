fx_version("cerulean")
game("gta5")

author("TrueDane Development")
description("TrueDane 3.0 housing engine based on ps-housing")
version("0.1.0-dev")
repository("https://github.com/TrueDane/td-housing")
td_repository("TrueDane/td-housing")

ui_page("html/index.html")

dependencies({
	"td_bridge",
	"ox_lib",
	"oxmysql",
	"fivem-freecam",
})

shared_scripts({
	"@td_bridge/init.lua",
	"@ox_lib/init.lua",
	"shared/config.lua",
	"config/shared.lua",
	"shared/framework.lua",
	"shared/property_capabilities.lua",
})

client_scripts({
	"config/client.lua",
	"client/shell.lua",
	"client/apartment.lua",
	"client/cl_property.lua",
	"client/client.lua",
	"client/modeler.lua",
	"client/integrations/wardrobe.lua",
	"client/modules/property_capabilities.lua",
	"client/migrate.lua",
})

server_scripts({
	"@oxmysql/lib/MySQL.lua",
	"server/legacy_registration_guard.lua",
	"server/sv_property.lua",
	"server/legacy_registration_restore.lua",
	"server/repositories/property_repository.lua",
	"server/services/ownership_service.lua",
	"server/services/property_capability_service.lua",
	"server/services/legacy_guard_service.lua",
	"server/modules/property_capabilities.lua",
	"server/modules/public_api.lua",
	"server/modules/legacy_compatibility.lua",
	"server/server.lua",
	"server/migrate.lua",
})

files({
	"html/**",
	"stream/starter_shells_k4mb1.ytyp",
	"stream/**.ytyp",
})

-- Fix for "stuck in black loading screen"
data_file("DLC_ITYP_REQUEST")("x64c:/levels/gta5/interiors/int_props/int_corporate.rpf/int_corporate.ytyp")
data_file("DLC_ITYP_REQUEST")("x64c:/levels/gta5/interiors/int_props/int_industrial.rpf/int_industrial.ytyp")
data_file("DLC_ITYP_REQUEST")("x64c:/levels/gta5/interiors/int_props/int_lev_des.rpf/int_lev_des.ytyp")
data_file("DLC_ITYP_REQUEST")("x64c:/levels/gta5/interiors/int_props/int_residential.rpf/int_residential.ytyp")
data_file("DLC_ITYP_REQUEST")("x64c:/levels/gta5/interiors/int_props/int_retail.rpf/int_retail.ytyp")
data_file("DLC_ITYP_REQUEST")("x64c:/levels/gta5/interiors/int_props/int_services.rpf/int_services.ytyp")
data_file("DLC_ITYP_REQUEST")("starter_shells_k4mb1.ytyp")
data_file("DLC_ITYP_REQUEST")("stream/**.ytyp")

this_is_a_map("yes")
