local PropertyCapabilityService = TDHousing.PropertyCapabilityService
local PropertyCapabilities = TDHousing.PropertyCapabilities

local realtorJobs = {}

for index = 1, #Config.RealtorJobNames do
    realtorJobs[Config.RealtorJobNames[index]] = true
end

local function notify(playerSource, description, notificationType)
    TD.Notify(playerSource, {
        title = 'TD-Housing',
        description = description,
        type = notificationType or 'inform',
    })
end

local function getJobState(playerSource)
    local job = TD.Player.GetJob(playerSource)

    if type(job) ~= 'table' then
        return nil, false
    end

    return job.name, job.onduty == true or job.onDuty == true
end

local function canManageAccess(playerSource, property)
    local identifier = TD.Player.GetIdentifier(playerSource)

    return PropertyCapabilities.CanManageAccess(property.propertyData, identifier)
end

RegisterNetEvent('ps-housing:server:buyFurniture', function(propertyId, items, _, isGarden)
    local playerSource = source
    local result, errorCode = PropertyCapabilityService.BuyFurniture(playerSource, propertyId, items, isGarden)

    if not result then
        notify(playerSource, ('Handlingen blev afvist (%s).'):format(errorCode or 'UNKNOWN_ERROR'), 'error')
    end
end)

RegisterNetEvent('ps-housing:server:openQBInv', function()
    notify(source, 'Denne stash-handler er udgået. Åbn stashen igen via boligens target.', 'error')
end)

RegisterNetEvent('ps-housing:server:removeFurniture', function(propertyId, furnitureId)
    local playerSource = source
    local success, errorCode = PropertyCapabilityService.RemoveFurniture(playerSource, propertyId, furnitureId)

    if not success then
        notify(playerSource, ('Objektet kunne ikke fjernes (%s).'):format(errorCode or 'UNKNOWN_ERROR'), 'error')
    end
end)

RegisterNetEvent('ps-housing:server:updateFurniture', function(propertyId, item)
    local playerSource = source

    if type(item) ~= 'table' then
        return
    end

    local success, errorCode = PropertyCapabilityService.UpdateFurniture(
        playerSource,
        propertyId,
        item.id,
        item.position,
        item.rotation
    )

    if not success then
        notify(playerSource, ('Objektet kunne ikke flyttes (%s).'):format(errorCode or 'UNKNOWN_ERROR'), 'error')
    end
end)

RegisterNetEvent('ps-housing:server:addAccess', function(propertyId, targetSource)
    local playerSource = source
    local property = Property.Get(propertyId)

    if not property or not canManageAccess(playerSource, property) then
        notify(playerSource, 'Kun boligens ejer kan give adgang.', 'error')
        return
    end

    targetSource = tonumber(targetSource)
    local targetIdentifier = targetSource and TD.Player.GetIdentifier(targetSource) or nil

    if not targetIdentifier then
        notify(playerSource, 'Spilleren blev ikke fundet.', 'error')
        return
    end

    local success, errorCode = PropertyCapabilityService.GrantAccess(propertyId, targetIdentifier, 'guest')

    if not success then
        notify(playerSource, ('Adgangen kunne ikke gives (%s).'):format(errorCode or 'UNKNOWN_ERROR'), 'error')
        return
    end

    notify(playerSource, 'Gæsteadgang er givet.', 'success')
    notify(targetSource, 'Du har fået adgang til boligen.', 'success')
end)

RegisterNetEvent('ps-housing:server:removeAccess', function(propertyId, identifier)
    local playerSource = source
    local property = Property.Get(propertyId)

    if not property or not canManageAccess(playerSource, property) then
        notify(playerSource, 'Kun boligens ejer kan fjerne adgang.', 'error')
        return
    end

    local success, errorCode = PropertyCapabilityService.RevokeAccess(propertyId, identifier)

    if not success then
        notify(playerSource, ('Adgangen kunne ikke fjernes (%s).'):format(errorCode or 'UNKNOWN_ERROR'), 'error')
        return
    end

    notify(playerSource, 'Adgangen er fjernet.', 'success')
end)

lib.callback.register('ps-housing:cb:getPropertyInfo', function(source, propertyId)
    local jobName, onDuty = getJobState(source)

    if not realtorJobs[jobName] or not onDuty then
        return nil
    end

    local property = Property.Get(propertyId)

    if not property then
        return nil
    end

    local data = property.propertyData

    return {
        owner = data.owner and 'Registered owner' or 'No Owner',
        street = data.street,
        region = data.region,
        description = data.description,
        for_sale = data.for_sale,
        price = data.price,
        shell = data.shell,
        property_id = property.property_id,
    }
end)

lib.callback.register('ps-housing:cb:getPlayersInProperty', function(source, propertyId)
    local property = Property.Get(propertyId)

    if not property or not canManageAccess(source, property) then
        return {}
    end

    local players = {}

    for playerId in pairs(property.playersInside) do
        local targetSource = tonumber(playerId)

        if targetSource and targetSource ~= source then
            players[#players + 1] = {
                src = targetSource,
                name = GetPlayerName(targetSource) or ('Player %s'):format(targetSource),
            }
        end
    end

    return players
end)

lib.callback.register('ps-housing:cb:inventoryHasItems', function(source, stashId)
    if type(stashId) ~= 'string' then
        return true
    end

    local propertyId = stashId:match('^property_(%d+)')
    local property = propertyId and Property.Get(propertyId) or nil

    if not property or not PropertyCapabilities.CanManageFeatures(property.propertyData, TD.Player.GetIdentifier(source)) then
        return true
    end

    -- Until td_bridge exposes a provider-neutral stash-content query, be conservative:
    -- legacy clients may not delete a storage point based on client-supplied inventory state.
    return true
end)
