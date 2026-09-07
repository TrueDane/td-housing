TDHousing = TDHousing or {}
TDHousing.PropertyRepository = TDHousing.PropertyRepository or {}

local PropertyRepository = TDHousing.PropertyRepository

local function encode(value)
	return json.encode(value or {})
end

function PropertyRepository.GetCapabilities(propertyId)
	return MySQL.single.await(
		[[
        SELECT property_id, owner_citizenid, has_access, access_data,
            furniture_mode, storage_data, wardrobe_data
        FROM properties
        WHERE property_id = ?
    ]],
		{
			propertyId,
		}
	)
end

function PropertyRepository.UpdateCapabilities(propertyId, data)
	return MySQL.update.await(
		[[
        UPDATE properties
        SET access_data = ?,
            has_access = ?,
            furniture_mode = ?,
            storage_data = ?,
            wardrobe_data = ?,
            updated_at = CURRENT_TIMESTAMP
        WHERE property_id = ?
    ]],
		{
			encode(data.accessData),
			encode(data.legacyAccess),
			data.furnitureMode,
			encode(data.storage),
			encode(data.wardrobe),
			propertyId,
		}
	)
end

function PropertyRepository.UpdateAccess(propertyId, accessData, legacyAccess)
	return MySQL.update.await(
		[[
        UPDATE properties
        SET access_data = ?,
            has_access = ?,
            updated_at = CURRENT_TIMESTAMP
        WHERE property_id = ?
    ]],
		{
			encode(accessData),
			encode(legacyAccess),
			propertyId,
		}
	)
end

function PropertyRepository.UpdateFurniture(propertyId, furnitures)
	return MySQL.update.await(
		[[
        UPDATE properties
        SET furnitures = ?,
            updated_at = CURRENT_TIMESTAMP
        WHERE property_id = ?
    ]],
		{
			encode(furnitures),
			propertyId,
		}
	)
end
