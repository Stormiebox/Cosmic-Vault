package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local CosmicVaultEconomy = {}

-- Famine Score logic: 
-- 0 = Normal, 1-100 = Struggling, >100 = Famine

function CosmicVaultEconomy.addFamineScore(factionIndex, amount)
    local server = Server()
    if not server then return end
    
    local key = "cv_famine_" .. tostring(factionIndex)
    local currentScore = server:getValue(key) or 0
    currentScore = math.max(0, currentScore + amount)
    
    server:setValue(key, currentScore)
    
    return currentScore
end

function CosmicVaultEconomy.getFamineScore(factionIndex)
    local server = Server()
    if not server then return 0 end
    
    return server:getValue("cv_famine_" .. tostring(factionIndex)) or 0
end

function CosmicVaultEconomy.setFamineScore(factionIndex, amount)
    local server = Server()
    if not server then return end
    
    local key = "cv_famine_" .. tostring(factionIndex)
    server:setValue(key, math.max(0, amount))
end

function CosmicVaultEconomy.getFamineLevel(factionIndex)
    local score = CosmicVaultEconomy.getFamineScore(factionIndex)
    if score >= 100 then
        return "Severe Famine"
    elseif score >= 50 then
        return "Resource Starved"
    elseif score > 0 then
        return "Struggling"
    else
        return "Stable"
    end
end

return CosmicVaultEconomy
