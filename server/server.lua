local requiredDoorCapabilities = {
    "create",
    "get",
    "setCharacters",
    "setLocked",
}

for index = 1, #requiredDoorCapabilities do
    local capability = requiredDoorCapabilities[index]

    if not TD.HasCapability("doorlock", capability) then
        error(("TD-Housing requires td_bridge doorlock.%s"):format(capability))
    end
end

local AppearanceService = TDHousing.AppearanceService
local LegacyApartmentMigrationService = TDHousing.LegacyApartmentMigrationService

local dbloaded = false
MySQL.ready(function()
    MySQL.query('SELECT * FROM properties', {}, function(result)
        if not result then
            print("Error: No result returned from properties query.")
            return
        end
        if result.id then -- If only one result
            result = {result}
        end
        for _, v in pairs(result) do
            local id = tostring(v.property_id)
            local has_access = json.decode(v.has_access)
            local owner = v.owner_citizenid
            local propertyData = {
                property_id = tostring(id),
                owner = owner,
                street = v.street,
                region = v.region,
                description = v.description,
                has_access = has_access,
                extra_imgs = json.decode(v.extra_imgs),
                furnitures = json.decode(v.furnitures),
                for_sale = v.for_sale,
                price = v.price,
                shell = v.shell,
                apartment = v.apartment,
                door_data = json.decode(v.door_data),
                garage_data = json.decode(v.garage_data),
                zone_data = v.zone_data,
            }
            PropertiesTable[id] = Property:new(propertyData)

            if v.shell == 'mlo' and owner then
                local property = PropertiesTable[id]
                property:addMloDoorsAccess(owner)

                if has_access and #has_access > 0 then
                    for _, citizenId in ipairs(has_access) do
                        property:addMloDoorsAccess(citizenId)
                    end
                end
            end
        end

        dbloaded = true
    end, function(err)
        print("Error querying properties: " .. err)
    end)
end)

TD.Callback.Register("ps-housing:server:requestProperties", function()
    while not dbloaded do
        Wait(100)
    end

    return PropertiesTable
end)

local function findOnlineSourceByIdentifier(identifier)
    if type(identifier) ~= "string" or identifier == "" then
        return nil
    end

    for _, playerId in ipairs(GetPlayers()) do
        local playerSource = tonumber(playerId)

        if playerSource and TD.Player.GetIdentifier(playerSource) == identifier then
            return playerSource
        end
    end

    return nil
end

local function ensureFirstCharacter(playerSource, identifier)
    local success, status, message = AppearanceService.EnsureFirstCharacter(playerSource, identifier)

    if success ~= true then
        Debug(
            ("Unable to ensure character appearance for %s (%s): %s"):format(
                tostring(identifier),
                status or "UNKNOWN_ERROR",
                message or "Unknown appearance error"
            )
        )
    end

    return success, status
end

local function migrateLegacyApartmentStash(identifier, propertyId)
    local success, status, message = LegacyApartmentMigrationService.MigrateStash(identifier, propertyId)

    if success ~= true then
        Debug(
            ("Unable to migrate legacy apartment stash for %s (%s): %s"):format(
                tostring(identifier),
                status or "UNKNOWN_ERROR",
                message or "Unknown migration error"
            )
        )
    end

    return success, status
end

function RegisterProperty(propertyData, preventEnter, source)
    propertyData.owner = propertyData.owner or nil
    propertyData.has_access = propertyData.has_access or {}
    propertyData.extra_imgs = propertyData.extra_imgs or {}
    propertyData.furnitures = propertyData.furnitures or {}
    propertyData.door_data = propertyData.door_data or {}
    propertyData.garage_data = propertyData.garage_data or {}
    propertyData.zone_data = propertyData.zone_data or {}

    local cols = "(owner_citizenid, street, region, description, has_access, extra_imgs, furnitures, for_sale, price, shell, apartment, door_data, garage_data, zone_data)"
    local vals = "(@owner_citizenid, @street, @region, @description, @has_access, @extra_imgs, @furnitures, @for_sale, @price, @shell, @apartment, @door_data, @garage_data, @zone_data)"

    local id = MySQL.insert.await("INSERT INTO properties " .. cols .. " VALUES " .. vals , {
        ["@owner_citizenid"] = propertyData.owner or nil,
        ["@street"] = propertyData.street,
        ["@region"] = propertyData.region,
        ["@description"] = propertyData.description,
        ["@has_access"] = json.encode(propertyData.has_access),
        ["@extra_imgs"] = json.encode(propertyData.extra_imgs),
        ["@furnitures"] = json.encode(propertyData.furnitures),
        ["@for_sale"] = propertyData.for_sale ~= nil and propertyData.for_sale or 1,
        ["@price"] = propertyData.price or 0,
        ["@shell"] = propertyData.shell or '',
        ["@apartment"] = propertyData.apartment,
        ["@door_data"] = json.encode(propertyData.shell == 'mlo' and {count = #propertyData.door_data} or propertyData.door_data),
        ["@garage_data"] = json.encode(propertyData.garage_data),
        ["@zone_data"] = json.encode(propertyData.zone_data),
    })

    if source and propertyData.shell == 'mlo' then
        for index, door in ipairs(propertyData.door_data) do
            local isDouble = door[1] ~= nil
            local name = ('ps_mloproperty%s_%s'):format(id, index)
            local doorData = {
                name = name,
                locked = true,
                distance = 2.5,
            }

            if isDouble then
                doorData.doors = door
            else
                doorData.model = door.model
                doorData.coords = door.coords
                doorData.heading = door.heading
            end

            local success, errorCode, errorMessage = TD.Door.Create(source, doorData)

            if success ~= true then
                error(
                    ("Failed to create Housing door %s (%s): %s"):format(
                        name,
                        errorCode or "UNKNOWN_ERROR",
                        errorMessage or "Unknown provider error"
                    )
                )
            end
        end

        propertyData.door_data = {
            count = #propertyData.door_data,
        }

        Wait(1000)
    end

    id = tostring(id)
    propertyData.property_id = id
    PropertiesTable[id] = Property:new(propertyData)

    TriggerClientEvent("ps-housing:client:addProperty", -1, propertyData)

    if propertyData.apartment and not preventEnter then
        local src = findOnlineSourceByIdentifier(propertyData.owner)

        if not src then
            print("Error: Player not found for citizen ID " .. tostring(propertyData.owner))
            return
        end

        local property = Property.Get(id)
        if not property then
            print("Error: Property not found for ID " .. id)
            return
        end

        property:PlayerEnter(src)

        Wait(1000)
        ensureFirstCharacter(src, propertyData.owner)

        Framework[Config.Notify].Notify(
            src,
            "Open radial menu for furniture menu and place down your stash and clothing locker.",
            "info"
        )

        migrateLegacyApartmentStash(propertyData.owner, id)
    end

    return id
end

local function getMainDoor(propertyId, doorIndex, isShell)
    -- ps_mloproperty is prefix, self.property_id is property unique id, 1 is main door index, cause mlo can have multiple doors

    if isShell then
        local property = Property.Get(propertyId)
        if not property then return end
        return {
            coords = property.propertyData.door_data
        }
    end

    local id = ('ps_mloproperty%s_%s'):format(propertyId, doorIndex)
    local door = TD.Door.Get(id)

    return door and door.raw or nil
end
exports('getMainDoor', getMainDoor)
lib.callback.register("ps-housing:cb:getMainMloDoor", function(_, propertyId, doorIndex)
    return getMainDoor(propertyId, doorIndex)
end)

exports('registerProperty', RegisterProperty) -- triggered by realtor job
AddEventHandler("ps-housing:server:registerProperty", RegisterProperty)

TD.Callback.Register("ps-housing:cb:GetOwnedApartment", function(source, cid)
    Debug("ps-housing:cb:GetOwnedApartment", source, cid)

    local identifier = cid or TD.Player.GetIdentifier(source)

    if not identifier then
        print("Error: Player identifier not found for source: " .. tostring(source))
        return nil
    end

    local success, result = pcall(function()
        return MySQL.query.await(
            'SELECT * FROM properties WHERE owner_citizenid = ? AND apartment IS NOT NULL AND apartment <> ""',
            { identifier }
        )
    end)

    if not success then
        print("Error querying database for owned apartment with identifier: " .. identifier .. " - " .. result)
        return nil
    end

    if result and result[1] then
        return result[1]
    end

    return nil
end)

AddEventHandler("ps-housing:server:updateProperty", function(type, property_id, data)
    local property = Property.Get(property_id)
    if not property then return end

    property[type](property, data)
end)

AddEventHandler("onResourceStart", function(resourceName) -- Used for when the resource is restarted while in game
    if GetCurrentResourceName() == resourceName then
        while not dbloaded do
            Wait(100)
        end
        TriggerClientEvent('ps-housing:client:initialiseProperties', -1, PropertiesTable)
    end
end)

RegisterNetEvent("ps-housing:server:createNewApartment", function(aptLabel)
    local src = source
    local citizenid = GetCitizenid(src)
    if not Config.StartingApartment then return end
    local player = TD.Player.Get(src)

    if not player then
        return
    end

    local apartment = Config.Apartments[aptLabel]
    if not apartment then return end

    local propertyData = {
        owner = citizenid,
        description = string.format("This is %s's apartment in %s", player.name or citizenid, apartment.label),
        for_sale = 0,
        shell = apartment.shell,
        apartment = apartment.label,
    }

    Debug("Creating new apartment for " .. GetPlayerName(src) .. " in " .. apartment.label)

    Framework[Config.Logs].SendLog("Creating new apartment for " .. GetPlayerName(src) .. " in " .. apartment.label)

    RegisterProperty(propertyData)
end)

AddEventHandler("td_bridge:server:playerLoaded", function(playerSource)
    if Config.StartingApartment then
        return
    end

    local src = tonumber(playerSource)

    if not src then
        return
    end

    local citizenid = GetCitizenid(src)

    if citizenid then
        ensureFirstCharacter(src, citizenid)
    end
end)

AddEventHandler("ps-housing:server:addTenantToApartment", function(data)
    local apartment = data.apartment
    local targetSrc = tonumber(data.targetSrc)
    local realtorSrc = data.realtorSrc
    local targetCitizenid = GetCitizenid(targetSrc, realtorSrc)

    -- id of current apartment so we can change it
    local property_id = nil

    for _, v in pairs(PropertiesTable) do
        local propertyData = v.propertyData
        if propertyData.owner == targetCitizenid then
            if propertyData.apartment == apartment then
                Framework[Config.Notify].Notify(targetSrc, "You are already in this apartment", "error")
                Framework[Config.Notify].Notify(targetSrc, "This person is already in this apartment", "error")

                return
            elseif propertyData.apartment and #propertyData.apartment > 1 then
                property_id = propertyData.property_id
                break
            end
        end
    end

    if property_id == nil then
        local newApartment = Config.Apartments[apartment]
        if not newApartment then return end

        local targetPlayer = TD.Player.Get(targetSrc)

        if not targetPlayer then
            Framework[Config.Notify].Notify(realtorSrc, "Player not found.", "error")
            return
        end

        local propertyData = {
            owner = targetCitizenid,
            description = string.format("This is %s's apartment in %s", targetPlayer.name or targetCitizenid, newApartment.label),
            for_sale = 0,
            shell = newApartment.shell,
            apartment = newApartment.label,
        }

        Debug("Creating new apartment for " .. GetPlayerName(targetSrc) .. " in " .. newApartment.label)

        Framework[Config.Logs].SendLog("Creating new apartment for " .. GetPlayerName(targetSrc) .. " in " .. newApartment.label)

        Framework[Config.Notify].Notify(targetSrc, "Your apartment is now at " .. apartment, "success")
        Framework[Config.Notify].Notify(
            realtorSrc,
            "You have added " .. (targetPlayer.name or targetCitizenid) .. " to apartment " .. apartment,
            "success"
        )

        RegisterProperty(propertyData, true)

        return
    end

    local property = Property.Get(property_id)
    if not property then return end

    property:UpdateApartment(data)

    local targetPlayer = TD.Player.Get(targetSrc)

    if not targetPlayer then
        Framework[Config.Notify].Notify(realtorSrc, "Player not found.", "error")
        return
    end

    Framework[Config.Notify].Notify(targetSrc, "Your apartment is now at " .. apartment, "success")
    Framework[Config.Notify].Notify(
        realtorSrc,
        "You have added " .. (targetPlayer.name or targetCitizenid) .. " to apartment " .. apartment,
        "success"
    )
end)

exports('IsOwner', function(src, property_id)
    local property = Property.Get(property_id)
    if not property then return false end

    local citizenid = GetCitizenid(src, src)
    return property:CheckForAccess(citizenid)
end)

function GetCitizenid(targetSrc, callerSrc)
    local citizenid = TD.Player.GetIdentifier(tonumber(targetSrc))

    if not citizenid then
        if callerSrc then
            Framework[Config.Notify].Notify(callerSrc, "Player not found.", "error")
        end

        return
    end

    return citizenid
end

function GetCharName(src)
    local player = TD.Player.Get(tonumber(src))

    if not player then
        return
    end

    return player.name
end
