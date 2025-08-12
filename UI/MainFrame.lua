-- Mountie: Main UI Frame
Mountie.Debug("UI/MainFrame.lua loading...")

local mainFrame = nil

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

    -- Left panel (mounts)
    local mountPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    mountPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -35)
    mountPanel:SetSize(350, 520)
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

    local packPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    packPanel:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -20, -35)
    packPanel:SetSize(350, 520)
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
