-- v3.8.0: A shared, generic "who's winning this fight" scoreboard between
-- two factions -- proposed after Cosmic War's own War Score & Attrition system proved the
-- idea out. Deliberately NOT what Cosmic War's own getWarScore() runs on: War Score needs
-- asymmetric per-category weighting (kills vs. territory) with an independent cap on just
-- the kills component, which this single-combined-score primitive doesn't support, so
-- migrating it would have meant rebuilding and re-verifying logic that was only just
-- fixed this same pass. This is new, separate infrastructure for any OTHER Cosmic mod (or
-- a future Cosmic War mechanic) that wants a shared "conflict score" between two factions
-- without needing War's specific category/weighting rules.

-- namespace CosmicVaultConflict
CosmicVaultConflict = {}

local function pairKey(a, b)
    local lo, hi = math.min(a, b), math.max(a, b)
    return tostring(lo) .. "_" .. tostring(hi)
end

--- Records a weighted conflict event between two factions. A positive weight favors
-- factionAIndex, a negative weight favors factionBIndex -- callers choose their own
-- weight per event type (a kill, a captured asset, a diplomatic win, etc.), so this
-- primitive doesn't assume any particular category shape.
-- @param factionAIndex (int)
-- @param factionBIndex (int)
-- @param weight (number) signed weight of this event, from factionAIndex's perspective
function CosmicVaultConflict.recordEvent(factionAIndex, factionBIndex, weight)
    if not onServer() then return end
    if not factionAIndex or not factionBIndex or factionAIndex == factionBIndex or not weight then return end
    local server = Server()
    if not server then return end

    local key = pairKey(factionAIndex, factionBIndex)
    local lo = math.min(factionAIndex, factionBIndex)
    local delta = (factionAIndex == lo) and weight or -weight
    server:setValue("cvc_score_" .. key, (server:getValue("cvc_score_" .. key) or 0) + delta)
end

--- @return number the combined score from factionAIndex's perspective (positive = A ahead)
function CosmicVaultConflict.getScore(factionAIndex, factionBIndex)
    if not factionAIndex or not factionBIndex then return 0 end
    local server = Server()
    if not server then return 0 end

    local key = pairKey(factionAIndex, factionBIndex)
    local netForLo = server:getValue("cvc_score_" .. key) or 0

    local lo = math.min(factionAIndex, factionBIndex)
    if factionAIndex == lo then return netForLo end
    return -netForLo
end

--- Clears the score for a pair -- call once a conflict between them is considered resolved
-- so a future conflict between the same two factions starts fresh.
function CosmicVaultConflict.resetScore(factionAIndex, factionBIndex)
    if not onServer() then return end
    if not factionAIndex or not factionBIndex then return end
    local server = Server()
    if not server then return end
    server:setValue("cvc_score_" .. pairKey(factionAIndex, factionBIndex), nil)
end

return CosmicVaultConflict
