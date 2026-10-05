TDHousing = TDHousing or {}
TDHousing.PropertyRepository = TDHousing.PropertyRepository or {}

local PropertyRepository = TDHousing.PropertyRepository

local function encode(value)
	return json.encode(value or {})
end

function PropertyRepository.WhenReady(callback)
	return MySQL.ready(callback)
end

function PropertyRepository.GetAll()
	return MySQL.query.await("SELECT * FROM properties") or {}
end

function PropertyRepository.Create(data)
	return MySQL.insert.await(
		[[
        INSERT INTO properties (
            owner_citizenid,
            street,
            region,
            description,
            has_access,
            extra_imgs,
            furnitures,
            for_sale,
            price,
            shell,
            apartment,
            door_data,
            garage_data,
            zone_data
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]],
		{
			data.owner,
			data.street,
			data.region,
			data.description,
			encode(data.has_access),
			encode(data.extra_imgs),
			encode(data.furnitures),
			data.for_sale ~= nil and data.for_sale or 1,
			data.price or 0,
			data.shell or "",
			data.apartment,
			encode(data.door_data),
			encode(data.garage_data),
			encode(data.zone_data),
		}
	)
end

function PropertyRepository.GetOwnedApartment(identifier)
	return MySQL.single.await(
		[[
        SELECT *
        FROM properties
        WHERE owner_citizenid = ?
          AND apartment IS NOT NULL
          AND apartment <> ''
        LIMIT 1
    ]],
		{
			identifier,
		}
	)
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

function PropertyRepository.GetOwnedByIdentifier(identifier)
	return MySQL.query.await(
		[[
        SELECT property_id, owner_citizenid, street, region, description, apartment
        FROM properties
        WHERE owner_citizenid = ?
        ORDER BY COALESCE(street, apartment, CAST(property_id AS CHAR)) ASC
    ]],
		{
			identifier,
		}
	) or {}
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

function PropertyRepository.UpdateLegacyAccess(propertyId, legacyAccess)
	return MySQL.update.await(
		[[
        UPDATE properties
        SET has_access = ?,
            updated_at = CURRENT_TIMESTAMP
        WHERE property_id = ?
    ]],
		{
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

function PropertyRepository.UpdateOwner(propertyId, identifier)
	return MySQL.update.await(
		[[
        UPDATE properties
        SET owner_citizenid = ?,
            updated_at = CURRENT_TIMESTAMP
        WHERE property_id = ?
    ]],
		{
			identifier,
			propertyId,
		}
	)
end

function PropertyRepository.UpdateDescription(propertyId, description)
	return MySQL.update.await(
		[[
        UPDATE properties
        SET description = ?,
            updated_at = CURRENT_TIMESTAMP
        WHERE property_id = ?
    ]],
		{
			description,
			propertyId,
		}
	)
end

function PropertyRepository.UpdatePrice(propertyId, price)
	return MySQL.update.await(
		[[
        UPDATE properties
        SET price = ?,
            updated_at = CURRENT_TIMESTAMP
        WHERE property_id = ?
    ]],
		{
			price,
			propertyId,
		}
	)
end

function PropertyRepository.UpdateForSale(propertyId, forSale)
	return MySQL.update.await(
		[[
        UPDATE properties
        SET for_sale = ?,
            updated_at = CURRENT_TIMESTAMP
        WHERE property_id = ?
    ]],
		{
			forSale and 1 or 0,
			propertyId,
		}
	)
end

function PropertyRepository.UpdateShell(propertyId, shell)
	return MySQL.update.await(
		[[
        UPDATE properties
        SET shell = ?,
            updated_at = CURRENT_TIMESTAMP
        WHERE property_id = ?
    ]],
		{
			shell,
			propertyId,
		}
	)
end

function PropertyRepository.UpdateGarage(propertyId, garage)
	return MySQL.update.await(
		[[
        UPDATE properties
        SET garage_data = ?,
            updated_at = CURRENT_TIMESTAMP
        WHERE property_id = ?
    ]],
		{
			encode(garage),
			propertyId,
		}
	)
end

function PropertyRepository.UpdateImages(propertyId, images)
	return MySQL.update.await(
		[[
        UPDATE properties
        SET extra_imgs = ?,
            updated_at = CURRENT_TIMESTAMP
        WHERE property_id = ?
    ]],
		{
			encode(images),
			propertyId,
		}
	)
end

function PropertyRepository.UpdateDoor(propertyId, door, street, region)
	return MySQL.update.await(
		[[
        UPDATE properties
        SET door_data = ?,
            street = ?,
            region = ?,
            updated_at = CURRENT_TIMESTAMP
        WHERE property_id = ?
    ]],
		{
			encode(door),
			street,
			region,
			propertyId,
		}
	)
end

function PropertyRepository.UpdateApartment(propertyId, apartment)
	return MySQL.update.await(
		[[
        UPDATE properties
        SET apartment = ?,
            updated_at = CURRENT_TIMESTAMP
        WHERE property_id = ?
    ]],
		{
			apartment,
			propertyId,
		}
	)
end

function PropertyRepository.Delete(propertyId)
	return MySQL.update.await("DELETE FROM properties WHERE property_id = ?", {
		propertyId,
	})
end
