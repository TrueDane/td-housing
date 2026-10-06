if GetResourceState("qbx_properties") ~= "started" then
	return
end

local apartments = {}

for apartmentId, apartment in pairs(Config.Apartments) do
	apartments[#apartments + 1] = {
		label = apartment.label,
		description = "Luxury Apartments!",
		enter = vec3(apartment.door.x, apartment.door.y, apartment.door.z),
		id = apartmentId,
	}
end

TriggerEvent("ps-housing:setApartments", apartments)
