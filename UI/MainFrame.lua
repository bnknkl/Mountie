-- Mountie: Main UI Frame.
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

    local unionRadio = CreateFrame("CheckButton", nil, settingsPanel, "UIRadioButtonTemplate")
    unionRadio:SetPoint("TOPLEFT", intersectionRadio, "BOTTOMLEFT", 0, -5)
    unionRadio.text = unionRadio:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    unionRadio.text:SetPoint("LEFT", unionRadio, "RIGHT", 5, 0)
    unionRadio.text:SetText("Use mounts from any matching pack")
    -- TODO: this could use a better description, "union" might be confusing to users

    -- Radio button behavior
    local function UpdateOverlapMode(mode)
        MountieDB.settings.packOverlapMode = mode
        priorityRadio:SetChecked(mode == "priority")
        intersectionRadio:SetChecked(mode == "intersection")
        unionRadio:SetChecked(mode == "union")
        
        -- Re-evaluate active packs
        C_Timer.After(0.1, Mountie.SelectActivePack)
    end

    priorityRadio:SetScript("OnClick", function() UpdateOverlapMode("priority") end)
    intersectionRadio:SetScript("OnClick", function() UpdateOverlapMode("intersection") end)
    unionRadio:SetScript("OnClick", function() UpdateOverlapMode("union") end)

    -- Flying preference (existing setting, moved here)
    local flyingCheck = CreateFrame("CheckButton", nil, settingsPanel, "UICheckButtonTemplate")
    flyingCheck:SetPoint("LEFT", unionRadio.text, "RIGHT", 40, 0)
    flyingCheck.text = flyingCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    flyingCheck.text:SetPoint("LEFT", flyingCheck, "RIGHT", 5, 0)
    flyingCheck.text:SetText("Prefer flying mounts")

    flyingCheck:SetScript("OnClick", function(self)
        MountieDB.settings.preferFlyingMounts = self:GetChecked()
    end)

    -- Verbose mode checkbox
    local verboseCheck = CreateFrame("CheckButton", nil, settingsPanel, "UICheckButtonTemplate")
    verboseCheck:SetPoint("LEFT", flyingCheck.text, "RIGHT", 40, 0)
    verboseCheck.text = verboseCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    verboseCheck.text:SetPoint("LEFT", verboseCheck, "RIGHT", 5, 0)
    verboseCheck.text:SetText("Show summon messages")

    verboseCheck:SetScript("OnClick", function(self)
        MountieDB.settings.verboseMode = self:GetChecked()
    end)

    -- Initialize settings
    settingsPanel:SetScript("OnShow", function()
        local overlapMode = MountieDB.settings.packOverlapMode or "priority"
        UpdateOverlapMode(overlapMode)
        flyingCheck:SetChecked(MountieDB.settings.preferFlyingMounts)
        verboseCheck:SetChecked(MountieDB.settings.verboseMode)
    end)

    return settingsPanel
end

-- Function to create or update the Mountie macro
local function EnsureMountieMacro()
    local macroName = "Mountie"
    local macroBody = "/mountie mount"
    local macroIcon = "Interface\\Icons\\Ability_Mount_RidingHorse"
    
    -- Check if macro already exists
    local macroIndex = GetMacroIndexByName(macroName)
    
    if macroIndex == 0 then
        -- Macro doesn't exist, try to create it
        local numAccountMacros, numCharacterMacros = GetNumMacros()
        
        -- Try account macros first (they're shared across characters)
        if numAccountMacros < MAX_ACCOUNT_MACROS then
            CreateMacro(macroName, macroIcon, macroBody, nil) -- nil = account macro
            Mountie.Debug("Created account macro: " .. macroName)
        elseif numCharacterMacros < MAX_CHARACTER_MACROS then
            CreateMacro(macroName, macroIcon, macroBody, 1) -- 1 = character-specific macro
            Mountie.Debug("Created character macro: " .. macroName)
        else
            Mountie.Print("Cannot create macro - macro slots full!")
            return false
        end
    else
        -- Macro exists, update it to make sure it has the right content
        EditMacro(macroIndex, macroName, macroIcon, macroBody)
        Mountie.Debug("Updated existing macro: " .. macroName)
    end
    
    return true
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

    -- Create instructional text for action bar macro
    local macroInstructions = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    macroInstructions:SetPoint("BOTTOM", settingsPanel, "BOTTOM", 0, -11) -- Below the settings panel
    macroInstructions:SetText("Create a macro with |cff00ff00/mountie mount|r and add it to your action bar!")
    macroInstructions:SetTextColor(0.8, 0.8, 0.8, 1)
    
    -- Add version number in bottom right corner
    local versionText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    versionText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 5)
    versionText:SetText("v" .. (Mountie.version or "0.6"))
    versionText:SetTextColor(0.6, 0.6, 0.6, 0.8)

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
    
    -- Mount counter (shows filtered results)
    local mountCounter = mountPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mountCounter:SetPoint("TOP", mountTitle, "BOTTOM", 0, -8)
    mountCounter:SetText("Loading...")
    mountCounter:SetTextColor(0.9, 0.9, 0.5, 1) -- Slightly yellow to make it more visible
    mountPanel.mountCounter = mountCounter

    -- Search box (left side) - moved down to make room for counter
    local searchBox = CreateFrame("EditBox", nil, mountPanel, "InputBoxTemplate")
    searchBox:SetSize(140, 20)
    searchBox:SetPoint("LEFT", mountPanel, "LEFT", 15, 16)
    searchBox:SetPoint("TOP", mountCounter, "BOTTOM", 0, -4)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(50)
    searchBox:SetText("Search...")
    searchBox:SetTextColor(0.6, 0.6, 0.6, 1)

    -- Filter dropdown (right side) - moved down to align with search box
    local filterDropdown = CreateFrame("Frame", nil, mountPanel, "UIDropDownMenuTemplate")
    filterDropdown:SetPoint("RIGHT", mountPanel, "RIGHT", -25, 20)
    filterDropdown:SetPoint("TOP", mountCounter, "BOTTOM", 0, 0)
    filterDropdown:SetSize(140, 20)

    -- Initialize filter state
    local currentFilters = {
        showUnowned = false,
        hideUnusable = true,
        flyingOnly = false,
        sourceFilter = "all"
    }

    local mountList = MountieUI.CreateMountList(mountPanel)
    mountPanel.mountList = mountList
    mountPanel.currentFilters = currentFilters
    
    -- Store references for backward compatibility
    mountPanel.filterCheck = {GetChecked = function() return currentFilters.showUnowned end}
    mountPanel.hideUnusableCheck = {GetChecked = function() return currentFilters.hideUnusable end}
    mountPanel.flyingOnlyCheck = {GetChecked = function() return currentFilters.flyingOnly end}

    -- Search box functionality
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
            currentFilters.searchText = self:GetText()
            MountieUI.UpdateMountList(mountList, currentFilters)
        end
    end)

    -- Filter dropdown initialization function
    local function InitializeFilterDropdown(self, level)
        if level == 1 then
            -- Show Mounts section title
            local info = UIDropDownMenu_CreateInfo()
            info.text = "Show Mounts"
            info.isTitle = true
            info.notCheckable = true
            info.func = nil
            UIDropDownMenu_AddButton(info, level)
            
            -- Show unowned toggle
            info = UIDropDownMenu_CreateInfo()
            info.text = "Show unowned mounts"
            info.checked = currentFilters.showUnowned
            info.keepShownOnClick = true
            info.isNotRadio = true
            info.func = function(self)
                currentFilters.showUnowned = not currentFilters.showUnowned
                MountieUI.UpdateMountList(mountList, currentFilters)
            end
            UIDropDownMenu_AddButton(info, level)
            
            -- Hide unusable toggle
            info = UIDropDownMenu_CreateInfo()
            info.text = "Hide unusable mounts"
            info.checked = currentFilters.hideUnusable
            info.keepShownOnClick = true
            info.isNotRadio = true
            info.func = function(self)
                currentFilters.hideUnusable = not currentFilters.hideUnusable
                MountieUI.UpdateMountList(mountList, currentFilters)
            end
            UIDropDownMenu_AddButton(info, level)
            
            -- Flying only toggle
            info = UIDropDownMenu_CreateInfo()
            info.text = "Flying mounts only"
            info.checked = currentFilters.flyingOnly
            info.keepShownOnClick = true
            info.isNotRadio = true
            info.func = function(self)
                currentFilters.flyingOnly = not currentFilters.flyingOnly
                MountieUI.UpdateMountList(mountList, currentFilters)
            end
            UIDropDownMenu_AddButton(info, level)
            
            -- Separator
            info = UIDropDownMenu_CreateInfo()
            info.text = ""
            info.isTitle = true
            info.notCheckable = true
            info.func = nil
            UIDropDownMenu_AddButton(info, level)
            
            -- Source filters title
            info = UIDropDownMenu_CreateInfo()
            info.text = "Filter by Source"
            info.isTitle = true
            info.notCheckable = true
            info.func = nil
            UIDropDownMenu_AddButton(info, level)
            
            -- Source filter options
            info = UIDropDownMenu_CreateInfo()
            info.text = "Favorites Only"
            info.checked = currentFilters.sourceFilter == "favorites"
            info.keepShownOnClick = true
            info.isNotRadio = true
            info.func = function(self)
                if currentFilters.sourceFilter == "favorites" then
                    currentFilters.sourceFilter = "all"  -- Turn off if already on
                else
                    currentFilters.sourceFilter = "favorites"  -- Turn on if off
                end
                MountieUI.UpdateMountList(mountList, currentFilters)
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end

    UIDropDownMenu_Initialize(filterDropdown, InitializeFilterDropdown)
    UIDropDownMenu_SetText(filterDropdown, "Filters")
    UIDropDownMenu_SetWidth(filterDropdown, 120)

    -- Right panel (packs) - adjusted to match mounts panel height
    local packPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    packPanel:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -20, -35)
    packPanel:SetSize(350, 420) -- Same height as mounts panel
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
        -- Initialize with current filters and update counter
        local currentFilters = frame.mountPanel.currentFilters
        currentFilters.searchText = ""
        MountieUI.UpdateMountList(frame.mountPanel.mountList, currentFilters)
        frame.packPanel.refreshPacks()
        
        -- Force counter update on first load
        C_Timer.After(0.1, function()
            if frame.mountPanel.mountCounter then
                MountieUI.UpdateMountList(frame.mountPanel.mountList, currentFilters)
            end
        end)
    end
end

Mountie.Debug("UI/MainFrame.lua loaded")