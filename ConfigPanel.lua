-- ConfigPanel.lua: Settings panel and /avq slash command for AVQueueHelper

-- ============================================================
-- Settings Panel Frame
-- ============================================================

local panel = CreateFrame("Frame", "AVQueueHelperSettingsPanel", UIParent, "BasicFrameTemplateWithInset")
panel:SetSize(190, 330)
panel:SetPoint("CENTER", 0, 50)
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", panel.StartMoving)
panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
panel:Hide()

-- Title
panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
panel.title:SetPoint("TOP", panel, "TOP", 0, -5)
panel.title:SetText("AVQueueHelper")

-- ESC close support is handled in the OnShow handler below

-- ============================================================
-- Log Level Dropdown
-- ============================================================

local LOG_LEVEL = AVQueueHelper_Shared.LOG_LEVEL
local CONFIG    = AVQueueHelper_Shared.CONFIG

-- Label
local logLevelLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
logLevelLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -40)
logLevelLabel:SetText("Log Level")

-- Dropdown
local logLevelDropdown = CreateFrame("Frame", "AVQueueHelperLogLevelDropdown", panel, "UIDropDownMenuTemplate")
logLevelDropdown:SetPoint("TOPLEFT", logLevelLabel, "BOTTOMLEFT", -16, -4)

-- Map numeric values to display names (ordered)
local LOG_LEVEL_OPTIONS = {
    { text = "DEBUG", value = LOG_LEVEL.DEBUG },
    { text = "INFO",  value = LOG_LEVEL.INFO  },
    { text = "WARN",  value = LOG_LEVEL.WARN  },
    { text = "ERROR", value = LOG_LEVEL.ERROR },
}

local function LogLevelDropdown_Initialize(self, level)
    for _, opt in ipairs(LOG_LEVEL_OPTIONS) do
        local info = UIDropDownMenu_CreateInfo()
        info.text     = opt.text
        info.value    = opt.value
        info.checked  = (CONFIG.LOG_LEVEL == opt.value)
        local optText = opt.text
        info.func     = function(item)
            CONFIG.LOG_LEVEL = item.value
            AVQueueHelperDB.logLevel = item.value
            UIDropDownMenu_SetSelectedValue(logLevelDropdown, item.value)
            UIDropDownMenu_SetText(logLevelDropdown, optText)
        end
        UIDropDownMenu_AddButton(info, level)
    end
end

-- Resolve display text for a given log level value
local function GetLogLevelText(value)
    for _, opt in ipairs(LOG_LEVEL_OPTIONS) do
        if opt.value == value then return opt.text end
    end
    return "Unknown"
end

UIDropDownMenu_Initialize(logLevelDropdown, LogLevelDropdown_Initialize)
UIDropDownMenu_SetWidth(logLevelDropdown, 120)
UIDropDownMenu_SetSelectedValue(logLevelDropdown, CONFIG.LOG_LEVEL)
UIDropDownMenu_SetText(logLevelDropdown, GetLogLevelText(CONFIG.LOG_LEVEL))

-- ============================================================
-- Keybind Capture Button
-- ============================================================

local settingsState = {
    capturingKeybind = false,
}

-- Label
local keybindLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
keybindLabel:SetPoint("TOPLEFT", logLevelDropdown, "BOTTOMLEFT", 16, -12)
keybindLabel:SetText("Keybind")

-- Button showing current keybind; click to enter capture mode
local keybindButton = CreateFrame("Button", "AVQueueHelperKeybindButton", panel, "UIPanelButtonTemplate")
keybindButton:SetSize(140, 30)
keybindButton:SetPoint("TOPLEFT", keybindLabel, "BOTTOMLEFT", 0, -4)
keybindButton:SetText(CONFIG.KEYBIND)

keybindButton:SetScript("OnClick", function(self)
    if not settingsState.capturingKeybind then
        settingsState.capturingKeybind = true
        self:SetText("Press a key...")
        self:EnableKeyboard(true)
        self:SetPropagateKeyboardInput(false)
    end
end)

-- Keybind capture: OnKeyDown handler
keybindButton:SetScript("OnKeyDown", function(self, key)
    if not settingsState.capturingKeybind then
        self:SetPropagateKeyboardInput(true)
        return
    end

    -- ESC exits capture mode without changing anything (don't propagate to avoid closing panel)
    if key == "ESCAPE" then
        settingsState.capturingKeybind = false
        self:SetText(CONFIG.KEYBIND)
        self:EnableKeyboard(false)
        self:SetPropagateKeyboardInput(false)
        return
    end

    local PrintMessage = AVQueueHelper_Shared.PrintMessage
    local LOG_LEVEL_REF = AVQueueHelper_Shared.LOG_LEVEL

    -- Check for conflict (allow if bound to our own addon buttons or is current keybind)
    local action = GetBindingAction(key)
    local isOwnBinding = action and (
        action == "CLICK AVQueueHelperButton:LeftButton" or
        action == "CLICK AVQueueHelperJoinButton:LeftButton" or
        action == "CLICK AVQueueHelperJumpButton:LeftButton" or
        action == "CLICK AVQueueHelperEnterButton:LeftButton"
    )
    if action and action ~= "" and key ~= CONFIG.KEYBIND and not isOwnBinding then
        -- Conflict detected: warn and abort
        PrintMessage("Key \"" .. key .. "\" conflicts with action: " .. action .. ", binding aborted", LOG_LEVEL_REF.WARN)
        settingsState.capturingKeybind = false
        self:SetText(CONFIG.KEYBIND)
        self:EnableKeyboard(false)
        self:SetPropagateKeyboardInput(true)
        return
    end

    -- No conflict: unbind old key, bind new key to current stage button
    local oldKey = CONFIG.KEYBIND

    -- Determine current button based on addon state
    local addonState = AVQueueHelper_Shared.addonState
    local STATE = AVQueueHelper_Shared.STATE
    local currentButton
    if addonState.currentState == STATE.QUEUING then
        currentButton = "AVQueueHelperJoinButton"
    elseif addonState.currentState == STATE.READY then
        currentButton = "AVQueueHelperEnterButton"
    else
        currentButton = "AVQueueHelperButton"
    end

    -- Unbind old key and clear any stale binding on new key, then bind new key
    SetBinding(oldKey)
    SetBinding(key)
    SetBindingClick(key, currentButton)

    -- Update config and saved variables
    CONFIG.KEYBIND = key
    AVQueueHelperDB.keybind = key

    -- Exit capture mode and update display (don't propagate this keypress to avoid triggering the new binding)
    settingsState.capturingKeybind = false
    self:SetText(key)
    self:EnableKeyboard(false)
    self:SetPropagateKeyboardInput(false)
end)

-- ============================================================
-- Volume Boost Slider
-- ============================================================

-- Label
local volumeBoostLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
volumeBoostLabel:SetPoint("TOPLEFT", keybindButton, "BOTTOMLEFT", 0, -16)
volumeBoostLabel:SetText("Volume Boost")

-- Slider
local volumeBoostSlider = CreateFrame("Slider", "AVQueueHelperVolumeBoostSlider", panel, "OptionsSliderTemplate")
volumeBoostSlider:SetPoint("TOPLEFT", volumeBoostLabel, "BOTTOMLEFT", 0, -12)
volumeBoostSlider:SetWidth(140)
volumeBoostSlider:SetMinMaxValues(1.0, 2.0)
volumeBoostSlider:SetValueStep(0.1)
volumeBoostSlider:SetObeyStepOnDrag(true)
volumeBoostSlider:SetValue(CONFIG.VOLUME_BOOST_FACTOR)

-- Low/High labels
local sliderName = volumeBoostSlider:GetName()
local sliderLow = _G[sliderName .. "Low"]
local sliderHigh = _G[sliderName .. "High"]
sliderLow:SetText("1.0")
sliderHigh:SetText("2.0")

-- Current value label (one decimal place)
local volumeBoostValueLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
volumeBoostValueLabel:SetPoint("TOP", volumeBoostSlider, "BOTTOM", 0, -2)
volumeBoostValueLabel:SetText(string.format("%.1f", CONFIG.VOLUME_BOOST_FACTOR))

-- OnValueChanged: round to one decimal, persist, and update label
volumeBoostSlider:SetScript("OnValueChanged", function(_, value)
    local rounded = math.floor(value * 10 + 0.5) / 10
    CONFIG.VOLUME_BOOST_FACTOR = rounded
    AVQueueHelperDB.volumeBoostFactor = rounded
    volumeBoostValueLabel:SetText(string.format("%.1f", rounded))
end)

-- Refresh selection when panel is shown (picks up external changes)
panel:SetScript("OnShow", function()
    -- Ensure frame is in UISpecialFrames for ESC-to-close
    local found = false
    for _, name in ipairs(UISpecialFrames) do
        if name == "AVQueueHelperSettingsPanel" then
            found = true
            break
        end
    end
    if not found then
        tinsert(UISpecialFrames, "AVQueueHelperSettingsPanel")
    end

    UIDropDownMenu_SetSelectedValue(logLevelDropdown, CONFIG.LOG_LEVEL)
    UIDropDownMenu_SetText(logLevelDropdown, GetLogLevelText(CONFIG.LOG_LEVEL))
    -- Sync keybind button text with current CONFIG value
    if not settingsState.capturingKeybind then
        keybindButton:SetText(CONFIG.KEYBIND)
    end
    -- Sync volume boost slider with current CONFIG value
    volumeBoostSlider:SetValue(CONFIG.VOLUME_BOOST_FACTOR)
    volumeBoostValueLabel:SetText(string.format("%.1f", CONFIG.VOLUME_BOOST_FACTOR))
end)

-- Expose for cross-file access (keybind capture logic in task 4.2)
AVQueueHelper_Shared.settingsState = settingsState
AVQueueHelper_Shared.keybindButton = keybindButton

-- ============================================================
-- Slash Command: /avq
-- ============================================================

SLASH_AVQUEUEHELPER1 = "/avq"
SlashCmdList["AVQUEUEHELPER"] = function()
    if AVQueueHelperSettingsPanel:IsShown() then
        AVQueueHelperSettingsPanel:Hide()
    else
        AVQueueHelperSettingsPanel:Show()
    end
end
