local ADDON_NAME, ns = ...
local Config = {}
ns.Config = Config

local QUALITY_NAMES = {
    [2] = "|cff1eff00Uncommon|r",
    [3] = "|cff0070ddRare|r",
    [4] = "|cffa335eeEpic|r",
    [5] = "|cffff8000Legendary|r",
}
local QUALITY_SORT = {2, 3, 4}

function Config:Initialize()
    local addon = ns.addon

    local options = {
        name = ns.DISPLAY_NAME,
        type = "group",
        args = {
            enabled = {
                name  = "Enable",
                desc  = "Enable " .. ns.DISPLAY_NAME .. " loot tracking",
                type  = "toggle",
                order = 1,
                get   = function() return addon.db.profile.enabled end,
                set   = function(_, val)
                    addon.db.profile.enabled = val
                    if val then addon:Enable() else addon:Disable() end
                end,
            },
            minQuality = {
                name    = "Minimum Rarity",
                desc    = "Only track items of this rarity or better (ignored in Debug mode)",
                type    = "select",
                order   = 2,
                values  = QUALITY_NAMES,
                sorting = QUALITY_SORT,
                get     = function() return addon.db.profile.minQuality end,
                set     = function(_, val) addon.db.profile.minQuality = val end,
            },
            autoWhisper = {
                name  = "Auto Whisper",
                desc  = "Whisper players who loot items that are upgrades for you",
                type  = "toggle",
                order = 3,
                get   = function() return addon.db.profile.autoWhisper end,
                set   = function(_, val) addon.db.profile.autoWhisper = val end,
            },
            whisperOnlyIfLooterOutgearsSlot = {
                name  = "Only whisper if item is not a upgrade for the looter",
                width = "full",
                desc  = "Skip the auto-whisper unless the looter already has a higher-ilvl item equipped in that slot. They are more likely to trade or pass it.",
                type  = "toggle",
                order = 4,
                get   = function() return addon.db.profile.whisperOnlyIfLooterOutgearsSlot end,
                set   = function(_, val) addon.db.profile.whisperOnlyIfLooterOutgearsSlot = val end,
            },
            whisperTemplate = {
                name  = "Whisper Message",
                desc  = "Message sent to the looter. Use %item as a placeholder for the item link.",
                type  = "input",
                order = 5,
                width = "full",
                get   = function() return addon.db.profile.whisperTemplate end,
                set   = function(_, val)
                    if val and val:trim() ~= "" then
                        addon.db.profile.whisperTemplate = val
                    end
                end,
            },
        },
    }

    addon.aceConfig:RegisterOptionsTable(ADDON_NAME, options)
    addon.configDialog:AddToBlizOptions(ADDON_NAME, ns.DISPLAY_NAME)
end
