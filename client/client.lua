PlayerData = {}
local loaded = false

local function setPlayerData(playerData)
	if type(playerData) ~= "table" or not playerData.identifier then
		PlayerData = {}
		return false
	end

	PlayerData = {
		citizenid = playerData.identifier,
		job = playerData.job,
		name = playerData.name,
	}

	return true
end

local function createProperty(property)
	PropertiesTable[property.property_id] = Property:new(property)
end

local function clearProperties()
	if Modeler.IsMenuActive then
		Modeler:CloseMenu()
	end

	for propertyId, property in pairs(PropertiesTable) do
		property:RemoveProperty()
		PropertiesTable[propertyId] = nil
	end

	for apartmentId, apartment in pairs(ApartmentsTable) do
		apartment:RemoveApartment()
		ApartmentsTable[apartmentId] = nil
	end

	loaded = false
end

RegisterNetEvent("ps-housing:client:addProperty", createProperty)

RegisterNetEvent("ps-housing:client:removeProperty", function(propertyId)
	local property = Property.Get(propertyId)

	if property then
		property:RemoveProperty(true)
	end

	PropertiesTable[propertyId] = nil
end)

function InitialiseProperties(properties)
	if loaded then
		return
	end

	if not setPlayerData(TD.Player.GetData()) then
		return
	end

	Debug("Initialising properties")

	for apartmentId, apartmentData in pairs(Config.Apartments) do
		ApartmentsTable[apartmentId] = Apartment:new(apartmentData)
	end

	if not properties then
		properties = TD.Callback.Await("ps-housing:server:requestProperties")
	end

	for _, property in pairs(properties or {}) do
		createProperty(property.propertyData)
	end

	TriggerEvent("ps-housing:client:initialisedProperties")

	Debug("Initialised properties")
	loaded = true
end

AddEventHandler("td_bridge:client:playerLoaded", function(playerData)
	setPlayerData(playerData)
	InitialiseProperties()
end)

AddEventHandler("td_bridge:client:playerUnloaded", function()
	clearProperties()
	PlayerData = {}
end)

AddEventHandler("td_bridge:client:jobChanged", function(job)
	PlayerData.job = job
end)

RegisterNetEvent("ps-housing:client:initialiseProperties", InitialiseProperties)

CreateThread(function()
	if setPlayerData(TD.Player.GetData()) then
		InitialiseProperties()
	end
end)

RegisterNetEvent("ps-housing:client:setupSpawnUI", function(cData)
	DoScreenFadeOut(1000)

	if not TD.HasCapability("spawn", "open") then
		Framework[Config.Notify].Notify("Spawn provider is unavailable.", "error")
		DoScreenFadeIn(500)
		return
	end

	local result = TD.Callback.Await("ps-housing:cb:GetOwnedApartment", cData.citizenid)

	if result or not Config.StartingApartment then
		TD.Spawn.Open(cData)
		return
	end

	if TD.HasCapability("spawn", "openStartingApartments") then
		TD.Spawn.OpenStartingApartments(cData, Config.Apartments)
		return
	end

	Debug("Configured spawn provider does not support Housing starting-apartment selection; using generic spawn flow")
	TD.Spawn.Open(cData)
end)

AddEventHandler("onResourceStop", function(resourceName)
	if GetCurrentResourceName() == resourceName then
		clearProperties()
	end
end)

exports("GetProperties", function()
	return PropertiesTable
end)

exports("GetProperty", function(propertyId)
	return Property.Get(propertyId)
end)

exports("GetApartments", function()
	return ApartmentsTable
end)

exports("GetApartment", function(apartment)
	return Apartment.Get(apartment)
end)

exports("GetShells", function()
	return Config.Shells
end)

lib.callback.register("ps-housing:cb:confirmPurchase", function(amount, street, id)
	return lib.alertDialog({
		header = "Purchase Confirmation",
		content = "Are you sure you want to purchase " .. street .. " " .. id .. " for $" .. amount .. "?",
		centered = true,
		cancel = true,
		labels = {
			confirm = "Purchase",
			cancel = "Cancel",
		},
	})
end)

lib.callback.register("ps-housing:cb:confirmRaid", function(street, id)
	return lib.alertDialog({
		header = "Raid",
		content = "Do you want to raid " .. street .. " " .. id .. "?",
		centered = true,
		cancel = true,
		labels = {
			confirm = "Raid",
			cancel = "Cancel",
		},
	})
end)

lib.callback.register("ps-housing:cb:ringDoorbell", function()
	return lib.alertDialog({
		header = "Ring Doorbell",
		content = "You dont have a key for this property, would you like to ring the doorbell?",
		centered = true,
		cancel = true,
		labels = {
			confirm = "Ring",
			cancel = "Cancel",
		},
	})
end)

lib.callback.register("ps-housing:cb:showcase", function()
	return lib.alertDialog({
		header = "Showcase Property",
		content = "Do you want to showcase this property?",
		centered = true,
		cancel = true,
		labels = {
			confirm = "Yes",
			cancel = "Cancel",
		},
	})
end)
