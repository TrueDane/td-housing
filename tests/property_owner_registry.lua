TDHousing = {
	PropertyRepository = {},
	PropertyCapabilityService = {},
	PropertyMutationService = {},
	OwnershipService = {},
}

local querySeen
MySQL = {
	query = {
		await = function(sql)
			querySeen = sql

			return {
				{
					property_id = 17,
					owner_citizenid = "CID_OWNER",
					street = "Alta St",
					region = "Downtown",
					apartment = nil,
				},
			}
		end,
	},
}

local exported = {}
exports = function(name, handler)
	exported[name] = handler
end

Property = {
	Get = function()
		return nil
	end,
}

dofile("server/repositories/property_repository.lua")
dofile("server/modules/public_api.lua")

assert(type(exported.GetPropertyOwnerEntries) == "function", "owner export missing")
local entries = exported.GetPropertyOwnerEntries()

assert(#entries == 1, "owner registry export should return an owned property")
assert(entries[1].owner_citizenid == "CID_OWNER", "owner id missing")
assert(entries[1].property_id == 17, "property id missing")
assert(entries[1].has_access == nil, "access list must not be exported")
assert(entries[1].description == nil, "private description must not be exported")

assert(querySeen:find("FROM properties", 1, true), "wrong owner repository query")
assert(querySeen:find("owner_citizenid IS NOT NULL", 1, true), "unowned property filter missing")
assert(not querySeen:find("SELECT *", 1, true), "owner query must not select unrelated columns")

print("property_owner_registry: ok")
