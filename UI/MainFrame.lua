-- Mountie: Main UI Frame
Mountie.Debug("UI/MainFrame.lua loading...")

local mainFrame = nil

function MountieUI.CreateSettingsPanel(parent)
    local settingsPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    settingsPanel:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 20, 20)
    settingsPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -20, 20)
    settingsPanel:SetHeight(120)
    settingsPanel:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    settingsPanel:SetBackdropColor(0, 0, 0, 0.3)
    settingsPanel:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    local settingsTitle = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    settingsTitle:SetPoint("TOPLEFT", settingsPanel, "TOPLEFT", 10, -10)
    settingsTitle:SetText("Settings")

    -- Pack Overlap Mode
    local overlapLabel = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    overlapLabel:SetPoint("TOPLEFT", settingsTitle, "BOTTOMLEFT", 0, -10)
    overlapLabel:SetText("When multiple packs match:")

    local priorityRadio = CreateFrame("CheckButton", nil, settingsPanel, "UIRadioButtonTemplate")
    priorityRadio:SetPoint("TOPLEFT", overlapLabel, "BOTTOMLEFT", 0, -5)
    priorityRadio.text = priorityRadio:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    priorityRadio.text:SetPoint("LEFT", priorityRadio, "RIGHT", 5, 0)
    priorityRadio.text:SetText("Use highest priority pack only")

    local intersectionRadio = CreateFrame("CheckButton", nil, settingsPanel, "UIRadioButtonTemplate")
    intersectionRadio:SetPoint("TOPLEFT", priorityRadio, "BOTTOMLEFT", 0, -5)
    intersectionRadio.text = intersectionRadio:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    intersectionRadio.text:SetPoint("LEFT", intersectionRadio, "RIGHT", 5, 0)
    intersectionRadio.text:SetText("Use mounts common to all matching packs")

    -- Radio button behavior
    local function UpdateOverlapMode(mode)
        MountieDB.settings.packOverlapMode = mode
        priorityRadio:SetChecked(mode == "priority")
        intersectionRadio:SetChecked(mode == "intersection")
        
        -- Re-evaluate active packs
        C_Timer.After(0.1, Mountie.SelectActivePack)
    end

    priorityRadio:SetScript("OnClick", function() UpdateOverlapMode("priority") end)
    intersectionRadio:SetScript("OnClick", function() UpdateOverlapMode("intersection") end)

    -- Flying preference (existing setting, moved here)
    local flyingCheck = CreateFrame("CheckButton", nil, settingsPanel, "UICheckButtonTemplate")
    flyingCheck:SetPoint("LEFT", intersectionRadio.text, "RIGHT", 40, 0)
    flyingCheck.text = flyingCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    flyingCheck.text:SetPoint("LEFT", flyingCheck, "RIGHT", 5, 0)
    flyingCheck.text:SetText("Prefer flying mounts")

    flyingCheck:SetScript("OnClick", function(self)
        MountieDB.settings.preferFlyingMounts = self:GetChecked()
    end)

    -- Initialize settings
    settingsPanel:SetScript("OnShow", function()
        local overlapMode = MountieDB.settings.packOverlapMode or "priority"
        UpdateOverlapMode(overlapMode)
        flyingCheck:SetChecked(MountieDB.settings.preferFlyingMounts)
    end)

    return settingsPanel
end

function MountieUI.CreateMainFrame()
    if mainFrame then
        return mainFrame
    end

    local frame = CreateFrame("Frame", "MountieMainFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(800, 600)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    frame.TitleText:SetText("Mountie")

    frame.CloseButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    -- Create settings panel first
    local settingsPanel = MountieUI.CreateSettingsPanel(frame)
    frame.settingsPanel = settingsPanel

    -- Left panel (mounts)
    local mountPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    mountPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -35)
    mountPanel:SetSize(350, 420) -- Reduced height to make room for settings
    mountPanel:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    mountPanel:SetBackdropColor(0, 0, 0, 0.3)
    mountPanel:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    local mountTitle = mountPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    mountTitle:SetPoint("TOP", mountPanel, "TOP", 0, -15)
    mountTitle:SetText("Your Mounts")

    local filterCheck = CreateFrame("CheckButton", nil, mountPanel, "UICheckButtonTemplate")
    filterCheck:SetPoint("TOPRIGHT", mountPanel, "TOPRIGHT", -10, -15)
    filterCheck:SetSize(20, 20)
    filterCheck.text = filterCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    filterCheck.text:SetPoint("RIGHT", filterCheck, "LEFT", -5, 0)
    filterCheck.text:SetText("Show unowned")

    local searchBox = CreateFrame("EditBox", nil, mountPanel, "InputBoxTemplate")
    searchBox:SetSize(140, 20)
    searchBox:SetPoint("LEFT", mountPanel, "LEFT", 15, 0)
    searchBox:SetPoint("TOP", mountTitle, "BOTTOM", 0, -10)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(50)
    searchBox:SetText("Search...")
    searchBox:SetTextColor(0.6, 0.6, 0.6, 1)

    local filterDropdown = CreateFrame("Frame", nil, mountPanel, "UIDropDownMenuTemplate")
    filterDropdown:SetPoint("RIGHT", mountPanel, "RIGHT", -25, 0)
    filterDropdown:SetPoint("TOP", mountTitle, "BOTTOM", 0, -5)
    filterDropdown:SetSize(120, 20)

    local mountList = MountieUI.CreateMountList(mountPanel)
    -- Store references so ToggleMainFrame can populate immediately
    mountPanel.mountList   = mountList
    mountPanel.filterCheck = filterCheck

    searchBox:SetScript("OnEditFocusGained", function(self)
        if self:GetText() == "Search..." then
            self:SetText("")
            self:SetTextColor(1, 1, 1, 1)
        end
    end)
    searchBox:SetScript("OnEditFocusLost", function(self)
        if self:GetText() == "" then
            self:SetText("Search...")
            self:SetTextColor(0.6, 0.6, 0.6, 1)
        end
    end)

    searchBox:SetScript("OnTextChanged", function(self)
        if self:GetText() ~= "Search..." then
            local showUnowned = filterCheck:GetChecked()
            local sourceFilter = UIDropDownMenu_GetSelectedValue(filterDropdown) or "all"
            MountieUI.UpdateMountList(mountList, showUnowned, self:GetText(), sourceFilter)
        end
    end)

    local function InitializeDropdown(self, level)
        local info = UIDropDownMenu_CreateInfo()
        if level == 1 then
            info.text = "All Sources"
            info.value = "all"
            info.func = function()
                UIDropDownMenu_SetSelectedValue(filterDropdown, "all")
                local showUnowned = filterCheck:GetChecked()
                local searchText = (searchBox:GetText() == "Search...") and "" or searchBox:GetText()
                MountieUI.UpdateMountList(mountList, showUnowned, searchText, "all")
            end
            info.checked = UIDropDownMenu_GetSelectedValue(filterDropdown) == "all"
            UIDropDownMenu_AddButton(info)

            info.text = "Favorites Only"
            info.value = "favorites"
            info.func = function()
                UIDropDownMenu_SetSelectedValue(filterDropdown, "favorites")
                local showUnowned = filterCheck:GetChecked()
                local searchText = (searchBox:GetText() == "Search...") and "" or searchBox:GetText()
                MountieUI.UpdateMountList(mountList, showUnowned, searchText, "favorites")
            end
            info.checked = UIDropDownMenu_GetSelectedValue(filterDropdown) == "favorites"
            UIDropDownMenu_AddButton(info)

            info.text = "Drops"
            info.value = "drop"
            info.func = function()
                UIDropDownMenu_SetSelectedValue(filterDropdown, "drop")
                local showUnowned = filterCheck:GetChecked()
                local searchText = (searchBox:GetText() == "Search...") and "" or searchBox:GetText()
                MountieUI.UpdateMountList(mountList, showUnowned, searchText, "drop")
            end
            info.checked = UIDropDownMenu_GetSelectedValue(filterDropdown) == "drop"
            UIDropDownMenu_AddButton(info)

            info.text = "Vendor"
            info.value = "vendor"
            info.func = function()
                UIDropDownMenu_SetSelectedValue(filterDropdown, "vendor")
                local showUnowned = filterCheck:GetChecked()
                local searchText = (searchBox:GetText() == "Search...") and "" or searchBox:GetText()
                MountieUI.UpdateMountList(mountList, showUnowned, searchText, "vendor")
            end
            info.checked = UIDropDownMenu_GetSelectedValue(filterDropdown) == "vendor"
            UIDropDownMenu_AddButton(info)
        end
    end

    UIDropDownMenu_Initialize(filterDropdown, InitializeDropdown)
    UIDropDownMenu_SetSelectedValue(filterDropdown, "all")
    UIDropDownMenu_SetText(filterDropdown, "All Sources")
    UIDropDownMenu_SetWidth(filterDropdown, 80)

    filterCheck:SetScript("OnClick", function(self)
        local showUnowned = self:GetChecked()
        local searchText = (searchBox:GetText() == "Search...") and "" or searchBox:GetText()
        local sourceFilter = UIDropDownMenu_GetSelectedValue(filterDropdown) or "all"
        MountieUI.UpdateMountList(mountList, showUnowned, searchText, sourceFilter)
    end)

    -- Right panel (packs) - adjusted to connect to settings panel
    local packPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    packPanel:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -20, -35)
    packPanel:SetPoint("BOTTOMRIGHT", settingsPanel, "TOPRIGHT", 0, -10) -- Connect to settings panel
    packPanel:SetSize(350, 0) -- Height will be calculated from points
    packPanel:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    packPanel:SetBackdropColor(0, 0, 0, 0.3)
    packPanel:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    MountieUI.SetupPackPanel(packPanel)

    frame.mountPanel = mountPanel
    frame.packPanel  = packPanel

    frame:Hide()
    table.insert(UISpecialFrames, "MountieMainFrame")

    mainFrame = frame
    return frame
end

function MountieUI.ToggleMainFrame()
    local frame = MountieUI.CreateMainFrame()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        local showUnowned = frame.mountPanel.filterCheck:GetChecked()
        MountieUI.UpdateMountList(frame.mountPanel.mountList, showUnowned, "", "all")
        frame.packPanel.refreshPacks()
    end
end

Mountie.Debug("UI/MainFrame.lua loaded")