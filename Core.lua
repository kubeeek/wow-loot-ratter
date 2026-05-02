local ADDON_NAME, ns = ...
ns.DISPLAY_NAME = "Loot Ratter"

ns.L = {
    SENT             = "sent",
    ASK_BUTTON       = "Ask",
    WHISPER_TEMPLATE = "hey, do you need %item?",
    UPGRADE          = "upgrade for you",
}

local LootRatter = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME,
    "AceConsole-3.0", "AceEvent-3.0")
ns.addon = LootRatter

local defaults = {
    profile = {
        enabled     = true,
        autoWhisper = true,
        whisperOnlyIfLooterOutgearsSlot = false,
        minQuality      = 2,
        whisperTemplate = ns.L.WHISPER_TEMPLATE,
        debug           = false,
    },
}

function LootRatter:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New(ADDON_NAME .. "DB", defaults, true)
    self.aceConfig = LibStub("AceConfig-3.0")
    self.configDialog = LibStub("AceConfigDialog-3.0")
    self:RegisterChatCommand("lw", "SlashHandler")
    ns.Config:Initialize()
end

function LootRatter:OnEnable()
    ns.Tracker:Enable()
end

function LootRatter:OnDisable()
    ns.Tracker:Disable()
end

function LootRatter:SlashHandler(input)
    input = input and input:trim() or ""
    if input == "debug" then
        self.db.profile.debug = not self.db.profile.debug
        self:Print(ns.DISPLAY_NAME .. ": Debug " .. (self.db.profile.debug and "ON" or "OFF"))
    elseif input == "debug show" then
        ns.UI:ShowTest()
    else
        self.configDialog:Open(ADDON_NAME)
    end
end

function LootRatter:Debug(msg)
    if self.db and self.db.profile.debug then
        self:Print("|cff888888[Debug]|r " .. tostring(msg))
    end
end
