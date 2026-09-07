TDHousing = TDHousing or {}
TDHousing.OwnershipService = TDHousing.OwnershipService or {}

local OwnershipService = TDHousing.OwnershipService
local PropertyRepository = TDHousing.PropertyRepository

local function normalizeIdentifier(identifier)
	if identifier == nil then
		return nil
	end

	if type(identifier) ~= 'string' then
		return false
	end

	identifier = identifier:match('^%s*(.-)%s*$')

	if identifier == '' then
		return false
	end

	return identifier
end

function OwnershipService.SetOwner(propertyId, identifier)
	local property = Property.Get(propertyId)

	if not property then
		return nil, 'PROPERTY_NOT_FOUND'
	end

	identifier = normalizeIdentifier(identifier)

	if identifier == false then
		return nil, 'INVALID_IDENTIFIER'
	end

	local previousOwner = property.propertyData.owner

	if previousOwner == identifier then
		return true
	end

	if not PropertyRepository.UpdateOwner(property.property_id, identifier) then
		return nil, 'OWNER_UPDATE_FAILED'
	end

	if previousOwner and property.propertyData.shell == 'mlo' then
		property:removeMloDoorsAccess(previousOwner)
	end

	property.propertyData.owner = identifier

	if identifier and property.propertyData.shell == 'mlo' then
		property:addMloDoorsAccess(identifier)
	end

	TriggerClientEvent('ps-housing:client:updateProperty', -1, 'UpdateOwner', property.property_id, identifier)
	TriggerClientEvent('td_housing:client:ownerChanged', -1, property.property_id, identifier)

	return true
end
