TDHousing = TDHousing or {}

local LegacyApartmentMigrationService = {}
local Repository = TDHousing.LegacyApartmentRepository

function LegacyApartmentMigrationService.MigrateStash(identifier, propertyId)
    if type(identifier) ~= "string" or identifier == "" then
        return nil, "INVALID_IDENTIFIER"
    end

    local normalizedPropertyId = tostring(propertyId or "")

    if normalizedPropertyId == "" then
        return nil, "INVALID_PROPERTY_ID"
    end

    local record, lookupError, lookupMessage = Repository.FindStash(identifier)

    if lookupError then
        return nil, lookupError, lookupMessage
    end

    if not record then
        return true, "NO_LEGACY_STASH"
    end

    if not TD.HasCapability("inventory", "importLegacyStash") then
        return nil, "LEGACY_STASH_IMPORT_UNSUPPORTED"
    end

    local items = {}

    if type(record.items) == "string" and record.items ~= "" then
        local decoded = json.decode(record.items)
        if type(decoded) == "table" then
            items = decoded
        end
    elseif type(record.items) == "table" then
        items = record.items
    end

    local stashId = ("property_%s"):format(normalizedPropertyId)
    local imported, importError, importMessage = TD.Inventory.ImportLegacyStash(stashId, items)

    if imported ~= true then
        return nil, importError or "LEGACY_STASH_IMPORT_FAILED", importMessage
    end

    local deleted, deleteError, deleteMessage = Repository.DeleteStash(record)

    if deleted ~= true then
        return nil, deleteError, deleteMessage
    end

    return true, "LEGACY_STASH_MIGRATED"
end

TDHousing.LegacyApartmentMigrationService = LegacyApartmentMigrationService
