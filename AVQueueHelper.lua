-- AVQueueHelper: Auto-queue Alterac Valley with F12
-- State enum
local STATE = {
    IDLE        = "IDLE",
    TARGETING   = "TARGETING",
    INTERACTING = "INTERACTING",  -- Waiting for F12 to trigger INTERACTTARGET
    GOSSIPING   = "GOSSIPING",
    QUEUING     = "QUEUING",
    READY       = "READY",       -- BG queue popped, waiting for F12 to enter
}

-- Log levels
local LOG_LEVEL = {
    DEBUG = 1,
    INFO  = 2,
    WARN  = 3,
    ERROR = 4,
}

-- NPC names per faction
local NPC_NAMES = {
    Alliance = "Stormpike Emissary",
    Horde    = "Frostwolf Emissary",
}

-- Configuration constants
local CONFIG = {
    NPC_NAME       = nil,  -- set dynamically on PLAYER_LOGIN based on faction
    STEP_DELAY     = 0.2,
    TIMEOUT        = 6,
    KEYBIND        = "F12",
    MSG_PREFIX     = "|cFF00FF00[AVQueueHelper]|r ",
    ALERT_SOUND    = 1018,  -- WolfFidget2
    ALERT_INTERVAL = 3,
    LOG_LEVEL      = LOG_LEVEL.INFO,
}

-- Addon state variables
local addonState = {
    currentState = STATE.IDLE,
    timeoutTimer = nil,
    stepTimer    = nil,
    generation   = 0,
    alertTimer   = nil,
    flashTimer   = nil,
}

-- ============================================================
-- Core event framework
-- ============================================================

local eventHandlers = {}

local frame = CreateFrame("Frame", "AVQueueHelperFrame", UIParent)
frame:RegisterEvent("GOSSIP_SHOW")
frame:RegisterEvent("BATTLEFIELDS_SHOW")
frame:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
frame:SetScript("OnEvent", function(self, event, ...)
    if eventHandlers[event] then
        eventHandlers[event](...)
    end
end)

-- ============================================================
-- Utility functions
-- ============================================================

local function PrintMessage(msg, level)
    level = level or LOG_LEVEL.INFO
    if level < CONFIG.LOG_LEVEL then return end
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(CONFIG.MSG_PREFIX .. msg)
    end
end

local function GetState()
    return addonState.currentState
end

local function SetState(newState)
    addonState.currentState = newState
end

local function CancelTimeout()
    if addonState.timeoutTimer then
        addonState.timeoutTimer:Cancel()    ---@diagnostic disable-line: undefined-field
        addonState.timeoutTimer = nil
    end
end

local function StopAlertSound()
    if addonState.alertTimer then
        addonState.alertTimer:Cancel()  ---@diagnostic disable-line: undefined-field
        addonState.alertTimer = nil
    end
end

-- Red screen flash for confirm alert
local flashFrame = CreateFrame("Frame", "AVQueueHelperFlashFrame", UIParent)
flashFrame:SetFrameStrata("TOOLTIP")
flashFrame:SetAllPoints(UIParent)
local flashTex = flashFrame:CreateTexture(nil, "OVERLAY")
flashTex:SetAllPoints()
flashTex:SetColorTexture(1, 0, 0, 0.3)
flashFrame:Hide()

local function StopFlash()
    if addonState.flashTimer then
        addonState.flashTimer:Cancel()  ---@diagnostic disable-line: undefined-field
        addonState.flashTimer = nil
    end
    flashFrame:Hide()
end

local function StartFlash()
    StopFlash()
    flashFrame:Show()
    flashTex:Show()
    local visible = true
    addonState.flashTimer = C_Timer.NewTicker(0.5, function()
        visible = not visible
        if visible then
            flashTex:Show()
        else
            flashTex:Hide()
        end
    end)
end

local function StartAlertSound()
    StopAlertSound()
    PlaySound(CONFIG.ALERT_SOUND, "Master")
    addonState.alertTimer = C_Timer.NewTicker(CONFIG.ALERT_INTERVAL, function()
        if GetState() ~= STATE.READY then
            StopAlertSound()
            return
        end
        PlaySound(CONFIG.ALERT_SOUND, "Master")
    end)
end

local function ResetState()
    if addonState.stepTimer then
        addonState.stepTimer:Cancel()  ---@diagnostic disable-line: undefined-field
        addonState.stepTimer = nil
    end
    CancelTimeout()
    StopAlertSound()
    StopFlash()
    addonState.generation = addonState.generation + 1
    SetState(STATE.IDLE)
    -- Ensure keybind is rebound to the target button
    SetBindingClick(CONFIG.KEYBIND, "AVQueueHelperButton")
end

local function StartTimeout()
    CancelTimeout()
    addonState.timeoutTimer = C_Timer.NewTimer(CONFIG.TIMEOUT, function()
        PrintMessage("Queue process timed out, please retry", LOG_LEVEL.INFO)
        addonState.timeoutTimer = nil
        ResetState()
    end)
end

-- ============================================================
-- Queue workflow step functions
-- ============================================================

local SelectFirstGossipOption

SelectFirstGossipOption = function()
    SelectGossipOption(1)
end

-- ============================================================
-- Event handlers
-- ============================================================

eventHandlers["GOSSIP_SHOW"] = function()
    -- PrintMessage("GOSSIP_SHOW fired, state: " .. GetState())
    if GetState() ~= STATE.INTERACTING then return end
    SetBindingClick(CONFIG.KEYBIND, "AVQueueHelperButton")
    local gen = addonState.generation
    addonState.stepTimer = C_Timer.NewTimer(CONFIG.STEP_DELAY, function()
        if addonState.generation ~= gen then return end
        addonState.stepTimer = nil
        SetState(STATE.GOSSIPING)
        SelectFirstGossipOption()
    end)
end

eventHandlers["BATTLEFIELDS_SHOW"] = function()
    -- PrintMessage("BATTLEFIELDS_SHOW fired, state: " .. GetState())
    if GetState() ~= STATE.GOSSIPING then return end
    -- JoinBattlefield() is also a protected function requiring a hardware event.
    -- Rebind F12 to a macro button that /click's the Blizzard Join Battle button.
    SetState(STATE.QUEUING)
    SetBindingClick(CONFIG.KEYBIND, "AVQueueHelperJoinButton")
    PrintMessage("Battlefield window open, press " .. CONFIG.KEYBIND .. " to join queue", LOG_LEVEL.INFO)
end

eventHandlers["UPDATE_BATTLEFIELD_STATUS"] = function()
    -- When a queued BG becomes ready to enter (status == "confirm"),
    -- rebind keybind to the enter button so the player can press F12 to enter.
    -- Only do this when IDLE (not mid-flow).
    if GetState() ~= STATE.IDLE then return end
    for i = 1, 3 do
        local status = GetBattlefieldStatus(i)
        if status == "confirm" then
            SetState(STATE.READY)
            SetBindingClick(CONFIG.KEYBIND, "AVQueueHelperEnterButton")
            PrintMessage("Battleground ready! Press " .. CONFIG.KEYBIND .. " to enter", LOG_LEVEL.INFO)
            StartAlertSound()
            StartFlash()
            return
        end
    end
    -- If we were in READY state but confirm went away (expired), reset
    if GetState() == STATE.READY then
        PrintMessage("Battleground entry expired", LOG_LEVEL.INFO)
        ResetState()
    end
end

-- ============================================================
-- Secure buttons & F12 keybinding
-- ============================================================
-- TargetUnit(), InteractUnit(), and JoinBattlefield() are all protected
-- functions that can only run in a hardware-event secure execution path.
-- The player must press F12 three times, each triggering a different action:
--
--   F12 press 1: Secure macro button executes /target NPC
--     PostClick verifies target, rebinds F12 to INTERACTTARGET
--   F12 press 2: Game executes INTERACTTARGET -> opens NPC dialog
--     GOSSIP_SHOW fires -> auto-selects first gossip option
--     BATTLEFIELDS_SHOW fires -> rebinds F12 to Join Battle button
--   F12 press 3: /click BattlefieldFrameJoinButton -> queue joined
--     PostClick resets state, rebinds F12 back to initial target button

-- Jump button: /jump to prevent AFK while queued
local jumpBtn = CreateFrame("Button", "AVQueueHelperJumpButton", UIParent, "SecureActionButtonTemplate")
jumpBtn:SetAttribute("type", "macro")
jumpBtn:SetAttribute("macrotext", "/jump")
jumpBtn:SetScript("PostClick", function()
    PrintMessage("Already queued for a battleground, please wait", LOG_LEVEL.INFO)
    SetBindingClick(CONFIG.KEYBIND, "AVQueueHelperButton")
end)

local btn = CreateFrame("Button", "AVQueueHelperButton", UIParent, "SecureActionButtonTemplate")
btn:SetAttribute("type", "macro")

btn:SetScript("PostClick", function()
    if GetState() ~= STATE.IDLE then return end

    -- Check battlefield status before starting queue flow
    for i = 1, 3 do
        local status = GetBattlefieldStatus(i)
        if status == "queued" then
            PrintMessage("Already queued for a battleground, please wait", LOG_LEVEL.INFO)
            return
        end
        if status == "active" then
            local winner = GetBattlefieldWinner()
            if winner ~= nil then
                -- Match is over, safe to leave without deserter
                PrintMessage("Battleground ended, leaving", LOG_LEVEL.INFO)
                LeaveBattlefield()
            else
                PrintMessage("Battleground still in progress", LOG_LEVEL.INFO)
            end
            return
        end
    end

    StartTimeout()
    SetState(STATE.TARGETING)
    if UnitName("target") == CONFIG.NPC_NAME then
        SetBinding(CONFIG.KEYBIND, "INTERACTTARGET")
        SetState(STATE.INTERACTING)
        PrintMessage("Targeted " .. CONFIG.NPC_NAME .. ", press " .. CONFIG.KEYBIND .. " again to interact", LOG_LEVEL.INFO)
    else
        PrintMessage(CONFIG.NPC_NAME .. " not found, move closer and retry", LOG_LEVEL.WARN)
        ResetState()
    end
end)

-- Join Battle button: /click's the Blizzard Join Battle button
local joinBtn = CreateFrame("Button", "AVQueueHelperJoinButton", UIParent, "SecureActionButtonTemplate")
joinBtn:SetAttribute("type", "macro")
joinBtn:SetAttribute("macrotext", "/click BattlefieldFrameJoinButton")
joinBtn:SetScript("PostClick", function()
    if GetState() ~= STATE.QUEUING then return end
    PrintMessage("Join Battle clicked, queue complete", LOG_LEVEL.INFO)
    ResetState()
end)

-- Enter Battleground button: /click's the Blizzard PVP ready dialog enter button
local enterBtn = CreateFrame("Button", "AVQueueHelperEnterButton", UIParent, "SecureActionButtonTemplate")
enterBtn:SetAttribute("type", "macro")
enterBtn:SetAttribute("macrotext", "/click PVPReadyDialogEnterBattleButton")
enterBtn:SetScript("PostClick", function()
    if GetState() ~= STATE.READY then return end
    PrintMessage("Entering battleground", LOG_LEVEL.INFO)
    ResetState()
end)

-- Register Configured key, default is F12, keybinding on login
frame:RegisterEvent("PLAYER_LOGIN")
eventHandlers["PLAYER_LOGIN"] = function()
    local faction = UnitFactionGroup("player")
    CONFIG.NPC_NAME = NPC_NAMES[faction]
    if not CONFIG.NPC_NAME then
        PrintMessage("Unknown faction: " .. tostring(faction) .. ", defaulting to Alliance NPC", LOG_LEVEL.WARN)
        CONFIG.NPC_NAME = NPC_NAMES["Alliance"]
    end
    btn:SetAttribute("macrotext", "/target " .. CONFIG.NPC_NAME)
    SetBindingClick(CONFIG.KEYBIND, "AVQueueHelperButton")
    PrintMessage(CONFIG.KEYBIND .. " bound — press " .. CONFIG.KEYBIND .. " x3 near " .. CONFIG.NPC_NAME .. " to queue AV (" .. faction .. ")", LOG_LEVEL.INFO)
    frame:UnregisterEvent("PLAYER_LOGIN")
end
