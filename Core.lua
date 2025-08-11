-- Mountie: Core Pack and Mount Management
Mountie.Debug("Core.lua loading...")

-- Runtime state for active-pack selection
Mountie.runtime = Mountie.runtime or {
    activePackName = nil,
    selectedPacks = {},
    cachedTransmogSetID = nil,
}

-- Cache for transmog set data
local transmogSetCache = {}
local lastTransmogCheck = 0
local TRANSMOG_CHECK_INTERVAL = 2 -- Check every 2 seconds

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

-- Get all available transmog sets and cache them
local function BuildTransmogSetCache()
    if next(transmogSetCache) then return end -- Already built
    
    Mountie.Debug("Building transmog set cache...")
    
    -- Get all sets
    local allSets = C_TransmogSets.GetAllSets()
    
    for _, setInfo in ipairs(allSets) do
        if setInfo.setID and setInfo.name then
            -- Get the appearances for this set
            local setAppearances = {}
            local sources = C_TransmogSets.GetSetSources(setInfo.setID)
            
            for _, sourceInfo in ipairs(sources) do
                if sourceInfo.appearanceID and sourceInfo.invType then
                    -- Convert invType to slot ID for comparison
                    local slotID = nil
                    if sourceInfo.invType == "INVTYPE_HEAD" then slotID = 1
                    elseif sourceInfo.invType == "INVTYPE_SHOULDER" then slotID = 3
                    elseif sourceInfo.invType == "INVTYPE_CHEST" or sourceInfo.invType == "INVTYPE_ROBE" then slotID = 5
                    elseif sourceInfo.invType == "INVTYPE_WAIST" then slotID = 6
                    elseif sourceInfo.invType == "INVTYPE_LEGS" then slotID = 7
                    elseif sourceInfo.invType == "INVTYPE_FEET" then slotID = 8
                    elseif sourceInfo.invType == "INVTYPE_WRIST" then slotID = 9
                    elseif sourceInfo.invType == "INVTYPE_HAND" then slotID = 10
                    elseif sourceInfo.invType == "INVTYPE_CLOAK" then slotID = 15
                    end
                    
                    if slotID then
                        setAppearances[slotID] = sourceInfo.appearanceID
                    end
                end
            end
            
            transmogSetCache[setInfo.setID] = {
                name = setInfo.name,
                appearances = setAppearances,
                expansionID = setInfo.expansionID,
                classMask = setInfo.classMask,
                collected = setInfo.collected
            }
        end
    end
    
    Mountie.Debug("Cached " .. #allSets .. " transmog sets")
end

-- Get current equipped appearance IDs
local function GetCurrentAppearances()
    local appearances = {}
    local slots = {1, 3, 5, 6, 7, 8, 9, 10, 15} -- Head, Shoulder, Chest, Waist, Legs, Feet, Wrist, Hands, Back
    
    for _, slotID in ipairs(slots) do
        local appearanceID, secondaryAppearanceID = C_TransmogCollection.GetSlotVisualInfo(slotID)
        if appearanceID and appearanceID ~= 0 then
            appearances[slotID] = appearanceID
        end
    end
    
    return appearances
end

-- Enhanced current transmog set detection
local function GetCurrentTransmogSetID()
    local currentTime = GetTime()
    if currentTime - lastTransmogCheck < TRANSMOG_CHECK_INTERVAL then
        return Mountie.runtime.cachedTransmogSetID
    end

    lastTransmogCheck = currentTime

    -- Build cache if needed
    BuildTransmogSetCache()

    -- Get current appearances
    local currentAppearances = GetCurrentAppearances()

    -- Find best matching set
    local bestMatch = nil
    local bestMatchScore = 0
    local minPiecesForMatch = 3 -- At least 3 pieces must match

    for setID, setData in pairs(transmogSetCache) do
        -- Only check sets available to this character's class
        local playerClass = select(2, UnitClass("player"))
        local classMask = setData.classMask or 0

        local skip = false
        if classMask > 0 then
            local classTable = {
                WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5,
                DEATHKNIGHT = 6, SHAMAN = 7, MAGE = 8, WARLOCK = 9, MONK = 10,
                DRUID = 11, DEMONHUNTER = 12, EVOKER = 13
            }
            local classFlag = classTable[playerClass]
            if classFlag and bit.band(classMask, bit.lshift(1, classFlag - 1)) == 0 then
                skip = true
            end
        end

        if not skip then
            -- Count matching pieces
            local matchingPieces = 0
            local totalSetPieces = 0

            for slotID, setAppearanceID in pairs(setData.appearances) do
                totalSetPieces = totalSetPieces + 1
                if currentAppearances[slotID] == setAppearanceID then
                    matchingPieces = matchingPieces + 1
                end
            end

            -- Calculate match score (percentage of set pieces worn)
            local matchScore = totalSetPieces > 0 and (matchingPieces / totalSetPieces) or 0

            -- Require minimum pieces and minimum percentage
            if matchingPieces >= minPiecesForMatch and matchScore > bestMatchScore and matchScore >= 0.5 then
                bestMatchScore = matchScore
                bestMatch = setID
            end
        end
    end

    -- Cache the result
    Mountie.runtime.cachedTransmogSetID = bestMatch

    if bestMatch and MountieDB.settings.debugMode then
        local setName = transmogSetCache[bestMatch].name
        Mountie.Debug("Detected transmog set: " .. setName .. " (ID: " .. bestMatch .. ", " .. math.floor(bestMatchScore * 100) .. "% match)")
    end

    return bestMatch
end

-- Utility function to get transmog set info by ID
function Mountie.GetTransmogSetInfo(setID)
    BuildTransmogSetCache()
    return transmogSetCache[setID]
end

-- Get all available transmog sets (for UI)
function Mountie.GetAllTransmogSets()
    BuildTransmogSetCache()
    
    local sets = {}
    for setID, setData in pairs(transmogSetCache) do
        table.insert(sets, {
            setID = setID,
            name = setData.name,
            expansionID = setData.expansionID,
            collected = setData.collected
        })
    end
    
    -- Sort by expansion and name
    table.sort(sets, function(a, b)
        if a.expansionID ~= b.expansionID then
            return a.expansionID < b.expansionID
        end
        return a.name < b.name
    end)
    
    return sets
end

-- Enhanced rule matching with priority support
local function DoesRuleMatch(rule)
    if not rule or not rule.type then 
        return false, 0 
    end
    
    local priority = rule.priority or MountieDB.settings.rulePriorities[rule.type] or 0
    
    if rule.type == "zone" then
        if not rule.mapID then return false, 0 end
        local currentMapID = GetPlayerMapID()
        if not currentMapID then return false, 0 end

        if currentMapID == rule.mapID then
            return true, priority + 50 -- Exact match bonus
        end

        if rule.includeParents then
            local info = C_Map.GetMapInfo(currentMapID)
            while info and info.parentMapID and info.parentMapID > 0 do
                if info.parentMapID == rule.mapID then
                    return true, priority -- Parent match, base priority
                end
                info = C_Map.GetMapInfo(info.parentMapID)
            end
        end
        
        return false, 0
        
    elseif rule.type == "transmog" then
        if not rule.setID then return false, 0 end
        local currentSetID = GetCurrentTransmogSetID()
        if currentSetID == rule.setID then
            return true, priority
        end
        return false, 0
    end
    
    return false, 0
end

-- Score a pack against current context with detailed breakdown
local function ScorePackAgainstContext(pack)
    if not pack or not pack.conditions or #pack.conditions == 0 then
        return 0, {}
    end
    
    local totalScore = 0
    local matchedRules = {}
    
    for i, rule in ipairs(pack.conditions) do
        local matched, score = DoesRuleMatch(rule)
        if matched then
            totalScore = totalScore + score
            table.insert(matchedRules, {
                type = rule.type,
                score = score,
                index = i
            })
        end
    end
    
    return totalScore, matchedRules
end

-- Get all matching packs with their scores
local function GetMatchingPacks()
    local packs = Mountie.ListPacks()
    local matchingPacks = {}
    
    for _, pack in ipairs(packs) do
        local score, matchedRules = ScorePackAgainstContext(pack)
        if score > 0 then
            table.insert(matchingPacks, {
                pack = pack,
                score = score,
                matchedRules = matchedRules
            })
        end
    end
    
    -- Sort by score (highest first)
    table.sort(matchingPacks, function(a, b) return a.score > b.score end)
    
    return matchingPacks
end

-- Enhanced pack selection with overlap modes
function Mountie.SelectActivePack()
    local matchingPacks = GetMatchingPacks()
    
    if #matchingPacks == 0 then
        if Mountie.runtime.activePackName ~= nil then
            Mountie.runtime.activePackName = nil
            Mountie.runtime.selectedPacks = {}
            Mountie.Debug("No matching packs - cleared active pack")
        end
        return
    end
    
    local selectedPacks = {}
    local overlapMode = MountieDB.settings.packOverlapMode or "priority"
    
    if overlapMode == "priority" then
        -- Use only the highest-scoring pack
        selectedPacks = {matchingPacks[1]}
        
    elseif overlapMode == "intersection" then
        -- Use all matching packs (intersection will happen in mount selection)
        selectedPacks = matchingPacks
        
    end
    
    -- Store the selection results
    Mountie.runtime.selectedPacks = selectedPacks
    
    -- For backward compatibility, set activePackName to the primary pack
    local newActiveName = selectedPacks[1] and selectedPacks[1].pack.name or nil
    
    if newActiveName ~= Mountie.runtime.activePackName then
        Mountie.runtime.activePackName = newActiveName
        
        if #selectedPacks == 1 then
            Mountie.Print("Active pack: " .. newActiveName)
        elseif #selectedPacks > 1 then
            local packNames = {}
            for _, sp in ipairs(selectedPacks) do
                table.insert(packNames, sp.pack.name)
            end
            Mountie.Print("Active packs (intersection): " .. table.concat(packNames, ", "))
        end
    end
end

-- Get a random favorite mount, optionally preferring flying mounts
local function GetRandomFavoriteMount()
    EnsureFlyingPreferenceSetting()
    
    local allFavorites = {}
    local flyingFavorites = {}
    local allMountIDs = C_MountJournal.GetMountIDs()
    
    for _, mountID in ipairs(allMountIDs) do
        local name, spellID, icon, active, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected =
            C_MountJournal.GetMountInfoByID(mountID)
        if isCollected and isUsable and isFavorite then
            table.insert(allFavorites, mountID)
            
            if IsFlyingMount(mountID) then
                table.insert(flyingFavorites, mountID)
            end
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

-- Enhanced mount selection with intersection support
local function GetRandomMountFromSelectedPacks()
    local selectedPacks = Mountie.runtime.selectedPacks or {}
    
    if #selectedPacks == 0 then
        return nil
    end
    
    if #selectedPacks == 1 then
        -- Single pack - use existing logic
        return GetRandomMountFromActivePackWithFlyingPreference()
    end
    
    -- Multiple packs - find intersection
    local intersectionMounts = {}
    local firstPack = selectedPacks[1].pack
    
    -- Start with mounts from first pack
    for _, mountID in ipairs(firstPack.mounts) do
        local inAllPacks = true
        
        -- Check if this mount exists in ALL other packs
        for i = 2, #selectedPacks do
            local otherPack = selectedPacks[i].pack
            local foundInOther = false
            for _, otherMountID in ipairs(otherPack.mounts) do
                if otherMountID == mountID then
                    foundInOther = true
                    break
                end
            end
            if not foundInOther then
                inAllPacks = false
                break
            end
        end
        
        if inAllPacks then
            table.insert(intersectionMounts, mountID)
        end
    end
    
    if #intersectionMounts == 0 then
        Mountie.Debug("No mounts in intersection of all packs")
        return nil
    end
    
    -- Apply flying preference to intersection
    EnsureFlyingPreferenceSetting()
    local usableMounts = {}
    local flyingMounts = {}
    
    for _, mountID in ipairs(intersectionMounts) do
        local name, spellID, icon, active, isUsable = C_MountJournal.GetMountInfoByID(mountID)
        if isUsable then
            table.insert(usableMounts, mountID)
            if IsFlyingMount(mountID) then
                table.insert(flyingMounts, mountID)
            end
        end
    end
    
    if #usableMounts == 0 then
        return nil
    end
    
    -- Prefer flying if enabled and available
    if MountieDB.settings.preferFlyingMounts and CanFlyInCurrentZone() and #flyingMounts > 0 then
        local idx = math.random(1, #flyingMounts)
        return flyingMounts[idx]
    end
    
    -- Fallback to any usable mount from intersection
    local idx = math.random(1, #usableMounts)
    return usableMounts[idx]
end

-- Pick and summon a mount from the active pack (or a sensible fallback)
function Mountie.MountActive()
    Mountie.Debug("MountActive called")
    
    -- Try selected packs first (zone/transmog rules)
    local mountID = GetRandomMountFromSelectedPacks()
    local source = "rule-based packs"
    
    -- Fallback to WoW's random favorite if no rule-based selection
    if not mountID then
        Mountie.Debug("No mount from rule-based selection, using WoW's random favorite mount")
        C_MountJournal.SummonByID(0)
        Mountie.Print("Summoned random favorite mount (using WoW's selection)")
        return true
    end
    
    -- Summon the selected mount
    local name = C_MountJournal.GetMountInfoByID(mountID)
    local packInfo = ""
    local selectedPacks = Mountie.runtime.selectedPacks or {}
    
    if #selectedPacks > 1 then
        packInfo = " from intersection of " .. #selectedPacks .. " packs"
    elseif #selectedPacks == 1 then
        packInfo = " from " .. selectedPacks[1].pack.name
    end
    
    Mountie.Debug("Summoning mount: " .. (name or "Unknown") .. packInfo)
    Mountie.Print("Summoned " .. (name or "Unknown") .. packInfo)
    C_MountJournal.SummonByID(mountID)
    return true
end

-- Global wrapper for the keybind and macros
function Mountie_MountKeybind()
    -- Must be called from a hardware event (key press / macro)
    Mountie.MountActive()
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

-- Event handler for transmog changes
local function OnTransmogChanged()
    -- Clear cached transmog set ID to force re-detection
    Mountie.runtime.cachedTransmogSetID = nil
    lastTransmogCheck = 0
    
    -- Re-evaluate active packs after a short delay
    C_Timer.After(0.5, function()
        GetCurrentTransmogSetID() -- Update cache
        Mountie.SelectActivePack()
    end)
end

-- Hook into transmog change events
local transmogEventFrame = CreateFrame("Frame")
transmogEventFrame:RegisterEvent("TRANSMOGRIFY_UPDATE")
transmogEventFrame:RegisterEvent("TRANSMOGRIFY_SUCCESS") 
transmogEventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
transmogEventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "TRANSMOGRIFY_UPDATE" or event == "TRANSMOGRIFY_SUCCESS" then
        OnTransmogChanged()
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        -- Only care about visible equipment slots
        local equipmentSlot = ...
        local visibleSlots = {1, 3, 5, 6, 7, 8, 9, 10, 15}
        for _, slotID in ipairs(visibleSlots) do
            if equipmentSlot == slotID then
                OnTransmogChanged()
                break
            end
        end
    end
end)

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

    elseif command == "overlap-priority" then
        MountieDB.settings.packOverlapMode = "priority"
        Mountie.Print("Pack overlap mode: Priority (highest scoring pack only)")
        C_Timer.After(0.1, Mountie.SelectActivePack)

    elseif command == "overlap-intersection" then
        MountieDB.settings.packOverlapMode = "intersection"
        Mountie.Print("Pack overlap mode: Intersection (mounts common to all matching packs)")
        C_Timer.After(0.1, Mountie.SelectActivePack)

    elseif command == "transmog" then
        local currentSetID = GetCurrentTransmogSetID()
        if currentSetID then
            local setInfo = Mountie.GetTransmogSetInfo(currentSetID)
            local setName = setInfo and setInfo.name or ("Set " .. currentSetID)
            Mountie.Print("Current transmog set: " .. setName .. " (ID: " .. currentSetID .. ")")
        else
            Mountie.Print("No transmog set detected")
        end

    elseif command == "packs-status" then
        local matchingPacks = GetMatchingPacks()
        if #matchingPacks == 0 then
            Mountie.Print("No packs match current conditions")
        else
            Mountie.Print("Matching packs:")
            for i, packData in ipairs(matchingPacks) do
                local ruleTypes = {}
                for _, rule in ipairs(packData.matchedRules) do
                    table.insert(ruleTypes, rule.type)
                end
                Mountie.Print("  " .. i .. ". " .. packData.pack.name .. " (score: " .. packData.score .. ", rules: " .. table.concat(ruleTypes, ", ") .. ")")
            end
            
            local overlapMode = MountieDB.settings.packOverlapMode or "priority"
            local selectedPacks = Mountie.runtime.selectedPacks or {}
            
            if overlapMode == "priority" and #selectedPacks > 0 then
                Mountie.Print("Active pack (priority mode): " .. selectedPacks[1].pack.name)
            elseif overlapMode == "intersection" and #selectedPacks > 1 then
                local packNames = {}
                for _, sp in ipairs(selectedPacks) do
                    table.insert(packNames, sp.pack.name)
                end
                Mountie.Print("Active packs (intersection mode): " .. table.concat(packNames, ", "))
            end
        end

    elseif command == "rebuild-transmog" then
        -- Clear transmog cache and rebuild
        transmogSetCache = {}
        Mountie.runtime.cachedTransmogSetID = nil
        lastTransmogCheck = 0
        BuildTransmogSetCache()
        local setCount = 0
        for _ in pairs(transmogSetCache) do setCount = setCount + 1 end
        Mountie.Print("Rebuilt transmog cache with " .. setCount .. " sets")

    elseif command == "status" then
        EnsureFlyingPreferenceSetting()
        Mountie.Print("Status:")
        Mountie.Print("- Total packs: " .. #MountieDB.packs)
        Mountie.Print("- Debug mode: " .. (MountieDB.settings.debugMode and "ON" or "OFF"))
        Mountie.Print("- Flying preference: " .. (MountieDB.settings.preferFlyingMounts and "ON" or "OFF"))
        Mountie.Print("- Overlap mode: " .. (MountieDB.settings.packOverlapMode or "priority"))
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
        Mountie.Print("/mountie transmog - Show current transmog set")
        Mountie.Print("/mountie packs-status - Show matching packs and scores")
        Mountie.Print("/mountie overlap-priority/intersection - Set overlap mode")
        Mountie.Print("/mountie flying-on/off - Toggle flying mount preference")
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
        end
    elseif event == "PLAYER_ENTERING_WORLD" or
           event == "ZONE_CHANGED" or
           event == "ZONE_CHANGED_NEW_AREA" then
        -- Evaluate active pack on relevant context changes
        C_Timer.After(0.2, Mountie.SelectActivePack)
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