Property = {
	property_id = nil,
	propertyData = nil,
	playersInside = nil, -- src
	playersInGarden = nil, -- src
	playersDoorbell = nil, -- src

	raiding = false,
}
Property.__index = Property

function Property:new(propertyData)
	local self = setmetatable({}, Property)

	self.property_id = tostring(propertyData.property_id)
	self.propertyData = propertyData

	self.playersInside = {}
	self.playersInGarden = {}
	self.playersDoorbell = {}

	local stashName = ("property_%s"):format(propertyData.property_id)
	local stashConfig = Config.Shells[propertyData.shell].stash

	for k, v in ipairs(propertyData.furnitures) do
		if v.type == "storage" then
			Framework[Config.Inventory].RegisterInventory(
				k == 1 and stashName or stashName .. v.id,
				"Property: "
						.. (propertyData.street or propertyData.apartment or "Unknown")
						.. " #"
						.. propertyData.property_id
					or propertyData.apartment
					or stashName,
				stashConfig
			)
		end
	end

	return self
end

local function setWeatherSync(src, enabled)
	if not TD.HasCapability("weather", "setSync") then
		return
	end

	local success, weatherError, weatherMessage = TD.Weather.SetSync(src, enabled)

	if success ~= true then
		Debug(
			("Unable to set weather sync for player %s (%s): %s"):format(
				src,
				weatherError or "UNKNOWN_ERROR",
				weatherMessage or "Unknown provider error"
			)
		)
	end
end

function Property:PlayerEnter(src)
	local _src = tostring(src)
	local isMlo = self.propertyData.shell == "mlo"
	local isIpl = self.propertyData.apartment and Config.Apartments[self.propertyData.apartment].interior

	self.playersInside[_src] = true

	if not isMlo then
		setWeatherSync(src, false)
	end
	TriggerClientEvent("ps-housing:client:enterProperty", src, self.property_id, isMlo, self.propertyData)

	if next(self.playersDoorbell) then
		TriggerClientEvent("ps-housing:client:updateDoorbellPool", src, self.property_id, self.playersDoorbell)
		if self.playersDoorbell[_src] then
			self.playersDoorbell[_src] = nil
		end
	end

	local citizenid = GetCitizenid(src)

	if
		self:CheckForAccess(citizenid)
		and TD.HasCapability("framework", "getMetadata")
		and TD.HasCapability("framework", "setMetadata")
	then
		local insideMeta = TD.Player.GetMetadata(src, "inside")

		if type(insideMeta) ~= "table" then
			insideMeta = {}
		end

		insideMeta.property_id = self.property_id
		TD.Player.SetMetadata(src, "inside", insideMeta)
	end

	if not isMlo or isIpl then
		local bucket = tonumber(self.property_id) -- because the property_id is a string
		SetPlayerRoutingBucket(src, bucket)
	end
end

function Property:PlayerLeave(src)
	local _src = tostring(src)
	self.playersInside[_src] = nil

	setWeatherSync(src, true)

	local citizenid = GetCitizenid(src)

	if
		self:CheckForAccess(citizenid)
		and TD.HasCapability("framework", "getMetadata")
		and TD.HasCapability("framework", "setMetadata")
	then
		local insideMeta = TD.Player.GetMetadata(src, "inside")

		if type(insideMeta) ~= "table" then
			insideMeta = {}
		end

		insideMeta.property_id = nil
		TD.Player.SetMetadata(src, "inside", insideMeta)
	end

	SetPlayerRoutingBucket(src, 0)
end

function Property:CheckForAccess(citizenid)
	if self.propertyData.owner == citizenid then
		return true
	end
	return lib.table.contains(self.propertyData.has_access, citizenid)
end

function Property:AddToDoorbellPoolTemp(src)
	local _src = tostring(src)

	local name = GetCharName(src)

	self.playersDoorbell[_src] = {
		src = src,
		name = name,
	}

	for src, _ in pairs(self.playersInside) do
		local targetSrc = tonumber(src)

		Framework[Config.Notify].Notify(targetSrc, "Someone is at the door.", "info")
		TriggerClientEvent("ps-housing:client:updateDoorbellPool", targetSrc, self.property_id, self.playersDoorbell)
	end

	Framework[Config.Notify].Notify(src, "You rang the doorbell. Just wait...", "info")

	SetTimeout(10000, function()
		if self.playersDoorbell[_src] then
			self.playersDoorbell[_src] = nil
			Framework[Config.Notify].Notify(src, "No one answered the door.", "error")
		end

		for src, _ in pairs(self.playersInside) do
			local targetSrc = tonumber(src)

			TriggerClientEvent(
				"ps-housing:client:updateDoorbellPool",
				targetSrc,
				self.property_id,
				self.playersDoorbell
			)
		end
	end)
end

function Property:RemoveFromDoorbellPool(src)
	local _src = tostring(src)

	if self.playersDoorbell[_src] then
		self.playersDoorbell[_src] = nil
	end

	for src, _ in pairs(self.playersInside) do
		local targetSrc = tonumber(src)

		TriggerClientEvent("ps-housing:client:updateDoorbellPool", targetSrc, self.property_id, self.playersDoorbell)
	end
end

function Property:StartRaid()
	self.raiding = true

	for src, _ in pairs(self.playersInside) do
		local targetSrc = tonumber(src)
		Framework[Config.Notify].Notify(targetSrc, "This Property is being Raided.", "error")
	end

	SetTimeout(Config.RaidTimer * 60000, function()
		self.raiding = false
	end)
end

function Property:UpdateFurnitures(furnitures, isGarden)
	local newfurnitures = {}

	for i = 1, #furnitures do
		newfurnitures[i] = {
			id = furnitures[i].id,
			label = furnitures[i].label,
			object = furnitures[i].object,
			position = furnitures[i].position,
			rotation = furnitures[i].rotation,
			type = furnitures[i].type,
		}
	end

	self.propertyData.furnitures = newfurnitures

	MySQL.update("UPDATE properties SET furnitures = @furnitures WHERE property_id = @property_id", {
		["@furnitures"] = json.encode(newfurnitures),
		["@property_id"] = self.property_id,
	})

	if isGarden then
		for src, _ in pairs(self.playersInGarden) do
			TriggerClientEvent("ps-housing:client:updateFurniture", tonumber(src), self.property_id, furnitures, true)
		end
		return
	end

	for src, _ in pairs(self.playersInside) do
		TriggerClientEvent("ps-housing:client:updateFurniture", tonumber(src), self.property_id, furnitures)
	end
end

function Property:UpdateDescription(data)
	local description = data.description
	local realtorSrc = data.realtorSrc

	if self.propertyData.description == description then
		return
	end

	self.propertyData.description = description

	MySQL.update("UPDATE properties SET description = @description WHERE property_id = @property_id", {
		["@description"] = description,
		["@property_id"] = self.property_id,
	})

	TriggerClientEvent("ps-housing:client:updateProperty", -1, "UpdateDescription", self.property_id, description)

	Framework[Config.Logs].SendLog(
		"**Changed Description** of property with id: " .. self.property_id .. " by: " .. GetPlayerName(realtorSrc)
	)

	Debug("Changed Description of property with id: " .. self.property_id, "by: " .. GetPlayerName(realtorSrc))
end

function Property:UpdatePrice(data)
	local price = data.price
	local realtorSrc = data.realtorSrc

	if self.propertyData.price == price then
		return
	end

	self.propertyData.price = price

	MySQL.update("UPDATE properties SET price = @price WHERE property_id = @property_id", {
		["@price"] = price,
		["@property_id"] = self.property_id,
	})

	TriggerClientEvent("ps-housing:client:updateProperty", -1, "UpdatePrice", self.property_id, price)

	Framework[Config.Logs].SendLog(
		"**Changed Price** of property with id: " .. self.property_id .. " by: " .. GetPlayerName(realtorSrc)
	)

	Debug("Changed Price of property with id: " .. self.property_id, "by: " .. GetPlayerName(realtorSrc))
end

function Property:UpdateForSale(data)
	local forsale = data.forsale
	local realtorSrc = data.realtorSrc

	self.propertyData.for_sale = forsale

	MySQL.update("UPDATE properties SET for_sale = @for_sale WHERE property_id = @property_id", {
		["@for_sale"] = forsale and 1 or 0,
		["@property_id"] = self.property_id,
	})

	TriggerClientEvent("ps-housing:client:updateProperty", -1, "UpdateForSale", self.property_id, forsale)

	Framework[Config.Logs].SendLog(
		"**Changed For Sale** of property with id: " .. self.property_id .. " by: " .. GetPlayerName(realtorSrc)
	)

	Debug("Changed For Sale of property with id: " .. self.property_id, "by: " .. GetPlayerName(realtorSrc))
end

function Property:UpdateShell(data)
	local shell = data.shell
	local realtorSrc = data.realtorSrc

	if self.propertyData.shell == shell then
		return
	end

	self.propertyData.shell = shell

	MySQL.update("UPDATE properties SET shell = @shell WHERE property_id = @property_id", {
		["@shell"] = shell,
		["@property_id"] = self.property_id,
	})

	TriggerClientEvent("ps-housing:client:updateProperty", -1, "UpdateShell", self.property_id, shell)

	Framework[Config.Logs].SendLog(
		"**Changed Shell** of property with id: " .. self.property_id .. " by: " .. GetPlayerName(realtorSrc)
	)

	Debug("Changed Shell of property with id: " .. self.property_id, "by: " .. GetPlayerName(realtorSrc))
end

local function doorName(propertyId, doorIndex)
	return ("ps_mloproperty%s_%s"):format(propertyId, doorIndex)
end

local function containsIdentifier(identifiers, expected)
	for index = 1, #identifiers do
		if identifiers[index] == expected then
			return true
		end
	end

	return false
end

function Property:addMloDoorsAccess(citizenid)
	if self.propertyData.shell ~= "mlo" then
		return true
	end

	for index = 1, self.propertyData.door_data.count do
		local name = doorName(self.property_id, index)
		local door, errorCode, errorMessage = TD.Door.Get(name)

		if not door then
			Debug(
				("Unable to read door %s (%s): %s"):format(
					name,
					errorCode or "UNKNOWN_ERROR",
					errorMessage or "Unknown provider error"
				)
			)
			return false
		end

		local characters = door.characters or {}

		if not containsIdentifier(characters, citizenid) then
			characters[#characters + 1] = citizenid

			local success, updateError, updateMessage = TD.Door.SetCharacters(name, characters)

			if success ~= true then
				Debug(
					("Unable to update door access %s (%s): %s"):format(
						name,
						updateError or "UNKNOWN_ERROR",
						updateMessage or "Unknown provider error"
					)
				)
				return false
			end
		end
	end

	return true
end

function Property:removeMloDoorsAccess(citizenid)
	if self.propertyData.shell ~= "mlo" then
		return true
	end

	for index = 1, self.propertyData.door_data.count do
		local name = doorName(self.property_id, index)
		local door, errorCode, errorMessage = TD.Door.Get(name)

		if not door then
			Debug(
				("Unable to read door %s (%s): %s"):format(
					name,
					errorCode or "UNKNOWN_ERROR",
					errorMessage or "Unknown provider error"
				)
			)
			return false
		end

		local characters = {}
		local changed = false

		for characterIndex = 1, #(door.characters or {}) do
			local identifier = door.characters[characterIndex]

			if identifier == citizenid then
				changed = true
			else
				characters[#characters + 1] = identifier
			end
		end

		if changed then
			local success, updateError, updateMessage = TD.Door.SetCharacters(name, characters)

			if success ~= true then
				Debug(
					("Unable to update door access %s (%s): %s"):format(
						name,
						updateError or "UNKNOWN_ERROR",
						updateMessage or "Unknown provider error"
					)
				)
				return false
			end
		end
	end

	return true
end
function Property:UpdateOwner()
	Debug("Legacy Housing-owned sale flow is disabled. Ownership changes must use the TD-Housing SetOwner public API.")

	return false, "LEGACY_OWNER_FLOW_DISABLED"
end

function Property:UpdateImgs(data)
	local imgs = data.imgs
	local realtorSrc = data.realtorSrc

	self.propertyData.imgs = imgs

	MySQL.update("UPDATE properties SET extra_imgs = @extra_imgs WHERE property_id = @property_id", {
		["@extra_imgs"] = json.encode(imgs),
		["@property_id"] = self.property_id,
	})

	TriggerClientEvent("ps-housing:client:updateProperty", -1, "UpdateImgs", self.property_id, imgs)

	Framework[Config.Logs].SendLog(
		"**Changed Images** of property with id: " .. self.property_id .. " by: " .. GetPlayerName(realtorSrc)
	)

	Debug("Changed Imgs of property with id: " .. self.property_id, "by: " .. GetPlayerName(realtorSrc))
end

function Property:UpdateDoor(data)
	local door = data.door

	if not door then
		return
	end
	local realtorSrc = data.realtorSrc

	local newDoor = {
		x = math.floor(door.x * 10000) / 10000,
		y = math.floor(door.y * 10000) / 10000,
		z = math.floor(door.z * 10000) / 10000,
		h = math.floor(door.h * 10000) / 10000,
		length = door.length or 1.5,
		width = door.width or 2.2,
		locked = door.locked or false,
	}

	self.propertyData.door_data = newDoor

	self.propertyData.street = data.street
	self.propertyData.region = data.region

	MySQL.update(
		"UPDATE properties SET door_data = @door, street = @street, region = @region WHERE property_id = @property_id",
		{
			["@door"] = json.encode(newDoor),
			["@property_id"] = self.property_id,
			["@street"] = data.street,
			["@region"] = data.region,
		}
	)

	TriggerClientEvent(
		"ps-housing:client:updateProperty",
		-1,
		"UpdateDoor",
		self.property_id,
		newDoor,
		data.street,
		data.region
	)

	Framework[Config.Logs].SendLog(
		"**Changed Door** of property with id: " .. self.property_id .. " by: " .. GetPlayerName(realtorSrc)
	)

	Debug("Changed Door of property with id: " .. self.property_id, "by: " .. GetPlayerName(realtorSrc))
end

function Property:UpdateHas_access(data)
	local has_access = data or {}

	self.propertyData.has_access = has_access

	MySQL.update("UPDATE properties SET has_access = @has_access WHERE property_id = @property_id", {
		["@has_access"] = json.encode(has_access), --Array of cids
		["@property_id"] = self.property_id,
	})

	TriggerClientEvent("ps-housing:client:updateProperty", -1, "UpdateHas_access", self.property_id, has_access)

	Debug("Changed Has Access of property with id: " .. self.property_id)
end

function Property:UpdateGarage(data)
	local garage = data.garage
	local realtorSrc = data.realtorSrc

	local newData = {}

	if data ~= nil then
		newData = {
			x = math.floor(garage.x * 10000) / 10000,
			y = math.floor(garage.y * 10000) / 10000,
			z = math.floor(garage.z * 10000) / 10000,
			h = math.floor(garage.h * 10000) / 10000,
			length = garage.length or 3.0,
			width = garage.width or 5.0,
		}
	end

	self.propertyData.garage_data = newData

	MySQL.update("UPDATE properties SET garage_data = @garageCoords WHERE property_id = @property_id", {
		["@garageCoords"] = json.encode(newData),
		["@property_id"] = self.property_id,
	})

	TriggerClientEvent("ps-housing:client:updateProperty", -1, "UpdateGarage", self.property_id, newData)

	Framework[Config.Logs].SendLog(
		"**Changed Garage** of property with id: " .. self.property_id .. " by: " .. GetPlayerName(realtorSrc)
	)

	Debug("Changed Garage of property with id: " .. self.property_id, "by: " .. GetPlayerName(realtorSrc))
end

function Property:UpdateApartment(data)
	local apartment = data.apartment
	local realtorSrc = data.realtorSrc
	local targetSrc = data.targetSrc

	self.propertyData.apartment = apartment

	MySQL.update("UPDATE properties SET apartment = @apartment WHERE property_id = @property_id", {
		["@apartment"] = apartment,
		["@property_id"] = self.property_id,
	})

	Framework[Config.Notify].Notify(
		realtorSrc,
		"Changed Apartment of property with id: " .. self.property_id .. " to " .. apartment,
		"success"
	)

	Framework[Config.Notify].Notify(targetSrc, "Changed Apartment to " .. apartment, "success")

	Framework[Config.Logs].SendLog(
		"**Changed Apartment** with id: "
			.. self.property_id
			.. " by: **"
			.. GetPlayerName(realtorSrc)
			.. "** for **"
			.. GetPlayerName(targetSrc)
			.. "**"
	)

	TriggerClientEvent("ps-housing:client:updateProperty", -1, "UpdateApartment", self.property_id, apartment)

	Debug("Changed Apartment of property with id: " .. self.property_id, "by: " .. GetPlayerName(realtorSrc))
end

function Property:DeleteProperty(data)
	local realtorSrc = data.realtorSrc
	local propertyid = self.property_id
	local realtorName = GetPlayerName(realtorSrc)

	MySQL.Async.execute("DELETE FROM properties WHERE property_id = @property_id", {
		["@property_id"] = propertyid,
	}, function(rowsChanged)
		if rowsChanged > 0 then
			Debug("Deleted property with id: " .. propertyid, "by: " .. realtorName)
		end
	end)

	if self.propertyData.shell == "mlo" and TD.HasCapability("doorlock", "remove") then
		for index = 1, self.propertyData.door_data.count do
			local name = doorName(propertyid, index)
			local removed, doorError, doorMessage = TD.Door.Remove(name)

			if removed ~= true and doorError ~= "DOOR_NOT_FOUND" then
				Debug(
					("Unable to remove door %s (%s): %s"):format(
						name,
						doorError or "UNKNOWN_ERROR",
						doorMessage or "Unknown provider error"
					)
				)
			end
		end
	end

	TriggerClientEvent("ps-housing:client:removeProperty", -1, propertyid)

	Framework[Config.Notify].Notify(realtorSrc, "Property with id: " .. propertyid .. " has been removed.", "info")

	Framework[Config.Logs].SendLog("**Property Deleted** with id: " .. propertyid .. " by: " .. realtorName)

	PropertiesTable[propertyid] = nil
	self = nil

	Debug("Deleted property with id: " .. propertyid, "by: " .. realtorName)
end

function Property.Get(property_id)
	return PropertiesTable[tostring(property_id)]
end

RegisterNetEvent("ps-housing:server:enterGarden", function(property_id)
	local src = source
	local property = Property.Get(property_id)

	if not property then
		Debug("Properties returned", json.encode(PropertiesTable, { indent = true }))
		return
	end

	property.playersInGarden[tostring(src)] = true
end)

RegisterNetEvent("ps-housing:server:enterProperty", function(property_id, spawn, isanmlo)
	local src = source
	Debug("Player is trying to enter property", property_id)

	local property = Property.Get(property_id)
	if not property then
		Debug("Properties returned", json.encode(PropertiesTable, { indent = true }))
		return
	end

	local citizenid = GetCitizenid(src)

	if property:CheckForAccess(citizenid) and not isanmlo then
		Debug("Player has access to property")
		if spawn == "spawn" then
			TriggerClientEvent("ps-housing:client:enterProperty", src, property_id, spawn)
		else
			property:PlayerEnter(src)
		end
		Debug("Player entered property")
		return
	else
		property:PlayerEnter(src)
	end

	if not isanmlo then
		local ringDoorbellConfirmation = lib.callback.await("ps-housing:cb:ringDoorbell", src)
		if ringDoorbellConfirmation == "confirm" then
			property:AddToDoorbellPoolTemp(src)
			Debug("Ringing doorbell")
			return
		end
	end
end)

RegisterNetEvent("ps-housing:server:showcaseProperty", function(property_id)
	local src = source

	local property = Property.Get(property_id)

	if not property then
		Debug("Properties returned", json.encode(PropertiesTable, { indent = true }))
		return
	end

	local job = TD.Player.GetJob(src)
	local jobName = job and job.name
	local onDuty = job and job.is_on_duty == true

	if jobName and RealtorJobs[jobName] and onDuty then
		local showcase = lib.callback.await("ps-housing:cb:showcase", src)
		if showcase == "confirm" then
			property:PlayerEnter(src)
			return
		end
	end
end)

RegisterNetEvent("ps-housing:server:raidProperty", function(property_id)
	local src = source
	Debug("Player is trying to raid property", property_id)

	local property = Property.Get(property_id)

	if not property then
		Debug("Properties returned", json.encode(PropertiesTable, { indent = true }))
		return
	end

	local job = TD.Player.GetJob(src)

	if type(job) ~= "table" then
		return
	end

	local jobName = job.name
	local gradeAllowed = (tonumber(job.grade) or 0) >= Config.MinGradeToRaid
	local onDuty = job.is_on_duty == true
	local raidItem = Config.RaidItem
	local hasStormRam = (tonumber(TD.Inventory.Count(src, raidItem)) or 0) > 0
	local isAllowedToRaid = PoliceJobs[jobName] and onDuty and gradeAllowed
	if isAllowedToRaid then
		if hasStormRam then
			if not property.raiding then
				local confirmRaid = lib.callback.await(
					"ps-housing:cb:confirmRaid",
					src,
					(property.propertyData.street or property.propertyData.apartment) .. " " .. property.property_id,
					property_id
				)
				if confirmRaid == "confirm" then
					property:StartRaid(src)
					property:PlayerEnter(src)
					Framework[Config.Notify].Notify(src, "Raid started", "success")

					if Config.ConsumeRaidItem then
						local removed = TD.Inventory.Remove(src, raidItem, 1, nil, "TD-Housing property raid")

						if removed ~= true then
							Framework[Config.Notify].Notify(src, "Stormram could not be consumed.", "error")
							return
						end
					end

					if property.propertyData.shell == "mlo" then
						for index = 1, property.propertyData.door_data.count do
							local name = doorName(property.property_id, index)
							local unlocked, doorError, doorMessage = TD.Door.SetLocked(name, false, src)

							if unlocked ~= true then
								Debug(
									("Unable to unlock raid door %s (%s): %s"):format(
										name,
										doorError or "UNKNOWN_ERROR",
										doorMessage or "Unknown provider error"
									)
								)
							end
						end
					end
				end
			else
				Framework[Config.Notify].Notify(src, "Raid in progress", "success")
				property:PlayerEnter(src)
			end
		else
			Framework[Config.Notify].Notify(src, "You need a stormram to perform a raid", "error")
		end
	else
		if not PoliceJobs[jobName] then
			Framework[Config.Notify].Notify(src, "Only police officers are permitted to perform raids", "error")
		elseif not onDuty then
			Framework[Config.Notify].Notify(src, "You must be onduty before performing a raid", "error")
		elseif not gradeAllowed then
			Framework[Config.Notify].Notify(src, "You must be a higher rank before performing a raid", "error")
		end
	end
end)

lib.callback.register("ps-housing:cb:getFurnitures", function(_, property_id)
	local property = Property.Get(property_id)
	if not property then
		return
	end
	return property.propertyData.furnitures or {}
end)

lib.callback.register("ps-housing:cb:getPlayersInProperty", function(source, property_id)
	local property = Property.Get(property_id)
	if not property then
		return
	end

	local players = {}

	for src, _ in pairs(property.playersInside) do
		local targetSrc = tonumber(src)
		if targetSrc ~= source then
			local name = GetCharName(targetSrc)

			players[#players + 1] = {
				src = targetSrc,
				name = name,
			}
		end
	end

	return players or {}
end)

RegisterNetEvent("ps-housing:server:leaveProperty", function(property_id)
	local src = source
	local property = Property.Get(property_id)

	if not property then
		return
	end

	property:PlayerLeave(src)
end)

-- When player presses doorbell, owner can let them in and this is what is triggered
RegisterNetEvent("ps-housing:server:doorbellAnswer", function(data)
	local src = source
	local targetSrc = data.targetSrc

	local property = Property.Get(data.property_id)
	if not property then
		return
	end

	if not property.playersInside[tostring(src)] then
		return
	end
	property:RemoveFromDoorbellPool(targetSrc)

	property:PlayerEnter(targetSrc)
end)

RegisterNetEvent("ps-housing:server:registerGarage", function(property_id)
	local src = source
	local property = Property.Get(property_id)

	if not property or not TD.HasCapability("garage", "registerHouse") then
		return
	end

	local citizenid = GetCitizenid(src)
	local propertyData = property.propertyData

	if not citizenid or propertyData.owner ~= citizenid then
		return
	end

	local garageData = propertyData.garage_data

	if
		type(garageData) ~= "table"
		or type(garageData.x) ~= "number"
		or type(garageData.y) ~= "number"
		or type(garageData.z) ~= "number"
		or type(garageData.h) ~= "number"
	then
		return
	end

	local label = tostring(propertyData.street or propertyData.apartment or "Property")
		.. property.property_id
		.. " Garage"
	local registered, garageError, garageMessage =
		TD.Garage.RegisterHouse(src, "housegarage-" .. property.property_id, {
			property_id = property.property_id,
			label = label,
			x = garageData.x,
			y = garageData.y,
			z = garageData.z,
			h = garageData.h,
			allowed_identifiers = {
				propertyData.owner,
			},
		})

	if registered ~= true then
		Debug(
			("Unable to register garage for property %s (%s): %s"):format(
				property.property_id,
				garageError or "UNKNOWN_ERROR",
				garageMessage or "Unknown provider error"
			)
		)
	end
end)

lib.callback.register("ps-housing:cb:getPlayersWithAccess", function(source, property_id)
	local src = source
	local citizenidSrc = GetCitizenid(src)
	local property = Property.Get(property_id)

	if not property then
		return
	end
	if property.propertyData.owner ~= citizenidSrc then
		return
	end

	local withAccess = {}
	local has_access = property.propertyData.has_access

	for i = 1, #has_access do
		local citizenid = has_access[i]
		local player = TD.Player.GetByIdentifier(citizenid)

		withAccess[#withAccess + 1] = {
			citizenid = citizenid,
			name = player and player.name or citizenid,
		}
	end

	return withAccess
end)

RegisterNetEvent("ps-housing:server:resetMetaData", function()
	local src = source

	if not TD.HasCapability("framework", "setMetadata") then
		return
	end

	local insideMeta = TD.HasCapability("framework", "getMetadata") and TD.Player.GetMetadata(src, "inside") or {}

	if type(insideMeta) ~= "table" then
		insideMeta = {}
	end

	insideMeta.property_id = nil
	TD.Player.SetMetadata(src, "inside", insideMeta)
end)
