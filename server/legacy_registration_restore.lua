local LegacyRegistration = TDHousing and TDHousing.LegacyRegistration

if not LegacyRegistration then
	return
end

RegisterNetEvent = LegacyRegistration.registerNetEvent
lib.callback.register = LegacyRegistration.callbackRegister
