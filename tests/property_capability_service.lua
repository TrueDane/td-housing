Config = {
	Furnitures = {},
	Inventory = "bridge",
	MinGradeToRaid = 3,
	Shells = {
		mlo = {
			stash = {
				maxweight = 100000,
				slots = 20,
			},
		},
	},
}

PoliceJobs = {}
RealtorJobs = {
	realestate = true,
}

local propertyState
local persistedFurnitures
local registeredStashes = {}
local inventoryEmptyState = true

Framework = {
	bridge = {
		RegisterInventory = function(stashId, label, stashConfig)
			registeredStashes[#registeredStashes + 1] = {
				id = stashId,
				label = label,
				config = stashConfig,
			}
			return true
		end,
	},
}

TDHousing = {
	PropertyCapabilities = {},
	PropertyRepository = {},
}

local Capabilities = TDHousing.PropertyCapabilities

function Capabilities.Normalize(propertyData)
	propertyData.furnitures = propertyData.furnitures or {}
	propertyData.access_data = propertyData.access_data or {}
	propertyData.has_access = propertyData.has_access or {}
	return propertyData
end

function Capabilities.GetStorageConfig()
	return {
		maxWeight = 100000,
		maxweight = 100000,
		slots = 20,
	}
end

function Capabilities.CanModifyFurniture()
	return true
end

function Capabilities.HasDoorAccess()
	return false
end

function Capabilities.CanManageAccess()
	return true
end

function Capabilities.CanManageFeatures()
	return true
end

function Capabilities.BuildLegacyAccess()
	return {}
end

function Capabilities.GetPlacementLimit()
	return 5
end

function Capabilities.CountFurnitureType()
	return 0
end

function Capabilities.IsSystemFurnitureType()
	return false
end

function Capabilities.CanPlaceItem()
	return true
end

function Capabilities.CanUseStorage()
	return true
end

function Capabilities.GetAccessRole()
	return "owner"
end

function Capabilities.FilterFurnitureCatalog()
	return {}
end

function TDHousing.PropertyRepository.GetCapabilities()
	return nil
end

function TDHousing.PropertyRepository.UpdateFurniture(_, furnitures)
	persistedFurnitures = furnitures
	return 1
end

function TDHousing.PropertyRepository.UpdateCapabilities()
	return 1
end

function TDHousing.PropertyRepository.UpdateAccess()
	return 1
end

Property = {}

function Property.new(_, propertyData)
	for index = 1, #propertyData.furnitures do
		local furniture = propertyData.furnitures[index]

		if furniture.type == "storage" then
			local baseId = ("property_%s"):format(propertyData.property_id)
			local legacyId = index == 1 and baseId or ("%s%s"):format(baseId, furniture.id)

			Framework[Config.Inventory].RegisterInventory(legacyId, "Legacy", Config.Shells.mlo.stash)
		end
	end

	return {
		property_id = tostring(propertyData.property_id),
		propertyData = propertyData,
		playersInside = {},
		playersDoorbell = {},
		raiding = false,
	}
end

function Property.PlayerEnter(self, playerSource)
	self.legacyEntered = playerSource
end

function Property.RemoveFromDoorbellPool() end

function Property.StartRaid() end

function Property.addMloDoorsAccess() end

function Property.removeMloDoorsAccess() end

function Property.UpdateHas_access() end

function Property.Get(propertyId)
	if propertyState and tostring(propertyState.property_id) == tostring(propertyId) then
		return propertyState
	end

	return nil
end

TD = {
	Player = {
		GetIdentifier = function()
			return "OWNER"
		end,
		GetJob = function()
			return {
				name = "realestate",
				grade = 1,
				is_on_duty = true,
			}
		end,
	},
	Inventory = {
		IsEmpty = function(stashId)
			return inventoryEmptyState, stashId
		end,
		RegisterStash = function()
			return true
		end,
		Open = function()
			return true
		end,
	},
	Notify = function() end,
}

function TriggerClientEvent() end

source = 0

dofile("server/services/property_capability_service.lua")

local legacyData = {
	property_id = "42",
	shell = "mlo",
	owner = nil,
	furnitures = {
		{
			id = "chair-1",
			type = "chair",
		},
		{
			id = "storage-1",
			type = "storage",
		},
	},
}

local instance = Property:new(legacyData)

assert(
	legacyData.furnitures[2].stash_id == "property_42storage-1",
	"legacy storage id should be persisted from the original furniture position"
)
assert(persistedFurnitures == legacyData.furnitures, "storage id migration should persist furniture state")
assert(#registeredStashes == 1, "legacy storage should be registered exactly once")
assert(registeredStashes[1].id == "property_42storage-1", "registered stash should use the stable migrated id")

propertyState = instance
Property.PlayerEnter(instance, 15)
assert(instance.legacyEntered == 15, "normalized is_on_duty realtor should retain temporary property entry")

propertyState.propertyData.owner = "OWNER"
propertyState.propertyData.furnitures = {
	{
		id = "storage-1",
		type = "storage",
		stash_id = "property_42storage-1",
	},
}
persistedFurnitures = nil
inventoryEmptyState = false

local removed, removeError = TDHousing.PropertyCapabilityService.RemoveFurniture(15, "42", "storage-1")
assert(removed == nil, "non-empty storage must not be removed")
assert(removeError == "STORAGE_NOT_EMPTY", "non-empty storage should return a stable error")
assert(#propertyState.propertyData.furnitures == 1, "non-empty storage must remain persisted")

inventoryEmptyState = nil

local uncertain, uncertainError = TDHousing.PropertyCapabilityService.RemoveFurniture(15, "42", "storage-1")
assert(uncertain == nil, "unknown storage state must fail closed")
assert(uncertainError == "STORAGE_STATE_UNAVAILABLE", "unknown storage state should return a stable error")
assert(#propertyState.propertyData.furnitures == 1, "unknown storage state must not remove furniture")

inventoryEmptyState = true

local success, successError = TDHousing.PropertyCapabilityService.RemoveFurniture(15, "42", "storage-1")
assert(success == true, "empty storage should be removable")
assert(successError == nil, "successful storage removal should not return an error")
assert(#propertyState.propertyData.furnitures == 0, "empty storage should be removed")
assert(persistedFurnitures == propertyState.propertyData.furnitures, "successful removal should persist furniture")

print("property capability service tests passed")
