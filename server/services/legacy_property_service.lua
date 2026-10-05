TDHousing = TDHousing or {}

local LegacyPropertyService = {}
local PropertyRepository = TDHousing.PropertyRepository

local function changed(rows)
	return (tonumber(rows) or 0) > 0
end

function LegacyPropertyService.LoadAll()
	return PropertyRepository.GetAll()
end

function LegacyPropertyService.Create(propertyData)
	local persisted = {
		owner = propertyData.owner,
		street = propertyData.street,
		region = propertyData.region,
		description = propertyData.description,
		has_access = propertyData.has_access or {},
		extra_imgs = propertyData.extra_imgs or {},
		furnitures = propertyData.furnitures or {},
		for_sale = propertyData.for_sale,
		price = propertyData.price,
		shell = propertyData.shell,
		apartment = propertyData.apartment,
		door_data = propertyData.shell == "mlo" and { count = #(propertyData.door_data or {}) }
			or propertyData.door_data
			or {},
		garage_data = propertyData.garage_data or {},
		zone_data = propertyData.zone_data or {},
	}

	return PropertyRepository.Create(persisted)
end

function LegacyPropertyService.GetOwnedApartment(identifier)
	return PropertyRepository.GetOwnedApartment(identifier)
end

function LegacyPropertyService.UpdateFurniture(propertyId, furnitures)
	return changed(PropertyRepository.UpdateFurniture(propertyId, furnitures))
end

function LegacyPropertyService.UpdateDescription(propertyId, description)
	return changed(PropertyRepository.UpdateDescription(propertyId, description))
end

function LegacyPropertyService.UpdatePrice(propertyId, price)
	return changed(PropertyRepository.UpdatePrice(propertyId, price))
end

function LegacyPropertyService.UpdateForSale(propertyId, forSale)
	return changed(PropertyRepository.UpdateForSale(propertyId, forSale))
end

function LegacyPropertyService.UpdateShell(propertyId, shell)
	return changed(PropertyRepository.UpdateShell(propertyId, shell))
end

function LegacyPropertyService.UpdateImages(propertyId, images)
	return changed(PropertyRepository.UpdateImages(propertyId, images))
end

function LegacyPropertyService.UpdateDoor(propertyId, door, street, region)
	return changed(PropertyRepository.UpdateDoor(propertyId, door, street, region))
end

function LegacyPropertyService.UpdateAccess(propertyId, access)
	return changed(PropertyRepository.UpdateLegacyAccess(propertyId, access))
end

function LegacyPropertyService.UpdateGarage(propertyId, garage)
	return changed(PropertyRepository.UpdateGarage(propertyId, garage))
end

function LegacyPropertyService.UpdateApartment(propertyId, apartment)
	return changed(PropertyRepository.UpdateApartment(propertyId, apartment))
end

function LegacyPropertyService.Delete(propertyId)
	return changed(PropertyRepository.Delete(propertyId))
end

TDHousing.LegacyPropertyService = LegacyPropertyService
