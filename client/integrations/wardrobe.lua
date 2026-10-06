TDHousing = TDHousing or {}
TDHousing.Wardrobe = TDHousing.Wardrobe or {}

local Wardrobe = TDHousing.Wardrobe

function Wardrobe.Open()
	if not TD.HasCapability("appearance", "openWardrobe") then
		return nil, "WARDROBE_PROVIDER_UNAVAILABLE"
	end

	return TD.Appearance.OpenWardrobe()
end
