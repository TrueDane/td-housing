TDHousing = TDHousing or {}
TDHousing.PropertyCapabilityService = TDHousing.PropertyCapabilityService or {}

local PropertyCapabilityService = TDHousing.PropertyCapabilityService
local PropertyCapabilities = TDHousing.PropertyCapabilities
local PropertyRepository = TDHousing.PropertyRepository

local legacyPropertyNew = Property.new
local legacyPlayerEnter = Property.PlayerEnter
local legacyRemoveFromDoorbellPool = Property.RemoveFromDoorbellPool
local legacyStartRaid = Property.StartRaid
local legacyAddMloDoorsAccess = Property.addMloDoorsAccess
local legacyRemoveMloDoorsAccess = Property.removeMloDoorsAccess
local legacyUpdateHasAccess = Property.UpdateHas_access

local entryAuthorizations = {}
local catalog = {}

local function notify(source, description, notificationType)
	if not source or source <= 0 then
		return
	end

	TD.Notify(source, {
		title = "TD-Housing",
		description = description,
		type = notificationType or "inform",
	})
end

local function isServerInvocation()
	local eventSource = tonumber(source)

	return not eventSource or eventSource <= 0 or eventSource == 65535
end

local function getIdentifier(playerSource)
	if not playerSource then
		return nil
	end

	return TD.Player.GetIdentifier(tonumber(playerSource))
end

local function getJobState(playerSource)
	local job = TD.Player.GetJob(playerSource)

	if type(job) ~= "table" then
		return nil, false, 0
	end

	local grade = job.grade

	if type(grade) == "table" then
		grade = grade.level or grade.grade
	end

	return job.name, job.onduty == true or job.onDuty == true, tonumber(grade) or 0
end

local function authorizeEntry(propertyId, playerSource, durationSeconds)
	propertyId = tostring(propertyId)
	playerSource = tonumber(playerSource)

	if not playerSource then
		return
	end

	entryAuthorizations[propertyId] = entryAuthorizations[propertyId] or {}
	entryAuthorizations[propertyId][playerSource] = os.time() + (durationSeconds or 10)
end

local function consumeEntryAuthorization(propertyId, playerSource)
	local propertyAuthorizations = entryAuthorizations[tostring(propertyId)]

	if not propertyAuthorizations then
		return false
	end

	playerSource = tonumber(playerSource)
	local expiresAt = propertyAuthorizations[playerSource]

	if not expiresAt then
		return false
	end

	propertyAuthorizations[playerSource] = nil

	return expiresAt >= os.time()
end

local function canEnterTemporarily(property, playerSource)
	if consumeEntryAuthorization(property.property_id, playerSource) then
		return true
	end

	local jobName, onDuty, grade = getJobState(playerSource)

	if property.raiding and PoliceJobs[jobName] and onDuty and grade >= Config.MinGradeToRaid then
		return true
	end

	if not property.propertyData.owner and RealtorJobs[jobName] and onDuty then
		return true
	end

	return false
end

local function decodeRow(propertyData, row)
	if not row then
		return PropertyCapabilities.Normalize(propertyData)
	end

	propertyData.owner = row.owner_citizenid or propertyData.owner
	propertyData.has_access = row.has_access or propertyData.has_access
	propertyData.access_data = row.access_data
	propertyData.furniture_mode = row.furniture_mode
	propertyData.storage_data = row.storage_data
	propertyData.wardrobe_data = row.wardrobe_data

	return PropertyCapabilities.Normalize(propertyData)
end

local function hydrateProperty(propertyData)
	if not propertyData or not propertyData.property_id then
		return PropertyCapabilities.Normalize(propertyData)
	end

	local success, row = pcall(PropertyRepository.GetCapabilities, propertyData.property_id)

	if not success then
		return PropertyCapabilities.Normalize(propertyData)
	end

	return decodeRow(propertyData, row)
end

local function buildCatalog()
	catalog = {}

	for categoryIndex = 1, #Config.Furnitures do
		local category = Config.Furnitures[categoryIndex]

		for itemIndex = 1, #(category.items or {}) do
			local item = category.items[itemIndex]

			if type(item.object) == "string" and item.object ~= "" then
				local key = ("%s:%s"):format(item.object, item.type or "")

				if not catalog[key] then
					catalog[key] = {
						object = item.object,
						label = item.label or item.object,
						type = item.type,
						price = math.max(0, math.floor(tonumber(item.price) or 0)),
					}
				end
			end
		end
	end
end

local function getCatalogItem(object, itemType)
	if type(object) ~= "string" then
		return nil
	end

	return catalog[("%s:%s"):format(object, itemType or "")]
end

local function finiteNumber(value)
	value = tonumber(value)

	if not value or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end

	return value
end

local function normalizeVector(value)
	if type(value) ~= "table" then
		return nil
	end

	local x = finiteNumber(value.x)
	local y = finiteNumber(value.y)
	local z = finiteNumber(value.z)

	if not x or not y or not z then
		return nil
	end

	return {
		x = math.floor(x * 10000) / 10000,
		y = math.floor(y * 10000) / 10000,
		z = math.floor(z * 10000) / 10000,
	}
end

local function storageStashId(property, furnitureId)
	local storageIndex = 0

	for index = 1, #property.propertyData.furnitures do
		local furniture = property.propertyData.furnitures[index]

		if furniture.type == "storage" then
			storageIndex = storageIndex + 1

			if tostring(furniture.id) == tostring(furnitureId) then
				if storageIndex == 1 then
					return ("property_%s"):format(property.property_id)
				end

				return ("property_%s%s"):format(property.property_id, furniture.id)
			end
		end
	end

	return nil
end

local function registerStorage(property, furniture)
	local stashId = storageStashId(property, furniture.id)

	if not stashId then
		return false
	end

	local storage = PropertyCapabilities.GetStorageConfig(property.propertyData)
	local label = property.propertyData.street
		or property.propertyData.apartment
		or ("Property #%s"):format(property.property_id)

	return TD.Inventory.RegisterStash(stashId, {
		label = ("Property: %s"):format(label),
		slots = storage.slots,
		max_weight = storage.maxWeight,
	}) == true
end

local function syncCapabilities(property)
	local data = PropertyCapabilities.Normalize(property.propertyData)
	local legacyAccess = PropertyCapabilities.BuildLegacyAccess(data)

	property.propertyData.has_access = legacyAccess

	local updated = PropertyRepository.UpdateCapabilities(property.property_id, {
		accessData = data.access_data,
		legacyAccess = legacyAccess,
		furnitureMode = data.furniture_mode,
		storage = data.storage_data,
		wardrobe = data.wardrobe_data,
	})

	if updated then
		TriggerClientEvent("td_housing:client:updateCapabilities", -1, property.property_id, {
			access_data = data.access_data,
			furniture_mode = data.furniture_mode,
			storage_data = data.storage_data,
			wardrobe_data = data.wardrobe_data,
			has_access = legacyAccess,
		})
		TriggerClientEvent(
			"ps-housing:client:updateProperty",
			-1,
			"UpdateHas_access",
			property.property_id,
			legacyAccess
		)
	end

	return updated and true or false
end

local function actorCanManageAccess(property)
	if isServerInvocation() then
		return true
	end

	return PropertyCapabilities.CanManageAccess(property.propertyData, getIdentifier(source))
end

local function findFurniture(property, furnitureId)
	for index = 1, #property.propertyData.furnitures do
		local furniture = property.propertyData.furnitures[index]

		if tostring(furniture.id) == tostring(furnitureId) then
			return furniture, index
		end
	end

	return nil
end

local function persistFurniture(property)
	local updated = PropertyRepository.UpdateFurniture(property.property_id, property.propertyData.furnitures)

	if not updated then
		return false
	end

	for playerSource in pairs(property.playersInside) do
		TriggerClientEvent(
			"ps-housing:client:updateFurniture",
			tonumber(playerSource),
			property.property_id,
			property.propertyData.furnitures
		)
	end

	return true
end

local function canPlaceCart(property, identifier, items)
	local pendingCounts = {
		storage = 0,
		clothing = 0,
	}

	for index = 1, #items do
		local item = items[index]
		local catalogItem = getCatalogItem(item.object, item.type)

		if not catalogItem then
			return nil, "INVALID_FURNITURE_ITEM"
		end

		local itemType = catalogItem.type

		if PropertyCapabilities.IsSystemFurnitureType(itemType) then
			local limit = PropertyCapabilities.GetPlacementLimit(property.propertyData, itemType)
			local existing = PropertyCapabilities.CountFurnitureType(property.propertyData, itemType)
			local pending = pendingCounts[itemType] or 0

			if limit <= 0 or existing + pending >= limit then
				return nil, itemType == "storage" and "STORAGE_LIMIT_REACHED" or "WARDROBE_LIMIT_REACHED"
			end

			pendingCounts[itemType] = pending + 1
		else
			local allowed, errorCode = PropertyCapabilities.CanPlaceItem(property.propertyData, identifier, itemType)

			if not allowed then
				return nil, errorCode
			end
		end
	end

	return true
end

buildCatalog()

Property.new = function(self, propertyData)
	propertyData = hydrateProperty(propertyData)

	local inventoryProvider = Framework[Config.Inventory]
	local originalRegisterInventory = inventoryProvider and inventoryProvider.RegisterInventory

	if originalRegisterInventory then
		inventoryProvider.RegisterInventory = function(stash, label)
			return originalRegisterInventory(stash, label, PropertyCapabilities.GetStorageConfig(propertyData))
		end
	end

	local success, instance = pcall(legacyPropertyNew, self, propertyData)

	if originalRegisterInventory then
		inventoryProvider.RegisterInventory = originalRegisterInventory
	end

	if not success then
		error(instance)
	end

	return instance
end

Property.CheckForAccess = function(self, identifier)
	return PropertyCapabilities.HasDoorAccess(self.propertyData, identifier)
end

Property.PlayerEnter = function(self, playerSource)
	local identifier = getIdentifier(playerSource)

	if
		not PropertyCapabilities.HasDoorAccess(self.propertyData, identifier)
		and not canEnterTemporarily(self, playerSource)
	then
		return false
	end

	legacyPlayerEnter(self, playerSource)
	return true
end

Property.RemoveFromDoorbellPool = function(self, playerSource)
	if self.playersDoorbell[tostring(playerSource)] then
		authorizeEntry(self.property_id, playerSource, 10)
	end

	return legacyRemoveFromDoorbellPool(self, playerSource)
end

Property.StartRaid = function(self, playerSource)
	if playerSource then
		authorizeEntry(self.property_id, playerSource, 10)
	end

	return legacyStartRaid(self)
end

Property.addMloDoorsAccess = function(self, identifier)
	if not actorCanManageAccess(self) then
		return false
	end

	legacyAddMloDoorsAccess(self, identifier)
	return true
end

Property.removeMloDoorsAccess = function(self, identifier)
	if not actorCanManageAccess(self) then
		return false
	end

	legacyRemoveMloDoorsAccess(self, identifier)
	return true
end

Property.UpdateHas_access = function(self, access)
	if not actorCanManageAccess(self) then
		return false
	end

	legacyUpdateHasAccess(self, access)

	local existingRoles = {}

	for index = 1, #self.propertyData.access_data do
		local entry = self.propertyData.access_data[index]
		existingRoles[entry.identifier] = entry.role
	end

	local normalizedAccess = {}

	for index = 1, #(access or {}) do
		local identifier = access[index]

		if type(identifier) == "string" and identifier ~= "" then
			normalizedAccess[#normalizedAccess + 1] = {
				identifier = identifier,
				role = existingRoles[identifier] or PropertyCapabilities.AccessRole.GUEST,
			}
		end
	end

	self.propertyData.access_data = normalizedAccess
	PropertyRepository.UpdateAccess(self.property_id, normalizedAccess, access or {})
	TriggerClientEvent("td_housing:client:updateCapabilities", -1, self.property_id, {
		access_data = normalizedAccess,
		has_access = access or {},
	})

	return true
end

function PropertyCapabilityService.GetCapabilities(propertyId, playerSource)
	local property = Property.Get(propertyId)

	if not property then
		return nil, "PROPERTY_NOT_FOUND"
	end

	local identifier = playerSource and getIdentifier(playerSource) or nil
	local data = PropertyCapabilities.Normalize(property.propertyData)

	return {
		propertyId = tostring(property.property_id),
		role = PropertyCapabilities.GetAccessRole(data, identifier),
		furnitureMode = data.furniture_mode,
		storage = data.storage_data,
		wardrobe = data.wardrobe_data,
	}
end

function PropertyCapabilityService.ApplySettings(propertyId, settings)
	local property = Property.Get(propertyId)

	if not property then
		return nil, "PROPERTY_NOT_FOUND"
	end

	if type(settings) ~= "table" then
		return nil, "INVALID_SETTINGS"
	end

	local data = property.propertyData

	if settings.furnitureMode ~= nil then
		data.furniture_mode = settings.furnitureMode
	end

	if settings.storage ~= nil then
		data.storage_data = settings.storage
	end

	if settings.wardrobe ~= nil then
		data.wardrobe_data = settings.wardrobe
	end

	PropertyCapabilities.Normalize(data)

	if not syncCapabilities(property) then
		return nil, "SETTINGS_UPDATE_FAILED"
	end

	return true
end

function PropertyCapabilityService.GrantAccess(propertyId, identifier, role)
	local property = Property.Get(propertyId)

	if not property then
		return nil, "PROPERTY_NOT_FOUND"
	end

	if type(identifier) ~= "string" or identifier == "" then
		return nil, "INVALID_IDENTIFIER"
	end

	if role ~= PropertyCapabilities.AccessRole.RESIDENT and role ~= PropertyCapabilities.AccessRole.GUEST then
		return nil, "INVALID_ACCESS_ROLE"
	end

	local accessData = property.propertyData.access_data
	local found = false

	for index = 1, #accessData do
		if accessData[index].identifier == identifier then
			accessData[index].role = role
			found = true
			break
		end
	end

	if not found then
		accessData[#accessData + 1] = {
			identifier = identifier,
			role = role,
		}
	end

	property.propertyData.access_data = accessData

	if not syncCapabilities(property) then
		return nil, "ACCESS_UPDATE_FAILED"
	end

	if property.propertyData.shell == "mlo" then
		legacyAddMloDoorsAccess(property, identifier)
	end

	return true
end

function PropertyCapabilityService.RevokeAccess(propertyId, identifier)
	local property = Property.Get(propertyId)

	if not property then
		return nil, "PROPERTY_NOT_FOUND"
	end

	local accessData = property.propertyData.access_data
	local removed = false

	for index = #accessData, 1, -1 do
		if accessData[index].identifier == identifier then
			table.remove(accessData, index)
			removed = true
		end
	end

	if not removed then
		return true
	end

	property.propertyData.access_data = accessData

	if not syncCapabilities(property) then
		return nil, "ACCESS_UPDATE_FAILED"
	end

	if property.propertyData.shell == "mlo" then
		legacyRemoveMloDoorsAccess(property, identifier)
	end

	return true
end

function PropertyCapabilityService.OpenStorage(playerSource, propertyId, furnitureId)
	local property = Property.Get(propertyId)

	if not property then
		return nil, "PROPERTY_NOT_FOUND"
	end

	if not property.playersInside[tostring(playerSource)] then
		return nil, "PLAYER_NOT_INSIDE_PROPERTY"
	end

	local identifier = getIdentifier(playerSource)

	if not PropertyCapabilities.CanUseStorage(property.propertyData, identifier) then
		return nil, "STORAGE_ACCESS_DENIED"
	end

	local furniture = findFurniture(property, furnitureId)

	if not furniture or furniture.type ~= "storage" then
		return nil, "STORAGE_NOT_FOUND"
	end

	local stashId = storageStashId(property, furniture.id)
	local storage = PropertyCapabilities.GetStorageConfig(property.propertyData)
	local label = property.propertyData.street
		or property.propertyData.apartment
		or ("Property #%s"):format(property.property_id)

	registerStorage(property, furniture)

	return TD.Inventory.Open(playerSource, "stash", stashId, {
		id = stashId,
		label = ("Property: %s"):format(label),
		slots = storage.slots,
		max_weight = storage.maxWeight,
	})
end

function PropertyCapabilityService.BuyFurniture(playerSource, propertyId, items, isGarden)
	local property = Property.Get(propertyId)

	if not property then
		return nil, "PROPERTY_NOT_FOUND"
	end

	if not property.playersInside[tostring(playerSource)] and isGarden ~= true then
		return nil, "PLAYER_NOT_INSIDE_PROPERTY"
	end

	if type(items) ~= "table" or #items == 0 or #items > 50 then
		return nil, "INVALID_FURNITURE_ITEMS"
	end

	local identifier = getIdentifier(playerSource)
	local allowed, placementError = canPlaceCart(property, identifier, items)

	if not allowed then
		return nil, placementError
	end

	local additions = {}
	local totalPrice = 0

	for index = 1, #items do
		local rawItem = items[index]
		local catalogItem = getCatalogItem(rawItem.object, rawItem.type)
		local position = normalizeVector(rawItem.position)
		local rotation = normalizeVector(rawItem.rotation)

		if not catalogItem or not position or not rotation then
			return nil, "INVALID_FURNITURE_ITEM"
		end

		totalPrice = totalPrice + catalogItem.price
		additions[#additions + 1] = {
			id = ("%d%s"):format(math.random(100000, 999999), property.property_id),
			label = catalogItem.label,
			object = catalogItem.object,
			position = position,
			rotation = rotation,
			type = catalogItem.type,
		}
	end

	local moneyType

	if totalPrice > 0 then
		local cash = tonumber(TD.Player.GetMoney(playerSource, "cash")) or 0
		local bank = tonumber(TD.Player.GetMoney(playerSource, "bank")) or 0

		if cash >= totalPrice then
			moneyType = "cash"
		elseif bank >= totalPrice then
			moneyType = "bank"
		else
			return nil, "INSUFFICIENT_FUNDS"
		end

		if TD.Player.RemoveMoney(playerSource, moneyType, totalPrice, "TD-Housing furniture purchase") ~= true then
			return nil, "PAYMENT_FAILED"
		end
	end

	local originalCount = #property.propertyData.furnitures

	for index = 1, #additions do
		property.propertyData.furnitures[#property.propertyData.furnitures + 1] = additions[index]
	end

	if not persistFurniture(property) then
		for index = #property.propertyData.furnitures, originalCount + 1, -1 do
			table.remove(property.propertyData.furnitures, index)
		end

		if moneyType then
			TD.Player.AddMoney(playerSource, moneyType, totalPrice, "TD-Housing furniture rollback")
		end

		return nil, "FURNITURE_SAVE_FAILED"
	end

	for index = 1, #additions do
		if additions[index].type == "storage" then
			registerStorage(property, additions[index])
		end
	end

	return {
		totalPrice = totalPrice,
		count = #additions,
	}
end

function PropertyCapabilityService.UpdateFurniture(playerSource, propertyId, furnitureId, position, rotation)
	local property = Property.Get(propertyId)

	if not property then
		return nil, "PROPERTY_NOT_FOUND"
	end

	local identifier = getIdentifier(playerSource)
	local furniture = findFurniture(property, furnitureId)

	if not furniture then
		return nil, "FURNITURE_NOT_FOUND"
	end

	if not PropertyCapabilities.CanModifyFurniture(property.propertyData, identifier, furniture) then
		return nil, "FURNITURE_UPDATE_FORBIDDEN"
	end

	position = normalizeVector(position)
	rotation = normalizeVector(rotation)

	if not position or not rotation then
		return nil, "INVALID_FURNITURE_POSITION"
	end

	furniture.position = position
	furniture.rotation = rotation

	if not persistFurniture(property) then
		return nil, "FURNITURE_SAVE_FAILED"
	end

	return true
end

function PropertyCapabilityService.RemoveFurniture(playerSource, propertyId, furnitureId)
	local property = Property.Get(propertyId)

	if not property then
		return nil, "PROPERTY_NOT_FOUND"
	end

	local identifier = getIdentifier(playerSource)
	local furniture, index = findFurniture(property, furnitureId)

	if not furniture then
		return nil, "FURNITURE_NOT_FOUND"
	end

	if not PropertyCapabilities.CanModifyFurniture(property.propertyData, identifier, furniture) then
		return nil, "FURNITURE_REMOVE_FORBIDDEN"
	end

	table.remove(property.propertyData.furnitures, index)

	if not persistFurniture(property) then
		table.insert(property.propertyData.furnitures, index, furniture)
		return nil, "FURNITURE_SAVE_FAILED"
	end

	return true
end
