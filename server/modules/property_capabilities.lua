local PropertyCapabilityService = TDHousing.PropertyCapabilityService

local function notifyError(playerSource, errorCode)
	local messages = {
		PROPERTY_NOT_FOUND = "Boligen blev ikke fundet.",
		PLAYER_NOT_INSIDE_PROPERTY = "Du skal være inde i boligen.",
		STORAGE_ACCESS_DENIED = "Du har ikke adgang til boligens stash.",
		STORAGE_NOT_FOUND = "Stashen blev ikke fundet.",
		PROPERTY_MANAGE_FORBIDDEN = "Du må ikke ændre denne bolig.",
		STORAGE_DISABLED = "Stash er deaktiveret i denne bolig.",
		WARDROBE_DISABLED = "Garderobe er deaktiveret i denne bolig.",
		STORAGE_LIMIT_REACHED = "Boligen har allerede det maksimale antal stashes.",
		WARDROBE_LIMIT_REACHED = "Boligen har allerede det maksimale antal garderober.",
		FURNITURE_PLACEMENT_DISABLED = "Boligen tillader ikke placering af møbler.",
		INVALID_FURNITURE_ITEM = "Et af de valgte møbler er ugyldigt.",
		INVALID_FURNITURE_ITEMS = "Møbellisten er ugyldig.",
		INSUFFICIENT_FUNDS = "Du har ikke penge nok.",
		PAYMENT_FAILED = "Betalingen kunne ikke gennemføres.",
		FURNITURE_SAVE_FAILED = "Møblerne kunne ikke gemmes.",
		FURNITURE_NOT_FOUND = "Møblet blev ikke fundet.",
		FURNITURE_UPDATE_FORBIDDEN = "Du må ikke flytte dette objekt.",
		FURNITURE_REMOVE_FORBIDDEN = "Du må ikke fjerne dette objekt.",
		INVALID_FURNITURE_POSITION = "Placeringen er ugyldig.",
	}

	TD.Notify(playerSource, {
		title = "TD-Housing",
		description = messages[errorCode]
			or ("Handlingen kunne ikke gennemføres (%s)."):format(errorCode or "UNKNOWN_ERROR"),
		type = "error",
	})
end

TD.Callback.Register("td_housing:server:getPropertyCapabilities", function(source, propertyId)
	return PropertyCapabilityService.GetCapabilities(propertyId, source)
end)

RegisterNetEvent("td_housing:server:openStorage", function(propertyId, furnitureId)
	local playerSource = source
	local success, errorCode = PropertyCapabilityService.OpenStorage(playerSource, propertyId, furnitureId)

	if not success then
		notifyError(playerSource, errorCode)
	end
end)

RegisterNetEvent("td_housing:server:buyFurniture", function(propertyId, items, isGarden)
	local playerSource = source
	local result, errorCode = PropertyCapabilityService.BuyFurniture(playerSource, propertyId, items, isGarden)

	if not result then
		notifyError(playerSource, errorCode)
		return
	end

	TD.Notify(playerSource, {
		title = "TD-Housing",
		description = result.totalPrice > 0 and ("Møbler købt for $%s."):format(result.totalPrice)
			or "Boligfunktionen er placeret.",
		type = "success",
	})
end)

RegisterNetEvent("td_housing:server:updateFurniture", function(propertyId, furnitureId, position, rotation)
	local playerSource = source
	local success, errorCode =
		PropertyCapabilityService.UpdateFurniture(playerSource, propertyId, furnitureId, position, rotation)

	if not success then
		notifyError(playerSource, errorCode)
	end
end)

RegisterNetEvent("td_housing:server:removeFurniture", function(propertyId, furnitureId)
	local playerSource = source
	local success, errorCode = PropertyCapabilityService.RemoveFurniture(playerSource, propertyId, furnitureId)

	if not success then
		notifyError(playerSource, errorCode)
	end
end)

exports("GetPropertyCapabilities", function(propertyId)
	return PropertyCapabilityService.GetCapabilities(propertyId)
end)

exports("ApplyPropertySettings", function(propertyId, settings)
	return PropertyCapabilityService.ApplySettings(propertyId, settings)
end)

exports("GrantAccess", function(propertyId, identifier, role)
	return PropertyCapabilityService.GrantAccess(propertyId, identifier, role)
end)

exports("RevokeAccess", function(propertyId, identifier)
	return PropertyCapabilityService.RevokeAccess(propertyId, identifier)
end)
