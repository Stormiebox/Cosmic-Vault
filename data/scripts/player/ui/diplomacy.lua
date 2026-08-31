-- Cosmic Vault: Diplomacy UI Wrapper
-- Avorion VFS handles this file automatically
-- This script seamlessly injects custom faction traits into the vanilla diplomacy UI without breaking compatibility.

local cvf = include("cosmicvaultfaction")

-- Vanilla's real trait-rendering function is Diplomacy:updateTraits(faction) -
-- there is no "updateFactionInformation" anywhere in diplomacy.lua, so hooking
-- that name silently did nothing (nobody ever called it).
local cv_old_updateTraits = Diplomacy.updateTraits

function Diplomacy:updateTraits(faction)
    -- 1. Let vanilla Avorion render its hardcoded traits
    if cv_old_updateTraits then
        cv_old_updateTraits(self, faction)
    end

    if not faction or not self.traits then return end

    if cvf then
        local customTraits = cvf.getCustomTraits()
        if type(customTraits) == "table" then
            local appendedText = ""

            for traitId, data in pairs(customTraits) do
                if type(data) == "table" then
                    local value = cvf.getTrait(faction.index, traitId) or 0
                    if type(value) == "number" and value >= 0.25 then
                        local name = tostring(data.name or traitId)
                        local descriptions = data.descriptions

                        if self.traits.text ~= "" and appendedText == "" then
                            appendedText = appendedText .. "\n"
                        end
                        
                        appendedText = appendedText .. "\\c()" .. name .. "\\c(777)"

                        if type(descriptions) == "table" then
                            for _, description in pairs(descriptions) do
                                appendedText = appendedText .. "\n- " .. tostring(description)
                            end
                        end
                        
                        appendedText = appendedText .. "\n"
                    end
                end
            end
            
            -- Strip trailing newline
            if string.sub(appendedText, -1) == "\n" then
                appendedText = string.sub(appendedText, 1, -2)
            end

            if appendedText ~= "" then
                self.traits.text = self.traits.text .. "\n" .. appendedText
            end
        end
    end
end
