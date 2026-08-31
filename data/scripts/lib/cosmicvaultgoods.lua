include("goods")

-- namespace CosmicVaultGoods
CosmicVaultGoods = {}

--- Registers a custom trading good natively by appending to the global goods tables
-- @param goodData (table) Must contain {name, description, price, size, icon} at minimum
function CosmicVaultGoods.registerGood(goodData)
    if not goodData or type(goodData) ~= "table" then return end
    if not goodData.name then return end
    
    -- Ensure default properties if missing
    goodData.price = goodData.price or 100
    goodData.size = goodData.size or goodData.volume or 1.0
    goodData.description = goodData.description or ""
    goodData.icon = goodData.icon or "data/textures/icons/crate.png"
    goodData.plural = goodData.plural or goodData.name
    goodData.illegal = goodData.illegal or false
    goodData.suspicious = goodData.suspicious or false
    goodData.stolen = goodData.stolen or false
    goodData.dangerous = goodData.dangerous or false
    goodData.tags = goodData.tags or {}
    
    -- Check if it already exists to prevent duplicate entries on reload
    for _, existingGood in pairs(goodsArray) do
        if existingGood.name == goodData.name then
            return -- Already registered
        end
    end
    
    -- Insert into the global table lookup
    goods[goodData.name] = goodData
    
    -- Convert to a TradingGood object logic reference
    goodData.good = tableToGood

    -- Insert into goodsArray
    table.insert(goodsArray, goodData)
    
    -- Maintain spawnable arrays
    if not (goodData.tags.trinium or goodData.tags.xanion or goodData.tags.ogonite or goodData.tags.avorion) then
        if not goodData.illegal then
            table.insert(legalSpawnableGoods, goodData)
        end

        if not goodData.suspicious
                and not goodData.illegal
                and not goodData.dangerous
                and not goodData.stolen then
            table.insert(uncomplicatedSpawnableGoods, goodData)
        end

        table.insert(spawnableGoods, goodData)
    end

    if goodData.illegal then
        table.insert(illegalSpawnableGoods, goodData)
    end
    
    -- Keep arrays sorted for standard UI consistency
    table.sort(goodsArray, function (a, b) return a.name < b.name end)
end

return CosmicVaultGoods
