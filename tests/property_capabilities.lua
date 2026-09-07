Config = {
    Shells = {
        mlo = {
            stash = {
                maxweight = 100000,
                slots = 12,
            },
        },
    },
    Furnitures = {
        {
            category = 'Prerequisites',
            items = {
                {
                    object = 'storage_prop',
                    label = 'Storage',
                    price = 0,
                    type = 'storage',
                },
                {
                    object = 'wardrobe_prop',
                    label = 'Wardrobe',
                    price = 0,
                    type = 'clothing',
                },
            },
        },
        {
            category = 'Furniture',
            items = {
                {
                    object = 'chair_prop',
                    label = 'Chair',
                    price = 500,
                },
            },
        },
    },
}

json = {
    decode = function()
        error('JSON decoding is not expected in this unit test')
    end,
}

dofile('shared/property_capabilities.lua')

local Capabilities = TDHousing.PropertyCapabilities

local property = Capabilities.Normalize({
    owner = 'OWNER',
    shell = 'mlo',
    has_access = {
        'LEGACY_GUEST',
    },
    access_data = {
        {
            identifier = 'RESIDENT',
            role = 'resident',
        },
        {
            identifier = 'GUEST',
            role = 'guest',
        },
    },
    furniture_mode = 'fixed',
    storage_data = {
        enabled = true,
        maxWeight = 200000,
        slots = 30,
        maxPlacements = 1,
    },
    wardrobe_data = {
        enabled = true,
        maxPlacements = 1,
    },
    furnitures = {},
})

assert(Capabilities.GetAccessRole(property, 'OWNER') == 'owner', 'owner role should be resolved')
assert(Capabilities.GetAccessRole(property, 'RESIDENT') == 'resident', 'resident role should be resolved')
assert(Capabilities.GetAccessRole(property, 'GUEST') == 'guest', 'guest role should be resolved')
assert(Capabilities.GetAccessRole(property, 'LEGACY_GUEST') == 'guest', 'legacy access should normalize to guest')
assert(Capabilities.GetAccessRole(property, 'UNKNOWN') == 'visitor', 'unknown identifier should be visitor')

assert(Capabilities.HasDoorAccess(property, 'OWNER') == true, 'owner should have door access')
assert(Capabilities.HasDoorAccess(property, 'RESIDENT') == true, 'resident should have door access')
assert(Capabilities.HasDoorAccess(property, 'GUEST') == true, 'guest should have door access')
assert(Capabilities.HasDoorAccess(property, 'UNKNOWN') == false, 'visitor should not have door access by default')

assert(Capabilities.CanUseStorage(property, 'OWNER') == true, 'owner should use storage')
assert(Capabilities.CanUseStorage(property, 'RESIDENT') == true, 'resident should use storage')
assert(Capabilities.CanUseStorage(property, 'GUEST') == false, 'guest should not use storage')
assert(Capabilities.CanUseStorage(property, 'UNKNOWN') == false, 'visitor should not use storage')

assert(Capabilities.CanUseWardrobe(property, true) == true, 'anyone physically inside should use wardrobe')
assert(Capabilities.CanUseWardrobe(property, false) == false, 'wardrobe should require physical presence')

local storage = Capabilities.GetStorageConfig(property)
assert(storage.maxWeight == 200000, 'property storage weight should override shell')
assert(storage.maxweight == 200000, 'legacy maxweight alias should be preserved')
assert(storage.slots == 30, 'property storage slots should override shell')

local canPlaceStorage = Capabilities.CanPlaceItem(property, 'RESIDENT', 'storage')
local canPlaceWardrobe = Capabilities.CanPlaceItem(property, 'RESIDENT', 'clothing')
local canPlaceFurniture, furnitureError = Capabilities.CanPlaceItem(property, 'RESIDENT', nil)
local guestCanPlace = Capabilities.CanPlaceItem(property, 'GUEST', 'storage')

assert(canPlaceStorage == true, 'fixed properties should still allow storage placement')
assert(canPlaceWardrobe == true, 'fixed properties should still allow wardrobe placement')
assert(canPlaceFurniture == false, 'fixed properties should block normal furniture placement')
assert(furnitureError == 'FURNITURE_PLACEMENT_DISABLED', 'fixed furniture error should be stable')
assert(guestCanPlace == false, 'guest should not place property features')

property.furnitures = {
    {
        id = 'storage-1',
        type = 'storage',
    },
    {
        id = 'wardrobe-1',
        type = 'clothing',
    },
}

local secondStorage, storageError = Capabilities.CanPlaceItem(property, 'OWNER', 'storage')
local secondWardrobe, wardrobeError = Capabilities.CanPlaceItem(property, 'OWNER', 'clothing')

assert(secondStorage == false, 'storage placement limit should be enforced')
assert(storageError == 'STORAGE_LIMIT_REACHED', 'storage limit error should be stable')
assert(secondWardrobe == false, 'wardrobe placement limit should be enforced')
assert(wardrobeError == 'WARDROBE_LIMIT_REACHED', 'wardrobe limit error should be stable')

local filtered = Capabilities.FilterFurnitureCatalog(property, 'OWNER')
assert(#filtered == 1, 'fixed property catalog should only contain system features')
assert(#filtered[1].items == 2, 'fixed property catalog should expose stash and wardrobe')

local legacyProperty = Capabilities.Normalize({
    owner = 'OWNER',
    shell = 'mlo',
    has_access = {},
    furnitures = {},
})
local legacyStorage = Capabilities.GetStorageConfig(legacyProperty)

assert(legacyStorage.maxWeight == 100000, 'legacy property should fall back to shell storage weight')
assert(legacyStorage.slots == 12, 'legacy property should fall back to shell storage slots')
assert(legacyProperty.furniture_mode == 'player', 'legacy property should default to player furniture mode')

print('property capability tests passed')
