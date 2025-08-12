-- Mountie: Core Pack and Mount Management
Mountie.Debug("Core.lua loading...")

-- Runtime state for active-pack selection
Mountie.runtime = Mountie.runtime or {
    activePackName = nil,
}

-- Pack Management Functions
function Mountie.CreatePack(name, description)
    if not name or name == "" then
        return false, "Pack name cannot be empty"
    end

    Mountie.Debug("CreatePack called with name: " .. name)

    -- Check if pack already exists
    for _, pack in ipairs(MountieDB.packs) do
        if pack.name == name then
            return false, "Pack '" .. name .. "' already exists"
        end
    end

    local newPack = {
        name = name,
        description = description or "",
        mounts = {},
        conditions = {},
        created = time(),
    }

    table.insert(MountieDB.packs, newPack)
    Mountie.Debug("Pack added. Total packs: " .. #MountieDB.packs)
    return true, "Pack '" .. name .. "' created successfully"
end

function Mountie.DeletePack(name)
    for i, pack in ipairs(MountieDB.packs) do
        if pack.name == name then
            table.remove(MountieDB.packs, i)
            Mountie.Debug("Deleted pack: " .. name)
            return true, "Pack '" .. name .. "' deleted"
        end
    end
    return false, "Pack '" .. name .. "' not found"
end

function Mountie.GetPack(name)
    for _, pack in ipairs(MountieDB.packs) do
        if pack.name == name then
            return pack
        end
    end
    return nil
end

function Mountie.ListPacks()
    return MountieDB.packs
end

-- Mount Management Functions
function Mountie.AddMountToPack(packName, mountID)
    local pack = Mountie.GetPack(packName)
    if not pack then
        return false, "Pack '" .. packName .. "' not found"
    end

    local name, spellID, icon, active, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected =
        C_MountJournal.GetMountInfoByID(mountID)
    if not name then
        return false, "Mount ID " .. mountID .. " not found"
    end
    if not isCollected then
        return false, "You don't own the mount: " .. name
    end

    for _, existingID in ipairs(pack.mounts) do
        if existingID == mountID then
            return false, "Mount '" .. name .. "' is already in pack '" .. packName .. "'"
        end
    end

    table.insert(pack.mounts, mountID)
    Mountie.Debug("Added mount " .. name .. " to pack " .. packName)
    return true, "Added '" .. name .. "' to pack '" .. packName .. "'"
end

function Mountie.RemoveMountFromPack(packName, mountID)
    local pack = Mountie.GetPack(packName)
    if not pack then
        return false, "Pack '" .. packName .. "' not found"
    end

    for i, existingID in ipairs(pack.mounts) do
        if existingID == mountID then
            table.remove(pack.mounts, i)
            local name = C_MountJournal.GetMountInfoByID(mountID)
            Mountie.Debug("Removed mount " .. (name or "Unknown") .. " from pack " .. packName)
            
            -- DO NOT auto-refresh the pack panel here - let the UI handle it
            -- This was likely causing the auto-collapse behavior
            
            return true, "Removed mount from pack '" .. packName .. "'"
        end
    end

    return false, "Mount not found in pack '" .. packName .. "'"
end

function Mountie.GetOwnedMounts()
    local ownedMounts = {}
    local allMountIDs = C_MountJournal.GetMountIDs()

    for _, mountID in ipairs(allMountIDs) do
        local name, spellID, icon, active, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected =
            C_MountJournal.GetMountInfoByID(mountID)
        if isCollected and name then
            table.insert(ownedMounts, {
                id = mountID,
                name = name,
                icon = icon,
                isUsable = isUsable,
            })
        end
    end

    table.sort(ownedMounts, function(a, b) return a.name < b.name end)
    return ownedMounts
end

-- Get current best map for player
local function GetPlayerMapID()
    return C_Map.GetBestMapForUnit("player")
end

-- Database initialization in Utils.lua should be updated, but we'll handle the setting here
-- Ensure the setting exists
local function EnsureFlyingPreferenceSetting()
    MountieDB.settings = MountieDB.settings or {}
    if MountieDB.settings.preferFlyingMounts == nil then
        MountieDB.settings.preferFlyingMounts = true -- Default to enabled
    end
end

-- Check if player can fly in current zone
local function CanFlyInCurrentZone()
    return IsFlyableArea()
end

-- Check if a mount is a flying mount using the proper API
local function IsFlyingMount(mountID)
    -- Use the GetMountInfoExtraByID API to get the actual mount type
    local creatureDisplayInfoID, description, source, isSelfMount, mountTypeID, uiModelSceneID, animID, spellVisualKitID, disablePlayerMountPreview = C_MountJournal.GetMountInfoExtraByID(mountID)
    
    if not mountTypeID then
        -- Fallback to name-based detection if API fails
        local name = C_MountJournal.GetMountInfoByID(mountID)
        if name and MountieDB.settings.debugMode then
            Mountie.Debug("No mountTypeID for " .. name .. ", using name fallback")
        end
        return IsFlyingMountByName(mountID)
    end
    
    -- Debug: Log the actual mount type ID
    if MountieDB.settings.debugMode then
        local name = C_MountJournal.GetMountInfoByID(mountID)
        Mountie.Debug("Mount " .. (name or "Unknown") .. " has mountTypeID: " .. tostring(mountTypeID))
    end
    
    -- Mount type IDs for flying mounts (discovered through testing)
    local flyingTypeIDs = {
        247, 248, 424, -- Initial guesses
        402, -- Algarian Stormrider
        -- We'll add more as we discover them from debug output
    }
    
    for _, flyingType in ipairs(flyingTypeIDs) do
        if mountTypeID == flyingType then
            return true
        end
    end
    
    return false
end

-- Fallback name-based detection (simplified version of our previous method)
local function IsFlyingMountByName(mountID)
    local name = C_MountJournal.GetMountInfoByID(mountID)
    if not name then
        return false
    end
    
    local lowerName = string.lower(name)
    
    -- Most reliable patterns only
    local flyingPatterns = {
        "dragon", "drake", "wyrm", "proto%-drake",
        "gryphon", "griffin", "hippogryph", 
        "phoenix", "wind rider", "windrider",
        "flying", "flight", "carpet", "disc",
        "azure", "bronze", "twilight", "netherwing"
    }
    
    for _, pattern in ipairs(flyingPatterns) do
        if string.find(lowerName, pattern) then
            if MountieDB.settings.debugMode then
                Mountie.Debug("Mount " .. name .. " detected as flying by name pattern: " .. pattern)
            end
            return true
        end
    end
    
    return false
end

-- Get a random favorite mount, optionally preferring flying mounts
local function GetRandomFavoriteMount()
    EnsureFlyingPreferenceSetting()
    
    local allFavorites = {}
    local flyingFavorites = {}
    local allMountIDs = C_MountJournal.GetMountIDs()
    
    -- Debug: Let's see some actual mount types
    local mountTypesSeen = {}
    local sampleCount = 0
    
    for _, mountID in ipairs(allMountIDs) do
        local name, spellID, icon, active, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected =
            C_MountJournal.GetMountInfoByID(mountID)
        if isCollected and isUsable and isFavorite then
            table.insert(allFavorites, mountID)
            
            -- Get the full mount info including mountType
            local fullName, fullSpellID, fullIcon, fullActive, fullIsUsable, fullSourceType, fullIsFavorite, fullIsFactionSpecific, fullFaction, fullShouldHideOnChar, fullIsCollected, mountType = C_MountJournal.GetMountInfoByID(mountID)
            
            -- Log some examples for debugging
            if MountieDB.settings.debugMode and sampleCount < 5 then
                Mountie.Debug("Sample favorite mount: " .. (name or "Unknown") .. " (ID: " .. mountID .. ") has mountType: " .. tostring(mountType))
                sampleCount = sampleCount + 1
            end
            
            -- Track mount types we're seeing
            if mountType then
                mountTypesSeen[mountType] = (mountTypesSeen[mountType] or 0) + 1
            end
            
            if IsFlyingMount(mountID) then
                table.insert(flyingFavorites, mountID)
            end
        end
    end
    
    -- Debug: Show mount type distribution
    if MountieDB.settings.debugMode then
        Mountie.Debug("Mount types found in favorites:")
        for mountType, count in pairs(mountTypesSeen) do
            Mountie.Debug("  Type " .. mountType .. ": " .. count .. " mounts")
        end
    end
    
    -- If flying preference is enabled and we can fly, prefer flying mounts
    if MountieDB.settings.preferFlyingMounts and CanFlyInCurrentZone() and #flyingFavorites > 0 then
        local randomIndex = math.random(1, #flyingFavorites)
        Mountie.Debug("Selected flying favorite mount (found " .. #flyingFavorites .. " flying favorites out of " .. #allFavorites .. " total)")
        return flyingFavorites[randomIndex]
    end
    
    -- Fallback to any favorite
    if #allFavorites > 0 then
        local randomIndex = math.random(1, #allFavorites)
        if MountieDB.settings.preferFlyingMounts and CanFlyInCurrentZone() then
            Mountie.Debug("No flying favorites found, using any favorite (had " .. #flyingFavorites .. " flying out of " .. #allFavorites .. " total)")
        else
            Mountie.Debug("Selected any favorite mount (flying preference disabled or can't fly here)")
        end
        return allFavorites[randomIndex]
    end
    
    return nil
end

-- Get a random mount from active pack, optionally preferring flying mounts
local function GetRandomMountFromActivePackWithFlyingPreference()
    local name = Mountie.runtime.activePackName
    if not name then 
        Mountie.Debug("No active pack name")
        return nil 
    end
    
    local pack = Mountie.GetPack(name)
    if not pack then 
        Mountie.Debug("Active pack '" .. name .. "' not found")
        return nil 
    end
    
    if not pack.mounts or #pack.mounts == 0 then 
        Mountie.Debug("Active pack '" .. name .. "' has no mounts")
        return nil 
    end
    
    EnsureFlyingPreferenceSetting()
    
    -- Get all usable mounts from pack
    local usableMounts = {}
    local flyingMounts = {}
    
    for _, mountID in ipairs(pack.mounts) do
        local name, spellID, icon, active, isUsable = C_MountJournal.GetMountInfoByID(mountID)
        if isUsable then
            table.insert(usableMounts, mountID)
            if IsFlyingMount(mountID) then
                table.insert(flyingMounts, mountID)
            end
        end
    end
    
    if #usableMounts == 0 then
        Mountie.Debug("No usable mounts in active pack")
        return nil
    end
    
    -- If flying preference is enabled and we can fly, prefer flying mounts
    if MountieDB.settings.preferFlyingMounts and CanFlyInCurrentZone() and #flyingMounts > 0 then
        local idx = math.random(1, #flyingMounts)
        local mountID = flyingMounts[idx]
        Mountie.Debug("Selected flying mount ID " .. mountID .. " from active pack '" .. name .. "' (found " .. #flyingMounts .. " flying out of " .. #usableMounts .. " usable)")
        return mountID
    end
    
    -- Fallback to any usable mount from pack
    local idx = math.random(1, #usableMounts)
    local mountID = usableMounts[idx]
    if MountieDB.settings.preferFlyingMounts and CanFlyInCurrentZone() then
        Mountie.Debug("No flying mounts in pack, selected any mount ID " .. mountID .. " from active pack '" .. name .. "' (had " .. #flyingMounts .. " flying out of " .. #usableMounts .. " usable)")
    else
        Mountie.Debug("Selected mount ID " .. mountID .. " from active pack '" .. name .. "' (flying preference disabled or can't fly here)")
    end
    return mountID
end

-- Pick and summon a mount from the active pack (or a sensible fallback)
function Mountie.MountActive()
    Mountie.Debug("MountActive called")
    
    -- Priority 1: Prefer the active pack (with flying preference if enabled)
    local mountID = GetRandomMountFromActivePackWithFlyingPreference()
    local source = "active pack"

    -- Priority 2: If no active pack or it's empty, use WoW's built-in random favorite system
    if not mountID then
        Mountie.Debug("No mount from active pack, using WoW's random favorite mount")
        
        -- Use WoW's built-in "Summon Random Favorite Mount" macro command
        -- This automatically handles flying vs ground based on zone and has perfect detection
        C_MountJournal.SummonByID(0) -- 0 = random favorite mount
        Mountie.Print("Summoned random favorite mount (using WoW's selection)")
        return true
    end

    -- If we got a mount from active pack, summon it
    if mountID then
        local name = C_MountJournal.GetMountInfoByID(mountID)
        Mountie.Debug("Summoning mount from " .. source .. ": " .. (name or "Unknown"))
        Mountie.Print("Summoned " .. (name or "Unknown") .. " from " .. source)
        C_MountJournal.SummonByID(mountID)
        return true
    else
        Mountie.Print("No usable mounts found.")
        return false
    end
end

-- Global wrapper for the keybind and macros
function Mountie_MountKeybind()
    -- Must be called from a hardware event (key press / macro)
    Mountie.MountActive()
end


-- Return true if the given mapID is the same as, or an ancestor of, current map (when includeParents is true)
local function DoesZoneRuleMatch(rule)
    if not rule or rule.type ~= "zone" or not rule.mapID then return false, 0 end
    local currentMapID = GetPlayerMapID()
    if not currentMapID then return false, 0 end

    if currentMapID == rule.mapID then
        return true, 100 -- exact match scores higher
    end

    if rule.includeParents then
        -- walk up parent chain
        local info = C_Map.GetMapInfo(currentMapID)
        while info and info.parentMapID and info.parentMapID > 0 do
            if info.parentMapID == rule.mapID then
                return true, 50 -- parent/ancestor match
            end
            info = C_Map.GetMapInfo(info.parentMapID)
        end
    end

    return false, 0
end

-- Score a single pack against current context
local function ScorePackAgainstContext(pack)
    if not pack or not pack.conditions or #pack.conditions == 0 then
        return 0
    end
    local score = 0
    for _, rule in ipairs(pack.conditions) do
        if rule.type == "zone" then
            local matched, s = DoesZoneRuleMatch(rule)
            if matched then score = score + s end
        end
        -- Future: expansion, transmog outfit, indoor/underwater toggles, etc.
    end
    return score
end

-- Evaluate all packs and set activePackName to the best match; notify on change
function Mountie.SelectActivePack()
    local packs = Mountie.ListPacks()
    
    -- If no packs exist at all, clear active pack
    if #packs == 0 then
        if Mountie.runtime.activePackName ~= nil then
            Mountie.runtime.activePackName = nil
            Mountie.Debug("No packs exist - cleared active pack")
        end
        return
    end
    
    local bestName, bestScore = nil, -1
    for _, p in ipairs(packs) do
        local s = ScorePackAgainstContext(p)
        if s > bestScore then
            bestScore = s
            bestName = p.name
        end
    end

    -- Only switch if the bestScore is > 0 (i.e., at least one rule matched)
    local newActive = (bestScore > 0) and bestName or nil
    if newActive ~= Mountie.runtime.activePackName then
        Mountie.runtime.activePackName = newActive
        if newActive then
            Mountie.Print("Active pack: " .. newActive)
        else
            Mountie.Debug("No matching pack for this zone - will use favorites")
        end
    else
        Mountie.Debug("Active pack unchanged: " .. tostring(newActive))
    end
end

-- Helper to get a random mount from the active pack (future use for a macro/keybind)
function Mountie.GetRandomMountFromActivePack()
    local name = Mountie.runtime.activePackName
    if not name then 
        Mountie.Debug("No active pack name")
        return nil 
    end
    
    local pack = Mountie.GetPack(name)
    if not pack then 
        Mountie.Debug("Active pack '" .. name .. "' not found")
        return nil 
    end
    
    if not pack.mounts or #pack.mounts == 0 then 
        Mountie.Debug("Active pack '" .. name .. "' has no mounts")
        return nil 
    end
    
    local idx = math.random(1, #pack.mounts)
    local mountID = pack.mounts[idx]
    Mountie.Debug("Selected mount ID " .. mountID .. " from active pack '" .. name .. "'")
    return mountID
end

-- Slash command handler
local function SlashHandler(msg)
    local args = {}
    for word in string.gmatch(msg or "", "%S+") do
        table.insert(args, word)
    end
    local command = string.lower(args[1] or "")

    if command == "debug-on" then
        MountieDB.settings.debugMode = true
        Mountie.Print("Debug mode: ON")

    elseif command == "debug-off" then
        MountieDB.settings.debugMode = false
        Mountie.Print("Debug mode: OFF")

    elseif command == "flying-on" then
        EnsureFlyingPreferenceSetting()
        MountieDB.settings.preferFlyingMounts = true
        Mountie.Print("Flying mount preference: ON")

    elseif command == "flying-off" then
        EnsureFlyingPreferenceSetting()
        MountieDB.settings.preferFlyingMounts = false
        Mountie.Print("Flying mount preference: OFF")

    elseif command == "status" then
        EnsureFlyingPreferenceSetting()
        Mountie.Print("Status:")
        Mountie.Print("- Total packs: " .. #MountieDB.packs)
        Mountie.Print("- Debug mode: " .. (MountieDB.settings.debugMode and "ON" or "OFF"))
        Mountie.Print("- Flying preference: " .. (MountieDB.settings.preferFlyingMounts and "ON" or "OFF"))
        Mountie.Print("- Active pack: " .. (Mountie.runtime.activePackName or "None"))
        Mountie.Print("- Can fly here: " .. (CanFlyInCurrentZone() and "YES" or "NO"))

    elseif command == "test" then
        local allMountIDs = C_MountJournal.GetMountIDs()
        local ownedCount = 0
        for _, mountID in ipairs(allMountIDs) do
            local _, _, _, _, _, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(mountID)
            if isCollected then ownedCount = ownedCount + 1 end
        end
        Mountie.Print("Total mounts in game: " .. #allMountIDs)
        Mountie.Print("Mounts you own: " .. ownedCount)
        Mountie.Debug("Mount API test successful")

    elseif command == "create" then
        if not args[2] then
            Mountie.Print("Usage: /mountie create <pack_name> [description]")
            return
        end
        local packName = args[2]
        local description = table.concat(args, " ", 3)
        local success, message = Mountie.CreatePack(packName, description)
        Mountie.Print(message)

    elseif command == "delete" then
        if not args[2] then
            Mountie.Print("Usage: /mountie delete <pack_name>")
            return
        end
        local success, message = Mountie.DeletePack(args[2])
        Mountie.Print(message)

    elseif command == "list" then
        local packs = Mountie.ListPacks()
        if #packs == 0 then
            Mountie.Print("No packs created yet. Use /mountie create <n> to make one!")
        else
            Mountie.Print("Your mount packs:")
            for _, pack in ipairs(packs) do
                local mountCount = #pack.mounts
                Mountie.Print("- " .. pack.name .. " (" .. mountCount .. " mounts)")
                if pack.description ~= "" then
                    Mountie.Print("  " .. pack.description)
                end
            end
        end

    elseif command == "show" then
        if not args[2] then
            Mountie.Print("Usage: /mountie show <pack_name>")
            return
        end
        local pack = Mountie.GetPack(args[2])
        if not pack then
            Mountie.Print("Pack '" .. args[2] .. "' not found")
            return
        end

        Mountie.Print("Pack: " .. pack.name)
        if pack.description ~= "" then
            Mountie.Print("Description: " .. pack.description)
        end
        if #pack.mounts == 0 then
            Mountie.Print("No mounts in this pack yet")
        else
            Mountie.Print("Mounts (" .. #pack.mounts .. "):")
            for _, mountID in ipairs(pack.mounts) do
                local name = C_MountJournal.GetMountInfoByID(mountID)
                Mountie.Print("  - " .. (name or "Unknown mount"))
            end
        end

    elseif command == "add" then
        if not args[2] or not args[3] then
            Mountie.Print("Usage: /mountie add <pack_name> <mount_id>")
            Mountie.Print("Use /mountie mounts to see your mount IDs")
            return
        end
        local packName = args[2]
        local mountID = tonumber(args[3])
        if not mountID then
            Mountie.Print("Mount ID must be a number")
            return
        end
        local success, message = Mountie.AddMountToPack(packName, mountID)
        Mountie.Print(message)

    elseif command == "remove" then
        if not args[2] or not args[3] then
            Mountie.Print("Usage: /mountie remove <pack_name> <mount_id>")
            return
        end
        local packName = args[2]
        local mountID = tonumber(args[3])
        if not mountID then
            Mountie.Print("Mount ID must be a number")
            return
        end
        local success, message = Mountie.RemoveMountFromPack(packName, mountID)
        Mountie.Print(message)

    elseif command == "mounts" then
        local ownedMounts = Mountie.GetOwnedMounts()
        Mountie.Print("Your mounts (showing first 10):")
        for i = 1, math.min(10, #ownedMounts) do
            local mount = ownedMounts[i]
            Mountie.Print("ID " .. mount.id .. ": " .. mount.name)
        end
        if #ownedMounts > 10 then
            Mountie.Print("... and " .. (#ownedMounts - 10) .. " more. Use /mountie findmount <n> to search")
        end

    elseif command == "findmount" then
        if not args[2] then
            Mountie.Print("Usage: /mountie findmount <search_term>")
            return
        end
        local searchTerm = string.lower(table.concat(args, " ", 2))
        local ownedMounts = Mountie.GetOwnedMounts()
        local matches = {}
        for _, mount in ipairs(ownedMounts) do
            if string.find(string.lower(mount.name), searchTerm) then
                table.insert(matches, mount)
            end
        end
        if #matches == 0 then
            Mountie.Print("No mounts found matching: " .. searchTerm)
        else
            Mountie.Print("Found " .. #matches .. " mount(s) matching '" .. searchTerm .. "':")
            for _, mount in ipairs(matches) do
                Mountie.Print("ID " .. mount.id .. ": " .. mount.name)
            end
        end

    elseif command == "ui" or command == "" then
        MountieUI.ToggleMainFrame()

        -- Clear and hide the chat edit box after handling the slash command
        C_Timer.After(0, function()
            local active = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
            if active then
                -- Escape clears text and hides the edit box
                ChatEdit_OnEscapePressed(active)
            end
        end)
    
    elseif command == "mount" then
        if not Mountie.MountActive() then
            Mountie.Print("Try creating a pack or favoriting a mount first.")
        end


    else
        Mountie.Print("Mountie Commands:")
        Mountie.Print("/mountie (or /mountie ui) - Open main window")
        Mountie.Print("/mountie create <n> [description] - Create a new pack")
        Mountie.Print("/mountie delete <n> - Delete a pack")
        Mountie.Print("/mountie list - Show all packs")
        Mountie.Print("/mountie show <n> - Show mounts in a pack")
        Mountie.Print("/mountie add <pack> <mount_id> - Add mount to pack")
        Mountie.Print("/mountie remove <pack> <mount_id> - Remove mount from pack")
        Mountie.Print("/mountie mounts - Show your first 10 mounts")
        Mountie.Print("/mountie findmount <search> - Search for mounts")
        Mountie.Print("/mountie status - Show addon status")
        Mountie.Print("/mountie flying-on/off - Toggle flying mount preference")
        -- Note: hidden commands: /mountie debug-on, /mountie debug-off
    end
end

-- Initialize addon when loaded
local function OnAddonLoaded(self, event, addonName)
    if addonName == "Mountie" then
        Mountie.Debug("Mountie loaded successfully!")
        Mountie.Print("v1.0.0 loaded. Type /mountie for commands.")
    end
end

-- Event frame setup
local eventFrame = CreateFrame("Frame")

local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "Mountie" then
            Mountie.Debug("Mountie loaded successfully!")
            Mountie.Print("v1.0.0 loaded. Type /mountie for commands.")
            -- Evaluate once on load (after the world is ready we'll evaluate again)
        end
    elseif event == "PLAYER_ENTERING_WORLD" or
           event == "ZONE_CHANGED" or
           event == "ZONE_CHANGED_NEW_AREA" then
        -- Evaluate active pack on relevant context changes
        C_Timer.After(0.2, Mountie.SelectActivePack)  -- small delay so map data is ready
    end
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:SetScript("OnEvent", OnEvent)


-- Register slash commands
SLASH_MOUNTIE1 = "/mountie"
SLASH_MOUNTIE2 = "/mt"
SlashCmdList["MOUNTIE"] = SlashHandler

Mountie.Debug("Core.lua loaded")