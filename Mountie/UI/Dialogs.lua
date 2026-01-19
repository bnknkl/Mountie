-- Mountie: Dialog UI Components.
Mountie.Debug("UI/Dialogs.lua loading...")

-- Pack Creation Dialog
function MountieUI.CreatePackDialog()
    local dialog = CreateFrame("Frame", "MountiePackDialog", UIParent, "BasicFrameTemplateWithInset")
    dialog:SetSize(400, 200)
    dialog:SetPoint("CENTER")
    dialog:SetMovable(true)
    dialog:EnableMouse(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", function(self) self:StartMoving() end)
    dialog:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    dialog:SetFrameStrata("DIALOG")

    dialog.TitleText:SetText("Create New Pack")

    dialog.CloseButton:SetScript("OnClick", function()
        dialog:Hide()
    end)

    local nameLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLabel:SetPoint("TOPLEFT", dialog, "TOPLEFT", 20, -50)
    nameLabel:SetText("Pack Name:")

    local nameInput = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
    nameInput:SetSize(200, 30)
    nameInput:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -5)
    nameInput:SetAutoFocus(false)
    nameInput:SetMaxLetters(30)

    local descLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    descLabel:SetPoint("TOPLEFT", nameInput, "BOTTOMLEFT", 0, -15)
    descLabel:SetText("Description (optional):")

    local descInput = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
    descInput:SetSize(300, 30)
    descInput:SetPoint("TOPLEFT", descLabel, "BOTTOMLEFT", 0, -5)
    descInput:SetAutoFocus(false)
    descInput:SetMaxLetters(100)

    local createButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    createButton:SetSize(80, 25)
    createButton:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -20, 20)
    createButton:SetText("Create")

    local cancelButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    cancelButton:SetSize(80, 25)
    cancelButton:SetPoint("RIGHT", createButton, "LEFT", -10, 0)
    cancelButton:SetText("Cancel")

    createButton:SetScript("OnClick", function()
        local packName = Mountie.Trim(nameInput:GetText())
        local description = Mountie.Trim(descInput:GetText())

        if packName == "" then
            Mountie.Print("Pack name cannot be empty!")
            return
        end

        local success, message = Mountie.CreatePack(packName, description)
        Mountie.VerbosePrint(message)

        if success then
            dialog:Hide()
            if _G.MountieMainFrame and _G.MountieMainFrame.packPanel and _G.MountieMainFrame.packPanel.refreshPacks then
                _G.MountieMainFrame.packPanel.refreshPacks()
            end
        end
    end)

    cancelButton:SetScript("OnClick", function()
        dialog:Hide()
    end)

    nameInput:SetScript("OnEnterPressed", function()
        createButton:GetScript("OnClick")(createButton)
    end)
    descInput:SetScript("OnEnterPressed", function()
        createButton:GetScript("OnClick")(createButton)
    end)

    nameInput:SetScript("OnTabPressed", function()
        descInput:SetFocus()
    end)
    descInput:SetScript("OnTabPressed", function()
        nameInput:SetFocus()
    end)

    dialog:SetScript("OnShow", function()
        nameInput:SetText("")
        descInput:SetText("")
        nameInput:SetFocus()
    end)

    dialog:Hide()
    table.insert(UISpecialFrames, "MountiePackDialog")
    return dialog
end

-- Delete Confirmation Dialog
function MountieUI.CreateDeleteConfirmationDialog()
    local dialog = CreateFrame("Frame", "MountieDeleteDialog", UIParent, "BasicFrameTemplateWithInset")
    dialog:SetSize(350, 150)
    dialog:SetPoint("CENTER")
    dialog:SetMovable(true)
    dialog:EnableMouse(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", function(self) self:StartMoving() end)
    dialog:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    dialog:SetFrameStrata("DIALOG")

    dialog.TitleText:SetText("Delete Pack")

    dialog.CloseButton:SetScript("OnClick", function()
        dialog:Hide()
    end)

    local warningText = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    warningText:SetPoint("TOP", dialog, "TOP", 0, -50)
    warningText:SetPoint("LEFT", dialog, "LEFT", 20, 0)
    warningText:SetPoint("RIGHT", dialog, "RIGHT", -20, 0)
    warningText:SetJustifyH("CENTER")
    warningText:SetText("Are you sure you want to delete this pack?")

    local packNameText = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    packNameText:SetPoint("TOP", warningText, "BOTTOM", 0, -10)
    packNameText:SetTextColor(1, 1, 0.8, 1)
    dialog.packNameText = packNameText

    local deleteButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    deleteButton:SetSize(80, 25)
    deleteButton:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -20, 20)
    deleteButton:SetText("Delete")

    local cancelButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    cancelButton:SetSize(80, 25)
    cancelButton:SetPoint("RIGHT", deleteButton, "LEFT", -10, 0)
    cancelButton:SetText("Cancel")

    dialog.targetPack = nil

    deleteButton:SetScript("OnClick", function()
        if dialog.targetPack then
            local success, message = Mountie.DeletePack(dialog.targetPack.name)
            Mountie.VerbosePrint(message)
            if success then
                dialog:Hide()
                if _G.MountieMainFrame and _G.MountieMainFrame.packPanel and _G.MountieMainFrame.packPanel.refreshPacks then
                    _G.MountieMainFrame.packPanel.refreshPacks()
                end
            end
        end
    end)

    cancelButton:SetScript("OnClick", function()
        dialog:Hide()
    end)

    dialog:Hide()
    table.insert(UISpecialFrames, "MountieDeleteDialog")
    return dialog
end

-- Duplicate Pack Dialog
function MountieUI.CreateDuplicatePackDialog()
    local dialog = CreateFrame("Frame", "MountieDuplicateDialog", UIParent, "BasicFrameTemplateWithInset")
    dialog:SetSize(400, 200)
    dialog:SetPoint("CENTER")
    dialog:SetMovable(true)
    dialog:EnableMouse(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", function(self) self:StartMoving() end)
    dialog:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    dialog:SetFrameStrata("DIALOG")

    dialog.TitleText:SetText("Duplicate Pack")

    dialog.CloseButton:SetScript("OnClick", function()
        dialog:Hide()
    end)

    local nameLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLabel:SetPoint("TOPLEFT", dialog, "TOPLEFT", 20, -50)
    nameLabel:SetText("New Pack Name:")

    local nameInput = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
    nameInput:SetSize(200, 30)
    nameInput:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -5)
    nameInput:SetAutoFocus(false)
    nameInput:SetMaxLetters(30)

    local descLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    descLabel:SetPoint("TOPLEFT", nameInput, "BOTTOMLEFT", 0, -15)
    descLabel:SetText("Description (optional):")

    local descInput = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
    descInput:SetSize(300, 30)
    descInput:SetPoint("TOPLEFT", descLabel, "BOTTOMLEFT", 0, -5)
    descInput:SetAutoFocus(false)
    descInput:SetMaxLetters(100)

    local duplicateButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    duplicateButton:SetSize(80, 25)
    duplicateButton:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -20, 20)
    duplicateButton:SetText("Duplicate")

    local cancelButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    cancelButton:SetSize(80, 25)
    cancelButton:SetPoint("RIGHT", duplicateButton, "LEFT", -10, 0)
    cancelButton:SetText("Cancel")

    dialog.sourcePack = nil

    duplicateButton:SetScript("OnClick", function()
        local newName = Mountie.Trim(nameInput:GetText())
        local description = Mountie.Trim(descInput:GetText())

        if newName == "" then
            Mountie.Print("New pack name cannot be empty!")
            return
        end

        if dialog.sourcePack then
            local success, message = Mountie.DuplicatePack(dialog.sourcePack.name, newName, description)
            Mountie.VerbosePrint(message)

            if success then
                dialog:Hide()
                if _G.MountieMainFrame and _G.MountieMainFrame.packPanel and _G.MountieMainFrame.packPanel.refreshPacks then
                    _G.MountieMainFrame.packPanel.refreshPacks()
                end
            end
        end
    end)

    cancelButton:SetScript("OnClick", function()
        dialog:Hide()
    end)

    nameInput:SetScript("OnEnterPressed", function()
        duplicateButton:GetScript("OnClick")(duplicateButton)
    end)
    descInput:SetScript("OnEnterPressed", function()
        duplicateButton:GetScript("OnClick")(duplicateButton)
    end)

    nameInput:SetScript("OnTabPressed", function()
        descInput:SetFocus()
    end)
    descInput:SetScript("OnTabPressed", function()
        nameInput:SetFocus()
    end)

    dialog:SetScript("OnShow", function()
        if dialog.sourcePack then
            nameInput:SetText(dialog.sourcePack.name .. " Copy")
            descInput:SetText(dialog.sourcePack.description .. " (Copy)")
            nameInput:SetFocus()
            nameInput:HighlightText()
        end
    end)

    dialog:Hide()
    table.insert(UISpecialFrames, "MountieDuplicateDialog")
    return dialog
end

-- Context Menu System
local contextMenu = nil

function MountieUI.CreatePackContextMenu()
    if contextMenu then
        return contextMenu
    end
    
    contextMenu = CreateFrame("Frame", "MountiePackContextMenu", UIParent, "BackdropTemplate")
    contextMenu:SetSize(160, 120)
    contextMenu:SetFrameStrata("FULLSCREEN_DIALOG")
    contextMenu:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    contextMenu:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    contextMenu:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    contextMenu:Hide()
    contextMenu.pack = nil
    
    -- Menu items
    local menuItems = {}
    
    -- Configure Rules
    local rulesItem = CreateFrame("Button", nil, contextMenu)
    rulesItem:SetSize(150, 20)
    rulesItem:SetPoint("TOPLEFT", contextMenu, "TOPLEFT", 8, -8)
    rulesItem:SetNormalFontObject(GameFontNormalSmall)
    rulesItem:SetHighlightFontObject(GameFontHighlightSmall)
    rulesItem:SetText("Configure Rules")
    rulesItem:SetScript("OnClick", function()
        if contextMenu.pack then
            MountieUI.ShowRulesDialog(contextMenu.pack)
            contextMenu:Hide()
        end
    end)
    -- Create highlight texture for hover effect
    local rulesHighlight = rulesItem:CreateTexture(nil, "BACKGROUND")
    rulesHighlight:SetAllPoints(rulesItem)
    rulesHighlight:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    rulesHighlight:Hide()
    
    rulesItem:SetScript("OnEnter", function(self) rulesHighlight:Show() end)
    rulesItem:SetScript("OnLeave", function(self) rulesHighlight:Hide() end)
    table.insert(menuItems, rulesItem)
    
    -- Toggle Account-Wide
    local shareItem = CreateFrame("Button", nil, contextMenu)
    shareItem:SetSize(150, 20)
    shareItem:SetPoint("TOPLEFT", rulesItem, "BOTTOMLEFT", 0, 0)
    shareItem:SetNormalFontObject(GameFontNormalSmall)
    shareItem:SetHighlightFontObject(GameFontHighlightSmall)
    shareItem:SetScript("OnClick", function()
        if contextMenu.pack then
            local success, message = Mountie.TogglePackShared(contextMenu.pack.name)
            if success then
                Mountie.Print(message)
                -- Refresh the pack list to reflect changes
                if _G.MountieMainFrame and _G.MountieMainFrame.packPanel and _G.MountieMainFrame.packPanel.refreshPacks then
                    _G.MountieMainFrame.packPanel.refreshPacks()
                end
            else
                Mountie.Print("Error: " .. message)
            end
            contextMenu:Hide()
        end
    end)
    -- Create highlight texture for hover effect
    local shareHighlight = shareItem:CreateTexture(nil, "BACKGROUND")
    shareHighlight:SetAllPoints(shareItem)
    shareHighlight:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    shareHighlight:Hide()
    
    shareItem:SetScript("OnEnter", function(self) shareHighlight:Show() end)
    shareItem:SetScript("OnLeave", function(self) shareHighlight:Hide() end)
    table.insert(menuItems, shareItem)
    
    -- Toggle Fallback
    local fallbackItem = CreateFrame("Button", nil, contextMenu)
    fallbackItem:SetSize(150, 20)
    fallbackItem:SetPoint("TOPLEFT", shareItem, "BOTTOMLEFT", 0, 0)
    fallbackItem:SetNormalFontObject(GameFontNormalSmall)
    fallbackItem:SetHighlightFontObject(GameFontHighlightSmall)
    fallbackItem:SetScript("OnClick", function()
        if contextMenu.pack then
            local success, message = Mountie.TogglePackFallback(contextMenu.pack.name)
            if success then
                -- Refresh all pack frames to update fallback status display
                if _G.MountieMainFrame and _G.MountieMainFrame.packPanel and _G.MountieMainFrame.packPanel.refreshPacks then
                    _G.MountieMainFrame.packPanel.refreshPacks()
                end
            else
                Mountie.Print("Error: " .. message)
            end
            contextMenu:Hide()
        end
    end)
    -- Create highlight texture for hover effect
    local fallbackHighlight = fallbackItem:CreateTexture(nil, "BACKGROUND")
    fallbackHighlight:SetAllPoints(fallbackItem)
    fallbackHighlight:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    fallbackHighlight:Hide()
    
    fallbackItem:SetScript("OnEnter", function(self) fallbackHighlight:Show() end)
    fallbackItem:SetScript("OnLeave", function(self) fallbackHighlight:Hide() end)
    table.insert(menuItems, fallbackItem)
    
    -- Duplicate Pack
    local duplicateItem = CreateFrame("Button", nil, contextMenu)
    duplicateItem:SetSize(150, 20)
    duplicateItem:SetPoint("TOPLEFT", fallbackItem, "BOTTOMLEFT", 0, 0)
    duplicateItem:SetNormalFontObject(GameFontNormalSmall)
    duplicateItem:SetHighlightFontObject(GameFontHighlightSmall)
    duplicateItem:SetText("Duplicate Pack")
    duplicateItem:SetScript("OnClick", function()
        if contextMenu.pack then
            MountieUI.ShowDuplicateDialog(contextMenu.pack)
            contextMenu:Hide()
        end
    end)
    -- Create highlight texture for hover effect
    local duplicateHighlight = duplicateItem:CreateTexture(nil, "BACKGROUND")
    duplicateHighlight:SetAllPoints(duplicateItem)
    duplicateHighlight:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    duplicateHighlight:Hide()
    
    duplicateItem:SetScript("OnEnter", function(self) duplicateHighlight:Show() end)
    duplicateItem:SetScript("OnLeave", function(self) duplicateHighlight:Hide() end)
    table.insert(menuItems, duplicateItem)
    
    -- Delete Pack
    local deleteItem = CreateFrame("Button", nil, contextMenu)
    deleteItem:SetSize(150, 20)
    deleteItem:SetPoint("TOPLEFT", duplicateItem, "BOTTOMLEFT", 0, 0)
    deleteItem:SetNormalFontObject(GameFontNormalSmall)
    deleteItem:SetHighlightFontObject(GameFontHighlightSmall)
    deleteItem:SetText("Delete Pack")
    deleteItem:SetScript("OnClick", function()
        if contextMenu.pack then
            MountieUI.ShowDeleteConfirmation(contextMenu.pack)
            contextMenu:Hide()
        end
    end)
    -- Create highlight texture for hover effect (red for delete)
    local deleteHighlight = deleteItem:CreateTexture(nil, "BACKGROUND")
    deleteHighlight:SetAllPoints(deleteItem)
    deleteHighlight:SetColorTexture(0.5, 0.2, 0.2, 0.8)
    deleteHighlight:Hide()
    
    deleteItem:SetScript("OnEnter", function(self) deleteHighlight:Show() end)
    deleteItem:SetScript("OnLeave", function(self) deleteHighlight:Hide() end)
    table.insert(menuItems, deleteItem)
    
    contextMenu.menuItems = menuItems
    contextMenu.shareItem = shareItem
    contextMenu.fallbackItem = fallbackItem
    
    -- Update menu text based on pack state
    contextMenu.UpdateMenuItems = function(self, pack)
        if not pack then return end
        
        self.shareItem:SetText(pack.isShared and "Make Character-Specific" or "Make Account-Wide")
        self.fallbackItem:SetText(pack.isFallback and "Remove Fallback Status" or "Set as Fallback")
    end
    
    -- Hide menu when clicking elsewhere
    contextMenu:SetScript("OnHide", function(self)
        self.pack = nil
    end)
    
    return contextMenu
end

function MountieUI.ShowPackContextMenu(pack, x, y)
    local menu = MountieUI.CreatePackContextMenu()
    menu.pack = pack
    menu.UpdateMenuItems(menu, pack)
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
    menu:Show()
    
    -- Hide when clicking elsewhere
    local function hideMenu()
        if menu:IsShown() then
            menu:Hide()
        end
    end
    
    -- Set up click-away handler
    local hiddenFrame = CreateFrame("Frame", nil, UIParent)
    hiddenFrame:SetAllPoints()
    hiddenFrame:SetFrameStrata("FULLSCREEN")
    hiddenFrame:EnableMouse(true)
    hiddenFrame:SetScript("OnMouseDown", function() 
        hideMenu()
        hiddenFrame:Hide()
    end)
    hiddenFrame:Show()
    
    menu:SetScript("OnHide", function()
        hiddenFrame:Hide()
        menu.pack = nil
    end)
end

Mountie.Debug("UI/Dialogs.lua loaded")