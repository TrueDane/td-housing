TDHousing = TDHousing or {}
TDHousing.Wardrobe = TDHousing.Wardrobe or {}

local Wardrobe = TDHousing.Wardrobe

function Wardrobe.Open()
    local provider = Config.Wardrobe and Config.Wardrobe.provider or 'qb-clothing'

    if provider == 'qb-clothing' then
        if GetResourceState('qb-clothing') ~= 'started' then
            return nil, 'WARDROBE_PROVIDER_NOT_STARTED'
        end

        TriggerEvent('qb-clothing:client:openOutfitMenu')
        return true
    end

    return nil, 'WARDROBE_PROVIDER_UNSUPPORTED'
end
