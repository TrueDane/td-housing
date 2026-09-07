TDHousing = TDHousing or {}

local PropertyCapabilities = TDHousing.PropertyCapabilities
local guardedUpdateFurnitures = Property.UpdateFurnitures
local guardedUpdateHasAccess = Property.UpdateHas_access

local function isPlayerInvocation()
	local eventSource = tonumber(source)

	return eventSource ~= nil and eventSource > 0 and eventSource ~= 65535
end

local function restoreFurniture(property)
	local row = MySQL.single.await("SELECT furnitures FROM properties WHERE property_id = ?", {
		property.property_id,
	})

	local furnitures = {}

	if row and type(row.furnitures) == "string" and row.furnitures ~= "" then
		local success, decoded = pcall(json.decode, row.furnitures)

		if success and type(decoded) == "table" then
			furnitures = decoded
		end
	elseif row and type(row.furnitures) == "table" then
		furnitures = row.furnitures
	end

	property.propertyData.furnitures = furnitures
end

Property.UpdateFurnitures = function(self, furnitures, isGarden)
	if isPlayerInvocation() then
		restoreFurniture(self)
		return false
	end

	return guardedUpdateFurnitures(self, furnitures, isGarden)
end

Property.UpdateHas_access = function(self, access)
	if isPlayerInvocation() then
		local identifier = TD.Player.GetIdentifier(source)

		if not PropertyCapabilities.CanManageAccess(self.propertyData, identifier) then
			local legacyAccess = PropertyCapabilities.BuildLegacyAccess(self.propertyData)
			self.propertyData.has_access = legacyAccess

			TriggerClientEvent(
				"ps-housing:client:updateProperty",
				-1,
				"UpdateHas_access",
				self.property_id,
				legacyAccess
			)

			return false
		end
	end

	return guardedUpdateHasAccess(self, access)
end
