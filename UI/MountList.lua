-- Mountie: Mount List UI
Mountie.Debug("UI/MountList.lua loading...")

-- Helper function to check if a mount is flying using mount type IDs
local function IsFlyingMount(mountID)
    -- Get mount type ID from the API
    local creatureDisplayInfoID, description, source, isSelfMount, mountTypeID, uiModelSceneID, animID, spellVisualKitID, disablePlayerMountPreview = C_MountJournal.GetMountInfoExtraByID(mountID)
    
    if not mountTypeID then
        -- If we can't get mountTypeID, we can't reliably determine if it's flying
        return false
    end
    
    -- Debug: Log mount type IDs to help discover the patterns
    if MountieDB and MountieDB.settings and MountieDB.settings.debugMode then
        local name = C_MountJournal.GetMountInfoByID(mountID)
        Mountie.Debug("Mount: " .. (name or "Unknown") .. " | Type ID: " .. mountTypeID)
    end
    
    -- Known flying mount type IDs based on actual data analysis
    local flyingTypeIDs = {
        402, -- Modern drakes (Highland Drake, Winding Slitherdrake, Renewed Proto-Drake, etc.)
        424, -- Classic flying mounts (Golden Gryphon, Ebon Gryphon, most traditional flying mounts)
        436, -- Swimming/flying hybrid mounts (Depthstalker, Wondrous Wavewhisker, etc.)
        437, -- Flying discs and clouds (Red Flying Cloud, Golden Discus, Mogu Hazeblazer)
        444  -- Special ground mounts (Charming Courier)
    }
    
    -- Ground mount type IDs (for reference, these should NOT be flying)
    -- 230: Regular ground mounts (horses, wolves, bears, raptors, etc.)
    -- 241: Qiraji Battle Tanks
    -- 254: Special ground mounts (Crimson Tidestallion)
    -- 284: Chauffeured vehicles
    -- 444: Special ground mounts (Charming Courier)
    
    -- Check if this mount's type ID is in our flying list
    for _, flyingType in ipairs(flyingTypeIDs) do
        if mountTypeID == flyingType then
            return true
        end
    end
    
    return false
end

function MountieUI.CreateMountList(parent)
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -75)
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
            -- Show enhanced tooltip with 3D model
            MountieUI.ShowMountTooltipWithModel(self, self.mountData)
        end
    end)
    button:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        MountieUI.HideMountTooltip()
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
                Mountie.VerbosePrint(message)
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
                -- Debug mount data for filtering issues
                if MountieDB and MountieDB.settings and MountieDB.settings.debugMode then
                    local m = self.mountData
                    Mountie.Debug("  Mount ID: " .. (m.id or "nil"))
                    Mountie.Debug("  isUsable: " .. tostring(m.isUsable))
                    Mountie.Debug("  isCollected: " .. tostring(m.isCollected))
                    Mountie.Debug("  isFactionSpecific: " .. tostring(m.isFactionSpecific))
                    Mountie.Debug("  faction: " .. tostring(m.faction))
                    Mountie.Debug("  sourceType: " .. tostring(m.sourceType))
                    
                    -- Check what the game APIs return directly
                    local name, spellID, icon, active, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected =
                        C_MountJournal.GetMountInfoByID(m.id)
                    Mountie.Debug("  API isUsable: " .. tostring(isUsable))
                    Mountie.Debug("  API isFactionSpecific: " .. tostring(isFactionSpecific))
                    Mountie.Debug("  API faction: " .. tostring(faction))
                    
                    local playerFaction = UnitFactionGroup("player")
                    Mountie.Debug("  Player faction: " .. tostring(playerFaction))
                end
            end
        elseif mouseButton == "RightButton" then
            if self.mountData and self.mountData.isCollected then
                MountieUI.ShowMountContextMenu(self.mountData, self)
            end
        end
    end)

    return button
end

function MountieUI.UpdateMountList(scrollFrame, showUnowned, searchText, sourceFilter, hideUnusable, flyingOnly)
    local content = scrollFrame.content
    local buttons = scrollFrame.buttons

    -- Handle both old and new calling conventions
    local filters
    if type(showUnowned) == "table" then
        -- New calling convention: UpdateMountList(scrollFrame, filtersObject)
        filters = showUnowned
    else
        -- Old calling convention: UpdateMountList(scrollFrame, showUnowned, searchText, sourceFilter, hideUnusable, flyingOnly)
        filters = {
            showUnowned = showUnowned or false,
            searchText = searchText or "",
            sourceFilter = sourceFilter or "all",
            hideUnusable = hideUnusable == nil and true or hideUnusable,
            flyingOnly = flyingOnly or false
        }
    end

    -- Parse filters from the structure
    showUnowned = filters.showUnowned or false
    searchText = filters.searchText or ""
    sourceFilter = filters.sourceFilter or "all"
    hideUnusable = filters.hideUnusable == nil and true or filters.hideUnusable
    flyingOnly = filters.flyingOnly or false

    -- Debug filter values
    if MountieDB and MountieDB.settings and MountieDB.settings.debugMode then
        Mountie.Debug("UpdateMountList called with filters:")
        Mountie.Debug("  showUnowned: " .. tostring(showUnowned))
        Mountie.Debug("  searchText: '" .. searchText .. "'")
        Mountie.Debug("  sourceFilter: " .. sourceFilter)
        Mountie.Debug("  hideUnusable: " .. tostring(hideUnusable))
        Mountie.Debug("  flyingOnly: " .. tostring(flyingOnly))
    end

    -- Get player info for unusable filtering
    local playerClass = select(2, UnitClass("player"))
    local playerFaction = UnitFactionGroup("player")

    if MountieDB and MountieDB.settings and MountieDB.settings.debugMode then
        Mountie.Debug("Player info - Class: " .. tostring(playerClass) .. ", Faction: " .. tostring(playerFaction))
    end

    local mounts = {}
    if showUnowned then
        if MountieDB and MountieDB.settings and MountieDB.settings.debugMode then
            Mountie.Debug("Getting all mounts (including unowned)")
        end
        local allMountIDs = C_MountJournal.GetMountIDs()
        for _, mountID in ipairs(allMountIDs) do
            local name, spellID, icon, active, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected =
                C_MountJournal.GetMountInfoByID(mountID)
            if name then
                table.insert(mounts, {
                    id = mountID, name = name, icon = icon, spellID = spellID,
                    isCollected = isCollected, isUsable = isUsable,
                    sourceType = sourceType, isFavorite = isFavorite,
                    isFactionSpecific = isFactionSpecific, faction = faction
                })
            end
        end
    else
        if MountieDB and MountieDB.settings and MountieDB.settings.debugMode then
            Mountie.Debug("Getting owned mounts only")
        end
        mounts = Mountie.GetOwnedMounts()
        for _, mount in ipairs(mounts) do
            local _, spellID, _, _, _, sourceType, isFavorite, isFactionSpecific, faction =
                C_MountJournal.GetMountInfoByID(mount.id)
            mount.spellID = spellID
            mount.isCollected = true
            mount.sourceType = sourceType
            mount.isFavorite = isFavorite
            mount.isFactionSpecific = isFactionSpecific
            mount.faction = faction
        end
    end

    if MountieDB and MountieDB.settings and MountieDB.settings.debugMode then
        Mountie.Debug("Initial mount count: " .. #mounts)
        Mountie.Debug("About to start filtering - hideUnusable: " .. tostring(hideUnusable))
        Mountie.Debug("hideUnusable type: " .. type(hideUnusable))
        Mountie.Debug("hideUnusable == true: " .. tostring(hideUnusable == true))
        Mountie.Debug("About to check hideUnusable condition...")
    end

    -- Apply hideUnusable filter
    if hideUnusable then
        if MountieDB and MountieDB.settings and MountieDB.settings.debugMode then
            Mountie.Debug("SUCCESS: Inside hideUnusable filter block!")
            Mountie.Debug("Testing basic filter...")
        end
        
        local filtered = {}
        for i, m in ipairs(mounts) do
            if m.isUsable then
                table.insert(filtered, m)
            end
        end
        mounts = filtered
        
        if MountieDB and MountieDB.settings and MountieDB.settings.debugMode then
            Mountie.Debug("Basic filter complete: " .. #mounts .. " usable mounts remaining")
        end
    end

    -- Apply flying only filter
    if flyingOnly then
        local filtered = {}
        for _, m in ipairs(mounts) do
            if IsFlyingMount(m.id) then
                table.insert(filtered, m)
            end
        end
        mounts = filtered
    end

    -- Apply search filter
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

    -- Apply source filter
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
    
    -- Update the mount counter if it exists
    local mainFrame = _G.MountieMainFrame
    if mainFrame and mainFrame.mountPanel and mainFrame.mountPanel.mountCounter then
        local counter = mainFrame.mountPanel.mountCounter
        local filterText = ""
        
        -- Add filter description
        if flyingOnly then
            filterText = " flying"
        end
        if not showUnowned then
            filterText = filterText .. " owned"
        end
        if hideUnusable then
            filterText = filterText .. " usable"
        end
        if searchText ~= "" then
            filterText = filterText .. " matching '" .. searchText .. "'"
        end
        if sourceFilter ~= "all" then
            if sourceFilter == "favorites" then
                filterText = filterText .. " favorite"
            end
        end
        
        counter:SetText(#mounts .. filterText .. " mount" .. (#mounts == 1 and "" or "s"))
    end
end

-- Debug function to help discover mount type IDs - call this from console
function MountieUI.DebugMountTypes()
    if not MountieDB.settings.debugMode then
        Mountie.Print("Enable debug mode first with: /mountie debug-on")
        return
    end
    
    Mountie.Print("Scanning mount type IDs... check console for output")
    
    local typeStats = {}
    local allMountIDs = C_MountJournal.GetMountIDs()
    
    for _, mountID in ipairs(allMountIDs) do
        local name, spellID, icon, active, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected = C_MountJournal.GetMountInfoByID(mountID)
        
        if isCollected and name then
            local creatureDisplayInfoID, description, source, isSelfMount, mountTypeID = C_MountJournal.GetMountInfoExtraByID(mountID)
            
            if mountTypeID then
                if not typeStats[mountTypeID] then
                    typeStats[mountTypeID] = {}
                end
                table.insert(typeStats[mountTypeID], name)
            end
        end
    end
    
    -- Print the results
    local sortedTypes = {}
    for typeID, _ in pairs(typeStats) do
        table.insert(sortedTypes, typeID)
    end
    table.sort(sortedTypes)
    
    Mountie.Print("=== Mount Type ID Analysis ===")
    for _, typeID in ipairs(sortedTypes) do
        local mounts = typeStats[typeID]
        Mountie.Print("Type " .. typeID .. " (" .. #mounts .. " mounts):")
        for i = 1, math.min(3, #mounts) do  -- Show first 3 examples
            Mountie.Print("  - " .. mounts[i])
        end
        if #mounts > 3 then
            Mountie.Print("  ... and " .. (#mounts - 3) .. " more")
        end
    end
    Mountie.Print("=== End Analysis ===")
end

-- Debug function to analyze faction filtering issues
function MountieUI.DebugFactionMounts()
    if not MountieDB.settings.debugMode then
        Mountie.Print("Enable debug mode first with: /mountie debug-on")
        return
    end
    
    Mountie.Print("Analyzing faction-specific mounts...")
    
    local playerFaction = UnitFactionGroup("player")
    local allMountIDs = C_MountJournal.GetMountIDs()
    local factionMounts = {}
    
    for _, mountID in ipairs(allMountIDs) do
        local name, spellID, icon, active, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected = C_MountJournal.GetMountInfoByID(mountID)
        
        if isCollected and name and isFactionSpecific then
            table.insert(factionMounts, {
                name = name,
                faction = faction,
                isUsable = isUsable,
                mountID = mountID
            })
        end
    end
    
    Mountie.Print("=== Faction Mount Analysis ===")
    Mountie.Print("Player faction: " .. tostring(playerFaction))
    Mountie.Print("Found " .. #factionMounts .. " faction-specific mounts:")
    
    for _, mount in ipairs(factionMounts) do
        local factionName = "Unknown"
        if mount.faction == 0 then factionName = "Horde"
        elseif mount.faction == 1 then factionName = "Alliance"
        end
        
        local shouldBeUsable = (mount.faction == 1 and playerFaction == "Alliance") or (mount.faction == 0 and playerFaction == "Horde")
        local status = ""
        if mount.isUsable ~= shouldBeUsable then
            status = " [MISMATCH!]"
        end
        
        Mountie.Print("  " .. mount.name .. " - " .. factionName .. " (API usable: " .. tostring(mount.isUsable) .. ")" .. status)
    end
    Mountie.Print("=== End Analysis ===")
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
                Mountie.VerbosePrint(message)
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

-- Mount Model Flyout Functions
local mountModelFlyout = nil
local mountDebugFlyout = nil

function MountieUI.CreateMountModelFlyout()
    if mountModelFlyout then
        return mountModelFlyout
    end
    
    -- Create the flyout frame
    local flyout = CreateFrame("Frame", "MountieMountModelFlyout", UIParent, "BackdropTemplate")
    flyout:SetSize(200, 250)
    flyout:SetFrameStrata("DIALOG")
    flyout:SetFrameLevel(1000)
    
    -- Set backdrop
    flyout:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    flyout:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    flyout:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    
    -- Create model viewer using PlayerModel which supports creature display
    local modelFrame = CreateFrame("PlayerModel", nil, flyout)
    modelFrame:SetSize(180, 180)
    modelFrame:SetPoint("CENTER", flyout, "CENTER", 0, 10)
    
    
    -- Create mount name label
    local nameLabel = flyout:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    nameLabel:SetPoint("BOTTOM", flyout, "BOTTOM", 0, -10)
    nameLabel:SetTextColor(1, 1, 0.8, 1)
    nameLabel:SetJustifyH("CENTER")
    nameLabel:SetWordWrap(true)
    nameLabel:SetWidth(180)
    
    flyout.modelFrame = modelFrame
    flyout.nameLabel = nameLabel
    flyout.rotationTimer = nil
    flyout.isMouseOver = false
    flyout:Hide()
    
    -- Add mouse tracking for persistence
    flyout:EnableMouse(true)
    flyout:SetScript("OnEnter", function(self)
        self.isMouseOver = true
        -- Cancel any pending hide timers from the flyouts
        if self.hideTimer then
            self.hideTimer:Cancel()
            self.hideTimer = nil
        end
    end)
    flyout:SetScript("OnLeave", function(self)
        self.isMouseOver = false
        -- Hide if not moving to debug flyout
        self.hideTimer = C_Timer.After(0.1, function()
            self.hideTimer = nil
            if not self.isMouseOver and (not mountDebugFlyout or not mountDebugFlyout.isMouseOver) then
                MountieUI.HideMountModelFlyout()
            end
        end)
    end)
    
    mountModelFlyout = flyout
    return flyout
end

function MountieUI.CreateMountDebugFlyout()
    if mountDebugFlyout then
        return mountDebugFlyout
    end
    
    -- Create the debug flyout frame
    local flyout = CreateFrame("Frame", "MountieMountDebugFlyout", UIParent, "BackdropTemplate")
    flyout:SetSize(250, 200)
    flyout:SetFrameStrata("DIALOG")
    flyout:SetFrameLevel(1001) -- Higher than model flyout
    
    -- Set backdrop
    flyout:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    flyout:SetBackdropColor(0.1, 0.05, 0.05, 0.95) -- Slightly reddish for debug
    flyout:SetBackdropBorderColor(0.8, 0.3, 0.3, 1) -- Red border for debug
    
    -- Create title
    local title = flyout:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", flyout, "TOP", 0, -8)
    title:SetText("Debug Info")
    title:SetTextColor(1, 0.3, 0.3, 1) -- Red title
    
    -- Create scrollable text area for debug info
    local scrollFrame = CreateFrame("ScrollFrame", nil, flyout, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(220, 150)
    scrollFrame:SetPoint("TOP", title, "BOTTOM", 0, -5)
    
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(220, 150)
    scrollFrame:SetScrollChild(content)
    
    -- Create debug text
    local debugText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    debugText:SetPoint("TOPLEFT", content, "TOPLEFT", 5, -5)
    debugText:SetPoint("TOPRIGHT", content, "TOPRIGHT", -5, -5)
    debugText:SetJustifyH("LEFT")
    debugText:SetJustifyV("TOP")
    debugText:SetWordWrap(true)
    debugText:SetTextColor(0.9, 0.9, 0.9, 1)
    
    flyout.title = title
    flyout.debugText = debugText
    flyout.content = content
    flyout.isMouseOver = false
    flyout:Hide()
    
    -- Add mouse tracking for persistence
    flyout:EnableMouse(true)
    flyout:SetScript("OnEnter", function(self)
        self.isMouseOver = true
        -- Cancel any pending hide timers from the flyouts
        if self.hideTimer then
            self.hideTimer:Cancel()
            self.hideTimer = nil
        end
    end)
    flyout:SetScript("OnLeave", function(self)
        self.isMouseOver = false
        -- Hide immediately when leaving debug flyout
        self.hideTimer = C_Timer.After(0.1, function()
            self.hideTimer = nil
            if not self.isMouseOver then
                MountieUI.HideMountModelFlyout()
            end
        end)
    end)
    
    mountDebugFlyout = flyout
    return flyout
end

function MountieUI.ShowMountModelFlyout(mountData)
    if not mountData or not mountData.id then
        return
    end
    
    -- Don't recreate if already showing the same mount
    local flyout = MountieUI.CreateMountModelFlyout()
    if flyout:IsShown() and flyout.currentMountID == mountData.id then
        return
    end
    
    -- Position flyout to the left of the main frame
    if _G.MountieMainFrame and _G.MountieMainFrame:IsShown() then
        flyout:ClearAllPoints()
        flyout:SetPoint("RIGHT", _G.MountieMainFrame, "LEFT", -10, 0)
    else
        -- Fallback position if main frame isn't available
        flyout:SetPoint("CENTER", UIParent, "CENTER", -400, 0)
    end
    
    -- Set mount name and track current mount
    flyout.nameLabel:SetText(mountData.name or "Unknown Mount")
    flyout.currentMountID = mountData.id
    
    -- Set the mount model using PlayerModel methods
    local creatureDisplayInfoID = C_MountJournal.GetMountInfoExtraByID(mountData.id)
    
    if creatureDisplayInfoID and creatureDisplayInfoID > 0 then
        -- PlayerModel should support SetDisplayInfo or SetCreature
        if flyout.modelFrame.SetDisplayInfo then
            flyout.modelFrame:SetDisplayInfo(creatureDisplayInfoID)
        elseif flyout.modelFrame.SetCreature then
            -- Fallback: try using the mount ID as creature ID
            flyout.modelFrame:SetCreature(mountData.id)
        elseif flyout.modelFrame.SetUnit then
            -- Another fallback: try setting as unit
            flyout.modelFrame:SetUnit("player")
        end
        
        -- Set initial facing and start rotation
        if flyout.modelFrame.SetFacing then
            flyout.modelFrame:SetFacing(0)
        end
    end
    
    -- Start slow rotation animation
    if flyout.rotationTimer then
        flyout.rotationTimer:Cancel()
    end
    
    local currentRotation = 0
    flyout.rotationTimer = C_Timer.NewTicker(0.05, function() -- Update every 50ms for smooth rotation
        currentRotation = currentRotation + 0.02 -- Slow rotation speed
        if currentRotation > math.pi * 2 then
            currentRotation = 0
        end
        
        if flyout.modelFrame.SetFacing and flyout:IsShown() then
            flyout.modelFrame:SetFacing(currentRotation)
        else
            -- Stop rotation if flyout is hidden
            if flyout.rotationTimer then
                flyout.rotationTimer:Cancel()
                flyout.rotationTimer = nil
            end
        end
    end)
    
    flyout:Show()
    
    -- Show debug flyout if debug mode is enabled
    if MountieDB and MountieDB.settings and MountieDB.settings.debugMode then
        MountieUI.ShowMountDebugFlyout(mountData, flyout)
    end
end

function MountieUI.HideMountModelFlyout()
    if mountModelFlyout then
        -- Stop rotation timer
        if mountModelFlyout.rotationTimer then
            mountModelFlyout.rotationTimer:Cancel()
            mountModelFlyout.rotationTimer = nil
        end
        mountModelFlyout:Hide()
    end
    
    -- Also hide debug flyout
    if mountDebugFlyout then
        mountDebugFlyout:Hide()
    end
end

function MountieUI.ShowMountDebugFlyout(mountData, modelFlyout)
    if not mountData or not mountData.id then
        return
    end
    
    local debugFlyout = MountieUI.CreateMountDebugFlyout()
    
    -- Position debug flyout to the right of the model flyout
    if modelFlyout and modelFlyout:IsShown() then
        debugFlyout:ClearAllPoints()
        debugFlyout:SetPoint("LEFT", modelFlyout, "RIGHT", 10, 0)
    else
        -- Fallback position
        debugFlyout:SetPoint("CENTER", UIParent, "CENTER", 200, 0)
    end
    
    -- Gather all mount data
    local name, spellID, icon, active, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected = C_MountJournal.GetMountInfoByID(mountData.id)
    local creatureDisplayInfoID, description, source, isSelfMount, mountTypeID, uiModelSceneID, animID, spellVisualKitID, disablePlayerMountPreview = C_MountJournal.GetMountInfoExtraByID(mountData.id)
    
    -- Format debug information
    local debugInfo = string.format(
        "Mount ID: %s\n" ..
        "Name: %s\n" ..
        "Spell ID: %s\n" ..
        "Source Type: %s\n" ..
        "Mount Type ID: %s\n" ..
        "Display Info ID: %s\n" ..
        "UI Model Scene ID: %s\n" ..
        "Animation ID: %s\n" ..
        "Spell Visual Kit ID: %s\n" ..
        "Is Collected: %s\n" ..
        "Is Usable: %s\n" ..
        "Is Favorite: %s\n" ..
        "Is Faction Specific: %s\n" ..
        "Faction: %s\n" ..
        "Should Hide: %s\n" ..
        "Is Self Mount: %s\n" ..
        "Description: %s\n" ..
        "Source: %s",
        tostring(mountData.id),
        tostring(name),
        tostring(spellID),
        tostring(sourceType),
        tostring(mountTypeID),
        tostring(creatureDisplayInfoID),
        tostring(uiModelSceneID),
        tostring(animID),
        tostring(spellVisualKitID),
        tostring(isCollected),
        tostring(isUsable),
        tostring(isFavorite),
        tostring(isFactionSpecific),
        tostring(faction),
        tostring(shouldHideOnChar),
        tostring(isSelfMount),
        tostring(description or "None"),
        tostring(source or "None")
    )
    
    debugFlyout.debugText:SetText(debugInfo)
    
    -- Adjust content height based on text
    local textHeight = debugFlyout.debugText:GetStringHeight()
    debugFlyout.content:SetHeight(math.max(textHeight + 10, 150))
    
    debugFlyout:Show()
end

-- Enhanced tooltip system with 3D model
local mountTooltip = nil

function MountieUI.ShowMountTooltipWithModel(parent, mountData)
    if not mountData or not mountData.id then
        return
    end
    
    -- Create enhanced tooltip if it doesn't exist
    if not mountTooltip then
        mountTooltip = CreateFrame("Frame", "MountieEnhancedTooltip", UIParent, "BackdropTemplate")
        mountTooltip:SetSize(250, 200)
        mountTooltip:SetFrameStrata("TOOLTIP")
        mountTooltip:SetFrameLevel(1000)
        
        -- Set backdrop
        mountTooltip:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        mountTooltip:SetBackdropColor(0, 0, 0, 0.9)
        mountTooltip:SetBackdropBorderColor(1, 1, 1, 1)
        
        -- Mount name
        mountTooltip.nameText = mountTooltip:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        mountTooltip.nameText:SetPoint("TOP", mountTooltip, "TOP", 0, -10)
        mountTooltip.nameText:SetTextColor(1, 1, 0.8, 1)
        
        -- Create 3D model frame
        mountTooltip.model = CreateFrame("PlayerModel", nil, mountTooltip)
        mountTooltip.model:SetPoint("TOPLEFT", mountTooltip.nameText, "BOTTOMLEFT", -50, -10)
        mountTooltip.model:SetPoint("BOTTOMRIGHT", mountTooltip, "BOTTOMRIGHT", -10, 30)
        
        -- Mount source/details
        mountTooltip.sourceText = mountTooltip:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        mountTooltip.sourceText:SetPoint("BOTTOM", mountTooltip, "BOTTOM", 0, 10)
        mountTooltip.sourceText:SetPoint("LEFT", mountTooltip, "LEFT", 10, 0)
        mountTooltip.sourceText:SetPoint("RIGHT", mountTooltip, "RIGHT", -10, 0)
        mountTooltip.sourceText:SetJustifyH("CENTER")
        mountTooltip.sourceText:SetTextColor(0.8, 0.8, 0.8, 1)
    end
    
    -- Position tooltip near the parent button
    mountTooltip:ClearAllPoints()
    mountTooltip:SetPoint("LEFT", parent, "RIGHT", 10, 0)
    
    -- Set mount information
    mountTooltip.nameText:SetText(mountData.name or "Unknown Mount")
    
    -- Set source information
    local sourceText = ""
    if mountData.sourceType then
        sourceText = mountData.sourceType
        if mountData.isCollected then
            sourceText = sourceText .. " (Collected)"
        else
            sourceText = sourceText .. " (Not Collected)"
        end
    end
    mountTooltip.sourceText:SetText(sourceText)
    
    -- Set the 3D model
    local creatureDisplayInfoID = C_MountJournal.GetMountInfoExtraByID(mountData.id)
    if creatureDisplayInfoID and creatureDisplayInfoID > 0 then
        -- Try different model setting methods for compatibility
        if mountTooltip.model.SetDisplayInfo then
            mountTooltip.model:SetDisplayInfo(creatureDisplayInfoID)
        elseif mountTooltip.model.SetCreature then
            mountTooltip.model:SetCreature(mountData.id)
        end
        
        -- Set initial position and rotation
        if mountTooltip.model.SetPosition then
            mountTooltip.model:SetPosition(0, 0, 0)
        end
        if mountTooltip.model.SetFacing then
            mountTooltip.model:SetFacing(0.5) -- Slightly angled view
        end
    end
    
    mountTooltip:Show()
end

function MountieUI.HideMountTooltip()
    if mountTooltip then
        mountTooltip:Hide()
    end
end

Mountie.Debug("UI/MountList.lua loaded")