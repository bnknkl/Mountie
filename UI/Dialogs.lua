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

Mountie.Debug("UI/Dialogs.lua loaded")