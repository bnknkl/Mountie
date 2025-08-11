-- Mountie: Mount List UI
Mountie.Debug("UI/MountList.lua loading...")

function MountieUI.CreateMountList(parent)
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -80)
    scrollFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -30, 10)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(320, 1)
    scrollFrame:SetScrollChild(content)

    scrollFrame.content = content
    scrollFrame.buttons = {}
    return scrollFrame
end

function MountieUI.CreateMountButton(parent, index)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(300, 40)
    button:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    button:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    button:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetMovable(true)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(32, 32)
    icon:SetPoint("LEFT", button, "LEFT", 4, 0)
    button.icon = icon

    local name = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    name:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    name:SetPoint("RIGHT", button, "RIGHT", -8, 0)
    name:SetJustifyH("LEFT")
    button.name = name

    button:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.2, 0.2, 0.2, 0.8)
        if self.mountData then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local spellID = self.mountData.spellID
            if spellID then
                GameTooltip:SetMountBySpellID(spellID)
            else
                GameTooltip:SetText(self.mountData.name or "Unknown Mount")
            end
            GameTooltip:Show()
        end
    end)
    button:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        GameTooltip:Hide()
    end)

    button:SetScript("OnDragStart", function(self)
        if self.mountData and self.mountData.isCollected then
            local dragFrame = CreateFrame("Frame", nil, UIParent)
            dragFrame:SetSize(200, 30)
            dragFrame:SetFrameStrata("TOOLTIP")
            dragFrame:SetAlpha(0.8)

            local dragIcon = dragFrame:CreateTexture(nil, "ARTWORK")
            dragIcon:SetSize(24, 24)
            dragIcon:SetPoint("LEFT", dragFrame, "LEFT", 0, 0)
            dragIcon:SetTexture(self.mountData.icon)

            local dragText = dragFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            dragText:SetPoint("LEFT", dragIcon, "RIGHT", 4, 0)
            dragText:SetText(self.mountData.name)
            dragText:SetTextColor(1, 1, 1, 1)

            dragFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", GetCursorPosition() / UIParent:GetEffectiveScale())

            self.dragFrame = dragFrame
            self.isDragging = true

            local function UpdateDragPosition()
                if self.isDragging then
                    local x, y = GetCursorPosition()
                    local scale = UIParent:GetEffectiveScale()
                    dragFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
                    C_Timer.After(0.01, UpdateDragPosition)
                end
            end
            UpdateDragPosition()
        end
    end)

    button:SetScript("OnDragStop", function(self)
        if self.isDragging then
            self.isDragging = false
            if self.dragFrame then
                self.dragFrame:Hide()
                self.dragFrame = nil
            end
            local packFrame = MountieUI.GetPackFrameUnderCursor()
            if packFrame and packFrame.pack then
                local success, message = Mountie.AddMountToPack(packFrame.pack.name, self.mountData.id)
                Mountie.Print(message)
                if success then
                    if _G.MountieMainFrame and _G.MountieMainFrame.packPanel and _G.MountieMainFrame.packPanel.refreshPacks then
                        _G.MountieMainFrame.packPanel.refreshPacks()
                    end
                end
            end
        end
    end)

    button:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "LeftButton" then
            if self.mountData then
                Mountie.Debug("Left-clicked: " .. self.mountData.name)
            end
        elseif mouseButton == "RightButton" then
            if self.mountData and self.mountData.isCollected then
                MountieUI.ShowMountContextMenu(self.mountData, self)
            end
        end
    end)

    return button
end

function MountieUI.UpdateMountList(scrollFrame, showUnowned, searchText, sourceFilter)
    local content = scrollFrame.content
    local buttons = scrollFrame.buttons

    searchText = searchText or ""
    sourceFilter = sourceFilter or "all"

    local mounts = {}
    if showUnowned then
        local allMountIDs = C_MountJournal.GetMountIDs()
        for _, mountID in ipairs(allMountIDs) do
            local name, spellID, icon, active, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected =
                C_MountJournal.GetMountInfoByID(mountID)
            if name then
                table.insert(mounts, {
                    id = mountID, name = name, icon = icon, spellID = spellID,
                    isCollected = isCollected, isUsable = isUsable,
                    sourceType = sourceType, isFavorite = isFavorite,
                })
            end
        end
    else
        mounts = Mountie.GetOwnedMounts()
        for _, mount in ipairs(mounts) do
            local _, spellID, _, _, _, sourceType, isFavorite =
                C_MountJournal.GetMountInfoByID(mount.id)
            mount.spellID = spellID
            mount.isCollected = true
            mount.sourceType = sourceType
            mount.isFavorite = isFavorite
        end
    end

    if searchText ~= "" then
        local filtered = {}
        local searchLower = string.lower(searchText)
        for _, m in ipairs(mounts) do
            if string.find(string.lower(m.name), searchLower) then
                table.insert(filtered, m)
            end
        end
        mounts = filtered
    end

    if sourceFilter ~= "all" then
        local filtered = {}
        for _, m in ipairs(mounts) do
            local include = false
            if sourceFilter == "favorites" then
                include = m.isFavorite
            elseif sourceFilter == "drop" then
                include = m.sourceType == Enum.MountSourceType.Drop
            elseif sourceFilter == "vendor" then
                include = m.sourceType == Enum.MountSourceType.Vendor
            end
            if include then table.insert(filtered, m) end
        end
        mounts = filtered
    end

    table.sort(mounts, function(a, b) return a.name < b.name end)

    for i, mountData in ipairs(mounts) do
        local button = buttons[i]
        if not button then
            button = MountieUI.CreateMountButton(content, i)
            button:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i-1) * 45)
            buttons[i] = button
        end
        button.mountData = mountData
        button.icon:SetTexture(mountData.icon)
        button.name:SetText(mountData.name)
        if mountData.isCollected then
            button.name:SetTextColor(1, 1, 1, 1)
        else
            button.name:SetTextColor(0.6, 0.6, 0.6, 1)
        end
        button:Show()
    end

    for i = #mounts + 1, #buttons do
        buttons[i]:Hide()
    end

    local contentHeight = math.max(#mounts * 45, 1)
    content:SetHeight(contentHeight)
end

-- Mount Context Menu
function MountieUI.CreateMountContextMenu()
    local menu = CreateFrame("Frame", "MountieMountContextMenu", UIParent, "BackdropTemplate")
    menu:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    menu:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    menu:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetFrameLevel(1000)
    menu:EnableMouse(true)

    local closeButton = CreateFrame("Button", nil, menu)
    closeButton:SetSize(16, 16)
    closeButton:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -5, -5)
    closeButton:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    closeButton:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
    closeButton:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
    closeButton:SetScript("OnClick", function() menu:Hide() end)

    local title = menu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", menu, "TOP", 0, -10)
    title:SetText("Add to Pack")
    title:SetTextColor(1, 1, 0.8, 1)

    menu.title = title
    menu.closeButton = closeButton
    menu.packButtons = {}
    menu.targetMount = nil

    menu:SetScript("OnShow", function(self)
        local hideFrame = CreateFrame("Frame", nil, UIParent)
        hideFrame:SetAllPoints(UIParent)
        hideFrame:SetFrameStrata("BACKGROUND")
        hideFrame:EnableMouse(true)
        hideFrame:SetScript("OnMouseDown", function()
            self:Hide()
            hideFrame:Hide()
        end)
        self:HookScript("OnHide", function()
            if hideFrame then hideFrame:Hide() end
        end)
    end)

    menu:Hide()
    return menu
end

function MountieUI.UpdateMountContextMenu(menu, mountData)
    local packs = Mountie.ListPacks()
    local packButtons = menu.packButtons

    for _, b in ipairs(packButtons) do
        b:Hide()
        b:SetParent(nil)
    end
    packButtons = {}
    menu.packButtons = packButtons

    if #packs == 0 then
        menu:SetSize(160, 60)
        local noPacks = menu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        noPacks:SetPoint("CENTER", menu, "CENTER", 0, -10)
        noPacks:SetText("No packs created yet")
        noPacks:SetTextColor(0.6, 0.6, 0.6, 1)
        return
    end

    local buttonHeight = 22
    local buttonWidth = 140
    local padding = 8
    local titleHeight = 25
    local maxPacks = 8
    local visiblePacks = math.min(#packs, maxPacks)

    local menuWidth = buttonWidth + (padding * 2)
    local menuHeight = titleHeight + (visiblePacks * buttonHeight) + padding
    menu:SetSize(menuWidth, menuHeight)

    for i = 1, visiblePacks do
        local pack = packs[i]
        local button = CreateFrame("Button", nil, menu, "BackdropTemplate")
        button:SetSize(buttonWidth, buttonHeight - 2)
        button:SetPoint("TOP", menu.title, "BOTTOM", 0, -5 - ((i-1) * buttonHeight))

        button:SetBackdrop({
            bgFile = "Interface\\Buttons\\UI-Panel-Button-Up",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        button:SetBackdropColor(0.2, 0.2, 0.2, 1)
        button:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

        local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("CENTER", button, "CENTER", 0, 0)
        text:SetJustifyH("CENTER")

        local isInPack = false
        for _, mountID in ipairs(pack.mounts) do
            if mountID == mountData.id then isInPack = true; break end
        end

        if isInPack then
            text:SetText(pack.name .. " ✓")
            text:SetTextColor(0.8, 1, 0.8, 1)
            button:SetBackdropColor(0.1, 0.3, 0.1, 1)
            button:SetAlpha(0.8)
        else
            text:SetText(pack.name)
            text:SetTextColor(1, 1, 1, 1)
            button:SetBackdropColor(0.2, 0.2, 0.2, 1)
            button:SetAlpha(1.0)
        end

        button:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.3, 0.3, 0.3, 1)
        end)
        button:SetScript("OnLeave", function(self)
            if isInPack then
                self:SetBackdropColor(0.1, 0.3, 0.1, 1)
            else
                self:SetBackdropColor(0.2, 0.2, 0.2, 1)
            end
        end)
        button:SetScript("OnClick", function()
            if not isInPack then
                local success, message = Mountie.AddMountToPack(pack.name, mountData.id)
                Mountie.Print(message)
                if success then
                    menu:Hide()
                    if _G.MountieMainFrame and _G.MountieMainFrame.packPanel and _G.MountieMainFrame.packPanel.refreshPacks then
                        _G.MountieMainFrame.packPanel.refreshPacks()
                    end
                end
            else
                Mountie.Print("Mount is already in pack '" .. pack.name .. "'")
                menu:Hide()
            end
        end)

        packButtons[i] = button
    end

    if #packs > maxPacks then
        local moreText = menu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        moreText:SetPoint("BOTTOM", menu, "BOTTOM", 0, 5)
        moreText:SetText("... and " .. (#packs - maxPacks) .. " more")
        moreText:SetTextColor(0.6, 0.6, 0.6, 1)
    end
end

local mountContextMenu = nil
function MountieUI.ShowMountContextMenu(mountData, parentFrame)
    if not mountContextMenu then
        mountContextMenu = MountieUI.CreateMountContextMenu()
    end
    mountContextMenu.targetMount = mountData
    MountieUI.UpdateMountContextMenu(mountContextMenu, mountData)
    mountContextMenu:ClearAllPoints()
    mountContextMenu:SetPoint("LEFT", parentFrame, "RIGHT", 5, 0)
    mountContextMenu:Show()
end

function MountieUI.GetPackFrameUnderCursor()
    if not _G.MountieMainFrame or not _G.MountieMainFrame.packPanel or not _G.MountieMainFrame.packPanel.packList then
        return nil
    end
    local packFrames = _G.MountieMainFrame.packPanel.packList.packFrames
    for _, frame in ipairs(packFrames) do
        if frame:IsVisible() and frame:IsMouseOver() then
            return frame
        end
    end
    return nil
end

Mountie.Debug("UI/MountList.lua loaded")
