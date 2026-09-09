
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

-- V3.8.0: generalizes a pattern Cosmic War built for its own Warbonds system
-- (a payout that scales off how a tracked score changed during a holding period, which a
-- player could otherwise game by personally applying the very relief action that would
-- guarantee a good outcome) into a reusable Vault primitive. Any mod with a similar
-- "snapshot a running total at the start of a hold, diff it at the end" need -- not just
-- Famine relief -- can share this instead of hand-rolling its own tracker per scoreKey.
function CosmicVaultEconomy.recordReliefApplied(scoreKey, factionIndex, amount)
    if not onServer() then return end
    if not scoreKey or not factionIndex or factionIndex <= 0 or not amount or amount <= 0 then return end
    local server = Server()
    if not server then return end
    local key = "cve_relief_" .. scoreKey .. "_" .. tostring(factionIndex)
    server:setValue(key, (server:getValue(key) or 0) + amount)
end

--- @return number the running total ever recorded for this scoreKey/faction (0 if none)
function CosmicVaultEconomy.getReliefApplied(scoreKey, factionIndex)
    if not scoreKey or not factionIndex or factionIndex <= 0 then return 0 end
    local server = Server()
    if not server then return 0 end
    return server:getValue("cve_relief_" .. scoreKey .. "_" .. tostring(factionIndex)) or 0
end

-- Registers a score family that should passively drift toward `floor` over time. Vault
-- doesn't run its own ticker for this (it has no Galaxy-attached background loop of its
-- own) -- a consuming mod's existing background script calls tickPassiveDecay() once per
-- faction per pass, so multiple mods/mechanics can share the registration and math instead
-- of each hand-building the same "drift a stored value back toward a baseline" logic.
local passiveDecayRegistry = {}

function CosmicVaultEconomy.registerPassiveDecay(scoreKeyPrefix, amountPerHour, floor)
    if type(scoreKeyPrefix) ~= "string" or type(amountPerHour) ~= "number" then return end
    passiveDecayRegistry[scoreKeyPrefix] = { amountPerHour = amountPerHour, floor = floor or 0 }
end

--- Applies one registered family's decay to one faction for this tick. `timeStep` is the
-- real elapsed seconds since the caller's last tick (its own getUpdateInterval()).
function CosmicVaultEconomy.tickPassiveDecay(scoreKeyPrefix, factionIndex, timeStep)
    if not onServer() then return end
    local cfg = passiveDecayRegistry[scoreKeyPrefix]
    if not cfg or not factionIndex or not timeStep then return end
    local server = Server()
    if not server then return end

    local key = scoreKeyPrefix .. tostring(factionIndex)
    local current = server:getValue(key) or 0
    if current <= cfg.floor then return end

    local decay = cfg.amountPerHour * (timeStep / 3600)
    server:setValue(key, math.max(cfg.floor, current - decay))
end

--- Reads Cosmic War's published galaxy-wide hostility index (the sum of every AI
-- faction's current War Heat) -- a soft-optional read (returns 0 if Cosmic War isn't
-- installed, or hasn't published one yet) any Cosmic mod can use to scale its own systems
-- off "how much overall warfare is happening right now" without a hard dependency on
-- Cosmic War, the same soft-include spirit as this file's own `cw_bridge` above.
function CosmicVaultEconomy.getGalacticHostilityIndex()
    local server = Server()
    if not server then return 0 end
    return server:getValue("cw_galactic_hostility_index") or 0
end

return CosmicVaultEconomy
