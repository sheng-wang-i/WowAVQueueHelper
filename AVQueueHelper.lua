-- AVQueueHelper: Streamlines Alterac Valley queuing via F12
-- Three presses: target NPC → interact → join queue
-- Supports both Alliance (Stormpike Emissary) and Horde (Frostwolf Emissary)

-- ============================================================
-- Constants & Configuration
-- ============================================================

local STATE = {
    IDLE        = "IDLE",        -- Waiting for player to start queue flow
    TARGETING   = "TARGETING",   -- /target macro just fired, verifying result
    INTERACTING = "INTERACTING", -- NPC targeted, waiting for F12 → INTERACTTARGET
    GOSSIPING   = "GOSSIPING",   -- Gossip dialog open, auto-selecting first option
    QUEUING     = "QUEUING",     -- Battlefield window open, waiting for F12 → Join
    READY       = "READY",       -- Queue popped, alerting player to press F12 → Enter
}

local LOG_LEVEL = {
    DEBUG = 1,
    INFO  = 2,
    WARN  = 3,
    ERROR = 4,
}

local NPC_NAMES = {
    Alliance = "Stormpike Emissary",
    Horde    = "Frostwolf Emissary",
}

local CONFIG = {
    NPC_NAME       = nil,   -- Set dynamically on PLAYER_LOGIN based on faction
    STEP_DELAY     = 0.2,   -- Seconds between automated sub-steps
    TIMEOUT        = 6,     -- Seconds before the queue flow auto-resets
    KEYBIND        = "F12",
    MSG_PREFIX     = "|cFF00FF00[AVQueueHelper]|r ",
    ALERT_SOUND    = 1018,  -- Sound Kit ID (WolfFidget2)
    ALERT_INTERVAL = 3,     -- Seconds between repeated alert sounds
    LOG_LEVEL      = LOG_LEVEL.INFO,
}

-- ============================================================
-- Mutable State
-- ============================================================

local addonState = {
    currentState = STATE.IDLE,
    timeoutTimer = nil,  -- Global timeout timer reference
    stepTimer    = nil,  -- Current sub-step delay timer reference
    generation   = 0,    -- Incremented on reset; stale callbacks check this
    alertTimer   = nil,  -- Repeating alert sound ticker
    flashTimer   = nil,  -- Screen flash toggle ticker
}

-- ============================================================
-- Event Framework
-- ============================================================

local eventHandlers = {}

local frame = CreateFrame("Frame", "AVQueueHelperFrame", UIParent)
frame:RegisterEvent("GOSSIP_SHOW")
frame:RegisterEvent("BATTLEFIELDS_SHOW")
frame:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
frame:SetScript("OnEvent", function(_, event, ...)
    if eventHandlers[event] then
        eventHandlers[event](...)
    end
end)

-- ============================================================
-- Utility: Logging
-- ============================================================

local function PrintMessage(msg, level)
    level = level or LOG_LEVEL.INFO
    if level < CONFIG.LOG_LEVEL then return end
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(CONFIG.MSG_PREFIX .. msg)
    end
end

-- ============================================================
-- Utility: State Management
-- ============================================================

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

-- ============================================================
-- Alert: Sound
-- ============================================================

local function StopAlertSound()
    if addonState.alertTimer then
        addonState.alertTimer:Cancel()  ---@diagnostic disable-line: undefined-field
        addonState.alertTimer = nil
    end
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

-- ============================================================
-- Alert: Screen Flash
-- ============================================================

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

-- ============================================================
-- State Reset & Timeout
-- ============================================================

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
-- Event Handlers
-- ============================================================

-- GOSSIP_SHOW: NPC dialog opened after INTERACTTARGET.
-- Auto-select the first gossip option after a short delay.
eventHandlers["GOSSIP_SHOW"] = function()
    if GetState() ~= STATE.INTERACTING then return end
    SetBindingClick(CONFIG.KEYBIND, "AVQueueHelperButton")
    local gen = addonState.generation
    addonState.stepTimer = C_Timer.NewTimer(CONFIG.STEP_DELAY, function()
        if addonState.generation ~= gen then return end
        addonState.stepTimer = nil
        SetState(STATE.GOSSIPING)
        SelectGossipOption(1)
    end)
end

-- BATTLEFIELDS_SHOW: Battlefield join window appeared.
-- Rebind F12 to the Join Battle button so the player can confirm.
eventHandlers["BATTLEFIELDS_SHOW"] = function()
    if GetState() ~= STATE.GOSSIPING then return end
    SetState(STATE.QUEUING)
    SetBindingClick(CONFIG.KEYBIND, "AVQueueHelperJoinButton")
    PrintMessage("Battlefield window open, press " .. CONFIG.KEYBIND .. " to join queue", LOG_LEVEL.INFO)
end

-- UPDATE_BATTLEFIELD_STATUS: Fires when any BG slot changes status.
-- Detects queue pop ("confirm") and enters READY state with alerts.
eventHandlers["UPDATE_BATTLEFIELD_STATUS"] = function()
    if GetState() == STATE.READY then
        -- Check if confirm expired while we were alerting
        for i = 1, 3 do
            if GetBattlefieldStatus(i) == "confirm" then return end
        end
        PrintMessage("Battleground entry expired", LOG_LEVEL.INFO)
        ResetState()
        return
    end

    if GetState() ~= STATE.IDLE then return end

    for i = 1, 3 do
        if GetBattlefieldStatus(i) == "confirm" then
            SetState(STATE.READY)
            SetBindingClick(CONFIG.KEYBIND, "AVQueueHelperEnterButton")
            PrintMessage("Battleground ready! Press " .. CONFIG.KEYBIND .. " to enter", LOG_LEVEL.INFO)
            StartAlertSound()
            StartFlash()
            return
        end
    end
end

-- ============================================================
-- Secure Buttons
-- ============================================================
-- Protected APIs (TargetUnit, InteractUnit, JoinBattlefield) require a
-- hardware event, so the player presses F12 three times:
--
--   Press 1: /target NPC → PostClick verifies, rebinds F12 to INTERACTTARGET
--   Press 2: INTERACTTARGET → GOSSIP_SHOW → auto-select gossip option
--            → BATTLEFIELDS_SHOW → rebinds F12 to Join Battle
--   Press 3: /click BattlefieldFrameJoinButton → queue complete → reset

-- Button 1: Target NPC (macrotext set on PLAYER_LOGIN)
local targetBtn = CreateFrame("Button", "AVQueueHelperButton", UIParent, "SecureActionButtonTemplate")
targetBtn:SetAttribute("type", "macro")

targetBtn:SetScript("PostClick", function()
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

-- Button 2: Join Battle (/click Blizzard's Join Battle button)
local joinBtn = CreateFrame("Button", "AVQueueHelperJoinButton", UIParent, "SecureActionButtonTemplate")
joinBtn:SetAttribute("type", "macro")
joinBtn:SetAttribute("macrotext", "/click BattlefieldFrameJoinButton")
joinBtn:SetScript("PostClick", function()
    if GetState() ~= STATE.QUEUING then return end
    PrintMessage("Join Battle clicked, queue complete", LOG_LEVEL.INFO)
    ResetState()
end)

-- Button 3: Enter Battleground (/click Blizzard's PVP ready dialog button)
local enterBtn = CreateFrame("Button", "AVQueueHelperEnterButton", UIParent, "SecureActionButtonTemplate")
enterBtn:SetAttribute("type", "macro")
enterBtn:SetAttribute("macrotext", "/click PVPReadyDialogEnterBattleButton")
enterBtn:SetScript("PostClick", function()
    if GetState() ~= STATE.READY then return end
    PrintMessage("Entering battleground", LOG_LEVEL.INFO)
    ResetState()
end)

-- ============================================================
-- Initialization (PLAYER_LOGIN)
-- ============================================================

frame:RegisterEvent("PLAYER_LOGIN")
eventHandlers["PLAYER_LOGIN"] = function()
    local faction = UnitFactionGroup("player")
    CONFIG.NPC_NAME = NPC_NAMES[faction]
    if not CONFIG.NPC_NAME then
        PrintMessage("Unknown faction: " .. tostring(faction) .. ", defaulting to Alliance NPC", LOG_LEVEL.WARN)
        CONFIG.NPC_NAME = NPC_NAMES["Alliance"]
    end
    targetBtn:SetAttribute("macrotext", "/target " .. CONFIG.NPC_NAME)
    SetBindingClick(CONFIG.KEYBIND, "AVQueueHelperButton")
    PrintMessage(CONFIG.KEYBIND .. " bound — press " .. CONFIG.KEYBIND .. " x3 near " .. CONFIG.NPC_NAME .. " to queue AV (" .. faction .. ")", LOG_LEVEL.INFO)
    frame:UnregisterEvent("PLAYER_LOGIN")
end
