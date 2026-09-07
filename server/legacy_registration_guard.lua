TDHousing = TDHousing or {}
TDHousing.LegacyRegistration = TDHousing.LegacyRegistration or {}

local LegacyRegistration = TDHousing.LegacyRegistration

LegacyRegistration.registerNetEvent = RegisterNetEvent
LegacyRegistration.callbackRegister = lib.callback.register
LegacyRegistration.blockedEvents = {}
LegacyRegistration.blockedCallbacks = {}

local blockedEvents = {
	["ps-housing:server:buyFurniture"] = true,
	["ps-housing:server:openQBInv"] = true,
	["ps-housing:server:removeFurniture"] = true,
	["ps-housing:server:updateFurniture"] = true,
	["ps-housing:server:addAccess"] = true,
	["ps-housing:server:removeAccess"] = true,
}

local blockedCallbacks = {
	["ps-housing:cb:getPropertyInfo"] = true,
	["ps-housing:cb:getPlayersInProperty"] = true,
	["ps-housing:cb:inventoryHasItems"] = true,
}

RegisterNetEvent = function(name, handler)
	if blockedEvents[name] then
		LegacyRegistration.blockedEvents[name] = handler
		return LegacyRegistration.registerNetEvent(name)
	end

	return LegacyRegistration.registerNetEvent(name, handler)
end

lib.callback.register = function(name, handler)
	if blockedCallbacks[name] then
		LegacyRegistration.blockedCallbacks[name] = handler
		return
	end

	return LegacyRegistration.callbackRegister(name, handler)
end
