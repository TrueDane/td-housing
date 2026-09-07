local PropertyCapabilityService = TDHousing.PropertyCapabilityService
local OwnershipService = TDHousing.OwnershipService

local function copySettings(propertyData)
	if type(propertyData) ~= 'table' then
		return nil
	end

	if propertyData.settings then
		return propertyData.settings
	end

	if propertyData.furnitureMode or propertyData.storage or propertyData.wardrobe then
		return {
			furnitureMode = propertyData.furnitureMode,
			storage = propertyData.storage,
			wardrobe = propertyData.wardrobe,
		}
	end

	return nil
end

exports('RegisterProperty', function(propertyData, preventEnter, playerSource)
	if type(propertyData) ~= 'table' then
		return nil, 'INVALID_PROPERTY_DATA'
	end

	local settings = copySettings(propertyData)
	local propertyId = RegisterProperty(propertyData, preventEnter, playerSource)

	if not propertyId then
		return nil, 'PROPERTY_CREATE_FAILED'
	end

	if settings then
		local success, errorCode = PropertyCapabilityService.ApplySettings(propertyId, settings)

		if not success then
			return nil, errorCode or 'PROPERTY_SETTINGS_FAILED'
		end
	end

	return tostring(propertyId)
end)

exports('SetOwner', function(propertyId, identifier)
	return OwnershipService.SetOwner(propertyId, identifier)
end)

exports('GetProperty', function(propertyId)
	local property = Property.Get(propertyId)

	return property and property.propertyData or nil
end)
