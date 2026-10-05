TDHousing = TDHousing or {}

local LegacyApartmentRepository = {}

local function tableExists(tableName)
    local result = MySQL.scalar.await(
        [[
            SELECT 1
            FROM information_schema.tables
            WHERE table_schema = DATABASE()
              AND table_name = ?
            LIMIT 1
        ]],
        { tableName }
    )

    return result ~= nil
end

function LegacyApartmentRepository.FindStash(identifier)
    if type(identifier) ~= "string" or identifier == "" then
        return nil, "INVALID_IDENTIFIER"
    end

    local success, result = pcall(function()
        if not tableExists("apartments") then
            return nil
        end

        if tableExists("inventories") then
            local rows = MySQL.query.await(
                [[
                    SELECT items, identifier AS stash_key
                    FROM inventories
                    WHERE identifier IN (
                        SELECT name FROM apartments WHERE citizenid = ?
                    )
                    LIMIT 1
                ]],
                { identifier }
            )

            if rows and rows[1] then
                rows[1].source_table = "inventories"
                return rows[1]
            end
        end

        if tableExists("stashitems") then
            local rows = MySQL.query.await(
                [[
                    SELECT items, stash AS stash_key
                    FROM stashitems
                    WHERE stash IN (
                        SELECT name FROM apartments WHERE citizenid = ?
                    )
                    LIMIT 1
                ]],
                { identifier }
            )

            if rows and rows[1] then
                rows[1].source_table = "stashitems"
                return rows[1]
            end
        end

        return nil
    end)

    if not success then
        return nil, "LEGACY_STASH_LOOKUP_FAILED", tostring(result)
    end

    return result
end

function LegacyApartmentRepository.DeleteStash(record)
    if type(record) ~= "table" or type(record.stash_key) ~= "string" then
        return nil, "INVALID_STASH_RECORD"
    end

    local query

    if record.source_table == "inventories" then
        query = "DELETE FROM inventories WHERE identifier = ?"
    elseif record.source_table == "stashitems" then
        query = "DELETE FROM stashitems WHERE stash = ?"
    else
        return nil, "UNSUPPORTED_STASH_TABLE"
    end

    local success, result = pcall(function()
        return MySQL.update.await(query, { record.stash_key })
    end)

    if not success then
        return nil, "LEGACY_STASH_DELETE_FAILED", tostring(result)
    end

    return true
end

TDHousing.LegacyApartmentRepository = LegacyApartmentRepository
