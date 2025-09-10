-- Mountie: Rules Dialog
Mountie.Debug("UI/RulesDialog.lua loading...")

local rulesDialog -- singleton-ish

-- Ensure pack.conditions exists
local function EnsureConditions(pack)
    pack.conditions = pack.conditions or {}
end

local function UpdateZoneDisplay(dlg)
    if not dlg.zoneText then return end
    
    -- Try multiple methods to get the current zone
    local currentMapID = C_Map.GetBestMapForUnit("player")
    local zoneName = nil
    
    -- First try the standard API
    if currentMapID then
        local mapInfo = C_Map.GetMapInfo(currentMapID)
        if mapInfo and mapInfo.name then
            zoneName = mapInfo.name
            Mountie.Debug("Zone detected via GetBestMapForUnit: " .. zoneName)
        else
            Mountie.Debug("Got map ID " .. currentMapID .. " but no map info available")
        end
    end
    
    -- Fallback methods for when the main API fails (common after UI reload)
    if not zoneName then
        -- Try GetRealZoneText
        local realZone = GetRealZoneText()
        if realZone and realZone ~= "" then
            zoneName = realZone
            Mountie.Debug("Zone detected via GetRealZoneText: " .. zoneName)
        end
    end
    
    if not zoneName then
        -- Try GetZoneText as another fallback
        local zoneText = GetZoneText()
        if zoneText and zoneText ~= "" then
            zoneName = zoneText
            Mountie.Debug("Zone detected via GetZoneText: " .. zoneName)
        end
    end
    
    if not zoneName then
        -- Try GetSubZoneText as a last resort
        local subZone = GetSubZoneText()
        if subZone and subZone ~= "" then
            zoneName = subZone .. " (subzone)"
            Mountie.Debug("Zone detected via GetSubZoneText: " .. zoneName)
        end
    end
    
    -- If we found a zone name, display it
    if zoneName then
        dlg.zoneText:SetText(zoneName)
        return
    end
    
    -- If no zone detected, show "Unknown" and start retry process
    dlg.zoneText:SetText("Unknown")
    Mountie.Debug("Zone display set to Unknown - no zone info available via any method")
    
    -- More aggressive retry strategy for cases where zone isn't immediately available (like after UI reload)
    local retryAttempts = 0
    local maxRetries = 10
    local retryTimer
    
    local function RetryZoneDetection()
        retryAttempts = retryAttempts + 1
        if retryAttempts > maxRetries or not dlg:IsShown() then
            if retryTimer then
                retryTimer:Cancel()
            end
            Mountie.Debug("Zone detection gave up after " .. retryAttempts .. " attempts")
            return
        end
        
        -- Try all methods again
        local foundZone = nil
        
        local retryMapID = C_Map.GetBestMapForUnit("player")
        if retryMapID then
            local retryMapInfo = C_Map.GetMapInfo(retryMapID)
            if retryMapInfo and retryMapInfo.name then
                foundZone = retryMapInfo.name
                Mountie.Debug("Zone found on retry " .. retryAttempts .. " via GetBestMapForUnit: " .. foundZone)
            end
        end
        
        if not foundZone then
            local realZone = GetRealZoneText()
            if realZone and realZone ~= "" then
                foundZone = realZone
                Mountie.Debug("Zone found on retry " .. retryAttempts .. " via GetRealZoneText: " .. foundZone)
            end
        end
        
        if not foundZone then
            local zoneText = GetZoneText()
            if zoneText and zoneText ~= "" then
                foundZone = zoneText
                Mountie.Debug("Zone found on retry " .. retryAttempts .. " via GetZoneText: " .. foundZone)
            end
        end
        
        if foundZone then
            dlg.zoneText:SetText(foundZone)
            if retryTimer then
                retryTimer:Cancel()
            end
            return
        else
            Mountie.Debug("Retry " .. retryAttempts .. ": Still no zone info available")
        end
    end
    
    -- Start with immediate retry, then every 1 second for up to 10 seconds
    C_Timer.After(0.5, RetryZoneDetection)
    retryTimer = C_Timer.NewTicker(1, RetryZoneDetection)
end

-- Build the visible list of rules inside the dialog
local function RebuildRulesList(container, pack)
    Mountie.Debug("RebuildRulesList called for pack: " .. (pack.name or "unknown"))
    
    -- clear
    if container.ruleRows then
        for _, row in ipairs(container.ruleRows) do
            row:Hide()
            row:SetParent(nil)
        end
    end
    container.ruleRows = {}

    EnsureConditions(pack)
    Mountie.Debug("Pack has " .. #pack.conditions .. " conditions")
    
    local y = -10
    for i, rule in ipairs(pack.conditions) do
        local row = CreateFrame("Frame", nil, container)
        -- Increase height for custom transmog rules that have two lines of text
        local rowHeight = (rule.type == "custom_transmog") and 35 or 22
        row:SetSize(360, rowHeight)
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
            
            -- Add "Apply Set" button for transmog rules
            local applyBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            applyBtn:SetSize(80, 18)
            applyBtn:SetPoint("RIGHT", row, "RIGHT", -5, 0)
            applyBtn:SetText("Apply Set")
            
            -- Tooltip for apply button
            applyBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Apply Transmog Set", 1, 1, 1, 1, true)
                if C_Transmog.IsAtTransmogNPC() then
                    GameTooltip:AddLine("Click to apply this transmog set immediately.", 1, 1, 0.8, true)
                    GameTooltip:AddLine("Set: " .. setName, 0.8, 0.8, 1, true)
                else
                    GameTooltip:AddLine("Must be at a transmog vendor to apply sets.", 1, 0.5, 0.5, true)
                end
                GameTooltip:Show()
            end)
            applyBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            
            -- Enable/disable based on vendor status
            applyBtn:SetEnabled(C_Transmog.IsAtTransmogNPC())
            
            -- Apply button click handler
            applyBtn:SetScript("OnClick", function()
                if not C_Transmog.IsAtTransmogNPC() then
                    Mountie.Print("Must be at a transmog vendor to apply sets")
                    return
                end
                
                local success, message = Mountie.ApplyTransmogSet(rule.setID)
                Mountie.Print(message)
            end)
            
        elseif rule.type == "custom_transmog" then
            local transmogName = rule.transmogName or "Custom Transmog"
            local strictness = rule.strictness or 6
            local weaponsText = rule.includeWeapons and " +Weapons" or ""
            text:SetText(string.format("Custom Transmog: %s\n(Strictness: %d%s)", transmogName, strictness, weaponsText))
        else
            text:SetText("Unknown rule type")
        end

        -- Add strictness slider and weapon checkbox for custom transmog rules
        local strictnessSlider, weaponCheckbox
        if rule.type == "custom_transmog" then
            -- Weapon inclusion checkbox
            weaponCheckbox = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
            weaponCheckbox:SetSize(16, 16)
            weaponCheckbox:SetPoint("RIGHT", row, "RIGHT", -130, 0)
            weaponCheckbox:SetChecked(rule.includeWeapons or false)
            
            -- Weapon checkbox tooltip
            weaponCheckbox:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Include Weapons", 1, 1, 1, 1, true)
                GameTooltip:AddLine("Check to include weapon appearances in transmog matching.", 1, 1, 0.8, true)
                GameTooltip:AddLine("Uncheck to match armor only (weapons ignored).", 1, 1, 0.8, true)
                GameTooltip:Show()
            end)
            weaponCheckbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
            
            -- Update rule when checkbox changes
            weaponCheckbox:SetScript("OnClick", function(self)
                rule.includeWeapons = self:GetChecked()
                
                -- Adjust slider max value based on weapon inclusion
                local newMax = rule.includeWeapons and 13 or 11
                strictnessSlider:SetMinMaxValues(1, newMax)
                
                -- Adjust strictness if it's now too high
                if rule.strictness > newMax then
                    rule.strictness = newMax
                    strictnessSlider:SetValue(newMax)
                end
                
                -- Update display text
                local transmogName = rule.transmogName or "Custom Transmog"
                local strictness = rule.strictness or 6
                local weaponsText = rule.includeWeapons and " +Weapons" or ""
                text:SetText(string.format("Custom Transmog: %s\n(Strictness: %d%s)", transmogName, strictness, weaponsText))
                -- Re-evaluate packs
                C_Timer.After(0.1, Mountie.SelectActivePack)
            end)
            
            strictnessSlider = CreateFrame("Slider", nil, row, "OptionsSliderTemplate")
            strictnessSlider:SetSize(80, 20)
            strictnessSlider:SetPoint("RIGHT", row, "RIGHT", -50, 0)
            strictnessSlider:SetMinMaxValues(1, rule.includeWeapons and 13 or 11)
            strictnessSlider:SetValue(rule.strictness or 6)
            strictnessSlider:SetValueStep(1)
            strictnessSlider:SetObeyStepOnDrag(true)
            
            -- Add tooltip explaining strictness
            strictnessSlider:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Transmog Strictness", 1, 1, 1, 1, true)
                local maxSlots = rule.includeWeapons and 13 or 11
                local slotType = rule.includeWeapons and "armor + weapon pieces" or "armor pieces"
                GameTooltip:AddLine("How many " .. slotType .. " must match for this rule to activate:", 1, 1, 0.8, true)
                GameTooltip:AddLine(" ")
                if rule.includeWeapons then
                    GameTooltip:AddLine("1-4: Very loose (any few pieces)", 0.8, 1, 0.8)
                    GameTooltip:AddLine("5-8: Moderate (most pieces)", 1, 1, 0.8)
                    GameTooltip:AddLine("9-11: Strict (almost all pieces)", 1, 0.8, 0.8)
                    GameTooltip:AddLine("12-13: Perfect (all/nearly all pieces)", 1, 0.6, 0.6)
                else
                    GameTooltip:AddLine("1-3: Very loose (any few pieces)", 0.8, 1, 0.8)
                    GameTooltip:AddLine("4-6: Moderate (most pieces)", 1, 1, 0.8)
                    GameTooltip:AddLine("7-9: Strict (almost all pieces)", 1, 0.8, 0.8)
                    GameTooltip:AddLine("10-11: Perfect (all/nearly all pieces)", 1, 0.6, 0.6)
                end
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Current: " .. math.floor(self:GetValue()) .. " pieces must match", 1, 1, 1)
                GameTooltip:Show()
            end)
            strictnessSlider:SetScript("OnLeave", function() GameTooltip:Hide() end)
            
            -- Update the rule when slider changes
            strictnessSlider:SetScript("OnValueChanged", function(self, value)
                local newStrictness = math.floor(value)
                rule.strictness = newStrictness
                -- Update the display text
                local transmogName = rule.transmogName or "Custom Transmog"
                local weaponsText = rule.includeWeapons and " +Weapons" or ""
                text:SetText(string.format("Custom Transmog: %s\n(Strictness: %d%s)", transmogName, newStrictness, weaponsText))
                -- Re-evaluate packs
                C_Timer.After(0.1, Mountie.SelectActivePack)
                
                -- Update tooltip if it's showing
                if GameTooltip:IsOwned(self) then
                    GameTooltip:SetText("Transmog Strictness", 1, 1, 1, 1, true)
                    local slotType = rule.includeWeapons and "armor + weapon pieces" or "armor pieces"
                    GameTooltip:AddLine("How many " .. slotType .. " must match for this rule to activate:", 1, 1, 0.8, true)
                    GameTooltip:AddLine(" ")
                    if rule.includeWeapons then
                        GameTooltip:AddLine("1-4: Very loose (any few pieces)", 0.8, 1, 0.8)
                        GameTooltip:AddLine("5-8: Moderate (most pieces)", 1, 1, 0.8)
                        GameTooltip:AddLine("9-11: Strict (almost all pieces)", 1, 0.8, 0.8)
                        GameTooltip:AddLine("12-13: Perfect (all/nearly all pieces)", 1, 0.6, 0.6)
                    else
                        GameTooltip:AddLine("1-3: Very loose (any few pieces)", 0.8, 1, 0.8)
                        GameTooltip:AddLine("4-6: Moderate (most pieces)", 1, 1, 0.8)
                        GameTooltip:AddLine("7-9: Strict (almost all pieces)", 1, 0.8, 0.8)
                        GameTooltip:AddLine("10-11: Perfect (all/nearly all pieces)", 1, 0.6, 0.6)
                    end
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("Current: " .. newStrictness .. " pieces must match", 1, 1, 1)
                    GameTooltip:Show()
                end
            end)
        end

        local del = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        del:SetSize(22, 18)
        del:SetPoint("RIGHT", row, "RIGHT", (strictnessSlider and weaponCheckbox) and -155 or 0, 0)
        del:SetText("X")
        del:SetScript("OnClick", function()
            if Mountie.TableRemoveByIndex(pack.conditions, i) then
                Mountie.VerbosePrint("Removed rule.")
                RebuildRulesList(container, pack)
                -- Refresh the pack panel to show updated rule count
                if _G.MountieMainFrame and _G.MountieMainFrame.packPanel and _G.MountieMainFrame.packPanel.refreshPacks then
                    _G.MountieMainFrame.packPanel.refreshPacks()
                end
            end
        end)

        container.ruleRows[#container.ruleRows+1] = row
        row:Show() -- Explicitly show the row
        Mountie.Debug("Created rule row " .. i .. ": " .. text:GetText())
        -- Use different spacing based on row height
        y = y - (rowHeight + 2)
    end

    -- Update content height and manage scrollbar visibility
    local totalHeight = 20 -- Base padding
    for _, rule in ipairs(pack.conditions) do
        local ruleHeight = (rule.type == "custom_transmog") and 37 or 26 -- Row height + spacing
        totalHeight = totalHeight + ruleHeight
    end
    local contentHeight = math.max(totalHeight, 1)
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
    
    Mountie.Debug("RebuildRulesList completed, created " .. #container.ruleRows .. " rule rows")
    
    -- Force a UI update to ensure everything renders
    if container.GetParent and container:GetParent() then
        local parent = container:GetParent()
        if parent.GetParent and parent:GetParent() then
            local grandparent = parent:GetParent()
            if grandparent.Show then
                -- Force the dialog to refresh its layout
                C_Timer.After(0.01, function()
                    container:Show()
                    if scrollFrame then scrollFrame:Show() end
                end)
            end
        end
    end
end

-- Public API
function MountieUI.ShowRulesDialog(pack)
    Mountie.Debug("ShowRulesDialog called for pack: " .. (pack and pack.name or "nil"))
    
    if not rulesDialog then
        Mountie.Debug("Creating new rules dialog")
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
        zoneLabel:SetPoint("TOPLEFT", dlg.packNameText, "BOTTOMLEFT", 0, -15)
        zoneLabel:SetText("Current Zone:")

        local zoneText = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        zoneText:SetPoint("LEFT", zoneLabel, "RIGHT", 8, 0)
        zoneText:SetText("Unknown")
        dlg.zoneText = zoneText -- Store reference for updates

        -- "Match parent zones" checkbox
        local parentCheck = CreateFrame("CheckButton", nil, dlg, "UICheckButtonTemplate")
        parentCheck:SetPoint("TOPLEFT", zoneLabel, "BOTTOMLEFT", 0, -10)
        parentCheck.text = parentCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        parentCheck.text:SetPoint("LEFT", parentCheck, "RIGHT", 4, 0)
        parentCheck.text:SetText("Also match parent zones (continent/region)")

        -- Zone buttons row
        local addCurrentBtn = CreateFrame("Button", nil, dlg, "UIPanelButtonTemplate")
        addCurrentBtn:SetSize(120, 22)
        addCurrentBtn:SetPoint("TOPLEFT", parentCheck, "BOTTOMLEFT", 0, -10)
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
            Mountie.VerbosePrint("Added zone rule.")
            RebuildRulesList(dlg.rulesList, dlg.targetPack)
            -- Immediately re-evaluate active pack
            C_Timer.After(0.1, Mountie.SelectActivePack)
            -- Refresh the pack panel to show updated rule count
            if _G.MountieMainFrame and _G.MountieMainFrame.packPanel and _G.MountieMainFrame.packPanel.refreshPacks then
                _G.MountieMainFrame.packPanel.refreshPacks()
            end
        end)

        local browseBtn = CreateFrame("Button", nil, dlg, "UIPanelButtonTemplate")
        browseBtn:SetSize(100, 22)
        browseBtn:SetPoint("LEFT", addCurrentBtn, "RIGHT", 10, 0)
        browseBtn:SetText("Browse Zones")
        browseBtn:SetScript("OnClick", function()
            if dlg.zonePicker then
                dlg.zonePicker:Show()
            else
                dlg.zonePicker = MountieUI.CreateZonePicker(dlg)
                dlg.zonePicker:Show()
            end
        end)

        -- Current transmog display (moved down with more spacing)
        local transmogLabel = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        transmogLabel:SetPoint("TOPLEFT", addCurrentBtn, "BOTTOMLEFT", 0, -20)
        transmogLabel:SetText("Current Transmog:")

        local transmogText = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        transmogText:SetPoint("LEFT", transmogLabel, "RIGHT", 8, 0)
        transmogText:SetText("None detected")

        -- Transmog buttons row (properly spaced below transmog label)
        local addTransmogBtn = CreateFrame("Button", nil, dlg, "UIPanelButtonTemplate")
        addTransmogBtn:SetSize(150, 22)
        addTransmogBtn:SetPoint("TOPLEFT", transmogLabel, "BOTTOMLEFT", 0, -10)
        addTransmogBtn:SetText("Add Current Transmog")
        
        local addExistingBtn = CreateFrame("Button", nil, dlg, "UIPanelButtonTemplate")
        addExistingBtn:SetSize(150, 22)
        addExistingBtn:SetPoint("LEFT", addTransmogBtn, "RIGHT", 10, 0)
        addExistingBtn:SetText("Add Existing Transmog")
        
        addExistingBtn:SetScript("OnClick", function()
            if not dlg.targetPack then return end
            
            -- Find all existing custom transmog rules across all packs
            local existingTransmogs = {}
            local allPacks = Mountie.GetCharacterPacks()
            
            for _, pack in ipairs(allPacks) do
                if pack.conditions then
                    for _, condition in ipairs(pack.conditions) do
                        if condition.type == "custom_transmog" and condition.transmogName and condition.appearance then
                            -- Avoid duplicates by checking if we already have this transmog name
                            local found = false
                            for _, existing in ipairs(existingTransmogs) do
                                if existing.transmogName == condition.transmogName then
                                    found = true
                                    break
                                end
                            end
                            if not found then
                                table.insert(existingTransmogs, {
                                    transmogName = condition.transmogName,
                                    appearance = condition.appearance,
                                    includeWeapons = condition.includeWeapons,
                                    strictness = condition.strictness
                                })
                            end
                        end
                    end
                end
            end
            
            if #existingTransmogs == 0 then
                Mountie.Print("No existing custom transmog rules found. Create one first with 'Add Current Transmog'.")
                return
            end
            
            -- Create selection dialog
            local selectDialog = CreateFrame("Frame", nil, dlg, "BasicFrameTemplateWithInset")
            selectDialog:SetSize(350, 300)
            selectDialog:SetPoint("CENTER", dlg, "CENTER", 0, 0)
            selectDialog:SetFrameStrata("DIALOG")
            selectDialog:SetFrameLevel(dlg:GetFrameLevel() + 10)
            selectDialog.TitleText:SetText("Select Existing Transmog")
            
            local selectLabel = selectDialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            selectLabel:SetPoint("TOPLEFT", selectDialog, "TOPLEFT", 15, -35)
            selectLabel:SetText("Choose a transmog rule to copy:")
            
            -- Create scroll frame for transmog list
            local scrollFrame = CreateFrame("ScrollFrame", nil, selectDialog, "UIPanelScrollFrameTemplate")
            scrollFrame:SetPoint("TOPLEFT", selectLabel, "BOTTOMLEFT", 0, -10)
            scrollFrame:SetPoint("BOTTOMRIGHT", selectDialog, "BOTTOMRIGHT", -28, 50)
            
            local scrollContent = CreateFrame("Frame", nil, scrollFrame)
            scrollContent:SetSize(300, 1)
            scrollFrame:SetScrollChild(scrollContent)
            
            -- Create transmog selection buttons
            local yPos = -5
            for i, transmog in ipairs(existingTransmogs) do
                local btn = CreateFrame("Button", nil, scrollContent, "UIPanelButtonTemplate")
                btn:SetSize(280, 22)
                btn:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, yPos)
                
                local weaponText = transmog.includeWeapons and " +Weapons" or ""
                btn:SetText(string.format("%s (Strictness: %d%s)", transmog.transmogName, transmog.strictness or 6, weaponText))
                
                btn:SetScript("OnClick", function()
                    -- Add the selected transmog rule to current pack
                    EnsureConditions(dlg.targetPack)
                    table.insert(dlg.targetPack.conditions, {
                        type = "custom_transmog",
                        appearance = transmog.appearance,
                        transmogName = transmog.transmogName,
                        includeWeapons = transmog.includeWeapons,
                        strictness = transmog.strictness,
                        priority = MountieDB.settings.rulePriorities.transmog or 100,
                    })
                    
                    Mountie.VerbosePrint("Added existing transmog rule: " .. transmog.transmogName)
                    
                    RebuildRulesList(dlg.rulesList, dlg.targetPack)
                    C_Timer.After(0.1, Mountie.SelectActivePack)
                    
                    -- Refresh pack panel
                    if _G.MountieMainFrame and _G.MountieMainFrame.packPanel and _G.MountieMainFrame.packPanel.refreshPacks then
                        _G.MountieMainFrame.packPanel.refreshPacks()
                    end
                    
                    selectDialog:Hide()
                end)
                
                yPos = yPos - 25
            end
            
            -- Set scroll content height
            scrollContent:SetHeight(math.max(#existingTransmogs * 25 + 10, 1))
            
            -- Close button
            local closeBtn = CreateFrame("Button", nil, selectDialog, "UIPanelButtonTemplate")
            closeBtn:SetSize(60, 22)
            closeBtn:SetPoint("BOTTOM", selectDialog, "BOTTOM", 0, 15)
            closeBtn:SetText("Cancel")
            closeBtn:SetScript("OnClick", function() selectDialog:Hide() end)
            
            selectDialog:Show()
        end)
        
        addTransmogBtn:SetScript("OnClick", function()
            if not dlg.targetPack then return end
            
            -- Create input dialog for transmog name
            local inputDialog = CreateFrame("Frame", nil, dlg, "BasicFrameTemplateWithInset")
            inputDialog:SetSize(300, 120)
            inputDialog:SetPoint("CENTER", dlg, "CENTER", 0, 0)
            inputDialog:SetFrameStrata("DIALOG")
            inputDialog:SetFrameLevel(dlg:GetFrameLevel() + 10)
            inputDialog.TitleText:SetText("Name Your Transmog")
            
            local inputLabel = inputDialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            inputLabel:SetPoint("TOPLEFT", inputDialog, "TOPLEFT", 15, -35)
            inputLabel:SetText("Enter a name for this transmog:")
            
            local inputBox = CreateFrame("EditBox", nil, inputDialog, "InputBoxTemplate")
            inputBox:SetSize(200, 20)
            inputBox:SetPoint("TOPLEFT", inputLabel, "BOTTOMLEFT", 0, -10)
            inputBox:SetText("My Transmog")
            inputBox:SetAutoFocus(true)
            inputBox:HighlightText()
            
            local okBtn = CreateFrame("Button", nil, inputDialog, "UIPanelButtonTemplate")
            okBtn:SetSize(60, 22)
            okBtn:SetPoint("BOTTOMLEFT", inputDialog, "BOTTOMLEFT", 15, 15)
            okBtn:SetText("OK")
            
            local cancelBtn = CreateFrame("Button", nil, inputDialog, "UIPanelButtonTemplate")
            cancelBtn:SetSize(60, 22)
            cancelBtn:SetPoint("LEFT", okBtn, "RIGHT", 10, 0)
            cancelBtn:SetText("Cancel")
            
            local function addTransmogRule()
                local transmogName = inputBox:GetText()
                if transmogName == "" then transmogName = "My Transmog" end
                
                -- Capture current appearance using our new system
                local appearance = Mountie.CaptureCurrentAppearance(false)
                if not appearance or not next(appearance) then
                    Mountie.Print("Could not capture current transmog appearance.")
                    Mountie.Print("Visit a Transmogrifier vendor and open the transmog UI once to initialize the system.")
                    inputDialog:Hide()
                    return
                end
                
                -- Count filled slots for user feedback
                local filledSlots = 0
                for slot, appearanceID in pairs(appearance) do
                    if appearanceID then filledSlots = filledSlots + 1 end
                end
                
                -- Add custom transmog rule
                EnsureConditions(dlg.targetPack)
                table.insert(dlg.targetPack.conditions, {
                    type = "custom_transmog",
                    appearance = appearance,
                    transmogName = transmogName,
                    includeWeapons = false,
                    strictness = 6, -- Default strictness
                    priority = MountieDB.settings.rulePriorities.transmog or 100,
                })
                
                Mountie.VerbosePrint("Added custom transmog rule '" .. transmogName .. "' (" .. filledSlots .. " slots captured)")
                
                RebuildRulesList(dlg.rulesList, dlg.targetPack)
                C_Timer.After(0.1, Mountie.SelectActivePack)
                
                -- Refresh pack panel
                if _G.MountieMainFrame and _G.MountieMainFrame.packPanel and _G.MountieMainFrame.packPanel.refreshPacks then
                    _G.MountieMainFrame.packPanel.refreshPacks()
                end
                
                inputDialog:Hide()
            end
            
            okBtn:SetScript("OnClick", addTransmogRule)
            cancelBtn:SetScript("OnClick", function() inputDialog:Hide() end)
            inputBox:SetScript("OnEnterPressed", addTransmogRule)
            inputBox:SetScript("OnEscapePressed", function() inputDialog:Hide() end)
            
            inputDialog:Show()
        end)

        -- Rules list container (moved down with proper spacing)
        local listLabel = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        listLabel:SetPoint("TOPLEFT", addTransmogBtn, "BOTTOMLEFT", 0, -20)
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

        -- Zone change event handler for immediate updates
        local function OnZoneChanged()
            if dlg:IsShown() then
                UpdateZoneDisplay(dlg)
            end
        end
        
        -- OnShow: refresh current zone and transmog info and list
        dlg:SetScript("OnShow", function(self)
            Mountie.Debug("Rules dialog OnShow called")
            
            -- Update zone display using the robust zone detection
            UpdateZoneDisplay(self)
            
            -- Additional zone update attempts for UI reload scenarios
            C_Timer.After(1, function()
                if self:IsShown() then
                    UpdateZoneDisplay(self)
                end
            end)
            C_Timer.After(3, function()
                if self:IsShown() then
                    UpdateZoneDisplay(self)
                end
            end)
            
            -- Update current transmog display
            local currentSetID = Mountie.GetCurrentTransmogSetID()
            if currentSetID then
                local setInfo = Mountie.GetTransmogSetInfo(currentSetID)
                local setName = setInfo and setInfo.name or ("Set " .. currentSetID)
                self.transmogText:SetText(setName)
                self.addTransmogBtn:SetEnabled(true)
            else
                -- Check if we can at least capture current appearance for custom transmog
                local appearance = Mountie.CaptureCurrentAppearance(false)
                local filledSlots = 0
                if appearance then
                    for slot, appearanceID in pairs(appearance) do
                        if appearanceID then filledSlots = filledSlots + 1 end
                    end
                end
                
                if filledSlots >= 3 then
                    self.transmogText:SetText("Custom transmog (" .. filledSlots .. " pieces)")
                    self.addTransmogBtn:SetEnabled(true)
                else
                    self.transmogText:SetText("None detected")
                    self.addTransmogBtn:SetEnabled(false)
                end
            end
            
            if self.targetPack then
                Mountie.Debug("Target pack found: " .. self.targetPack.name)
                self.packNameText:SetText(self.targetPack.name)
                RebuildRulesList(self.rulesList, self.targetPack)
            else
                Mountie.Debug("No target pack found!")
            end
            
            -- Register for zone change events when dialog is shown
            if not self.zoneEventFrame then
                self.zoneEventFrame = CreateFrame("Frame")
                self.zoneEventFrame:SetScript("OnEvent", function(frame, event, ...)
                    OnZoneChanged()
                end)
            end
            
            -- Register zone change events
            self.zoneEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
            self.zoneEventFrame:RegisterEvent("ZONE_CHANGED")
            self.zoneEventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
            self.zoneEventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
            
            -- Set up periodic zone updates while dialog is open (as fallback)
            if not self.zoneUpdateTimer then
                self.zoneUpdateTimer = C_Timer.NewTicker(5, function()
                    if self:IsShown() then
                        UpdateZoneDisplay(self)
                    end
                end)
            end
        end)
        
        -- OnHide: clean up the zone update timer and event handlers
        dlg:SetScript("OnHide", function(self)
            if self.zoneUpdateTimer then
                self.zoneUpdateTimer:Cancel()
                self.zoneUpdateTimer = nil
            end
            
            -- Unregister zone change events when dialog is hidden
            if self.zoneEventFrame then
                self.zoneEventFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
                self.zoneEventFrame:UnregisterEvent("ZONE_CHANGED")
                self.zoneEventFrame:UnregisterEvent("ZONE_CHANGED_NEW_AREA")
                self.zoneEventFrame:UnregisterEvent("ZONE_CHANGED_INDOORS")
            end
        end)

        rulesDialog = dlg
    end

    Mountie.Debug("Setting target pack and showing dialog")
    rulesDialog.targetPack = pack
    rulesDialog:Show()
    
    -- Force initial zone detection and rules list update if this is the first time showing
    -- (OnShow might not fire on initial creation, and we need zone detection before RebuildRulesList)
    if pack then
        C_Timer.After(0.01, function()
            if rulesDialog.targetPack and rulesDialog:IsShown() then
                Mountie.Debug("Forcing initial zone detection and RebuildRulesList")
                -- Run zone detection first
                UpdateZoneDisplay(rulesDialog)
                -- Then rebuild the rules list
                RebuildRulesList(rulesDialog.rulesList, rulesDialog.targetPack)
            end
        end)
        
        -- Additional update after a longer delay to handle cases where zone info takes time to become available
        C_Timer.After(1, function()
            if rulesDialog.targetPack and rulesDialog:IsShown() then
                Mountie.Debug("Secondary zone detection update")
                UpdateZoneDisplay(rulesDialog)
            end
        end)
    end
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
            Mountie.VerbosePrint("Added zone rule: " .. zoneName)
            
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
    expansionFilter:SetPoint("LEFT", filterLabel, "RIGHT", 5, -2)
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

    -- Apply Set button
    local applyBtn = CreateFrame("Button", nil, picker, "UIPanelButtonTemplate")
    applyBtn:SetSize(80, 25)
    applyBtn:SetPoint("RIGHT", addBtn, "LEFT", -10, 0)
    applyBtn:SetText("Apply Set")
    applyBtn:SetEnabled(false)
    
    -- Tooltip for apply button
    applyBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Apply Transmog Set", 1, 1, 1, 1, true)
        if picker.selectedSetID then
            local setInfo = Mountie.GetTransmogSetInfo(picker.selectedSetID)
            local setName = setInfo and setInfo.name or ("Set " .. picker.selectedSetID)
            if C_Transmog.IsAtTransmogNPC() then
                GameTooltip:AddLine("Apply '" .. setName .. "' immediately.", 1, 1, 0.8, true)
            else
                GameTooltip:AddLine("Must be at a transmog vendor.", 1, 0.5, 0.5, true)
                GameTooltip:AddLine("Set: " .. setName, 0.8, 0.8, 1, true)
            end
        else
            GameTooltip:AddLine("Select a set first.", 0.8, 0.8, 0.8, true)
        end
        GameTooltip:Show()
    end)
    applyBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    -- Apply button click handler
    applyBtn:SetScript("OnClick", function()
        if not picker.selectedSetID then
            Mountie.Print("Please select a transmog set first")
            return
        end
        
        if not C_Transmog.IsAtTransmogNPC() then
            Mountie.Print("Must be at a transmog vendor to apply sets")
            return
        end
        
        local success, message = Mountie.ApplyTransmogSet(picker.selectedSetID)
        Mountie.Print(message)
        
        if success then
            picker:Hide()
        end
    end)

    -- Cancel button
    local cancelBtn = CreateFrame("Button", nil, picker, "UIPanelButtonTemplate")
    cancelBtn:SetSize(80, 25)
    cancelBtn:SetPoint("RIGHT", applyBtn, "LEFT", -10, 0)
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
                applyBtn:SetEnabled(true)
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
            Mountie.VerbosePrint("Added transmog rule: " .. setName)

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
        applyBtn:SetEnabled(false)
        searchBox:SetText("")
        PopulateSetList()
    end)

    picker:Hide()
    table.insert(UISpecialFrames, "MountieTransmogPicker")
    return picker
end

Mountie.Debug("UI/RulesDialog.lua loaded")