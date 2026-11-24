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
                    property_id = 10,
                    street = 'Elgin Ave',
                    region = 'Downtown',
                    apartment = nil,
                    door_data = '{"x":12,"y":34,"z":56}',
                    zone_data = nil,
                    is_owned = 1,
                },
            }
        end,
    },
}

local recordedExports = {}
exports = function(name, handler)
    recordedExports[name] = handler
end

Property = {
    Get = function()
        return nil
    end,
}

dofile('server/repositories/property_repository.lua')
dofile('server/modules/public_api.lua')

assert(type(recordedExports.GetPropertyMapEntries) == 'function', 'map export is missing')

local entries = recordedExports.GetPropertyMapEntries()
assert(#entries == 1, 'the map export should return the repository result')
assert(entries[1].street == 'Elgin Ave', 'property address missing')
assert(entries[1].is_owned == 1, 'owner-present flag missing')
assert(entries[1].owner_citizenid == nil, 'owner identifier leaked in the map snapshot')
assert(entries[1].access_data == nil, 'access data leaked in the map snapshot')

assert(querySeen:find('FROM properties', 1, true), 'map query must use the housing repository')
assert(not querySeen:find('SELECT *', 1, true), 'map query must not read all housing columns')
assert(querySeen:find('AS is_owned', 1, true), 'map query must project ownership as a boolean')

print('property_map_registry: ok')
