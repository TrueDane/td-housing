TDHousing = TDHousing or {}

local PropertyCapabilities = TDHousing.PropertyCapabilities
local capabilityCache = {}
local legacyGiveMenus = Property.GiveMenus
local legacyLoadFurniture = Property.LoadFurniture
local legacyModelerOpenMenu = Modeler.OpenMenu

local function notify(description, notificationType)
	TD.Notify({
		title = "TD-Housing",
		description = description,
		type = notificationType or "inform",
	})
end

local function floor(value)
	return math.floor(value * 10000) / 10000
end

local function getCapabilities(propertyId, refresh)
	propertyId = tostring(propertyId)

	if not refresh and capabilityCache[propertyId] then
		return capabilityCache[propertyId]
	end

	local capabilities = TD.Callback.Await("td_housing:server:getPropertyCapabilities", propertyId)

	if type(capabilities) ~= "table" then
		return nil
	end

	capabilityCache[propertyId] = capabilities
	return capabilities
end

local function applyCapabilities(property, capabilities)
	if not property or type(capabilities) ~= "table" then
		return
	end

	if capabilities.furnitureMode ~= nil then
		property.propertyData.furniture_mode = capabilities.furnitureMode
	end

	if capabilities.storage ~= nil then
		property.propertyData.storage_data = capabilities.storage
	end

	if capabilities.wardrobe ~= nil then
		property.propertyData.wardrobe_data = capabilities.wardrobe
	end
end

local function isManager(capabilities)
	return capabilities
		and (
			capabilities.role == PropertyCapabilities.AccessRole.OWNER
			or capabilities.role == PropertyCapabilities.AccessRole.RESIDENT
		)
end

local function buildCatalog(property, capabilities)
	applyCapabilities(property, capabilities)

	local propertyData = {
		owner = "__td_housing_actor__",
		has_access = {},
		access_data = {},
		furniture_mode = property.propertyData.furniture_mode,
		storage_data = property.propertyData.storage_data,
		wardrobe_data = property.propertyData.wardrobe_data,
		shell = property.propertyData.shell,
		furnitures = property.propertyData.furnitures,
	}

	return PropertyCapabilities.FilterFurnitureCatalog(propertyData, "__td_housing_actor__")
end

local function normalizeOffset(self, property, position)
	if property.propertyData.shell == "mlo" then
		return {
			x = floor(position.x),
			y = floor(position.y),
			z = floor(position.z),
		}
	end

	return {
		x = floor(position.x - self.shellPos.x),
		y = floor(position.y - self.shellPos.y),
		z = floor(position.z - self.shellPos.z),
	}
end

RegisterNetEvent("td_housing:client:updateCapabilities", function(propertyId, data)
	propertyId = tostring(propertyId)

	local property = Property.Get(propertyId)
	local cached = capabilityCache[propertyId] or {}

	if type(data) == "table" then
		if data.furniture_mode ~= nil then
			cached.furnitureMode = data.furniture_mode
		end

		if data.storage_data ~= nil then
			cached.storage = data.storage_data
		end

		if data.wardrobe_data ~= nil then
			cached.wardrobe = data.wardrobe_data
		end

		if property then
			property.propertyData.access_data = data.access_data or property.propertyData.access_data
			property.propertyData.has_access = data.has_access or property.propertyData.has_access
			property.propertyData.furniture_mode = data.furniture_mode or property.propertyData.furniture_mode
			property.propertyData.storage_data = data.storage_data or property.propertyData.storage_data
			property.propertyData.wardrobe_data = data.wardrobe_data or property.propertyData.wardrobe_data
		end
	end

	capabilityCache[propertyId] = cached
end)

Property.LoadFurniture = function(self, furniture)
	TDHousing.CurrentFurnitureId = furniture and furniture.id or nil
	local result = legacyLoadFurniture(self, furniture)
	TDHousing.CurrentFurnitureId = nil

	return result
end

Config.FurnitureTypes.storage = function(entity, propertyId, _, legacyId)
	local furnitureId = TDHousing.CurrentFurnitureId or legacyId

	TD.Target.AddLocalEntity(entity, {
		{
			name = ("td_housing_storage_%s_%s"):format(propertyId, tostring(furnitureId)),
			label = "Stash",
			icon = "fas fa-box-open",
			onSelect = function()
				TriggerServerEvent("td_housing:server:openStorage", propertyId, furnitureId)
			end,
		},
	}, 2.0)

	local property = Property.Get(propertyId)

	if property then
		property.storageTarget = property.storageTarget or {}
		property.storageTarget[entity] = furnitureId
	end
end

Config.FurnitureTypes.clothing = function(entity, propertyId)
	TD.Target.AddLocalEntity(entity, {
		{
			name = ("td_housing_wardrobe_%s"):format(propertyId),
			label = "Garderobe",
			icon = "fas fa-shirt",
			canInteract = function()
				local property = Property.Get(propertyId)
				return property ~= nil and property.inProperty == true
			end,
			onSelect = function()
				local property = Property.Get(propertyId)

				if not property or property.inProperty ~= true then
					return
				end

				local success, errorCode = TDHousing.Wardrobe.Open()

				if not success then
					notify(("Garderoben kunne ikke åbnes (%s)."):format(errorCode or "UNKNOWN_ERROR"), "error")
				end
			end,
		},
	}, 2.0)

	local property = Property.Get(propertyId)

	if property then
		property.clothingTarget = entity
	end
end

Property.GiveMenus = function(self, garden)
	local capabilities = getCapabilities(self.property_id, true)
	local originalAccessCanEdit = Config.AccessCanEditFurniture

	Config.AccessCanEditFurniture = isManager(capabilities)
	legacyGiveMenus(self, garden)
	Config.AccessCanEditFurniture = originalAccessCanEdit

	if self.owner and capabilities then
		capabilityCache[tostring(self.property_id)] = capabilities
	end
end

Modeler.OpenMenu = function(self, propertyId)
	local property = Property.Get(propertyId)

	if not property then
		return
	end

	local capabilities = getCapabilities(propertyId, true)

	if not isManager(capabilities) then
		notify("Du må ikke ændre denne bolig.", "error")
		return
	end

	local originalCatalog = Config.Furnitures
	local originalAccessCanEdit = Config.AccessCanEditFurniture

	Config.Furnitures = buildCatalog(property, capabilities)
	Config.AccessCanEditFurniture = true
	legacyModelerOpenMenu(self, propertyId)
	Config.Furnitures = originalCatalog
	Config.AccessCanEditFurniture = originalAccessCanEdit
end

Modeler.BuyCart = function(self)
	if not next(self.Cart) then
		notify("Din kurv er tom.", "error")
		return
	end

	local property = Property.Get(self.property_id)

	if not property then
		return
	end

	local capabilities = getCapabilities(self.property_id, true)

	if not isManager(capabilities) then
		notify("Du må ikke ændre denne bolig.", "error")
		return
	end

	local items = {}

	for _, item in pairs(self.Cart) do
		local position = item.position

		items[#items + 1] = {
			object = item.object,
			type = item.type,
			position = normalizeOffset(self, property, position),
			rotation = {
				x = item.rotation.x,
				y = item.rotation.y,
				z = item.rotation.z,
			},
		}
	end

	TriggerServerEvent("td_housing:server:buyFurniture", self.property_id, items, property.inGarden == true)
	self:ClearCart()
end

Modeler.UpdateFurniture = function(self, item)
	if not item or not item.entity then
		return
	end

	local property = Property.Get(self.property_id)

	if not property then
		return
	end

	local capabilities = getCapabilities(self.property_id, true)

	if not isManager(capabilities) then
		notify("Du må ikke flytte dette objekt.", "error")
		return
	end

	local position = GetEntityCoords(item.entity)
	local rotation = GetEntityRotation(item.entity)

	TriggerServerEvent(
		"td_housing:server:updateFurniture",
		self.property_id,
		item.id,
		normalizeOffset(self, property, position),
		{
			x = rotation.x,
			y = rotation.y,
			z = rotation.z,
		}
	)
end

Modeler.RemoveOwnedItem = function(self, item)
	if type(item) ~= "table" or not item.id then
		return
	end

	local capabilities = getCapabilities(self.property_id, true)

	if not isManager(capabilities) then
		notify("Du må ikke fjerne dette objekt.", "error")
		return
	end

	if item.entity then
		DeleteEntity(item.entity)
	end

	SendNUIMessage({
		action = "removeOwnedItem",
		data = item,
	})

	TriggerServerEvent("td_housing:server:removeFurniture", self.property_id, item.id)
end
