-- Mountie: Pack Panel UI
Mountie.Debug("UI/PackPanel.lua loading...")

function MountieUI.SetupPackPanel(packPanel)
    -- Pack panel title
    local packTitle = packPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    packTitle:SetPoint("TOP", packPanel, "TOP", 0, -15)
    packTitle:SetText("Mount Packs")
    
    -- Create New Pack button
    local createPackButton = CreateFrame("Button", nil, packPanel, "UIPanelButtonTemplate")
    createPackButton:SetSize(120, 25)
    createPackButton:SetPoint("TOP", packTitle, "BOTTOM", 0, -15)
    createPackButton:SetText("Create New Pack")
    
    -- Create pack list
    local packList = MountieUI.CreatePackList(packPanel)
    
    -- Store reference to dialog
    local packDialog = nil
    
    createPackButton:SetScript("OnClick", function()
        if not packDialog then
            packDialog = MountieUI.CreatePackDialog()
        end
        packDialog:Show()
    end)
    
    -- Refresh function for pack list with escape handling
    local function refreshPacks()
        if packList then
            -- Clean up any temporary expanded frame
            local content = packList.content
            if content.tempExpandedFrame then
                content.tempExpandedFrame:Hide()
                content.tempExpandedFrame:SetParent(nil)
                content.tempExpandedFrame = nil
            end
            
            -- Get current packs
            local packs = Mountie.ListPacks()
            
            -- Clear existing frames
            local packFrames = packList.packFrames
            for i, frame in ipairs(packFrames) do
                if frame then
                    frame:Hide()
                    frame:SetParent(nil)
                end
            end
            packFrames = {}
            packList.packFrames = packFrames
            
            -- Create new frames
            for i, pack in ipairs(packs) do
                local frame = MountieUI.CreatePackFrame(content, pack)
                frame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i-1) * 70)
                packFrames[i] = frame
                frame:Show()
            end
            
            -- Update content height
            local contentHeight = math.max(#packs * 70, 1)
            content:SetHeight(contentHeight)
            
            -- Reset scroll position
            local scrollFrame = content:GetParent()
            if scrollFrame and scrollFrame.SetVerticalScroll then
                scrollFrame:SetVerticalScroll(0)
            end
        end
    end
    
    -- Store references
    packPanel.createPackButton = createPackButton
    packPanel.packList = packList
    packPanel.refreshPacks = refreshPacks
    
    -- Also store a test function to verify the reference works
    packPanel.testFunction = function()
        Mountie.Debug("Test function called successfully")
        refreshPacks()
    end
end

function MountieUI.CreatePackList(parent)
    -- Create scroll frame for packs
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -75) -- Below the create button
    scrollFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -30, 10)
    
    -- Create content frame
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(320, 1)
    scrollFrame:SetScrollChild(content)
    
    -- Store references
    scrollFrame.content = content
    scrollFrame.packFrames = {}
    
    return scrollFrame
end

function MountieUI.CreatePackFrame(parent, pack)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(300, 60)
    
    -- Expansion state
    frame.isExpanded = false
    frame.mountFrames = {}
    
    -- Expand/collapse icon
    local expandIcon = frame:CreateTexture(nil, "OVERLAY")
    expandIcon:SetSize(12, 12)
    expandIcon:SetPoint("LEFT", frame, "LEFT", 8, 8)
    expandIcon:SetTexture("Interface\\Buttons\\UI-PlusButton-Up")
    frame.expandIcon = expandIcon
    
    -- Pack name
    local name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    name:SetPoint("TOPLEFT", expandIcon, "TOPRIGHT", 5, 0)
    name:SetText(pack.name)
    name:SetTextColor(1, 1, 0.8, 1) -- Slightly yellow
    frame.nameText = name
    
    -- Pack info (mount count, description, and rule count)
    local info = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    info:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2)
    info:SetPoint("RIGHT", frame, "RIGHT", -70, 0) -- Leave space for rules and delete buttons
    info:SetJustifyH("LEFT")
    
    local mountCount = #pack.mounts
    local infoText = mountCount .. " mount" .. (mountCount == 1 and "" or "s")
    if pack.description and pack.description ~= "" then
        infoText = infoText .. " - " .. pack.description
    end
    
    -- Count different rule types and add detailed indicator
    if pack.conditions and #pack.conditions > 0 then
        local zoneRuleCount = 0
        local transmogRuleCount = 0
        local customTransmogRuleCount = 0
        
        for _, rule in ipairs(pack.conditions) do
            if rule.type == "zone" then
                zoneRuleCount = zoneRuleCount + 1
            elseif rule.type == "transmog" then
                transmogRuleCount = transmogRuleCount + 1
            elseif rule.type == "custom_transmog" then
                customTransmogRuleCount = customTransmogRuleCount + 1
            end
        end
        
        local ruleDetails = {}
        if zoneRuleCount > 0 then
            table.insert(ruleDetails, "|cff88ccff" .. zoneRuleCount .. " zone" .. (zoneRuleCount > 1 and "s" or "") .. "|r")
        end
        if transmogRuleCount > 0 then
            table.insert(ruleDetails, "|cffcc88ff" .. transmogRuleCount .. " transmog" .. (transmogRuleCount > 1 and "s" or "") .. "|r")
        end
        if customTransmogRuleCount > 0 then
            table.insert(ruleDetails, "|cffffaa88" .. customTransmogRuleCount .. " custom" .. (customTransmogRuleCount > 1 and "s" or "") .. "|r")
        end
        
        if #ruleDetails > 0 then
            infoText = infoText .. " | " .. table.concat(ruleDetails, ", ")
        end
    end
    
    info:SetText(infoText)
    info:SetTextColor(0.8, 0.8, 0.8, 1)
    frame.infoText = info
    
    -- Rules button (gear/settings icon)
    local rulesButton = CreateFrame("Button", nil, frame)
    rulesButton:SetSize(20, 20)
    rulesButton:SetPoint("RIGHT", frame, "RIGHT", -33, 0) -- Position left of delete button
    rulesButton:SetNormalTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
    rulesButton:SetHighlightTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Highlight") 
    rulesButton:SetPushedTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Down")

    rulesButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Pack Rules", 1, 1, 1)
        GameTooltip:AddLine("Configure when this pack activates", 1, 0.8, 0.8)
        GameTooltip:Show()
    end)

    rulesButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    rulesButton:SetScript("OnClick", function(self)
        MountieUI.ShowRulesDialog(pack)
    end)
    
    -- Share toggle button (account-wide vs character-specific)
    local shareButton = CreateFrame("Button", nil, frame)
    shareButton:SetSize(20, 20)
    shareButton:SetPoint("RIGHT", frame, "RIGHT", -83, 0) -- Position left of rules button
    
    -- Set icon based on pack's shared status
    local function updateShareIcon()
        if pack.isShared then
            -- Create three person silhouettes for account-wide sharing
            shareButton:SetNormalTexture("Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon")
            shareButton:SetHighlightTexture("Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon")
            shareButton:SetPushedTexture("Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon")
            
            -- Create two additional silhouettes to the left
            if not shareButton.extraIcon1 then
                shareButton.extraIcon1 = shareButton:CreateTexture(nil, "OVERLAY")
                shareButton.extraIcon1:SetSize(16, 16)
                shareButton.extraIcon1:SetPoint("RIGHT", shareButton, "LEFT", 2, 0)
                shareButton.extraIcon1:SetTexture("Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon")
                shareButton.extraIcon1:SetAlpha(0.8) -- Slightly transparent
            end
            
            if not shareButton.extraIcon2 then
                shareButton.extraIcon2 = shareButton:CreateTexture(nil, "OVERLAY")
                shareButton.extraIcon2:SetSize(14, 14)
                shareButton.extraIcon2:SetPoint("RIGHT", shareButton.extraIcon1, "LEFT", 2, 0)
                shareButton.extraIcon2:SetTexture("Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon")
                shareButton.extraIcon2:SetAlpha(0.6) -- More transparent, smaller
            end
            
            shareButton.extraIcon1:Show()
            shareButton.extraIcon2:Show()
        else
            -- Single person silhouette for character-specific
            shareButton:SetNormalTexture("Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon")
            shareButton:SetHighlightTexture("Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon")
            shareButton:SetPushedTexture("Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon")
            
            -- Hide extra icons if they exist
            if shareButton.extraIcon1 then
                shareButton.extraIcon1:Hide()
            end
            if shareButton.extraIcon2 then
                shareButton.extraIcon2:Hide()
            end
        end
    end
    updateShareIcon()
    
    shareButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if pack.isShared then
            GameTooltip:SetText("Account-Wide Pack", 1, 1, 1)
            GameTooltip:AddLine("This pack is shared across all characters", 0.5, 1, 0.5)
            GameTooltip:AddLine("Click to make character-specific", 1, 0.8, 0.8)
        else
            GameTooltip:SetText("Character-Specific Pack", 1, 1, 1)
            GameTooltip:AddLine("This pack is only available on this character", 1, 1, 0.5)
            GameTooltip:AddLine("Click to share account-wide", 1, 0.8, 0.8)
        end
        GameTooltip:Show()
    end)

    shareButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    shareButton:SetScript("OnClick", function(self)
        local success, message = Mountie.TogglePackShared(pack.name)
        if success then
            Mountie.Print(message)
            -- Update the icon
            updateShareIcon()
            -- Refresh the pack list to reflect changes
            if _G.MountieMainFrame and _G.MountieMainFrame.packPanel and _G.MountieMainFrame.packPanel.refreshPacks then
                _G.MountieMainFrame.packPanel.refreshPacks()
            end
        else
            Mountie.Print("Error: " .. message)
        end
    end)
    
    -- Fallback toggle button
    local fallbackButton = CreateFrame("Button", nil, frame)
    fallbackButton:SetSize(20, 20)
    fallbackButton:SetPoint("RIGHT", frame, "RIGHT", -133, 0) -- Position left of share button with space for extra icons
    
    -- Set icon based on pack's fallback status
    local function updateFallbackIcon()
        if pack.isFallback then
            fallbackButton:SetNormalTexture("Interface\\Icons\\Ability_Mount_RidingHorse")
            fallbackButton:SetHighlightTexture("Interface\\Icons\\Ability_Mount_RidingHorse")
            fallbackButton:SetPushedTexture("Interface\\Icons\\Ability_Mount_RidingHorse")
            -- Add a gold tint for active fallback
            fallbackButton:GetNormalTexture():SetVertexColor(1, 1, 0, 1)
            fallbackButton:GetHighlightTexture():SetVertexColor(1, 1, 0.5, 1)
        else
            fallbackButton:SetNormalTexture("Interface\\Icons\\Ability_Mount_RidingHorse")
            fallbackButton:SetHighlightTexture("Interface\\Icons\\Ability_Mount_RidingHorse")
            fallbackButton:SetPushedTexture("Interface\\Icons\\Ability_Mount_RidingHorse")
            -- Gray tint for inactive fallback
            fallbackButton:GetNormalTexture():SetVertexColor(0.5, 0.5, 0.5, 1)
            fallbackButton:GetHighlightTexture():SetVertexColor(0.7, 0.7, 0.7, 1)
        end
    end
    updateFallbackIcon()
    
    fallbackButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if pack.isFallback then
            GameTooltip:SetText("Fallback Pack", 1, 1, 1)
            GameTooltip:AddLine("This pack is used when no rules match", 1, 1, 0.5)
            GameTooltip:AddLine("Click to remove fallback status", 1, 0.8, 0.8)
        else
            GameTooltip:SetText("Set as Fallback", 1, 1, 1)
            GameTooltip:AddLine("Use this pack when no rules match", 0.8, 0.8, 1)
            GameTooltip:AddLine("Click to set as fallback pack", 1, 0.8, 0.8)
        end
        GameTooltip:Show()
    end)

    fallbackButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    fallbackButton:SetScript("OnClick", function(self)
        local success, message = Mountie.TogglePackFallback(pack.name)
        if success then
            updateFallbackIcon()
            -- Refresh all pack frames to update fallback status display
            if _G.MountieMainFrame and _G.MountieMainFrame.packPanel and _G.MountieMainFrame.packPanel.refreshPacks then
                _G.MountieMainFrame.packPanel.refreshPacks()
            end
        else
            Mountie.Print("Error: " .. message)
        end
    end)
    
    -- Delete button (trash icon)
    local deleteButton = CreateFrame("Button", nil, frame)
    deleteButton:SetSize(20, 20)
    deleteButton:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
    deleteButton:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    deleteButton:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
    deleteButton:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
    
    -- Delete button styling and functionality
    local deleteIcon = deleteButton:CreateTexture(nil, "OVERLAY")
    deleteIcon:SetAllPoints(deleteButton)
    deleteIcon:SetTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    deleteIcon:SetTexCoord(0, 1, 0, 1)
    
    deleteButton:SetScript("OnEnter", function(self)
        deleteIcon:SetVertexColor(1, 0.3, 0.3, 1) -- Red tint on hover
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Delete Pack", 1, 1, 1)
        GameTooltip:AddLine("This will permanently delete this pack", 1, 0.8, 0.8)
        GameTooltip:Show()
    end)
    
    deleteButton:SetScript("OnLeave", function(self)
        deleteIcon:SetVertexColor(1, 1, 1, 1) -- Normal color
        GameTooltip:Hide()
    end)
    
    deleteButton:SetScript("OnClick", function(self)
        MountieUI.ShowDeleteConfirmation(pack)
    end)
    
    -- Hover effects for the main frame (simple color change for text)
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self)
        self.nameText:SetTextColor(1, 1, 1, 1) -- Brighter on hover
        
        -- Check if a mount is being dragged
        if MountieUI.IsMountBeingDragged() then
            self.nameText:SetTextColor(0.5, 1, 0.5, 1) -- Green when drag target
        end
    end)
    
    frame:SetScript("OnLeave", function(self)
        self.nameText:SetTextColor(1, 1, 0.8, 1) -- Back to yellow
    end)
    
    -- Click handler for expanding/collapsing
    frame:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            MountieUI.TogglePackExpansion(self, pack)
        end
    end)
    
    frame.pack = pack
    return frame
end

function MountieUI.UpdatePackList(scrollFrame)
    Mountie.Debug("UpdatePackList starting...")
    
    local content = scrollFrame.content
    local packFrames = scrollFrame.packFrames
    
    -- Get all packs
    local packs = Mountie.ListPacks()
    
    -- Create or update pack frames
    for i, pack in ipairs(packs) do
        local frame = packFrames[i]
        if not frame then
            frame = MountieUI.CreatePackFrame(content, pack)
            frame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i-1) * 70)
            packFrames[i] = frame
        else
            -- Update existing frame
            frame.pack = pack
            -- Update the pack frame content (name, description, mount count)
            -- This is a simplified update - in a more complex system we'd update the text elements
        end
        
        frame:Show()
    end
    
    -- Hide unused frames
    for i = #packs + 1, #packFrames do
        packFrames[i]:Hide()
    end
    
    -- Update content height for scrolling
    local contentHeight = math.max(#packs * 70, 1)
    content:SetHeight(contentHeight)
end

-- Pack Expansion Functions
function MountieUI.TogglePackExpansion(packFrame, pack)
    -- Check if we currently have an expanded frame for this pack
    local packPanel = _G.MountieMainFrame and _G.MountieMainFrame.packPanel
    local isCurrentlyExpanded = packPanel and packPanel.tempExpandedFrame and packPanel.tempExpandedFrame:IsShown()
    
    if isCurrentlyExpanded then
        -- We're collapsing - clean up temp expanded frame and show normal scroll view
        if packPanel then
            if packPanel.tempExpandedFrame then
                packPanel.tempExpandedFrame:Hide()
                packPanel.tempExpandedFrame:SetParent(nil)
                packPanel.tempExpandedFrame = nil
            end
            if packPanel.packList then
                packPanel.packList:Show()
            end
        end
    else
        -- We're expanding - create a properly clipped expanded view
        if _G.MountieMainFrame and _G.MountieMainFrame.packPanel then
            local packList = packPanel.packList
            
            -- Hide the scroll frame
            if packList then
                packList:Hide()
            end
            
            -- Clean up any existing temp frame
            if packPanel.tempExpandedFrame then
                packPanel.tempExpandedFrame:Hide()
                packPanel.tempExpandedFrame:SetParent(nil)
            end
            
            -- Calculate the available area (same as the scroll frame)
            local availableWidth = 320
            local availableHeight = packPanel:GetHeight() - 100 -- Account for title and button
            
            -- Create a scroll frame to contain the expanded content
            local expandedScrollFrame = CreateFrame("ScrollFrame", nil, packPanel, "UIPanelScrollFrameTemplate")
            expandedScrollFrame:SetPoint("TOPLEFT", packPanel, "TOPLEFT", 20, -80)
            expandedScrollFrame:SetSize(availableWidth, availableHeight)
            
            -- Create the content frame
            local expandedContent = CreateFrame("Frame", nil, expandedScrollFrame)
            expandedContent:SetSize(availableWidth - 30, 100) -- Start small, will resize
            expandedScrollFrame:SetScrollChild(expandedContent)
            
            -- Add background to the content
            local bg = expandedContent:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(expandedContent)
            bg:SetColorTexture(0.1, 0.1, 0.2, 0.8)
            
            -- Set up pack frame properties
            expandedContent.isExpanded = true -- Mark as expanded
            expandedContent.mountFrames = {}
            expandedContent.pack = pack
            
            -- Add minus button (collapse indicator)
            local minusButton = expandedContent:CreateTexture(nil, "OVERLAY")
            minusButton:SetSize(12, 12)
            minusButton:SetPoint("TOPLEFT", expandedContent, "TOPLEFT", 8, -8)
            minusButton:SetTexture("Interface\\Buttons\\UI-MinusButton-Up")
            expandedContent.minusButton = minusButton
            
            -- Add pack title
            local name = expandedContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            name:SetPoint("TOPLEFT", minusButton, "TOPRIGHT", 5, 0)
            name:SetText(pack.name)
            name:SetTextColor(1, 1, 0.8, 1)
            expandedContent.nameText = name
            
            -- Add pack info
            local info = expandedContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            info:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2)
            info:SetPoint("RIGHT", expandedContent, "RIGHT", -70, 0) -- Leave space for Rules button
            info:SetJustifyH("LEFT")
            
            local mountCount = #pack.mounts
            local infoText = mountCount .. " mount" .. (mountCount == 1 and "" or "s")
            if pack.description and pack.description ~= "" then
                infoText = infoText .. " - " .. pack.description
            end
            if pack.conditions and #pack.conditions > 0 then
                infoText = infoText .. " | " .. #pack.conditions .. " rule" .. (#pack.conditions == 1 and "" or "s")
            end
            info:SetText(infoText)
            info:SetTextColor(0.8, 0.8, 0.8, 1)
            expandedContent.infoText = info
            
            -- Add Rules button (gear/settings icon) - same as in normal pack view
            local rulesButton = CreateFrame("Button", nil, expandedContent)
            rulesButton:SetSize(20, 20)
            rulesButton:SetPoint("TOPRIGHT", expandedContent, "TOPRIGHT", -8, -8) -- Top right corner
            rulesButton:SetNormalTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
            rulesButton:SetHighlightTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Highlight") 
            rulesButton:SetPushedTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Down")

            rulesButton:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Pack Rules", 1, 1, 1)
                GameTooltip:AddLine("Configure when this pack activates", 1, 0.8, 0.8)
                GameTooltip:Show()
            end)

            rulesButton:SetScript("OnLeave", function(self)
                GameTooltip:Hide()
            end)

            rulesButton:SetScript("OnClick", function(self)
                MountieUI.ShowRulesDialog(pack)
            end)
            
            -- Add click handler to collapse - this was the key issue
            expandedContent:EnableMouse(true)
            expandedContent:SetScript("OnMouseUp", function(self, button)
                if button == "LeftButton" then
                    -- Call toggle again, but it will detect we're expanded and collapse
                    MountieUI.TogglePackExpansion(self, pack)
                end
            end)
            
            -- Show the frames
            expandedContent:Show()
            expandedScrollFrame:Show()
            
            -- Add the mounts
            if #pack.mounts > 0 then
                -- Create a sorted list of mounts by name
                local sortedMounts = {}
                for _, mountID in ipairs(pack.mounts) do
                    local name = C_MountJournal.GetMountInfoByID(mountID)
                    table.insert(sortedMounts, {
                        id = mountID,
                        name = name or "Unknown Mount"
                    })
                end
                
                -- Sort alphabetically by name
                table.sort(sortedMounts, function(a, b) 
                    return a.name < b.name 
                end)
                
                local yOffset = -35 -- Start below the info text
                for i, mountData in ipairs(sortedMounts) do
                    local mountFrame = CreateFrame("Frame", nil, expandedContent)
                    mountFrame:SetSize(280, 28)
                    mountFrame:SetPoint("TOPLEFT", expandedContent, "TOPLEFT", 8, yOffset)
                    
                    -- Mount background
                    local mountBg = mountFrame:CreateTexture(nil, "BACKGROUND")
                    mountBg:SetAllPoints(mountFrame)
                    mountBg:SetColorTexture(0.05, 0.05, 0.15, 0.6)
                    
                    -- Get mount info
                    local name, spellID, icon = C_MountJournal.GetMountInfoByID(mountData.id)
                    
                    -- Mount icon
                    local mountIcon = mountFrame:CreateTexture(nil, "ARTWORK")
                    mountIcon:SetSize(24, 24)
                    mountIcon:SetPoint("LEFT", mountFrame, "LEFT", 4, 0)
                    mountIcon:SetTexture(icon)
                    
                    -- Mount name
                    local mountName = mountFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    mountName:SetPoint("LEFT", mountIcon, "RIGHT", 6, 0)
                    mountName:SetText(mountData.name)
                    mountName:SetTextColor(0.9, 0.9, 0.9, 1)
                    
                    mountFrame:Show()
                    expandedContent.mountFrames[i] = mountFrame
                    yOffset = yOffset - 29 -- Move down for next mount
                end
                
                -- Resize the content to fit all mounts
                local contentHeight = 35 + (#sortedMounts * 29) + 10 -- header + mounts + padding
                expandedContent:SetHeight(contentHeight)
            else
                -- No mounts
                local noMountsText = expandedContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                noMountsText:SetPoint("TOPLEFT", info, "BOTTOMLEFT", 8, -4)
                noMountsText:SetText("No mounts in this pack")
                noMountsText:SetTextColor(0.6, 0.6, 0.6, 1)
                expandedContent:SetHeight(80)
            end
            
            -- Store reference to the scroll frame (not content)
            packPanel.tempExpandedFrame = expandedScrollFrame
            
            if MountieDB and MountieDB.settings and MountieDB.settings.debugMode then
                Mountie.Debug("Created scrollable expansion with " .. #pack.mounts .. " mounts")
            end
        end
    end
end

function MountieUI.ExpandPackFrame(packFrame, pack)
    packFrame.isExpanded = true
    
    -- Calculate height with much tighter spacing
    local baseHeight = 60 -- Original pack frame height  
    local newHeight
    
    if #pack.mounts > 0 then
        -- 29px per mount (28px mount + 1px gap) + 10px total padding (2px top + 8px bottom)
        local mountsHeight = #pack.mounts * 29 + 10
        newHeight = baseHeight + mountsHeight
    else
        newHeight = 80 -- Reduced height for "no mounts" message
    end
    
    -- Set the new height on the pack frame
    packFrame:SetHeight(newHeight)
    
    -- Change expand icon to minus
    packFrame.expandIcon:SetTexture("Interface\\Buttons\\UI-MinusButton-Up")
    
    -- Show mounts if there are any
    if #pack.mounts > 0 then
        for i, mountID in ipairs(pack.mounts) do
            local mountFrame = MountieUI.CreatePackMountFrame(packFrame, mountID, i)
            packFrame.mountFrames[i] = mountFrame
        end
    else
        -- Show "No mounts" message
        local noMountsText = packFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        noMountsText:SetPoint("TOPLEFT", packFrame.infoText, "BOTTOMLEFT", 8, -4) -- Much closer spacing
        noMountsText:SetText("No mounts in this pack")
        noMountsText:SetTextColor(0.6, 0.6, 0.6, 1)
        packFrame.noMountsText = noMountsText
    end
end

function MountieUI.CollapsePackFrame(packFrame)
    packFrame.isExpanded = false
    
    -- Change expand icon back to plus
    packFrame.expandIcon:SetTexture("Interface\\Buttons\\UI-PlusButton-Up")
    
    -- Hide and remove mount frames
    for _, mountFrame in ipairs(packFrame.mountFrames) do
        mountFrame:Hide()
        mountFrame:SetParent(nil)
    end
    packFrame.mountFrames = {}
    
    -- Remove "no mounts" text if it exists
    if packFrame.noMountsText then
        packFrame.noMountsText:Hide()
        packFrame.noMountsText = nil
    end
    
    -- Reset pack frame to original height
    packFrame:SetHeight(60)
end

function MountieUI.CreatePackMountFrame(packFrame, mountID, index)
    local mountFrame = CreateFrame("Frame", nil, packFrame)
    mountFrame:SetSize(280, 28)
    
    -- Position relative to the pack info text with much tighter spacing
    if index == 1 then
        mountFrame:SetPoint("TOPLEFT", packFrame.infoText, "BOTTOMLEFT", 8, -2) -- Much closer: reduced from -6 to -2
    else
        -- Position relative to the previous mount frame with no gap
        local prevFrame = packFrame.mountFrames[index - 1]
        mountFrame:SetPoint("TOPLEFT", prevFrame, "BOTTOMLEFT", 0, -1) -- Just 1px gap
    end
    
    -- Add a subtle background for each mount row that aligns properly
    local bg = mountFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(mountFrame)
    bg:SetColorTexture(0.05, 0.05, 0.15, 0.6) -- Slightly transparent dark background
    
    -- Get mount info
    local name, spellID, icon = C_MountJournal.GetMountInfoByID(mountID)
    
    -- Mount icon
    local mountIcon = mountFrame:CreateTexture(nil, "ARTWORK")
    mountIcon:SetSize(24, 24)
    mountIcon:SetPoint("LEFT", mountFrame, "LEFT", 4, 0)
    mountIcon:SetTexture(icon)
    
    -- Mount name
    local mountName = mountFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mountName:SetPoint("LEFT", mountIcon, "RIGHT", 6, 0)
    mountName:SetPoint("RIGHT", mountFrame, "RIGHT", -20, 0)
    mountName:SetJustifyH("LEFT")
    mountName:SetText(name or "Unknown Mount")
    mountName:SetTextColor(0.9, 0.9, 0.9, 1)
    
    -- Remove button
    local removeButton = CreateFrame("Button", nil, mountFrame)
    removeButton:SetSize(16, 16)
    removeButton:SetPoint("RIGHT", mountFrame, "RIGHT", -2, 0)
    removeButton:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    removeButton:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
    removeButton:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
    
    removeButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Remove from pack", 1, 1, 1)
        GameTooltip:Show()
    end)
    
    removeButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    removeButton:SetScript("OnClick", function(self)
        Mountie.Debug("Remove button clicked for mount ID: " .. mountID)
        
        local success, message = Mountie.RemoveMountFromPack(packFrame.pack.name, mountID)
        Mountie.VerbosePrint(message)
        
        if success then
            Mountie.Debug("Mount removed successfully, updating UI in-place")
            
            -- Get the updated pack data
            local updatedPack = Mountie.GetPack(packFrame.pack.name)
            if updatedPack then
                Mountie.Debug("Updated pack has " .. #updatedPack.mounts .. " mounts remaining")
                
                packFrame.pack = updatedPack -- Update the pack reference
                
                -- Remove this specific mount frame
                mountFrame:Hide()
                mountFrame:SetParent(nil)
                
                -- Remove from the mount frames list
                for i, frame in ipairs(packFrame.mountFrames) do
                    if frame == mountFrame then
                        table.remove(packFrame.mountFrames, i)
                        Mountie.Debug("Removed mount frame from list, " .. #packFrame.mountFrames .. " frames remaining")
                        break
                    end
                end
                
                -- Reposition remaining mount frames
                for i, frame in ipairs(packFrame.mountFrames) do
                    frame:ClearAllPoints()
                    if i == 1 then
                        frame:SetPoint("TOPLEFT", packFrame.infoText, "BOTTOMLEFT", 8, -2)
                    else
                        frame:SetPoint("TOPLEFT", packFrame.mountFrames[i-1], "BOTTOMLEFT", 0, -1)
                    end
                end
                
                -- Update pack height
                local baseHeight = 60
                local newHeight
                if #updatedPack.mounts > 0 then
                    local mountsHeight = #updatedPack.mounts * 29 + 10
                    newHeight = baseHeight + mountsHeight
                    Mountie.Debug("Calculated new height: " .. newHeight)
                end
            end
        end
    end)
    
    -- Mount tooltip and subtle hover effects
    mountFrame:EnableMouse(true)
    mountFrame:SetScript("OnEnter", function(self)
        -- Brighten the background on hover
        bg:SetColorTexture(0.1, 0.1, 0.2, 0.7)
        mountName:SetTextColor(1, 1, 1, 1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if spellID then
            GameTooltip:SetMountBySpellID(spellID)
        else
            GameTooltip:SetText(name or "Unknown Mount", 1, 1, 1)
        end
        GameTooltip:Show()
        
        -- Show mount model in flyout window
        local mountData = { id = mountID, name = name, spellID = spellID }
        MountieUI.ShowMountModelFlyout(mountData)
    end)
    
    mountFrame:SetScript("OnLeave", function(self)
        -- Back to normal background
        bg:SetColorTexture(0.05, 0.05, 0.15, 0.6)
        mountName:SetTextColor(0.9, 0.9, 0.9, 1)
        GameTooltip:Hide()
        -- Delayed hide to allow movement to flyouts
        C_Timer.After(0.5, function()
            -- Double-check that mouse is actually away from the mount frame
            if self:IsMouseOver() then
                return -- Still over the mount frame, don't hide
            end
            
            -- Check if mouse is over any flyout before hiding
            local shouldHide = true
            if _G.MountieMountModelFlyout and _G.MountieMountModelFlyout.isMouseOver then
                shouldHide = false
            end
            if _G.MountieMountDebugFlyout and _G.MountieMountDebugFlyout.isMouseOver then
                shouldHide = false
            end
            if shouldHide then
                MountieUI.HideMountModelFlyout()
            end
        end)
    end)
    
    return mountFrame
end

-- Pack Visibility Functions
function MountieUI.HideOtherPackFrames(expandedFrame)
    -- Get the pack list from the main frame
    if _G.MountieMainFrame and _G.MountieMainFrame.packPanel and _G.MountieMainFrame.packPanel.packList then
        local packFrames = _G.MountieMainFrame.packPanel.packList.packFrames
        for _, frame in ipairs(packFrames) do
            if frame ~= expandedFrame then
                frame:Hide()
            end
        end
    end
end

function MountieUI.ShowAllPackFrames()
    -- Get the pack list from the main frame
    if _G.MountieMainFrame and _G.MountieMainFrame.packPanel and _G.MountieMainFrame.packPanel.packList then
        local packFrames = _G.MountieMainFrame.packPanel.packList.packFrames
        for _, frame in ipairs(packFrames) do
            frame:Show()
        end
    end
end

function MountieUI.MovePackToTop(expandedFrame)
    -- Clear all points and move the expanded pack to the top of the scroll area
    expandedFrame:ClearAllPoints()
    if _G.MountieMainFrame and _G.MountieMainFrame.packPanel and _G.MountieMainFrame.packPanel.packList then
        local content = _G.MountieMainFrame.packPanel.packList.content
        expandedFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    end
end

-- Helper function for delete confirmation
function MountieUI.ShowDeleteConfirmation(pack)
    local deleteConfirmDialog = MountieUI.CreateDeleteConfirmationDialog()
    deleteConfirmDialog.targetPack = pack
    deleteConfirmDialog.packNameText:SetText('"' .. pack.name .. '"')
    deleteConfirmDialog:Show()
end

-- Helper function to check if a mount is being dragged
function MountieUI.IsMountBeingDragged()
    -- Check if any mount button in the mount list is currently dragging
    if _G.MountieMainFrame and _G.MountieMainFrame.mountPanel and _G.MountieMainFrame.mountPanel.mountList then
        local buttons = _G.MountieMainFrame.mountPanel.mountList.buttons
        for _, button in ipairs(buttons) do
            if button.isDragging then
                return true
            end
        end
    end
    return false
end

Mountie.Debug("UI/PackPanel.lua loaded")