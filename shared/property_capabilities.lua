TDHousing = TDHousing or {}
TDHousing.PropertyCapabilities = TDHousing.PropertyCapabilities or {}

local PropertyCapabilities = TDHousing.PropertyCapabilities

PropertyCapabilities.AccessRole = {
	OWNER = "owner",
	RESIDENT = "resident",
	GUEST = "guest",
	VISITOR = "visitor",
}

PropertyCapabilities.FurnitureMode = {
	PLAYER = "player",
	FIXED = "fixed",
	DISABLED = "disabled",
}

local validFurnitureModes = {
	player = true,
	fixed = true,
	disabled = true,
}

local function copyTable(value)
	local copy = {}

	if type(value) ~= "table" then
		return copy
	end

	for key, item in pairs(value) do
		if type(item) == "table" then
			copy[key] = copyTable(item)
		else
			copy[key] = item
		end
	end

	return copy
end

local function decodeTable(value)
	if type(value) == "table" then
		return copyTable(value)
	end

	if type(value) ~= "string" or value == "" then
		return {}
	end

	local success, decoded = pcall(json.decode, value)

	if not success or type(decoded) ~= "table" then
		return {}
	end

	return decoded
end

local function positiveInteger(value, fallback)
	value = tonumber(value)

	if not value or value <= 0 then
		return fallback
	end

	return math.floor(value)
end

local function normalizeAccessData(value, legacyAccess)
	local access = decodeTable(value)
	local normalized = {}
	local seen = {}

	for index = 1, #access do
		local entry = access[index]

		if type(entry) == "table" and type(entry.identifier) == "string" and entry.identifier ~= "" then
			local role = entry.role == PropertyCapabilities.AccessRole.RESIDENT
					and PropertyCapabilities.AccessRole.RESIDENT
				or PropertyCapabilities.AccessRole.GUEST

			if not seen[entry.identifier] then
				normalized[#normalized + 1] = {
					identifier = entry.identifier,
					role = role,
				}
				seen[entry.identifier] = true
			end
		end
	end

	legacyAccess = decodeTable(legacyAccess)

	for index = 1, #legacyAccess do
		local identifier = legacyAccess[index]

		if type(identifier) == "string" and identifier ~= "" and not seen[identifier] then
			normalized[#normalized + 1] = {
				identifier = identifier,
				role = PropertyCapabilities.AccessRole.GUEST,
			}
			seen[identifier] = true
		end
	end

	return normalized
end

function PropertyCapabilities.Normalize(propertyData)
	propertyData = propertyData or {}

	local shell = Config.Shells[propertyData.shell] or {}
	local shellStash = shell.stash or {}
	local storage = decodeTable(propertyData.storage_data or propertyData.storage)
	local wardrobe = decodeTable(propertyData.wardrobe_data or propertyData.wardrobe)
	local furnitureMode = propertyData.furniture_mode
		or propertyData.furnitureMode
		or PropertyCapabilities.FurnitureMode.PLAYER

	if not validFurnitureModes[furnitureMode] then
		furnitureMode = PropertyCapabilities.FurnitureMode.PLAYER
	end

	propertyData.furniture_mode = furnitureMode
	propertyData.access_data = normalizeAccessData(propertyData.access_data, propertyData.has_access)
	propertyData.storage_data = {
		enabled = storage.enabled ~= false,
		maxWeight = positiveInteger(
			storage.maxWeight or storage.maxweight,
			positiveInteger(shellStash.maxweight, 100000)
		),
		slots = positiveInteger(storage.slots, positiveInteger(shellStash.slots, 20)),
		maxPlacements = positiveInteger(storage.maxPlacements, 1),
	}
	propertyData.wardrobe_data = {
		enabled = wardrobe.enabled ~= false,
		maxPlacements = positiveInteger(wardrobe.maxPlacements, 1),
		useMode = "inside",
	}

	propertyData.has_access = propertyData.has_access or {}
	propertyData.furnitures = propertyData.furnitures or {}

	return propertyData
end

function PropertyCapabilities.GetAccessRole(propertyData, identifier)
	propertyData = PropertyCapabilities.Normalize(propertyData)

	if type(identifier) ~= "string" or identifier == "" then
		return PropertyCapabilities.AccessRole.VISITOR
	end

	if propertyData.owner == identifier then
		return PropertyCapabilities.AccessRole.OWNER
	end

	for index = 1, #propertyData.access_data do
		local entry = propertyData.access_data[index]

		if entry.identifier == identifier then
			return entry.role
		end
	end

	return PropertyCapabilities.AccessRole.VISITOR
end

function PropertyCapabilities.HasDoorAccess(propertyData, identifier)
	local role = PropertyCapabilities.GetAccessRole(propertyData, identifier)

	return role == PropertyCapabilities.AccessRole.OWNER
		or role == PropertyCapabilities.AccessRole.RESIDENT
		or role == PropertyCapabilities.AccessRole.GUEST
end

function PropertyCapabilities.CanManageAccess(propertyData, identifier)
	return PropertyCapabilities.GetAccessRole(propertyData, identifier) == PropertyCapabilities.AccessRole.OWNER
end

function PropertyCapabilities.CanManageFeatures(propertyData, identifier)
	local role = PropertyCapabilities.GetAccessRole(propertyData, identifier)

	return role == PropertyCapabilities.AccessRole.OWNER or role == PropertyCapabilities.AccessRole.RESIDENT
end

function PropertyCapabilities.CanUseStorage(propertyData, identifier)
	propertyData = PropertyCapabilities.Normalize(propertyData)

	if propertyData.storage_data.enabled ~= true then
		return false
	end

	return PropertyCapabilities.CanManageFeatures(propertyData, identifier)
end

function PropertyCapabilities.CanUseWardrobe(propertyData, isInside)
	propertyData = PropertyCapabilities.Normalize(propertyData)

	return propertyData.wardrobe_data.enabled == true and isInside == true
end

function PropertyCapabilities.IsSystemFurnitureType(itemType)
	return itemType == "storage" or itemType == "clothing"
end

function PropertyCapabilities.CountFurnitureType(propertyData, itemType)
	propertyData = PropertyCapabilities.Normalize(propertyData)

	local count = 0

	for index = 1, #propertyData.furnitures do
		if propertyData.furnitures[index].type == itemType then
			count = count + 1
		end
	end

	return count
end

function PropertyCapabilities.GetPlacementLimit(propertyData, itemType)
	propertyData = PropertyCapabilities.Normalize(propertyData)

	if itemType == "storage" then
		return propertyData.storage_data.enabled and propertyData.storage_data.maxPlacements or 0
	end

	if itemType == "clothing" then
		return propertyData.wardrobe_data.enabled and propertyData.wardrobe_data.maxPlacements or 0
	end

	return nil
end

function PropertyCapabilities.CanPlaceItem(propertyData, identifier, itemType)
	propertyData = PropertyCapabilities.Normalize(propertyData)

	if not PropertyCapabilities.CanManageFeatures(propertyData, identifier) then
		return false, "PROPERTY_MANAGE_FORBIDDEN"
	end

	if itemType == "storage" or itemType == "clothing" then
		local limit = PropertyCapabilities.GetPlacementLimit(propertyData, itemType)

		if limit <= 0 then
			return false, itemType == "storage" and "STORAGE_DISABLED" or "WARDROBE_DISABLED"
		end

		if PropertyCapabilities.CountFurnitureType(propertyData, itemType) >= limit then
			return false, itemType == "storage" and "STORAGE_LIMIT_REACHED" or "WARDROBE_LIMIT_REACHED"
		end

		return true
	end

	if propertyData.furniture_mode ~= PropertyCapabilities.FurnitureMode.PLAYER then
		return false, "FURNITURE_PLACEMENT_DISABLED"
	end

	return true
end

function PropertyCapabilities.CanModifyFurniture(propertyData, identifier, furniture)
	propertyData = PropertyCapabilities.Normalize(propertyData)

	if not PropertyCapabilities.CanManageFeatures(propertyData, identifier) then
		return false
	end

	if type(furniture) ~= "table" then
		return false
	end

	if PropertyCapabilities.IsSystemFurnitureType(furniture.type) then
		return true
	end

	return propertyData.furniture_mode == PropertyCapabilities.FurnitureMode.PLAYER
end

function PropertyCapabilities.GetStorageConfig(propertyData)
	propertyData = PropertyCapabilities.Normalize(propertyData)

	return {
		maxweight = propertyData.storage_data.maxWeight,
		maxWeight = propertyData.storage_data.maxWeight,
		slots = propertyData.storage_data.slots,
	}
end

function PropertyCapabilities.BuildLegacyAccess(propertyData)
	propertyData = PropertyCapabilities.Normalize(propertyData)

	local access = {}

	for index = 1, #propertyData.access_data do
		access[#access + 1] = propertyData.access_data[index].identifier
	end

	return access
end

function PropertyCapabilities.FilterFurnitureCatalog(propertyData, identifier)
	propertyData = PropertyCapabilities.Normalize(propertyData)

	if not PropertyCapabilities.CanManageFeatures(propertyData, identifier) then
		return {}
	end

	local filtered = {}

	for categoryIndex = 1, #Config.Furnitures do
		local category = Config.Furnitures[categoryIndex]
		local items = {}

		for itemIndex = 1, #(category.items or {}) do
			local item = category.items[itemIndex]
			local include = propertyData.furniture_mode == PropertyCapabilities.FurnitureMode.PLAYER

			if item.type == "storage" then
				include = propertyData.storage_data.enabled == true
			elseif item.type == "clothing" then
				include = propertyData.wardrobe_data.enabled == true
			end

			if include then
				items[#items + 1] = item
			end
		end

		if #items > 0 then
			filtered[#filtered + 1] = {
				category = category.category,
				items = items,
			}
		end
	end

	return filtered
end
