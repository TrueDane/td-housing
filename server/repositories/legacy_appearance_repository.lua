TDHousing = TDHousing or {}

local LegacyAppearanceRepository = {}

function LegacyAppearanceRepository.HasAppearance(identifier)
	if type(identifier) ~= "string" or identifier == "" then
		return nil, "INVALID_IDENTIFIER"
	end

	local success, result = pcall(function()
		return MySQL.scalar.await("SELECT 1 FROM playerskins WHERE citizenid = ? LIMIT 1", { identifier })
	end)

	if not success then
		return nil, "APPEARANCE_LOOKUP_FAILED", tostring(result)
	end

	return result ~= nil
end

TDHousing.LegacyAppearanceRepository = LegacyAppearanceRepository
