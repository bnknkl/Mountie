Mountie.Debug("MountJournalHook.lua loading...")

local MountJournalHook = {}

-- Check if a mount exists in a specific pack
local function IsMountInPack(mountID, packName)
    local pack = Mountie.GetPackByName(packName)
    if not pack then return false end
    
    -- TODO: this is probably slow for large packs, maybe use a lookup table?
    for _, existingMountID in ipairs(pack.mounts) do
        if existingMountID == mountID then
            return true
        end
    end
    return false
end

local function GetPacksForDropdown(mountID)
    local packs = {}
    
    local charPacks = Mountie.GetCharacterPacks()
    for _, pack in ipairs(charPacks) do
        local mountInPack = IsMountInPack(mountID, pack.name)  -- slightly different variable name
        table.insert(packs, {
            name = pack.name,
            isShared = false,
            text = pack.name .. " (Character)",
            isInPack = mountInPack
        })
    end
    
    if MountieDB.sharedPacks then
        for _, pack in ipairs(MountieDB.sharedPacks) do
            local isInPack = IsMountInPack(mountID, pack.name)
            table.insert(packs, {
                name = pack.name,
                isShared = true,
                text = pack.name .. " (Account)",
                isInPack = isInPack
            })
        end
    end
    
    return packs
end

-- Add mount to pack with message output
local function AddMountToPackFromContext(packName, mountID)
    local success, message = Mountie.AddMountToPack(packName, mountID)
    if success then
        Mountie.Print("[+] " .. message)
    else
        Mountie.Print("[-] " .. message)
    end
    -- TODO: maybe refresh the context menu after adding? right now you have to close and reopen to see the X
end

local function RemoveMountFromPackContext(packName, mountID)
    local success, message = Mountie.RemoveMountFromPack(packName, mountID)
    if success then
        Mountie.Print("[-] " .. message)
    else
        Mountie.Print("[!] " .. message)
    end
end

-- Create custom context menu for mount journal
local function CreateMountieContextMenu(self, level, menuList)
    if level == 1 then
        local mountID = self.mountID
        if not mountID then return end
        
        local name, spellID, icon, active, isUsable, sourceType, isFavorite = C_MountJournal.GetMountInfoByID(mountID)
        if not name then return end
        
        UIDropDownMenu_AddButton({
            text = "Mount",
            notCheckable = true,
            func = function()
                C_MountJournal.SummonByID(mountID)
                CloseDropDownMenus()
            end,
        }, level)
        
        if isFavorite then
            UIDropDownMenu_AddButton({
                text = "Remove Favorite",
                notCheckable = true,
                func = function()
                    C_MountJournal.SetIsFavorite(mountID, false)
                    CloseDropDownMenus()
                end,
            }, level)
        else
            UIDropDownMenu_AddButton({
                text = "Set Favorite",
                notCheckable = true,
                func = function()
                    C_MountJournal.SetIsFavorite(mountID, true)
                    CloseDropDownMenus()
                end,
            }, level)
        end
        
        local packs = GetPacksForDropdown(mountID)
        UIDropDownMenu_AddSeparator(level)
        
        if #packs > 0 then
            UIDropDownMenu_AddButton({
                text = "|cFF00FF96Add to Mountie Pack|r",
                hasArrow = true,
                notCheckable = true,
                menuList = "MOUNTIE_PACKS",
            }, level)
        else
            UIDropDownMenu_AddButton({
                text = "|cFF00C0FFCreate new pack...|r",
                notCheckable = true,
                func = function()
                    CloseDropDownMenus()
                    MountJournalHook.ShowCreatePackDialog(mountID)
                end,
                tooltipTitle = "Create New Pack",
                tooltipText = "Create a new pack and add this mount to it",
            }, level)
        end
        
    elseif menuList == "MOUNTIE_PACKS" then
        local mountID = UIDROPDOWNMENU_INIT_MENU.mountID
        local packs = GetPacksForDropdown(mountID)
        
        if #packs == 0 then
            UIDropDownMenu_AddButton({
                text = "|cFFFF6B6BNo packs available|r",
                notCheckable = true,
                disabled = true,
            }, level)
            UIDropDownMenu_AddButton({
                text = "Use /mountie ui to create packs",
                notCheckable = true,
                disabled = true,
            }, level)
        else
            for _, pack in ipairs(packs) do
                local displayText = pack.text
                local func = nil
                local tooltipTitle = ""
                local tooltipText = ""
                
                if pack.isInPack then
                    displayText = "|cFFFF4444X|r |cFF808080" .. pack.text .. "|r"
                    func = function()
                        RemoveMountFromPackContext(pack.name, mountID)
                        CloseDropDownMenus()
                    end
                    tooltipTitle = "Remove from Pack"
                    tooltipText = "Click the X to remove this mount from " .. pack.text
                else
                    displayText = pack.text
                    func = function()
                        AddMountToPackFromContext(pack.name, mountID)
                        CloseDropDownMenus()
                    end
                    tooltipTitle = "Add to Pack"
                    tooltipText = "Click to add this mount to " .. pack.text
                end
                
                UIDropDownMenu_AddButton({
                    text = displayText,
                    notCheckable = true,
                    func = func,
                    tooltipTitle = tooltipTitle,
                    tooltipText = tooltipText,
                }, level)
            end
            
            UIDropDownMenu_AddSeparator(level)
            
            UIDropDownMenu_AddButton({
                text = "|cFF00C0FFCreate new pack...|r",
                notCheckable = true,
                func = function()
                    CloseDropDownMenus()
                    MountJournalHook.ShowCreatePackDialog(mountID)
                end,
                tooltipTitle = "Create New Pack",
                tooltipText = "Create a new pack and add this mount to it",
            }, level)
        end
    end
end

local originalMountJournalInitialize = nil

-- Initialize mount journal context menu hooks
function MountJournalHook.Initialize()
    local function SetupHook()
        if not MountJournal then
            return false
        end
        
        Mountie.Debug("Setting up mount journal context menu hook")
        
        if MountJournal.mountOptionsMenu then
            local menu = MountJournal.mountOptionsMenu
            if menu.initialize then
                originalMountJournalInitialize = menu.initialize
                
                menu.initialize = function(self, level, menuList)
                    CreateMountieContextMenu(self, level, menuList)
                end
                
                Mountie.Debug("Successfully hooked mount journal context menu")
                return true
            end
        end
        
        if MountJournal and MountJournal.ListScrollFrame and MountJournal.ListScrollFrame.buttons then
            for _, button in pairs(MountJournal.ListScrollFrame.buttons) do
                if button and button.SetScript then
                    local originalOnClick = button:GetScript("OnClick")
                    button:SetScript("OnClick", function(self, mouseButton, down)
                        if mouseButton == "RightButton" and not down then
                            return
                        else
                            if originalOnClick then
                                originalOnClick(self, mouseButton, down)
                            end
                        end
                    end)
                end
            end
        end
        
        if MountJournal_InitMountButton then
            local originalInitButton = MountJournal_InitMountButton
            MountJournal_InitMountButton = function(button, elementData)
                originalInitButton(button, elementData)
                
                if button and elementData and elementData.mountID then
                    button.mountID = elementData.mountID
                    
                    button:SetScript("OnClick", function(self, mouseButton, down)
                        if mouseButton == "RightButton" and not down then
                            local mountID = self.mountID
                            if mountID then
                                CloseDropDownMenus()
                                
                                local menu = CreateFrame("Frame", "MountieContextMenu" .. mountID, UIParent, "UIDropDownMenuTemplate")
                                menu.mountID = mountID
                                UIDropDownMenu_Initialize(menu, CreateMountieContextMenu, "MENU")
                                
                                ToggleDropDownMenu(1, nil, menu, "cursor", 3, -3)
                                
                                return
                            end
                        elseif mouseButton == "LeftButton" and not down then
                            local mountID = self.mountID
                            if mountID then
                                C_MountJournal.SummonByID(mountID)
                            end
                        end
                    end)
                    
                    if button.SetAttribute then
                        button:SetAttribute("type", nil)
                        button:SetAttribute("spell", nil)
                    end
                end
            end
            
            Mountie.Debug("Successfully hooked MountJournal_InitMountButton")
            return true
        end
        
        return false
    end
    
    if not SetupHook() then
        local frame = CreateFrame("Frame")
        frame:RegisterEvent("ADDON_LOADED")
        frame:SetScript("OnEvent", function(self, event, addonName)
            if addonName == "Blizzard_Collections" then
                C_Timer.After(1, function()
                    if SetupHook() then
                        frame:UnregisterEvent("ADDON_LOADED")
                    end
                end)
            end
        end)
    end
end

MountJournalHook.Initialize()

-- Create pack dialog with automatic mount adding
function MountJournalHook.ShowCreatePackDialog(mountID)
    local dialog = CreateFrame("Frame", "MountiePackDialogFromJournal", UIParent, "BasicFrameTemplateWithInset")
    dialog:SetSize(400, 250)  -- Increased height to prevent overlap
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
    
    -- Add info text about auto-adding the mount with more spacing
    local infoText = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoText:SetPoint("TOPLEFT", descInput, "BOTTOMLEFT", 0, -20)  -- Increased spacing
    infoText:SetPoint("RIGHT", dialog, "RIGHT", -20, 0)
    infoText:SetTextColor(0.8, 0.8, 1, 1)  -- Light blue
    infoText:SetText("This mount will be automatically added to the new pack.")

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
        if success then
            -- Auto-add the mount to the newly created pack
            local addSuccess, addMessage = Mountie.AddMountToPack(packName, mountID)
            if addSuccess then
                Mountie.Print("[+] Created pack '" .. packName .. "' and added mount")
            else
                Mountie.Print("[+] Created pack '" .. packName .. "' but failed to add mount: " .. addMessage)
            end
            
            dialog:Hide()
            
            -- Refresh UI if it's open
            if _G.MountieMainFrame and _G.MountieMainFrame.packPanel and _G.MountieMainFrame.packPanel.refreshPacks then
                _G.MountieMainFrame.packPanel.refreshPacks()
            end
        else
            Mountie.Print("[-] " .. message)
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

    table.insert(UISpecialFrames, "MountiePackDialogFromJournal")
    dialog:Show()
    
    return dialog
end

-- Make it available globally
Mountie.MountJournalHook = MountJournalHook