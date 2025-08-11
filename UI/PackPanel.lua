-- Mountie: Pack Panel UI
print("UI/PackPanel.lua loading...")

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
    
    -- Refresh function for pack list
    local function refreshPacks()
        if packList then
            -- Get current packs
            local packs = Mountie.ListPacks()
            
            -- Clear existing frames
            local content = packList.content
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
        end
    end
    
    -- Store references
    packPanel.createPackButton = createPackButton
    packPanel.packList = packList
    packPanel.refreshPacks = refreshPacks
    
    -- Also store a test function to verify the reference works
    packPanel.testFunction = function()
        print("DEBUG: Test function called successfully")
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
    
    -- No background at all - let the individual mount frames handle their own backgrounds
    
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
    
    -- Pack info (mount count and description)
    local info = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    info:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2)
    info:SetPoint("RIGHT", frame, "RIGHT", -35, 0) -- Leave space for delete button
    info:SetJustifyH("LEFT")
    
    local mountCount = #pack.mounts
    local infoText = mountCount .. " mount" .. (mountCount == 1 and "" or "s")
    if pack.description and pack.description ~= "" then
        infoText = infoText .. " - " .. pack.description
    end
    info:SetText(infoText)
    info:SetTextColor(0.8, 0.8, 0.8, 1)
    frame.infoText = info
    
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
    print("DEBUG: UpdatePackList starting...") -- Debug
    
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
    if packFrame.isExpanded then
        MountieUI.CollapsePackFrame(packFrame)
        -- Refresh the entire pack list to restore proper positioning for ALL packs
        if _G.MountieMainFrame and _G.MountieMainFrame.packPanel and _G.MountieMainFrame.packPanel.refreshPacks then
            _G.MountieMainFrame.packPanel.refreshPacks()
        end
    else
        -- First, refresh the pack list to ensure clean state
        if _G.MountieMainFrame and _G.MountieMainFrame.packPanel and _G.MountieMainFrame.packPanel.refreshPacks then
            _G.MountieMainFrame.packPanel.refreshPacks()
        end
        -- Then expand the specific pack we want
        -- Find the refreshed frame for this pack
        if _G.MountieMainFrame and _G.MountieMainFrame.packPanel and _G.MountieMainFrame.packPanel.packList then
            local packFrames = _G.MountieMainFrame.packPanel.packList.packFrames
            for _, frame in ipairs(packFrames) do
                if frame.pack and frame.pack.name == pack.name then
                    MountieUI.HideOtherPackFrames(frame)
                    MountieUI.MovePackToTop(frame)
                    MountieUI.ExpandPackFrame(frame, pack)
                    break
                end
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
        local success, message = Mountie.RemoveMountFromPack(packFrame.pack.name, mountID)
        print(message)
        if success then
            -- Refresh the entire pack panel to rebuild the layout cleanly
            if _G.MountieMainFrame and _G.MountieMainFrame.packPanel and _G.MountieMainFrame.packPanel.refreshPacks then
                _G.MountieMainFrame.packPanel.refreshPacks()
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
    end)
    
    mountFrame:SetScript("OnLeave", function(self)
        -- Back to normal background
        bg:SetColorTexture(0.05, 0.05, 0.15, 0.6)
        mountName:SetTextColor(0.9, 0.9, 0.9, 1)
        GameTooltip:Hide()
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

print("UI/PackPanel.lua loaded")