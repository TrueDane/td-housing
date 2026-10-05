TDHousing = TDHousing or {}

local AppearanceService = {}
local Repository = TDHousing.LegacyAppearanceRepository

function AppearanceService.EnsureFirstCharacter(source, identifier)
	if type(source) ~= "number" or source <= 0 then
		return nil, "INVALID_SOURCE"
	end

	local hasAppearance, errorCode, errorMessage = Repository.HasAppearance(identifier)

	if hasAppearance == nil then
		return nil, errorCode, errorMessage
	end

	if hasAppearance then
		return true, "APPEARANCE_EXISTS"
	end

	if not TD.HasCapability("appearance", "createFirstCharacter") then
		return nil, "APPEARANCE_PROVIDER_UNAVAILABLE"
	end

	local success, bridgeError, bridgeMessage = TD.Appearance.CreateFirstCharacter(source)

	if success ~= true then
		return nil, bridgeError or "APPEARANCE_CREATE_FAILED", bridgeMessage
	end

	return true, "APPEARANCE_CREATION_STARTED"
end

TDHousing.AppearanceService = AppearanceService
