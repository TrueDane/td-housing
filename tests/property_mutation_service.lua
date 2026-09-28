Config = {
	Shells = {
		mlo = {},
		shell_a = {},
	},
}

local property = {
	property_id = "42",
	propertyData = {
		shell = "shell_a",
		garage_data = {},
		extra_imgs = {},
	},
}

local writes = {}
local clientEvents = {}

TDHousing = {
	PropertyRepository = {},
}

Property = {
	Get = function(propertyId)
		if tostring(propertyId) == "42" then
			return property
		end

		return nil
	end,
}

function TDHousing.PropertyRepository.UpdateShell(propertyId, shell)
	writes.shell = {
		propertyId = propertyId,
		shell = shell,
	}
	return 1
end

function TDHousing.PropertyRepository.UpdateGarage(propertyId, garage)
	writes.garage = {
		propertyId = propertyId,
		garage = garage,
	}
	return 1
end

function TDHousing.PropertyRepository.UpdateImages(propertyId, images)
	writes.images = {
		propertyId = propertyId,
		images = images,
	}
	return 1
end

function TriggerClientEvent(eventName, target, ...)
	clientEvents[#clientEvents + 1] = {
		eventName = eventName,
		target = target,
		args = {
			...,
		},
	}
end

dofile("server/services/property_mutation_service.lua")

local Service = TDHousing.PropertyMutationService

local shellUpdated, shellError = Service.UpdateShell("42", "mlo")
assert(shellUpdated == true, "valid shell update should succeed")
assert(shellError == nil, "valid shell update should not return an error")
assert(property.propertyData.shell == "mlo", "in-memory shell should be updated")
assert(writes.shell.shell == "mlo", "shell should be persisted")

local invalidShell, invalidShellError = Service.UpdateShell("42", "missing_shell")
assert(invalidShell == false, "unknown shell should be rejected")
assert(invalidShellError == "INVALID_SHELL", "unknown shell should return a stable error")

local garageUpdated, garageError = Service.UpdateGarage("42", {
	x = 1.123456,
	y = 2.234567,
	z = 3.345678,
	h = 90.123456,
})
assert(garageUpdated == true, "valid garage update should succeed")
assert(garageError == nil, "valid garage update should not return an error")
assert(writes.garage.garage.length == 3.0, "garage should receive the default length")
assert(writes.garage.garage.width == 5.0, "garage should receive the default width")
assert(writes.garage.garage.x == 1.1235, "garage x should be normalized")

local invalidGarage, invalidGarageError = Service.UpdateGarage("42", {
	x = "invalid",
	y = 2,
	z = 3,
	h = 90,
})
assert(invalidGarage == false, "invalid garage should be rejected")
assert(invalidGarageError == "INVALID_GARAGE_DATA", "invalid garage should return a stable error")

local imagesUpdated, imagesError = Service.UpdateImages("42", {
	"https://example.invalid/one.jpg",
	"https://example.invalid/two.jpg",
})
assert(imagesUpdated == true, "valid images should be updated")
assert(imagesError == nil, "valid images should not return an error")
assert(property.propertyData.extra_imgs[1] == "https://example.invalid/one.jpg", "canonical image state should update")
assert(
	property.propertyData.imgs[2] == "https://example.invalid/two.jpg",
	"legacy image alias should stay synchronized"
)

local invalidImages, invalidImagesError = Service.UpdateImages("42", {
	"",
})
assert(invalidImages == false, "empty image URL should be rejected")
assert(invalidImagesError == "INVALID_IMAGE", "invalid image should return a stable error")

local missingProperty, missingPropertyError = Service.UpdateGarage("999", {})
assert(missingProperty == false, "missing property should be rejected")
assert(missingPropertyError == "PROPERTY_NOT_FOUND", "missing property should return a stable error")

assert(#clientEvents == 6, "three successful updates should publish legacy and TrueDane client events")

print("property mutation service tests passed")
