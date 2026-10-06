Framework = {}

PoliceJobs = {}
RealtorJobs = {}

for index = 1, #Config.PoliceJobNames do
	PoliceJobs[Config.PoliceJobNames[index]] = true
end

for index = 1, #Config.RealtorJobNames do
	RealtorJobs[Config.RealtorJobNames[index]] = true
end

local function notificationType(notificationType)
	if notificationType == "primary" then
		return "inform"
	end

	return notificationType
end

if IsDuplicityVersion() then
	local serverAdapter = {}

	function serverAdapter.Notify(playerSource, message, messageType)
		return TD.Notify(playerSource, {
			title = "TD-Housing",
			description = message,
			type = notificationType(messageType) or "inform",
		})
	end

	function serverAdapter.RegisterInventory(stashId, label, stashConfig)
		stashConfig = stashConfig or {}

		return TD.Inventory.RegisterStash(stashId, {
			label = label,
			slots = stashConfig.slots,
			max_weight = stashConfig.maxWeight or stashConfig.maxweight,
		})
	end

	function serverAdapter.SendLog(message)
		if Config.EnableLogs then
			print(("[TD-Housing] %s"):format(message))
		end
	end

	Framework.td = serverAdapter
	Framework.qb = serverAdapter
	Framework.ox = serverAdapter

	return
end

local entityTargetNames = {}

local function currentJob()
	return TD.Player.GetJob()
end

local function isAllowedJob(jobNames, minimumGrade, requireDuty)
	local job = currentJob()

	if type(job) ~= "table" or not jobNames[job.name] then
		return false
	end

	if requireDuty and job.is_on_duty ~= true then
		return false
	end

	if minimumGrade and (tonumber(job.grade) or 0) < minimumGrade then
		return false
	end

	return true
end

local function propertyHasAccess(propertyId)
	local property = Property.Get(propertyId)

	return property ~= nil and (property.has_access == true or property.owner == true)
end

local function apartmentHasOwnedUnit(apartment)
	local apartmentData = ApartmentsTable[apartment]

	if not apartmentData or type(apartmentData.apartments) ~= "table" then
		return false
	end

	for propertyId in pairs(apartmentData.apartments) do
		local property = PropertiesTable[propertyId]

		if property and property.owner then
			return true
		end
	end

	return false
end

local clientAdapter = {}

function clientAdapter.Notify(message, messageType)
	return TD.Notify({
		title = "TD-Housing",
		description = message,
		type = notificationType(messageType) or "inform",
	})
end

function clientAdapter.AddEntrance(coords, size, heading, propertyId, enter, raid, showcase, showData, targetName)
	local propertyIdString = tostring(propertyId)

	return TD.Target.AddBoxZone({
		name = targetName,
		coords = vector3(coords.x, coords.y, coords.z),
		size = vector3(size.x, size.y, size.z),
		rotation = heading,
		debug = Config.DebugMode,
		options = {
			{
				name = ("td_housing_enter_%s"):format(propertyIdString),
				label = "Enter Property",
				icon = "fas fa-door-open",
				on_select = enter,
				can_interact = function()
					return propertyHasAccess(propertyIdString)
				end,
			},
			{
				name = ("td_housing_showcase_%s"):format(propertyIdString),
				label = "Showcase Property",
				icon = "fas fa-eye",
				on_select = showcase,
				can_interact = function()
					return isAllowedJob(RealtorJobs, nil, true)
				end,
			},
			{
				name = ("td_housing_info_%s"):format(propertyIdString),
				label = "Property Info",
				icon = "fas fa-circle-info",
				on_select = showData,
				can_interact = function()
					return isAllowedJob(RealtorJobs, nil, true)
				end,
			},
			{
				name = ("td_housing_doorbell_%s"):format(propertyIdString),
				label = "Ring Doorbell",
				icon = "fas fa-bell",
				on_select = enter,
				can_interact = function()
					return not propertyHasAccess(propertyIdString)
				end,
			},
			{
				name = ("td_housing_raid_%s"):format(propertyIdString),
				label = "Raid Property",
				icon = "fas fa-building-shield",
				on_select = raid,
				can_interact = function()
					return isAllowedJob(PoliceJobs, Config.MinGradeToRaid, true)
				end,
			},
		},
	})
end

function clientAdapter.AddApartmentEntrance(coords, size, heading, apartment, enter, seeAll, seeAllToRaid, targetName)
	return TD.Target.AddBoxZone({
		name = targetName,
		coords = vector3(coords.x, coords.y, coords.z),
		size = vector3(size.x, size.y, size.z),
		rotation = heading,
		debug = Config.DebugMode,
		options = {
			{
				name = ("td_housing_apartment_enter_%s"):format(apartment),
				label = "Enter Apartment",
				icon = "fas fa-door-open",
				on_select = enter,
				can_interact = function()
					return apartmentHasOwnedUnit(apartment)
				end,
			},
			{
				name = ("td_housing_apartment_list_%s"):format(apartment),
				label = "See all apartments",
				icon = "fas fa-circle-info",
				on_select = seeAll,
			},
			{
				name = ("td_housing_apartment_raid_%s"):format(apartment),
				label = "Raid Apartment",
				icon = "fas fa-building-shield",
				on_select = seeAllToRaid,
				can_interact = function()
					return isAllowedJob(PoliceJobs, Config.MinGradeToRaid, true)
				end,
			},
		},
	})
end

function clientAdapter.AddDoorZoneInside(coords, size, heading, leave, checkDoor)
	return TD.Target.AddBoxZone({
		coords = vector3(coords.x, coords.y, coords.z),
		size = vector3(size.x, size.y, size.z),
		rotation = heading,
		debug = Config.DebugMode,
		options = {
			{
				name = "td_housing_leave_property",
				label = "Leave Property",
				icon = "fas fa-right-from-bracket",
				on_select = leave,
			},
			{
				name = "td_housing_check_door",
				label = "Check Door",
				icon = "fas fa-bell",
				on_select = checkDoor,
			},
		},
	})
end

function clientAdapter.AddDoorZoneInsideTempShell(coords, size, heading, leave)
	return TD.Target.AddBoxZone({
		coords = vector3(coords.x, coords.y, coords.z),
		size = vector3(size.x, size.y, size.z),
		rotation = heading,
		debug = Config.DebugMode,
		options = {
			{
				name = "td_housing_leave_temp_property",
				label = "Leave",
				icon = "fas fa-right-from-bracket",
				on_select = leave,
			},
		},
	})
end

function clientAdapter.RemoveTargetZone(targetId)
	if targetId == nil then
		return true
	end

	return TD.Target.RemoveZone(targetId)
end

function clientAdapter.AddRadialOption(id, label, icon, action, eventName, args)
	return TD.Radial.Add({
		id = id,
		label = label,
		icon = icon,
		action = action,
		event = action and nil or eventName,
		args = args,
		should_close = true,
	})
end

function clientAdapter.RemoveRadialOption(id)
	return TD.Radial.Remove(id)
end

function clientAdapter.AddTargetEntity(entity, label, icon, action)
	local name = ("td_housing_entity_%s_%s"):format(tostring(entity), tostring(label):gsub("%s+", "_"))
	local key = tostring(entity)

	entityTargetNames[key] = entityTargetNames[key] or {}
	entityTargetNames[key][#entityTargetNames[key] + 1] = name

	return TD.Target.AddLocalEntity(entity, {
		{
			name = name,
			label = label,
			icon = icon,
			on_select = action,
		},
	}, 2.0)
end

function clientAdapter.RemoveTargetEntity(entity)
	local key = tostring(entity)
	local names = entityTargetNames[key]

	entityTargetNames[key] = nil

	return TD.Target.RemoveLocalEntity(entity, names)
end

function clientAdapter.inventoryHasItems()
	return false
end

function clientAdapter.OpenInventory(stashId, stashConfig)
	return TD.Inventory.Open("stash", stashId, {
		id = stashId,
		label = stashConfig and stashConfig.label,
		slots = stashConfig and stashConfig.slots,
		max_weight = stashConfig and (stashConfig.maxWeight or stashConfig.maxweight),
	})
end

Framework.td = clientAdapter
Framework.qb = clientAdapter
Framework.ox = clientAdapter
