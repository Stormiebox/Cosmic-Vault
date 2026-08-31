
-- Cosmic War is an optional sister mod from Vault's perspective (Vault is the
-- foundational dependency; nothing here requires War to be installed), so this
-- must be a soft include - a bare include("cosmicwarbridge") would throw
-- "module not found" and break this entire library on any install that has
-- Vault without War (e.g. Vault + Overhaul only).
local cw_ok, cw_bridge = pcall(include, "cosmicwarbridge")
if not cw_ok then cw_bridge = nil end
local FactionEradicationUtility = include("factioneradicationutility")
local CosmicVaultEconomy = {}

-- Famine Score logic:
-- 0 = Normal, 1-100 = Struggling, >100 = Famine

function CosmicVaultEconomy.addFamineScore(factionIndex, amount)
    if not onServer() then return end
    local server = Server()
    if not server then return end

    local key = "cv_famine_" .. tostring(factionIndex)
    local currentScore = server:getValue(key) or 0
    currentScore = math.max(0, currentScore + amount)

    server:setValue(key, currentScore)

    -- Synergy: Deep Economy Driving Warfare
    if currentScore >= 100 then
        local starvingFaction = Faction(factionIndex)
        if starvingFaction then
            -- Cap simultaneous Famine Wars to 1: Do not declare a new war if already fighting one
            if starvingFaction:getValue("enemy_faction") and starvingFaction:getValue("enemy_faction") > 0 then
                return currentScore
            end

            local factions = {}
            local factionStr = server:getValue("factions")
            if type(factionStr) == "string" and factionStr ~= "" then
                for id in string.gmatch(factionStr, "([^,]+)") do
                    local f = Faction(tonumber(id))
                    if f then table.insert(factions, f) end
                end
            end
            local bestTarget = nil
            local bestTargetWealth = -1
            
            for _, f in pairs(factions) do
                if f.index ~= factionIndex and not f.isPlayer and not f.isAlliance then
                    local isEradicated = false
                    if FactionEradicationUtility and FactionEradicationUtility.isFactionEradicated then
                        isEradicated = FactionEradicationUtility.isFactionEradicated(f.index)
                    end
                    
                    if not isEradicated then
                        local wealth = f.money or 0
                        if wealth > bestTargetWealth then
                            bestTarget = f
                            bestTargetWealth = wealth
                        end
                    end
                end
            end
            
            if bestTarget and cw_bridge and cw_bridge.forceDeclareWar then
                cw_bridge.forceDeclareWar(starvingFaction, bestTarget)
                
                local CosmicVaultNews = include("cosmicvaultnews")
                if CosmicVaultNews and CosmicVaultNews.publishArticle then
                    CosmicVaultNews.publishArticle({
                        title = "Desperation War: " .. tostring(starvingFaction.name) .. " Attacks " .. tostring(bestTarget.name),
                        content = "Driven by critical resource shortages and a surging famine score, the " .. tostring(starvingFaction.name) .. " military has launched a desperate invasion into " .. tostring(bestTarget.name) .. " territory to seize their wealth and supplies.\n\nGalactic economists are calling this the direct result of a collapsed market.",
                        category = "Conflict"
                    })
                end
                
                -- Reset famine score slightly so they don't declare war again instantly
                server:setValue(key, 80)
            end
        end
    end

    return currentScore
end

function CosmicVaultEconomy.getFamineScore(factionIndex)
    if type(Server) == "function" then
        local server = Server()
        if server then
            return server:getValue("cv_famine_" .. tostring(factionIndex)) or 0
        end
    end
    return 0
end

function CosmicVaultEconomy.setFamineScore(factionIndex, amount)
    if type(Server) == "function" then
        local server = Server()
        if server then
            local key = "cv_famine_" .. tostring(factionIndex)
            server:setValue(key, math.max(0, amount))
        end
    end
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

function CosmicVaultEconomy.TriggerMarketEvent(goodName, x, y, radius, eventType)
    if not onServer() then return end
    local server = Server()
    if not server then return end

    server:broadcastChatMessage("Server"%_T, ChatMessageType.Economy, "Market event %s for %s started near (%d, %d)."%_T, eventType, goodName, x, y)
    -- In a full implementation this would attach a script to the sector or register it globally
end

-- Registers a dynamic price hook for a good. economyupdater.lua's
-- getSupplyDemandPriceChange() reads this same "CVE_PriceHook_<good>" key
-- (pipe-separated "scriptName::functionName" entries) every time it computes
-- that good's price, and invokes each registered hook with (good, factor),
-- multiplying the result into the final price change factor.
function CosmicVaultEconomy.registerPriceHook(goodName, scriptName, functionName)
    if not onServer() then return end
    if type(goodName) ~= "string" or type(scriptName) ~= "string" or type(functionName) ~= "string" then return end
    local server = Server()
    if not server then return end

    local key = "CVE_PriceHook_" .. string.gsub(goodName, "%s+", "_")
    local entry = scriptName .. "::" .. functionName
    local hooksStr = server:getValue(key) or ""

    for hook in string.gmatch(hooksStr, "([^|]+)") do
        if hook == entry then return end
    end

    server:setValue(key, hooksStr == "" and entry or (hooksStr .. "|" .. entry))
end

return CosmicVaultEconomy
