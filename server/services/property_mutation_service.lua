TDHousing = TDHousing or {}
TDHousing.PropertyMutationService = TDHousing.PropertyMutationService or {}

local PropertyMutationService = TDHousing.PropertyMutationService
local PropertyRepository = TDHousing.PropertyRepository

local function finiteNumber(value)
	value = tonumber(value)

	if not value or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end

	return value
end

local function round(value)
	return math.floor(value * 10000 + 0.5) / 10000
end

local function getProperty(propertyId)
	if propertyId == nil then
		return nil, "INVALID_PROPERTY_ID"
	end

	local property = Property.Get(tostring(propertyId))

	if not property then
		return nil, "PROPERTY_NOT_FOUND"
	end

	return property
end

local function normalizeGarage(garage)
	if garage == nil then
		return {}
	end

	if type(garage) ~= "table" then
		return nil, "INVALID_GARAGE_DATA"
	end

	if next(garage) == nil then
		return {}
	end

	local x = finiteNumber(garage.x)
	local y = finiteNumber(garage.y)
	local z = finiteNumber(garage.z)
	local heading = finiteNumber(garage.h)
	local length = finiteNumber(garage.length) or 3.0
	local width = finiteNumber(garage.width) or 5.0

	if not x or not y or not z or not heading or length <= 0 or width <= 0 then
		return nil, "INVALID_GARAGE_DATA"
	end

	return {
		x = round(x),
		y = round(y),
		z = round(z),
		h = round(heading),
		length = round(length),
		width = round(width),
	}
end

local function normalizeImages(images)
	if type(images) ~= "table" or #images > 32 then
		return nil, "INVALID_IMAGES"
	end

	local normalized = {}

	for index = 1, #images do
		local image = images[index]

		if type(image) ~= "string" or image == "" or #image > 2048 then
			return nil, "INVALID_IMAGE"
		end

		normalized[index] = image
	end

	return normalized
end

function PropertyMutationService.UpdateShell(propertyId, shell)
	local property, errorCode = getProperty(propertyId)

	if not property then
		return false, errorCode
	end

	if type(shell) ~= "string" or shell == "" then
		return false, "INVALID_SHELL"
	end

	if shell ~= "mlo" and (type(Config.Shells) ~= "table" or Config.Shells[shell] == nil) then
		return false, "INVALID_SHELL"
	end

	if property.propertyData.shell == shell then
		return true
	end

	local affected = PropertyRepository.UpdateShell(property.property_id, shell)

	if tonumber(affected) ~= 1 then
		return false, "SHELL_UPDATE_FAILED"
	end

	property.propertyData.shell = shell

	TriggerClientEvent("ps-housing:client:updateProperty", -1, "UpdateShell", property.property_id, shell)
	TriggerClientEvent("td_housing:client:propertyUpdated", -1, "shell", property.property_id, shell)

	return true
end

function PropertyMutationService.UpdateGarage(propertyId, garage)
	local property, errorCode = getProperty(propertyId)

	if not property then
		return false, errorCode
	end

	local normalized, garageError = normalizeGarage(garage)

	if not normalized then
		return false, garageError
	end

	local affected = PropertyRepository.UpdateGarage(property.property_id, normalized)

	if tonumber(affected) ~= 1 then
		return false, "GARAGE_UPDATE_FAILED"
	end

	property.propertyData.garage_data = normalized

	TriggerClientEvent("ps-housing:client:updateProperty", -1, "UpdateGarage", property.property_id, normalized)
	TriggerClientEvent("td_housing:client:propertyUpdated", -1, "garage", property.property_id, normalized)

	return true
end

function PropertyMutationService.UpdateImages(propertyId, images)
	local property, errorCode = getProperty(propertyId)

	if not property then
		return false, errorCode
	end

	local normalized, imageError = normalizeImages(images)

	if not normalized then
		return false, imageError
	end

	local affected = PropertyRepository.UpdateImages(property.property_id, normalized)

	if tonumber(affected) ~= 1 then
		return false, "IMAGES_UPDATE_FAILED"
	end

	property.propertyData.extra_imgs = normalized
	property.propertyData.imgs = normalized

	TriggerClientEvent("ps-housing:client:updateProperty", -1, "UpdateImgs", property.property_id, normalized)
	TriggerClientEvent("td_housing:client:propertyUpdated", -1, "images", property.property_id, normalized)

	return true
end
