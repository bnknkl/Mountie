-- Mountie: Rules Dialog
Mountie.Debug("UI/RulesDialog.lua loading...")

local rulesDialog -- singleton-ish

-- Ensure pack.conditions exists
local function EnsureConditions(pack)
    pack.conditions = pack.conditions or {}
end

-- Build the visible list of rules inside the dialog
local function RebuildRulesList(container, pack)
    -- clear
    if container.ruleRows then
        for _, row in ipairs(container.ruleRows) do
            row:Hide()
            row:SetParent(nil)
        end
    end
    container.ruleRows = {}

    EnsureConditions(pack)
    local y = -10
    for i, rule in ipairs(pack.conditions) do
        local row = CreateFrame("Frame", nil, container)
        row:SetSize(360, 22)
        row:SetPoint("TOPLEFT", container, "TOPLEFT", 0, y)

        local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("LEFT", row, "LEFT", 0, 0)

        if rule.type == "zone" then
            local mi = C_Map.GetMapInfo(rule.mapID)
            local zoneName = mi and mi.name or ("MapID " .. tostring(rule.mapID))
            text:SetText(string.format("Zone: %s%s", zoneName, rule.includeParents and " (match parents)" or ""))
        elseif rule.type == "transmog" then
            local setInfo = Mountie.GetTransmogSetInfo(rule.setID)
            local setName = setInfo and setInfo.name or ("SetID " .. tostring(rule.setID))
            text:SetText("Transmog: " .. setName)
        else
            text:SetText("Unknown rule type")
        end

        local del = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        del:SetSize(22, 18)
        del:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        del:SetText("X")
        del:SetScript("OnClick", function()
            if Mountie.TableRemoveByIndex(pack.conditions, i) then
                Mountie.Print("Removed rule.")
                RebuildRulesList(container, pack)
                -- Refresh the pack panel to show updated rule count
                if _G.MountieMainFrame and _G.MountieMainFrame.packPanel and _G.MountieMainFrame.packPanel.refreshPacks then
                    _G.MountieMainFrame.packPanel.refreshPacks()
                end
            end
        end)

        container.ruleRows[#container.ruleRows+1] = row
        y = y - 24
    end

    -- Update content height and manage scrollbar visibility
    local contentHeight = math.max(#pack.conditions * 24 + 20, 1) -- 24px per rule + padding
    container:SetHeight(contentHeight)
    
    -- Get the scroll frame (container's parent)
    local scrollFrame = container:GetParent()
    if scrollFrame and scrollFrame.ScrollBar then
        local scrollFrameHeight = scrollFrame:GetHeight()
        
        -- Show/hide scrollbar based on whether content exceeds visible area
        if contentHeight > scrollFrameHeight then
            scrollFrame.ScrollBar:Show()
        else
            scrollFrame.ScrollBar:Hide()
            -- Reset scroll position when scrollbar is hidden
            scrollFrame:SetVerticalScroll(0)
        end
    end
end

-- Public API
function MountieUI.ShowRulesDialog(pack)
    if not rulesDialog then
        local dlg = CreateFrame("Frame", "MountieRulesDialog", UIParent, "BasicFrameTemplateWithInset")
        dlg:SetSize(420, 400) -- Increased height for transmog controls
        dlg:SetPoint("CENTER")
        dlg:SetMovable(true)
        dlg:EnableMouse(true)
        dlg:RegisterForDrag("LeftButton")
        dlg:SetScript("OnDragStart", function(self) self:StartMoving() end)
        dlg:SetScript("OnDragStop",  function(self) self:StopMovingOrSizing() end)
        dlg:SetFrameStrata("DIALOG")

        dlg.TitleText:SetText("Assign Rules")

        dlg.CloseButton:SetScript("OnClick", function() dlg:Hide() end)
        table.insert(UISpecialFrames, "MountieRulesDialog")

        -- Header: pack name
        dlg.packNameText = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        dlg.packNameText:SetPoint("TOPLEFT", dlg, "TOPLEFT", 16, -40)
        dlg.packNameText:SetTextColor(1, 1, 0.8, 1)

        -- Current zone display
        local zoneLabel = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        zoneLabel:SetPoint("TOPLEFT", dlg.packNameText, "BOTTOMLEFT", 0, -10)
        zoneLabel:SetText("Current Zone:")

        local zoneText = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        zoneText:SetPoint("LEFT", zoneLabel, "RIGHT", 8, 0)
        zoneText:SetText("Unknown")

        -- "Match parent zones" checkbox
        local parentCheck = CreateFrame("CheckButton", nil, dlg, "UICheckButtonTemplate")
        parentCheck:SetPoint("TOPLEFT", zoneLabel, "BOTTOMLEFT", 0, -10)
        parentCheck.text = parentCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        parentCheck.text:SetPoint("LEFT", parentCheck, "RIGHT", 4, 0)
        parentCheck.text:SetText("Also match parent zones (continent/region)")

        -- Add Current Zone button
        local addCurrentBtn = CreateFrame("Button", nil, dlg, "UIPanelButtonTemplate")
        addCurrentBtn:SetSize(120, 22)
        addCurrentBtn:SetPoint("LEFT", parentCheck.text, "RIGHT", 10, 0)
        addCurrentBtn:SetText("Add Current Zone")
        addCurrentBtn:SetScript("OnClick", function()
            if not dlg.targetPack then return end
            local mapID = C_Map.GetBestMapForUnit("player")
            if not mapID then
                Mountie.Print("Could not determine current zone.")
                return
            end
            EnsureConditions(dlg.targetPack)
            table.insert(dlg.targetPack.conditions, {
                type = "zone",
                mapID = mapID,
                includeParents = parentCheck:GetChecked() and true or false,
            })
            Mountie.Print("Added zone rule.")
            RebuildRulesList(dlg.rulesList, dlg.targetPack)
            -- Immediately re-evaluate active pack
            C_Timer.After(0.1, Mountie.SelectActivePack)
            -- Refresh the pack panel to show updated rule count
            if _G.MountieMainFrame and _G.MountieMainFrame.packPanel and _G.MountieMainFrame.packPanel.refreshPacks then
                _G.MountieMainFrame.packPanel.refreshPacks()
            end
        end)

        -- Browse Zones button
        local browseBtn = CreateFrame("Button", nil, dlg, "UIPanelButtonTemplate")
        browseBtn:SetSize(100, 22)
        browseBtn:SetPoint("TOP", addCurrentBtn, "BOTTOM", 0, 0)
        browseBtn:SetText("Browse Zones")
        browseBtn:SetScript("OnClick", function()
            if dlg.zonePicker then
                dlg.zonePicker:Show()
            else
                dlg.zonePicker = MountieUI.CreateZonePicker(dlg)
                dlg.zonePicker:Show()
            end
        end)

        -- Current transmog display
        local transmogLabel = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        transmogLabel:SetPoint("TOPLEFT", addCurrentBtn, "BOTTOMLEFT", -110, -10)
        transmogLabel:SetText("Current Transmog:")

        local transmogText = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        transmogText:SetPoint("LEFT", transmogLabel, "RIGHT", 8, 0)
        transmogText:SetText("None detected")

        -- Add Current Transmog button
        local addTransmogBtn = CreateFrame("Button", nil, dlg, "UIPanelButtonTemplate")
        addTransmogBtn:SetSize(130, 22)
        addTransmogBtn:SetPoint("LEFT", transmogText, "RIGHT", 10, 0)
        addTransmogBtn:SetText("Add Current Transmog")
        addTransmogBtn:SetScript("OnClick", function()
            if not dlg.targetPack then return end
            local setID = GetCurrentTransmogSetID()
            if not setID then
                Mountie.Print("No transmog set detected. Wear more pieces of a set.")
                return
            end
            
            EnsureConditions(dlg.targetPack)
            table.insert(dlg.targetPack.conditions, {
                type = "transmog",
                setID = setID,
                priority = MountieDB.settings.rulePriorities.transmog or 100,
            })
            
            local setInfo = Mountie.GetTransmogSetInfo(setID)
            local setName = setInfo and setInfo.name or ("Set " .. setID)
            Mountie.Print("Added transmog rule: " .. setName)
            
            RebuildRulesList(dlg.rulesList, dlg.targetPack)
            C_Timer.After(0.1, Mountie.SelectActivePack)
            
            -- Refresh pack panel
            if _G.MountieMainFrame and _G.MountieMainFrame.packPanel and _G.MountieMainFrame.packPanel.refreshPacks then
                _G.MountieMainFrame.packPanel.refreshPacks()
            end
        end)

        -- Browse Transmog Sets button
        local browseTransmogBtn = CreateFrame("Button", nil, dlg, "UIPanelButtonTemplate")
        browseTransmogBtn:SetSize(130, 22)
        browseTransmogBtn:SetPoint("TOP", addTransmogBtn, "BOTTOM", 0, 0)
        browseTransmogBtn:SetText("Browse Transmog Sets")
        browseTransmogBtn:SetScript("OnClick", function()
            if dlg.transmogPicker then
                dlg.transmogPicker:Show()
            else
                dlg.transmogPicker = MountieUI.CreateTransmogPicker(dlg)
                dlg.transmogPicker:Show()
            end
        end)

        -- Rules list container
        local listLabel = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        listLabel:SetPoint("TOPLEFT", transmogLabel, "BOTTOMLEFT", 0, -16)
        listLabel:SetText("Rules for this pack:")

        local rulesScroll = CreateFrame("ScrollFrame", nil, dlg, "UIPanelScrollFrameTemplate")
        rulesScroll:SetPoint("TOPLEFT", listLabel, "BOTTOMLEFT", 0, -6)
        rulesScroll:SetPoint("BOTTOMRIGHT", dlg, "BOTTOMRIGHT", -28, 16)

        local rulesContent = CreateFrame("Frame", nil, rulesScroll)
        rulesContent:SetSize(360, 1)
        rulesScroll:SetScrollChild(rulesContent)
        dlg.rulesList = rulesContent

        -- Initially hide the scrollbar
        if rulesScroll.ScrollBar then
            rulesScroll.ScrollBar:Hide()
        end

        -- Store refs
        dlg.zoneText = zoneText
        dlg.parentCheck = parentCheck
        dlg.transmogText = transmogText
        dlg.addTransmogBtn = addTransmogBtn

        -- OnShow: refresh current zone and transmog info and list
        dlg:SetScript("OnShow", function(self)
            local mapID = C_Map.GetBestMapForUnit("player")
            local mi = mapID and C_Map.GetMapInfo(mapID) or nil
            self.zoneText:SetText(mi and (mi.name .. " (ID " .. mapID .. ")") or "Unknown")
            
            -- Update current transmog display
            local currentSetID = GetCurrentTransmogSetID()
            if currentSetID then
                local setInfo = Mountie.GetTransmogSetInfo(currentSetID)
                local setName = setInfo and setInfo.name or ("Set " .. currentSetID)
                self.transmogText:SetText(setName)
                self.addTransmogBtn:SetEnabled(true)
            else
                self.transmogText:SetText("None detected")
                self.addTransmogBtn:SetEnabled(false)
            end
            
            if self.targetPack then
                self.packNameText:SetText(self.targetPack.name)
                RebuildRulesList(self.rulesList, self.targetPack)
            end
        end)

        rulesDialog = dlg
    end

    rulesDialog.targetPack = pack
    rulesDialog:Show()
end

-- Zone Picker Dialog
function MountieUI.CreateZonePicker(parentDialog)
    local picker = CreateFrame("Frame", "MountieZonePicker", UIParent, "BasicFrameTemplateWithInset")
    picker:SetSize(450, 400)
    picker:SetPoint("CENTER", parentDialog, "CENTER", 50, 0) -- Offset from main dialog
    picker:SetMovable(true)
    picker:EnableMouse(true)
    picker:RegisterForDrag("LeftButton")
    picker:SetScript("OnDragStart", function(self) self:StartMoving() end)
    picker:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    picker:SetFrameStrata("FULLSCREEN_DIALOG")
    picker:SetFrameLevel(parentDialog:GetFrameLevel() + 1)

    picker.TitleText:SetText("Select Zone")

    picker.CloseButton:SetScript("OnClick", function()
        picker:Hide()
    end)

    -- Search box
    local searchLabel = picker:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    searchLabel:SetPoint("TOPLEFT", picker, "TOPLEFT", 20, -40)
    searchLabel:SetText("Search:")

    local searchBox = CreateFrame("EditBox", nil, picker, "InputBoxTemplate")
    searchBox:SetSize(200, 25)
    searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 10, 0)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(50)

    -- Zone list scroll frame
    local zoneScroll = CreateFrame("ScrollFrame", nil, picker, "UIPanelScrollFrameTemplate")
    zoneScroll:SetPoint("TOPLEFT", searchLabel, "BOTTOMLEFT", 0, -15)
    zoneScroll:SetPoint("BOTTOMRIGHT", picker, "BOTTOMRIGHT", -50, 50)

    local zoneContent = CreateFrame("Frame", nil, zoneScroll)
    zoneContent:SetSize(380, 1)
    zoneScroll:SetScrollChild(zoneContent)

    -- Add Zone button
    local addBtn = CreateFrame("Button", nil, picker, "UIPanelButtonTemplate")
    addBtn:SetSize(80, 25)
    addBtn:SetPoint("BOTTOMRIGHT", picker, "BOTTOMRIGHT", -20, 20)
    addBtn:SetText("Add Zone")
    addBtn:SetEnabled(false) -- Disabled until a zone is selected

    -- Cancel button
    local cancelBtn = CreateFrame("Button", nil, picker, "UIPanelButtonTemplate")
    cancelBtn:SetSize(80, 25)
    cancelBtn:SetPoint("RIGHT", addBtn, "LEFT", -10, 0)
    cancelBtn:SetText("Cancel")
    cancelBtn:SetScript("OnClick", function() picker:Hide() end)

    -- Store state
    picker.selectedMapID = nil
    picker.zoneButtons = {}

    -- Function to populate zone list
    local function PopulateZoneList(searchText)
        -- Clear existing buttons
        for _, btn in ipairs(picker.zoneButtons) do
            btn:Hide()
            btn:SetParent(nil)
        end
        picker.zoneButtons = {}

        -- Store expanded state
        picker.expandedContinents = picker.expandedContinents or {}

        -- Get continent data with nested zones
        local continentData = {}
        
        -- Try multiple approaches to get all continents
        local potentialContinents = {}
        
        -- Method 1: Get from Cosmic map (946)
        local cosmicChildren = C_Map.GetMapChildrenInfo(946, Enum.UIMapType.Continent)
        if cosmicChildren then
            for _, continent in ipairs(cosmicChildren) do
                potentialContinents[continent.mapID] = continent
            end
        end
        
        -- Method 2: Try other potential parent maps
        local otherParents = {946, 947} -- Cosmic and any other top-level maps
        for _, parentID in ipairs(otherParents) do
            local children = C_Map.GetMapChildrenInfo(parentID, Enum.UIMapType.Continent)
            if children then
                for _, continent in ipairs(children) do
                    potentialContinents[continent.mapID] = continent
                end
            end
        end
        
        -- Method 3: Add known major continents manually (comprehensive list)
        local knownContinents = {
            {mapID = 12, name = "Kalimdor"}, -- Classic Kalimdor
            {mapID = 13, name = "Eastern Kingdoms"}, -- Classic EK
            {mapID = 101, name = "Outland"}, -- BC
            {mapID = 113, name = "Northrend"}, -- Wrath
            {mapID = 424, name = "Pandaria"}, -- MoP
            {mapID = 572, name = "Draenor"}, -- WoD
            {mapID = 619, name = "Broken Isles"}, -- Legion
            {mapID = 875, name = "Zandalar"}, -- BfA Horde
            {mapID = 876, name = "Kul Tiras"}, -- BfA Alliance
            {mapID = 1550, name = "The Shadowlands"}, -- Shadowlands
            {mapID = 1978, name = "Dragon Isles"}, -- Dragonflight
            {mapID = 2274, name = "Khaz Algar"}, -- The War Within
        }
        
        for _, continent in ipairs(knownContinents) do
            -- Verify the continent exists and get the actual name from the API
            local mapInfo = C_Map.GetMapInfo(continent.mapID)
            if mapInfo then
                potentialContinents[continent.mapID] = {
                    mapID = continent.mapID,
                    name = mapInfo.name -- Use the real name from the API
                }
            end
        end
        
        -- Method 4: Try to discover unknown continents by scanning a range
        -- This helps catch new continents that aren't in our hard-coded list
        local scanRanges = {
            {1, 50}, -- Classic range
            {100, 200}, -- BC range  
            {400, 500}, -- MoP range
            {550, 650}, -- WoD/Legion range
            {850, 950}, -- BfA range
            {1500, 1600}, -- Shadowlands range
            {1950, 2050}, -- Dragonflight range
            {2200, 2500}, -- War Within range (expanded for newer zones)
        }
        
        for _, range in ipairs(scanRanges) do
            for mapID = range[1], range[2] do
                local mapInfo = C_Map.GetMapInfo(mapID)
                if mapInfo and mapInfo.mapType == Enum.UIMapType.Continent then
                    potentialContinents[mapID] = {
                        mapID = mapID,
                        name = mapInfo.name
                    }
                end
            end
        end
        
        -- Build continent data with zones
        local continentsByName = {} -- Track by name to avoid duplicates
        
        for _, continent in pairs(potentialContinents) do
            -- Skip if we already have a continent with this exact name
            if continentsByName[continent.name] then
                local existing = continentsByName[continent.name]
                -- Keep the one with more zones, or lower ID if zone count is equal
                local existingZoneCount = #(existing.zones or {})
                
                -- Get zone count for this continent
                local zones = {}
                local standardZones = C_Map.GetMapChildrenInfo(continent.mapID, Enum.UIMapType.Zone)
                if standardZones then
                    zones = standardZones
                end
                
                -- For newer continents, also scan manually
                if continent.mapID >= 2200 then
                    local startRange = continent.mapID + 1
                    local endRange = continent.mapID + 300
                    
                    for zoneID = startRange, endRange do
                        local zoneInfo = C_Map.GetMapInfo(zoneID)
                        if zoneInfo and zoneInfo.mapType == Enum.UIMapType.Zone then
                            local parentInfo = zoneInfo.parentMapID and C_Map.GetMapInfo(zoneInfo.parentMapID)
                            if parentInfo and parentInfo.mapID == continent.mapID then
                                local alreadyExists = false
                                for _, existingZone in ipairs(zones) do
                                    if existingZone.mapID == zoneID then
                                        alreadyExists = true
                                        break
                                    end
                                end
                                if not alreadyExists then
                                    zones[#zones + 1] = {
                                        mapID = zoneID,
                                        name = zoneInfo.name
                                    }
                                end
                            end
                        end
                    end
                end
                
                local thisZoneCount = #zones
                
                -- Replace existing if this one has more zones, or same zones but lower ID
                if thisZoneCount > existingZoneCount or 
                   (thisZoneCount == existingZoneCount and continent.mapID < existing.mapID) then
                    continentsByName[continent.name] = {
                        mapID = continent.mapID,
                        name = continent.name,
                        type = "Continent",
                        zones = zones
                    }
                end
                -- Skip processing this duplicate (don't add to continentData)
            else
                -- This is a new continent name, process normally
                local zones = {}
                
                -- Method 1: Standard zone query
                local standardZones = C_Map.GetMapChildrenInfo(continent.mapID, Enum.UIMapType.Zone)
                if standardZones then
                    for _, zone in ipairs(standardZones) do
                        zones[#zones + 1] = zone
                    end
                end
                
                -- Method 2: For newer continents, scan for zones in nearby ID ranges
                if continent.mapID >= 2200 then -- War Within and future expansions
                    local startRange = continent.mapID + 1
                    local endRange = continent.mapID + 300 -- Scan 300 IDs after the continent
                    
                    for zoneID = startRange, endRange do
                        local zoneInfo = C_Map.GetMapInfo(zoneID)
                        if zoneInfo and zoneInfo.mapType == Enum.UIMapType.Zone then
                            -- Check if this zone's parent is our continent
                            local parentInfo = zoneInfo.parentMapID and C_Map.GetMapInfo(zoneInfo.parentMapID)
                            if parentInfo and parentInfo.mapID == continent.mapID then
                                -- Add this zone if we don't already have it
                                local alreadyExists = false
                                for _, existingZone in ipairs(zones) do
                                    if existingZone.mapID == zoneID then
                                        alreadyExists = true
                                        break
                                    end
                                end
                                if not alreadyExists then
                                    zones[#zones + 1] = {
                                        mapID = zoneID,
                                        name = zoneInfo.name
                                    }
                                end
                            end
                        end
                    end
                end
                
                continentsByName[continent.name] = {
                    mapID = continent.mapID,
                    name = continent.name,
                    type = "Continent",
                    zones = zones
                }
            end
        end
        
        -- Convert back to array
        local continentData = {}
        for _, continent in pairs(continentsByName) do
            table.insert(continentData, continent)
        end

        -- Sort continents by name
        table.sort(continentData, function(a, b) return a.name < b.name end)

        -- Build display list based on search and expansion state
        local displayItems = {}
        searchText = searchText and string.lower(searchText) or ""

        for _, continent in ipairs(continentData) do
            local continentMatches = (searchText == "" or string.find(string.lower(continent.name), searchText))
            local hasMatchingZones = false
            
            -- Check if any zones match search
            local matchingZones = {}
            for _, zone in ipairs(continent.zones) do
                if searchText == "" or string.find(string.lower(zone.name), searchText) then
                    hasMatchingZones = true
                    table.insert(matchingZones, zone)
                end
            end
            
            -- Sort matching zones
            table.sort(matchingZones, function(a, b) return a.name < b.name end)
            
            -- Add continent if it matches or has matching zones
            if continentMatches or hasMatchingZones then
                table.insert(displayItems, {
                    mapID = continent.mapID,
                    name = continent.name,
                    type = "Continent",
                    level = 0,
                    isExpanded = picker.expandedContinents[continent.mapID]
                })
                
                -- Add zones if continent is expanded or we're searching
                if picker.expandedContinents[continent.mapID] or searchText ~= "" then
                    for _, zone in ipairs(matchingZones) do
                        table.insert(displayItems, {
                            mapID = zone.mapID,
                            name = zone.name,
                            type = "Zone",
                            level = 1,
                            parentID = continent.mapID
                        })
                    end
                end
            end
        end

        -- Create buttons for display items
        for i, item in ipairs(displayItems) do
            local btn = CreateFrame("Button", nil, zoneContent, "BackdropTemplate")
            btn:SetSize(360, 25)
            btn:SetPoint("TOPLEFT", zoneContent, "TOPLEFT", 0, -(i-1) * 27)
            
            btn:SetBackdrop({
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 8,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            })
            btn:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
            btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)

            -- Indent based on level
            local indent = item.level * 20

            -- Expand/collapse icon for continents
            local expandIcon = nil
            if item.type == "Continent" then
                expandIcon = btn:CreateTexture(nil, "OVERLAY")
                expandIcon:SetSize(12, 12)
                expandIcon:SetPoint("LEFT", btn, "LEFT", indent + 4, 0)
                if item.isExpanded then
                    expandIcon:SetTexture("Interface\\Buttons\\UI-MinusButton-Up")
                else
                    expandIcon:SetTexture("Interface\\Buttons\\UI-PlusButton-Up")
                end
                btn.expandIcon = expandIcon
                indent = indent + 16 -- Make room for the icon
            end

            local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            text:SetPoint("LEFT", btn, "LEFT", indent + 8, 0)
            text:SetPoint("RIGHT", btn, "RIGHT", -30, 0)
            text:SetJustifyH("LEFT")
            
            -- Different display for continents vs zones
            if item.type == "Continent" then
                text:SetText(item.name .. " (Continent)")
                text:SetTextColor(1, 1, 0.6, 1) -- Yellow for continents
            else
                text:SetText(item.name)
                text:SetTextColor(1, 1, 1, 1) -- White for zones
            end

            -- ID display
            local idText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            idText:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
            idText:SetText(tostring(item.mapID))
            idText:SetTextColor(0.6, 0.6, 0.6, 1)

            -- Store item data
            btn.itemData = item

            -- Click handler - BOTH continents and zones are now selectable
            btn:SetScript("OnClick", function()
                -- Clear previous selection
                if picker.selectedButton then
                    picker.selectedButton:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
                end
                
                -- Select this item (continent or zone)
                picker.selectedMapID = item.mapID
                picker.selectedButton = btn
                btn:SetBackdropColor(0.2, 0.4, 0.2, 0.8) -- Green selection
                addBtn:SetEnabled(true)
            end)

            -- Right-click for continents expands/collapses (alternative to left-click selection)
            if item.type == "Continent" then
                btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                btn:SetScript("OnClick", function(self, mouseButton)
                    if mouseButton == "RightButton" then
                        -- Right-click: Toggle expansion
                        picker.expandedContinents[item.mapID] = not picker.expandedContinents[item.mapID]
                        PopulateZoneList(searchBox:GetText())
                    else
                        -- Left-click: Select continent
                        if picker.selectedButton then
                            picker.selectedButton:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
                        end
                        picker.selectedMapID = item.mapID
                        picker.selectedButton = btn
                        btn:SetBackdropColor(0.2, 0.4, 0.2, 0.8) -- Green selection
                        addBtn:SetEnabled(true)
                    end
                end)
            end

            -- Hover effects
            btn:SetScript("OnEnter", function(self)
                if self ~= picker.selectedButton then
                    if item.type == "Continent" then
                        self:SetBackdropColor(0.15, 0.15, 0.2, 0.8) -- Slightly different hover for continents
                    else
                        self:SetBackdropColor(0.2, 0.2, 0.2, 0.8)
                    end
                end
                
                -- Show tooltip for continents explaining the click behavior
                if item.type == "Continent" then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText("Left-click: Select entire continent")
                    GameTooltip:AddLine("Right-click: Expand/collapse zones", 0.8, 0.8, 0.8)
                    GameTooltip:Show()
                end
            end)
            btn:SetScript("OnLeave", function(self)
                if self ~= picker.selectedButton then
                    self:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
                end
                GameTooltip:Hide()
            end)

            picker.zoneButtons[i] = btn
        end

        -- Update content height
        local contentHeight = math.max(#displayItems * 27, 1)
        zoneContent:SetHeight(contentHeight)

        -- Manage scrollbar
        if zoneScroll.ScrollBar then
            if contentHeight > zoneScroll:GetHeight() then
                zoneScroll.ScrollBar:Show()
            else
                zoneScroll.ScrollBar:Hide()
                zoneScroll:SetVerticalScroll(0)
            end
        end
    end

    -- Search functionality
    searchBox:SetScript("OnTextChanged", function(self)
        PopulateZoneList(self:GetText())
    end)

    -- Add button functionality
    addBtn:SetScript("OnClick", function()
        if picker.selectedMapID and parentDialog.targetPack then
            EnsureConditions(parentDialog.targetPack)
            table.insert(parentDialog.targetPack.conditions, {
                type = "zone",
                mapID = picker.selectedMapID,
                includeParents = parentDialog.parentCheck:GetChecked() and true or false,
            })
            
            local mapInfo = C_Map.GetMapInfo(picker.selectedMapID)
            local zoneName = mapInfo and mapInfo.name or ("MapID " .. picker.selectedMapID)
            Mountie.Print("Added zone rule: " .. zoneName)
            
            RebuildRulesList(parentDialog.rulesList, parentDialog.targetPack)
            C_Timer.After(0.1, Mountie.SelectActivePack)
            -- Refresh the pack panel to show updated rule count
            if _G.MountieMainFrame and _G.MountieMainFrame.packPanel and _G.MountieMainFrame.packPanel.refreshPacks then
                _G.MountieMainFrame.packPanel.refreshPacks()
            end
            picker:Hide()
        end
    end)

    -- OnShow: populate list and reset selection
    picker:SetScript("OnShow", function(self)
        self.selectedMapID = nil
        self.selectedButton = nil
        addBtn:SetEnabled(false)
        searchBox:SetText("")
        PopulateZoneList("")
    end)

    picker:Hide()
    table.insert(UISpecialFrames, "MountieZonePicker")
    return picker
end

-- Transmog Set Picker Dialog
function MountieUI.CreateTransmogPicker(parentDialog)
    local picker = CreateFrame("Frame", "MountieTransmogPicker", UIParent, "BasicFrameTemplateWithInset")
    picker:SetSize(500, 450)
    picker:SetPoint("CENTER", parentDialog, "CENTER", 60, 0)
    picker:SetMovable(true)
    picker:EnableMouse(true)
    picker:RegisterForDrag("LeftButton")
    picker:SetScript("OnDragStart", function(self) self:StartMoving() end)
    picker:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    picker:SetFrameStrata("FULLSCREEN_DIALOG")
    picker:SetFrameLevel(parentDialog:GetFrameLevel() + 1)

    picker.TitleText:SetText("Select Transmog Set")

    picker.CloseButton:SetScript("OnClick", function()
        picker:Hide()
    end)

    -- Search box
    local searchLabel = picker:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    searchLabel:SetPoint("TOPLEFT", picker, "TOPLEFT", 20, -40)
    searchLabel:SetText("Search:")

    local searchBox = CreateFrame("EditBox", nil, picker, "InputBoxTemplate")
    searchBox:SetSize(200, 25)
    searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 10, 0)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(50)

    -- Filter dropdown for expansions
    local filterLabel = picker:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    filterLabel:SetPoint("LEFT", searchBox, "RIGHT", 20, 0)
    filterLabel:SetText("Expansion:")

    local expansionFilter = CreateFrame("Frame", nil, picker, "UIDropDownMenuTemplate")
    expansionFilter:SetPoint("LEFT", filterLabel, "RIGHT", 5, 0)
    expansionFilter:SetSize(120, 20)

    -- Collection filter
    local collectedCheck = CreateFrame("CheckButton", nil, picker, "UICheckButtonTemplate")
    collectedCheck:SetPoint("TOPLEFT", searchLabel, "BOTTOMLEFT", 0, -10)
    collectedCheck.text = collectedCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    collectedCheck.text:SetPoint("LEFT", collectedCheck, "RIGHT", 5, 0)
    collectedCheck.text:SetText("Show only collected sets")
    collectedCheck:SetChecked(true) -- Default to collected only

    -- Transmog set list
    local setScroll = CreateFrame("ScrollFrame", nil, picker, "UIPanelScrollFrameTemplate")
    setScroll:SetPoint("TOPLEFT", collectedCheck, "BOTTOMLEFT", 0, -15)
    setScroll:SetPoint("BOTTOMRIGHT", picker, "BOTTOMRIGHT", -50, 50)

    local setContent = CreateFrame("Frame", nil, setScroll)
    setContent:SetSize(430, 1)
    setScroll:SetScrollChild(setContent)

    -- Add Set button
    local addBtn = CreateFrame("Button", nil, picker, "UIPanelButtonTemplate")
    addBtn:SetSize(80, 25)
    addBtn:SetPoint("BOTTOMRIGHT", picker, "BOTTOMRIGHT", -20, 20)
    addBtn:SetText("Add Set")
    addBtn:SetEnabled(false)

    -- Cancel button
    local cancelBtn = CreateFrame("Button", nil, picker, "UIPanelButtonTemplate")
    cancelBtn:SetSize(80, 25)
    cancelBtn:SetPoint("RIGHT", addBtn, "LEFT", -10, 0)
    cancelBtn:SetText("Cancel")
    cancelBtn:SetScript("OnClick", function() picker:Hide() end)

    -- Store state
    picker.selectedSetID = nil
    picker.setButtons = {}

    -- Expansion names for filter
    local expansionNames = {
        [0] = "Classic",
        [1] = "Burning Crusade", 
        [2] = "Wrath of the Lich King",
        [3] = "Cataclysm",
        [4] = "Mists of Pandaria",
        [5] = "Warlords of Draenor",
        [6] = "Legion",
        [7] = "Battle for Azeroth",
        [8] = "Shadowlands",
        [9] = "Dragonflight",
        [10] = "The War Within"
    }

    -- Initialize expansion filter dropdown
    local function InitializeExpansionDropdown(self, level)
        local info = UIDropDownMenu_CreateInfo()
        if level == 1 then
            info.text = "All Expansions"
            info.value = -1
            info.func = function()
                UIDropDownMenu_SetSelectedValue(expansionFilter, -1)
                PopulateSetList()
            end
            info.checked = UIDropDownMenu_GetSelectedValue(expansionFilter) == -1
            UIDropDownMenu_AddButton(info)

            -- Add expansion options
            for expID = 0, 10 do
                if expansionNames[expID] then
                    info.text = expansionNames[expID]
                    info.value = expID
                    info.func = function()
                        UIDropDownMenu_SetSelectedValue(expansionFilter, expID)
                        PopulateSetList()
                    end
                    info.checked = UIDropDownMenu_GetSelectedValue(expansionFilter) == expID
                    UIDropDownMenu_AddButton(info)
                end
            end
        end
    end

    UIDropDownMenu_Initialize(expansionFilter, InitializeExpansionDropdown)
    UIDropDownMenu_SetSelectedValue(expansionFilter, -1)
    UIDropDownMenu_SetText(expansionFilter, "All")
    UIDropDownMenu_SetWidth(expansionFilter, 100)

    -- Function to populate transmog set list
    function PopulateSetList()
        -- Clear existing buttons
        for _, btn in ipairs(picker.setButtons) do
            btn:Hide()
            btn:SetParent(nil)
        end
        picker.setButtons = {}

        -- Get filter values
        local searchText = string.lower(searchBox:GetText() or "")
        local selectedExpansion = UIDropDownMenu_GetSelectedValue(expansionFilter) or -1
        local collectedOnly = collectedCheck:GetChecked()

        -- Get all transmog sets
        local allSets = Mountie.GetAllTransmogSets()
        local filteredSets = {}

        for _, setData in ipairs(allSets) do
            local include = true

            -- Apply filters
            if searchText ~= "" and not string.find(string.lower(setData.name), searchText) then
                include = false
            end

            if selectedExpansion >= 0 and setData.expansionID ~= selectedExpansion then
                include = false
            end

            if collectedOnly and not setData.collected then
                include = false
            end

            if include then
                table.insert(filteredSets, setData)
            end
        end

        -- Create buttons for filtered sets
        for i, setData in ipairs(filteredSets) do
            local btn = CreateFrame("Button", nil, setContent, "BackdropTemplate")
            btn:SetSize(410, 30)
            btn:SetPoint("TOPLEFT", setContent, "TOPLEFT", 0, -(i-1) * 32)

            btn:SetBackdrop({
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 8,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            })
            btn:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
            btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)

            -- Set name
            local nameText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            nameText:SetPoint("LEFT", btn, "LEFT", 8, 0)
            nameText:SetPoint("RIGHT", btn, "RIGHT", -120, 0)
            nameText:SetJustifyH("LEFT")
            nameText:SetText(setData.name)
            
            if setData.collected then
                nameText:SetTextColor(1, 1, 1, 1)
            else
                nameText:SetTextColor(0.6, 0.6, 0.6, 1)
            end

            -- Expansion name
            local expText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            expText:SetPoint("RIGHT", btn, "RIGHT", -40, 0)
            expText:SetText(expansionNames[setData.expansionID] or "Unknown")
            expText:SetTextColor(0.8, 0.8, 0.8, 1)

            -- Set ID
            local idText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            idText:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
            idText:SetText(tostring(setData.setID))
            idText:SetTextColor(0.6, 0.6, 0.6, 1)

            -- Store set data
            btn.setData = setData

            -- Click handler
            btn:SetScript("OnClick", function()
                -- Clear previous selection
                if picker.selectedButton then
                    picker.selectedButton:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
                end

                -- Select this set
                picker.selectedSetID = setData.setID
                picker.selectedButton = btn
                btn:SetBackdropColor(0.2, 0.4, 0.2, 0.8)
                addBtn:SetEnabled(true)
            end)

            -- Hover effects
            btn:SetScript("OnEnter", function(self)
                if self ~= picker.selectedButton then
                    self:SetBackdropColor(0.2, 0.2, 0.2, 0.8)
                end
                
                -- Show set preview in tooltip
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(setData.name, 1, 1, 1)
                if expansionNames[setData.expansionID] then
                    GameTooltip:AddLine(expansionNames[setData.expansionID], 0.8, 0.8, 0.8)
                end
                GameTooltip:AddLine("Set ID: " .. setData.setID, 0.6, 0.6, 0.6)
                if setData.collected then
                    GameTooltip:AddLine("Collected", 0.5, 1, 0.5)
                else
                    GameTooltip:AddLine("Not collected", 1, 0.5, 0.5)
                end
                GameTooltip:Show()
            end)

            btn:SetScript("OnLeave", function(self)
                if self ~= picker.selectedButton then
                    self:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
                end
                GameTooltip:Hide()
            end)

            picker.setButtons[i] = btn
        end

        -- Update content height
        local contentHeight = math.max(#filteredSets * 32, 1)
        setContent:SetHeight(contentHeight)

        -- Manage scrollbar
        if setScroll.ScrollBar then
            if contentHeight > setScroll:GetHeight() then
                setScroll.ScrollBar:Show()
            else
                setScroll.ScrollBar:Hide()
                setScroll:SetVerticalScroll(0)
            end
        end
    end

    -- Search functionality
    searchBox:SetScript("OnTextChanged", function(self)
        PopulateSetList()
    end)

    -- Collection filter
    collectedCheck:SetScript("OnClick", function(self)
        PopulateSetList()
    end)

    -- Add button functionality
    addBtn:SetScript("OnClick", function()
        if picker.selectedSetID and parentDialog.targetPack then
            EnsureConditions(parentDialog.targetPack)
            table.insert(parentDialog.targetPack.conditions, {
                type = "transmog",
                setID = picker.selectedSetID,
                priority = MountieDB.settings.rulePriorities.transmog or 100,
            })

            local setInfo = Mountie.GetTransmogSetInfo(picker.selectedSetID)
            local setName = setInfo and setInfo.name or ("Set " .. picker.selectedSetID)
            Mountie.Print("Added transmog rule: " .. setName)

            RebuildRulesList(parentDialog.rulesList, parentDialog.targetPack)
            C_Timer.After(0.1, Mountie.SelectActivePack)
            
            -- Refresh pack panel
            if _G.MountieMainFrame and _G.MountieMainFrame.packPanel and _G.MountieMainFrame.packPanel.refreshPacks then
                _G.MountieMainFrame.packPanel.refreshPacks()
            end
            
            picker:Hide()
        end
    end)

    -- OnShow: populate list and reset selection
    picker:SetScript("OnShow", function(self)
        self.selectedSetID = nil
        self.selectedButton = nil
        addBtn:SetEnabled(false)
        searchBox:SetText("")
        PopulateSetList()
    end)

    picker:Hide()
    table.insert(UISpecialFrames, "MountieTransmogPicker")
    return picker
end

Mountie.Debug("UI/RulesDialog.lua loaded")