package.path = package.path .. ";data/scripts/lib/?.lua"
include("goods")

-- namespace CosmicVaultGoods
CosmicVaultGoods = {}

--- Registers a custom trading good natively by appending to the global goods table
-- @param goodData (table) Must contain {name, description, price, volume, icon} at minimum
function CosmicVaultGoods.registerGood(goodData)
    if not goodData or type(goodData) ~= "table" then return end
    if not goodData.name then return end
    
    -- Ensure default properties if missing
    goodData.price = goodData.price or 100
    goodData.volume = goodData.volume or 1.0
    goodData.description = goodData.description or ""
    goodData.icon = goodData.icon or "data/textures/icons/crate.png"
    
    -- Check if it already exists to prevent duplicate entries on reload
    for _, existingGood in pairs(goods) do
        if existingGood.name == goodData.name then
            return -- Already registered
        end
    end
    
    -- Insert into the global table
    table.insert(goods, goodData)
    
    -- Update the lookup tables used by tradingpost.lua and others
    if goods[goodData.name] == nil then
        goods[goodData.name] = goodData
    end
end

return CosmicVaultGoods
