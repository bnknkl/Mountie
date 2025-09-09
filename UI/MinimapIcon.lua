Mountie.Debug("UI/MinimapIcon.lua loading...")

local MinimapIcon = {}

local function CreateMinimapButton()
    local button = CreateFrame("Button", "MountieMinimapButton", Minimap)
    button:SetFrameStrata("MEDIUM")
    button:SetSize(31, 31)
    button:SetFrameLevel(8)
    button:RegisterForClicks("anyUp")
    button:RegisterForDrag("LeftButton")
    button:SetMovable(true)
    -- TODO: add right-click drag maybe? some other addons do that

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 1)
    icon:SetTexture("Interface\\Icons\\Ability_Mount_RidingHorse")
    button.icon = icon

    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetPoint("TOPLEFT")
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button.overlay = overlay

    local savedAngle = MountieDB.settings.minimapIconAngle or 220
    local radius = 95
    local x = radius * math.cos(math.rad(savedAngle))
    local y = radius * math.sin(math.rad(savedAngle))
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)

    return button
end

local function UpdateTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:SetText("Mountie", 1, 1, 1)
    
    local selectedPacks = Mountie.runtime.selectedPacks or {}
    if #selectedPacks == 0 then
        local fallbackPack = Mountie.GetFallbackPack()
        if fallbackPack then
            GameTooltip:AddLine("Active: " .. fallbackPack.name .. " (fallback)", 0.8, 0.8, 1)
        else
            GameTooltip:AddLine("Active: None", 0.8, 0.8, 0.8)
        end
    elseif #selectedPacks == 1 then
        GameTooltip:AddLine("Active: " .. selectedPacks[1].pack.name, 0.8, 1, 0.8)
    else
        local packNames = {}
        for _, sp in ipairs(selectedPacks) do
            table.insert(packNames, sp.pack.name)
        end
        GameTooltip:AddLine("Active: " .. table.concat(packNames, ", "), 0.8, 1, 0.8)
    end
    
    local overlapMode = MountieDB.settings.packOverlapMode or "priority"
    local modeText = ""
    if overlapMode == "priority" then
        modeText = "Priority mode"
    elseif overlapMode == "intersection" then
        modeText = "Intersection mode"
    elseif overlapMode == "union" then
        modeText = "Union mode"
    end
    GameTooltip:AddLine("Mode: " .. modeText, 1, 1, 0.8)
    
    local flyingPref = MountieDB.settings.preferFlyingMounts and "Yes" or "No"
    GameTooltip:AddLine("Prefer flying: " .. flyingPref, 1, 1, 0.8)
    
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Left-click: Open Mountie UI", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Right-click: Summon mount", 0.8, 0.8, 0.8)
    
    GameTooltip:Show()
end

-- Initialize minimap icon with click handlers
function MinimapIcon.Initialize()
    local button = CreateMinimapButton()
    
    -- Handle clicks
    button:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "LeftButton" then
            if MountieMainFrame then
                if MountieMainFrame:IsShown() then
                    MountieMainFrame:Hide()
                else
                    MountieMainFrame:Show()
                end
            else
                Mountie.Print("Opening Mountie UI...")
                SlashCmdList["MOUNTIE"]("ui")
            end
        elseif mouseButton == "RightButton" then
            Mountie.MountActive()
        end
    end)
    
    button:SetScript("OnEnter", function(self)
        UpdateTooltip(self)
    end)
    
    button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    button:SetScript("OnDragStart", function(self)
        self.isDragging = true
        self:SetScript("OnUpdate", function(self)
            local scale = UIParent:GetEffectiveScale()
            local x, y = GetCursorPosition()
            x = x / scale
            y = y / scale
            
            local centerX, centerY = Minimap:GetCenter()
            
            local deltaX = x - centerX
            local deltaY = y - centerY
            local angle = math.atan2(deltaY, deltaX)
            
            local radius = 95
            
            local edgeX = radius * math.cos(angle)
            local edgeY = radius * math.sin(angle)
            
            self:ClearAllPoints()
            self:SetPoint("CENTER", Minimap, "CENTER", edgeX, edgeY)
        end)
    end)
    
    button:SetScript("OnDragStop", function(self)
        self.isDragging = false
        self:SetScript("OnUpdate", nil)
        
        local centerX, centerY = Minimap:GetCenter()
        local buttonX, buttonY = self:GetCenter()
        local deltaX = buttonX - centerX
        local deltaY = buttonY - centerY
        local angle = math.deg(math.atan2(deltaY, deltaX))
        
        if angle < 0 then
            angle = angle + 360
        end
        
        MountieDB.settings.minimapIconAngle = angle
        Mountie.Debug("Saved minimap icon position: angle " .. angle)
    end)
    
    Mountie.Debug("Minimap icon initialized")
    return button
end

function MinimapIcon.UpdateIcon()
    local btn = _G["MountieMinimapButton"]  -- shorter variable name
    if not btn then return end
    
    local selectedPacks = Mountie.runtime.selectedPacks or {}
    if #selectedPacks > 0 then
        local pack = selectedPacks[1].pack
        if pack.mounts and #pack.mounts > 0 then
            local mountID = pack.mounts[1]
            local name, spellID, icon = C_MountJournal.GetMountInfoByID(mountID)
            if icon then
                btn.icon:SetTexture(icon)
                return
            end
        end
    end
    
    -- fallback icon
    btn.icon:SetTexture("Interface\\Icons\\Ability_Mount_RidingHorse")
    -- TODO: maybe cycle through different icons from the pack instead of just using the first one?
end

Mountie.MinimapIcon = MinimapIcon

Mountie.Debug("UI/MinimapIcon.lua loaded")