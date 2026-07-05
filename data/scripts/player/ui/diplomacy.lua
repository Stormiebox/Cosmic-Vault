-- Cosmic Vault: Diplomacy UI Wrapper
-- Avorion VFS handles this file automatically
-- This script seamlessly injects custom faction traits into the vanilla diplomacy UI without breaking compatibility.

local cvf = include("cosmicvaultfaction")

local cv_old_updateFactionInformation = Diplomacy.updateFactionInformation

function Diplomacy:updateFactionInformation()
    -- 1. Let vanilla Avorion render its hardcoded traits
    if cv_old_updateFactionInformation then
        cv_old_updateFactionInformation(self)
    end

    if not self.factionListBox or not self.factions or not self.traits then return end

    -- 2. Inject our custom traits at the end of the text block
    local index = self.factionListBox.selected
    if type(index) ~= "number" or index < 0 then return end

    local relation = self.factions[index + 1]
    if type(relation) ~= "table" or not relation.factionIndex then return end

    local faction = Faction(relation.factionIndex)
    if not faction then return end

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
