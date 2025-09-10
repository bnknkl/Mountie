Mountie.Debug("Core.lua loading...")

Mountie.runtime = Mountie.runtime or {
    activePackName = nil,
    selectedPacks = {},
    cachedTransmogSetID = nil,
}

-- Version - update this when you change the .toc version
Mountie.version = "0.8"
local transmogSetCache = {}
local lastTransmogCheck = 0
local TRANSMOG_CHECK_INTERVAL = 2

function Mountie.CreatePack(name, description)
    if not name or name == "" then
        return false, "Pack name cannot be empty"
    end

    Mountie.Debug("CreatePack called with name: " .. name)

    local existingPack = Mountie.GetPackByName(name)
    if existingPack then
        local location = existingPack.isShared and "shared" or "character-specific"
        return false, "Pack '" .. name .. "' already exists (" .. location .. ")"
    end
    
    -- TODO: should probably validate the description length too

    local newPack = {
        name = name,
        description = description or "",
        mounts = {},
        conditions = {},
        created = time(),
        isShared = false, -- New packs default to character-specific
        isFallback = false, -- New packs default to not being fallback
    }

    local packs = Mountie.GetCharacterPacks()
    table.insert(packs, newPack)
    Mountie.SetCharacterPacks(packs)
    Mountie.VerbosePrint("Pack added. Total packs: " .. #packs)
    return true, "Pack '" .. name .. "' created successfully"
end

function Mountie.DeletePack(name)
    -- First try character-specific packs
    local charPacks = Mountie.GetCharacterPacks()
    for i, pack in ipairs(charPacks) do
        if pack.name == name then
            table.remove(charPacks, i)
            Mountie.SetCharacterPacks(charPacks)
            Mountie.Debug("Deleted character-specific pack: " .. name)
            return true, "Pack '" .. name .. "' deleted"
        end
    end
    
    -- Then try shared packs
    if MountieDB.sharedPacks then
        for i, pack in ipairs(MountieDB.sharedPacks) do
            if pack.name == name then
                table.remove(MountieDB.sharedPacks, i)
                Mountie.Debug("Deleted shared pack: " .. name)
                return true, "Shared pack '" .. name .. "' deleted"
            end
        end
    end
    
    return false, "Pack '" .. name .. "' not found"
end

function Mountie.DuplicatePack(sourceName, newName, newDescription)
    if not sourceName or sourceName == "" then
        return false, "Source pack name cannot be empty"
    end
    
    if not newName or newName == "" then
        return false, "New pack name cannot be empty"
    end
    
    Mountie.Debug("DuplicatePack called - source: " .. sourceName .. ", new: " .. newName)
    
    -- Check if new name already exists
    local existingPack = Mountie.GetPackByName(newName)
    if existingPack then
        local location = existingPack.isShared and "shared" or "character-specific"
        return false, "Pack '" .. newName .. "' already exists (" .. location .. ")"
    end
    
    -- Find source pack to duplicate
    local sourcePack = Mountie.GetPackByName(sourceName)
    if not sourcePack then
        return false, "Source pack '" .. sourceName .. "' not found"
    end
    
    -- Create deep copy of the source pack
    local duplicatedPack = {
        name = newName,
        description = newDescription or (sourcePack.description .. " (Copy)"),
        mounts = {},
        conditions = {},
        created = time(),
        isShared = false, -- New duplicated packs default to character-specific
        isFallback = false, -- New duplicated packs cannot be fallback (only one fallback allowed)
    }
    
    -- Deep copy mounts
    if sourcePack.mounts then
        for _, mountID in ipairs(sourcePack.mounts) do
            table.insert(duplicatedPack.mounts, mountID)
        end
    end
    
    -- Deep copy conditions
    if sourcePack.conditions then
        for _, condition in ipairs(sourcePack.conditions) do
            local newCondition = {}
            for key, value in pairs(condition) do
                if type(value) == "table" then
                    -- Deep copy nested tables (like transmog data)
                    newCondition[key] = {}
                    for k, v in pairs(value) do
                        newCondition[key][k] = v
                    end
                else
                    newCondition[key] = value
                end
            end
            table.insert(duplicatedPack.conditions, newCondition)
        end
    end
    
    -- Add duplicated pack to character packs (always character-specific)
    local packs = Mountie.GetCharacterPacks()
    table.insert(packs, duplicatedPack)
    Mountie.SetCharacterPacks(packs)
    
    Mountie.VerbosePrint("Pack '" .. sourceName .. "' duplicated as '" .. newName .. "' (" .. #duplicatedPack.mounts .. " mounts, " .. #duplicatedPack.conditions .. " conditions)")
    return true, "Pack '" .. sourceName .. "' duplicated as '" .. newName .. "'"
end

function Mountie.GetPack(name)
    return Mountie.GetPackByName(name)
end

function Mountie.ListPacks()
    return Mountie.GetAllAvailablePacks()
end

-- Toggle fallback status for a pack
function Mountie.TogglePackFallback(packName)
    local pack = Mountie.GetPackByName(packName)
    if not pack then
        return false, "Pack '" .. packName .. "' not found"
    end
    
    local allPacks = Mountie.GetAllAvailablePacks()
    
    if pack.isFallback then
        -- Remove fallback status
        pack.isFallback = false
        return true, "Pack '" .. packName .. "' is no longer the fallback pack"
    else
        -- Clear fallback from any other pack first (only one fallback allowed)
        for _, otherPack in ipairs(allPacks) do
            if otherPack.isFallback and otherPack.name ~= packName then
                otherPack.isFallback = false
                Mountie.Debug("Removed fallback status from pack: " .. otherPack.name)
            end
        end
        
        -- Set this pack as fallback
        pack.isFallback = true
        return true, "Pack '" .. packName .. "' is now the fallback pack"
    end
end

-- Get the current fallback pack
function Mountie.GetFallbackPack()
    local allPacks = Mountie.GetAllAvailablePacks()
    for _, pack in ipairs(allPacks) do
        if pack.isFallback then
            return pack
        end
    end
    return nil
end

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

    -- check if already exists
    for _, existingMountID in ipairs(pack.mounts) do  -- inconsistent variable naming
        if existingMountID == mountID then
            return false, "Mount '" .. name .. "' is already in pack '" .. packName .. "'"
        end
    end

    table.insert(pack.mounts, mountID)
    Mountie.VerbosePrint("Added mount " .. name .. " to pack " .. packName)
    return true, "Added '" .. name .. "' to pack '" .. packName .. "'"
    -- TODO: should we sort the mounts somehow? alphabetical maybe?
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
            Mountie.VerbosePrint("Removed mount " .. (name or "Unknown") .. " from pack " .. packName)
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
    if not allSets then
        Mountie.Debug("No transmog sets available from API")
        return
    end
    
    for _, setInfo in ipairs(allSets) do
        if setInfo.setID and setInfo.name then
            -- Get the appearances for this set using the correct API
            local setAppearances = {}
            
            -- Try the primary appearances API first
            local sourceIDs = C_TransmogSets.GetSetPrimaryAppearances(setInfo.setID)
            
            if sourceIDs and type(sourceIDs) == "table" then
                for _, sourceInfo in ipairs(sourceIDs) do
                    if sourceInfo and sourceInfo.appearanceID and sourceInfo.invType then
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
            else
                -- If primary appearances API doesn't work, we'll store the set anyway
                -- but without detailed appearance data (transmog detection will be basic)
                Mountie.Debug("Could not get appearance data for set: " .. setInfo.name)
            end
            
            transmogSetCache[setInfo.setID] = {
                name = setInfo.name,
                appearances = setAppearances,
                expansionID = setInfo.expansionID or 0,
                classMask = setInfo.classMask or 0,
                collected = setInfo.collected or false
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
        -- Try multiple API approaches for getting appearance data
        local appearanceID = nil
        
        -- Method 1: Try C_TransmogCollection.GetSlotInfo (this is likely the correct modern API)
        if C_TransmogCollection and C_TransmogCollection.GetSlotInfo then
            local success, slotInfo = pcall(C_TransmogCollection.GetSlotInfo, slotID)
            if success and slotInfo and slotInfo.appearanceID then
                appearanceID = slotInfo.appearanceID
            end
        end
        
        -- Method 2: Try the older API if the first doesn't work
        if not appearanceID and C_TransmogCollection and C_TransmogCollection.GetSlotVisualInfo then
            local success, tempAppearanceID = pcall(C_TransmogCollection.GetSlotVisualInfo, slotID)
            if success and tempAppearanceID then
                appearanceID = tempAppearanceID
            end
        end
        
        -- Skip Method 3 for now as it's causing the error
        
        if appearanceID and appearanceID ~= 0 then
            appearances[slotID] = appearanceID
        end
    end
    
    return appearances
end

-- Enhanced current transmog set detection
function Mountie.GetCurrentTransmogSetID()
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
        
        -- Skip sets not available to this class (if classMask is set)
        local skipThisSet = false
        if classMask > 0 then
            local classTable = {
                WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5,
                DEATHKNIGHT = 6, SHAMAN = 7, MAGE = 8, WARLOCK = 9, MONK = 10,
                DRUID = 11, DEMONHUNTER = 12, EVOKER = 13
            }
            local classFlag = classTable[playerClass]
            if classFlag and bit.band(classMask, bit.lshift(1, classFlag - 1)) == 0 then
                skipThisSet = true -- Skip this set
            end
        end
        
        if not skipThisSet then
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

-- Get all available transmog sets (for UI) - filtered by current character's class
function Mountie.GetAllTransmogSets()
    BuildTransmogSetCache()
    
    local sets = {}
    local playerClass = select(2, UnitClass("player"))
    
    -- Class bit flags for transmog sets
    local classTable = {
        WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5,
        DEATHKNIGHT = 6, SHAMAN = 7, MAGE = 8, WARLOCK = 9, MONK = 10,
        DRUID = 11, DEMONHUNTER = 12, EVOKER = 13
    }
    local playerClassFlag = classTable[playerClass]
    
    for setID, setData in pairs(transmogSetCache) do
        -- Filter by class availability
        local isAvailableToClass = true
        if setData.classMask and setData.classMask > 0 and playerClassFlag then
            -- Check if this class can use this set
            isAvailableToClass = bit.band(setData.classMask, bit.lshift(1, playerClassFlag - 1)) ~= 0
        end
        
        if isAvailableToClass then
            table.insert(sets, {
                setID = setID,
                name = setData.name,
                expansionID = setData.expansionID,
                collected = setData.collected
            })
        end
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
        
        -- Try multiple methods to get current map ID
        local currentMapID = GetPlayerMapID()
        
        -- Fallback methods if GetPlayerMapID() fails
        if not currentMapID then
            -- Try getting from best map for unit
            local mapID = C_Map.GetBestMapForUnit("player")
            if mapID then
                currentMapID = mapID
            end
        end
        
        if not currentMapID then
            -- Last resort: try getting from current zone text
            local zoneText = GetZoneText()
            if zoneText and zoneText ~= "" then
                -- Store unknown zones and retry later
                Mountie.Debug("Zone detection failed after teleport, zone text: " .. zoneText)
                C_Timer.After(2, function()
                    Mountie.Debug("Retrying pack evaluation after zone detection delay")
                    Mountie.SelectActivePack()
                end)
            end
            return false, 0
        end

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
        local currentSetID = Mountie.GetCurrentTransmogSetID()
        if currentSetID == rule.setID then
            return true, priority
        end
        return false, 0
        
    elseif rule.type == "custom_transmog" then
        if not rule.appearance or not rule.strictness then return false, 0 end
        local matches, matchCount, totalSlots = Mountie.MatchTransmogAppearance(
            rule.appearance,
            rule.includeWeapons or false,
            rule.strictness
        )
        if matches then
            -- Higher match percentage gives better score
            local matchScore = priority + (matchCount / totalSlots) * 25
            return true, matchScore
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
    
    -- Group rules by type for proper logic handling
    local zoneRules = {}
    local transmogRules = {}
    local customTransmogRules = {}
    
    for i, rule in ipairs(pack.conditions) do
        if rule.type == "zone" then
            table.insert(zoneRules, {rule = rule, index = i})
        elseif rule.type == "transmog" then
            table.insert(transmogRules, {rule = rule, index = i})
        elseif rule.type == "custom_transmog" then
            table.insert(customTransmogRules, {rule = rule, index = i})
        end
    end
    
    -- Zone rules: OR logic (any zone match qualifies)
    local zoneMatched = false
    if #zoneRules > 0 then
        for _, ruleData in ipairs(zoneRules) do
            local matched, score = DoesRuleMatch(ruleData.rule)
            if matched then
                zoneMatched = true
                totalScore = totalScore + score
                table.insert(matchedRules, {
                    type = ruleData.rule.type,
                    score = score,
                    index = ruleData.index
                })
                -- Continue checking other zones for potential higher scores
            end
        end
        
        -- If we have zone rules but none matched, pack doesn't qualify
        if not zoneMatched then
            return 0, {}
        end
    end
    
    -- Transmog rules: AND logic (all must match)
    if #transmogRules > 0 then
        for _, ruleData in ipairs(transmogRules) do
            local matched, score = DoesRuleMatch(ruleData.rule)
            if matched then
                totalScore = totalScore + score
                table.insert(matchedRules, {
                    type = ruleData.rule.type,
                    score = score,
                    index = ruleData.index
                })
            else
                -- If any transmog rule doesn't match, pack doesn't qualify
                return 0, {}
            end
        end
    end
    
    -- Custom transmog rules: AND logic (all must match)
    if #customTransmogRules > 0 then
        for _, ruleData in ipairs(customTransmogRules) do
            local matched, score = DoesRuleMatch(ruleData.rule)
            if matched then
                totalScore = totalScore + score
                table.insert(matchedRules, {
                    type = ruleData.rule.type,
                    score = score,
                    index = ruleData.index
                })
            else
                -- If any custom transmog rule doesn't match, pack doesn't qualify
                return 0, {}
            end
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
        
    elseif overlapMode == "union" then
        -- Use all matching packs (union will happen in mount selection)
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
        
        -- Update minimap icon when active pack changes
        if Mountie.MinimapIcon then
            Mountie.MinimapIcon.UpdateIcon()
        end
        -- TODO: also update any other UI elements that show active pack info
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
    
    -- Multiple packs - handle based on overlap mode
    local overlapMode = MountieDB.settings.packOverlapMode or "priority"
    local combinedMounts = {}
    
    if overlapMode == "intersection" then
        -- Find intersection - mounts that exist in ALL packs
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
                table.insert(combinedMounts, mountID)
            end
        end
        
        if #combinedMounts == 0 then
            Mountie.Debug("No mounts in intersection of all packs")
            return nil
        end
        
    elseif overlapMode == "union" then
        -- Find union - mounts that exist in ANY pack (no duplicates)
        local seenMounts = {}
        
        for _, packData in ipairs(selectedPacks) do
            for _, mountID in ipairs(packData.pack.mounts) do
                if not seenMounts[mountID] then
                    seenMounts[mountID] = true
                    table.insert(combinedMounts, mountID)
                end
            end
        end
        
        if #combinedMounts == 0 then
            Mountie.Debug("No mounts in union of all packs")
            return nil
        end
    end
    
    -- Apply flying preference to combined mounts
    EnsureFlyingPreferenceSetting()
    local usableMounts = {}
    local flyingMounts = {}
    
    for _, mountID in ipairs(combinedMounts) do
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

-- Get a random mount from the fallback pack, optionally preferring flying mounts
local function GetRandomMountFromFallbackPack()
    local fallbackPack = Mountie.GetFallbackPack()
    if not fallbackPack then
        Mountie.Debug("No fallback pack set")
        return nil
    end
    
    if not fallbackPack.mounts or #fallbackPack.mounts == 0 then
        Mountie.Debug("Fallback pack '" .. fallbackPack.name .. "' has no mounts")
        return nil
    end
    
    EnsureFlyingPreferenceSetting()
    
    -- Get all usable mounts from fallback pack
    local usableMounts = {}
    local flyingMounts = {}
    
    for _, mountID in ipairs(fallbackPack.mounts) do
        local name, spellID, icon, active, isUsable = C_MountJournal.GetMountInfoByID(mountID)
        if isUsable then
            table.insert(usableMounts, mountID)
            if IsFlyingMount(mountID) then
                table.insert(flyingMounts, mountID)
            end
        end
    end
    
    if #usableMounts == 0 then
        Mountie.Debug("No usable mounts in fallback pack")
        return nil
    end
    
    -- If flying preference is enabled and we can fly, prefer flying mounts
    if MountieDB.settings.preferFlyingMounts and CanFlyInCurrentZone() and #flyingMounts > 0 then
        local idx = math.random(1, #flyingMounts)
        local mountID = flyingMounts[idx]
        Mountie.Debug("Selected flying mount ID " .. mountID .. " from fallback pack '" .. fallbackPack.name .. "' (found " .. #flyingMounts .. " flying out of " .. #usableMounts .. " usable)")
        return mountID
    end
    
    -- Fallback to any usable mount from fallback pack
    local idx = math.random(1, #usableMounts)
    local mountID = usableMounts[idx]
    if MountieDB.settings.preferFlyingMounts and CanFlyInCurrentZone() then
        Mountie.Debug("No flying mounts in fallback pack, selected any mount ID " .. mountID .. " from fallback pack '" .. fallbackPack.name .. "' (had " .. #flyingMounts .. " flying out of " .. #usableMounts .. " usable)")
    else
        Mountie.Debug("Selected mount ID " .. mountID .. " from fallback pack '" .. fallbackPack.name .. "' (flying preference disabled or can't fly here)")
    end
    return mountID
end

function Mountie.MountActive()
    Mountie.Debug("MountActive called")
    
    local mountID = GetRandomMountFromSelectedPacks()
    local source = "rule-based packs"
    local packInfo = ""  -- this gets set later
    
    if mountID then
        -- We got a mount from rule-based selection
        local selectedPacks = Mountie.runtime.selectedPacks or {}
        if #selectedPacks > 1 then
            local overlapMode = MountieDB.settings.packOverlapMode or "priority"
            if overlapMode == "intersection" then
                packInfo = " from intersection of " .. #selectedPacks .. " packs"
            elseif overlapMode == "union" then
                packInfo = " from union of " .. #selectedPacks .. " packs"
            else
                packInfo = " from " .. #selectedPacks .. " packs"
            end
        elseif #selectedPacks == 1 then
            packInfo = " from " .. selectedPacks[1].pack.name
        end
    else
        -- Try fallback pack if no rule-based selection
        Mountie.Debug("No mount from rule-based selection, trying fallback pack")
        mountID = GetRandomMountFromFallbackPack()
        
        if mountID then
            local fallbackPack = Mountie.GetFallbackPack()
            source = "fallback pack"
            packInfo = " from fallback pack '" .. fallbackPack.name .. "'"
        else
            -- Final fallback to WoW's random favorite mount system
            Mountie.Debug("No fallback pack or no mounts in fallback pack, using WoW's random favorite mount")
            C_MountJournal.SummonByID(0)
            Mountie.Print("Summoned random favorite mount (using WoW's selection)")
            return true
        end
    end
    
    -- Summon the selected mount
    local name = C_MountJournal.GetMountInfoByID(mountID)
    Mountie.Debug("Summoning mount: " .. (name or "Unknown") .. packInfo)
    Mountie.VerbosePrint("Summoned " .. (name or "Unknown") .. packInfo)
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
        Mountie.GetCurrentTransmogSetID() -- Update cache
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
-- Parse command line arguments, handling quoted strings
local function ParseArgs(msg)
    local args = {}
    local i = 1
    local len = #msg
    
    while i <= len do
        -- Skip whitespace
        while i <= len and msg:sub(i, i):match("%s") do
            i = i + 1
        end
        
        if i > len then break end
        
        local startPos = i
        local arg = ""
        
        if msg:sub(i, i) == '"' then
            -- Quoted string
            i = i + 1 -- Skip opening quote
            while i <= len do
                local char = msg:sub(i, i)
                if char == '"' then
                    i = i + 1 -- Skip closing quote
                    break
                elseif char == '\\' and i < len then
                    -- Handle escaped characters
                    i = i + 1
                    arg = arg .. msg:sub(i, i)
                else
                    arg = arg .. char
                end
                i = i + 1
            end
        else
            -- Unquoted string
            while i <= len and not msg:sub(i, i):match("%s") do
                arg = arg .. msg:sub(i, i)
                i = i + 1
            end
        end
        
        if arg ~= "" then
            table.insert(args, arg)
        end
    end
    
    return args
end

local function SlashHandler(msg)
    local args = ParseArgs(msg or "")
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

    elseif command == "overlap-union" then
        MountieDB.settings.packOverlapMode = "union"
        Mountie.Print("Pack overlap mode: Union (mounts from any matching pack)")
        C_Timer.After(0.1, Mountie.SelectActivePack)

    elseif command == "transmog" then
        local currentSetID = Mountie.GetCurrentTransmogSetID()
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
                local modeText = overlapMode == "union" and "union mode" or "intersection mode"
                Mountie.Print("Active packs (" .. modeText .. "): " .. table.concat(packNames, ", "))
            end
        end

    elseif command == "characters" then
        if not MountieDB.characters or not next(MountieDB.characters) then
            Mountie.Print("No character data found.")
        else
            Mountie.Print("Mountie data across characters:")
            for charKey, charData in pairs(MountieDB.characters) do
                local packCount = charData.packs and #charData.packs or 0
                Mountie.Print("- " .. charKey .. ": " .. packCount .. " pack" .. (packCount == 1 and "" or "s"))
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
        local charPacks = Mountie.GetCharacterPacks()
        local sharedPacks = MountieDB.sharedPacks or {}
        local allPacks = Mountie.GetAllAvailablePacks()
        local charKey = UnitName("player") .. "-" .. GetRealmName()
        Mountie.Print("Status:")
        Mountie.Print("- Character: " .. charKey)
        Mountie.Print("- Character-specific packs: " .. #charPacks)
        Mountie.Print("- Account-wide packs: " .. #sharedPacks)
        Mountie.Print("- Total available packs: " .. #allPacks)
        Mountie.Print("- Verbose mode: " .. (MountieDB.settings.verboseMode and "ON" or "OFF"))
        Mountie.Print("- Debug mode: " .. (MountieDB.settings.debugMode and "ON" or "OFF"))
        Mountie.Print("- Flying preference: " .. (MountieDB.settings.preferFlyingMounts and "ON" or "OFF"))
        Mountie.Print("- Overlap mode: " .. (MountieDB.settings.packOverlapMode or "priority"))
        Mountie.Print("- Active pack: " .. (Mountie.runtime.activePackName or "None"))
        local fallbackPack = Mountie.GetFallbackPack()
        Mountie.Print("- Fallback pack: " .. (fallbackPack and fallbackPack.name or "None"))
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
        local allPacks = Mountie.GetAllAvailablePacks()
        if #allPacks == 0 then
            Mountie.Print("No packs created yet. Use /mountie create <n> to make one!")
        else
            Mountie.Print("Your mount packs:")
            for _, pack in ipairs(allPacks) do
                local mountCount = #pack.mounts
                local shareStatus = pack.isShared and " |cff88ff88[Account-Wide]|r" or " |cffffff88[Character]|r"
                local fallbackStatus = pack.isFallback and " |cffff9900[Fallback]|r" or ""
                Mountie.Print("- " .. pack.name .. " (" .. mountCount .. " mounts)" .. shareStatus .. fallbackStatus)
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

    elseif command == "debug-mount-types" then
        MountieUI.DebugMountTypes()

    elseif command == "debug-faction-mounts" then
        MountieUI.DebugFactionMounts()
        
    elseif command == "test-transmog" then
        local packName = args[2]
        local transmogName = args[3] or "Test Transmog"
        local strictness = tonumber(args[4]) or 6
        
        if not packName then
            Mountie.Print("Usage: /mountie test-transmog <pack_name> [transmog_name] [strictness]")
            return
        end
        
        -- Show what we're actually capturing
        local appearance = Mountie.CaptureCurrentAppearance(false)
        Mountie.Print("Capturing current appearance as '" .. transmogName .. "':")
        local filledSlots = 0
        for slot, appearanceID in pairs(appearance) do
            if appearanceID then
                filledSlots = filledSlots + 1
                Mountie.Print("  " .. slot .. ": " .. appearanceID)
            end
        end
        Mountie.Print("Total slots captured: " .. filledSlots)
        
        local success, message = Mountie.AddTransmogRule(packName, transmogName, false, strictness)
        Mountie.Print(message)
        
        if success then
            Mountie.Print("Testing transmog detection...")
            local matchingPacks = Mountie.CheckTransmogRules()
            if #matchingPacks > 0 then
                Mountie.Print("Found " .. #matchingPacks .. " matching transmog rule(s)")
                for _, match in ipairs(matchingPacks) do
                    Mountie.Print("- " .. match.pack.name .. " (" .. match.rule.name .. "): " .. 
                                match.matchCount .. "/" .. match.totalSlots .. " pieces")
                end
            else
                Mountie.Print("No matching transmog rules")
            end
        end
        
    elseif command == "show-appearance" then
        local appearance = Mountie.CaptureCurrentAppearance(true)
        Mountie.Print("Current appearance:")
        for slot, appearanceID in pairs(appearance) do
            Mountie.Print("- " .. slot .. ": " .. (appearanceID or "empty"))
        end
        
    elseif command == "debug-zone" then
        Mountie.Print("Zone Detection Debug:")
        
        local mapID1 = GetPlayerMapID()
        local mapID2 = C_Map.GetBestMapForUnit("player")
        local zoneText = GetZoneText()
        local subzoneText = GetSubZoneText()
        local realZoneText = GetRealZoneText()
        
        Mountie.Print("GetPlayerMapID(): " .. (mapID1 or "nil"))
        Mountie.Print("GetBestMapForUnit(): " .. (mapID2 or "nil"))
        Mountie.Print("Zone Text: " .. (zoneText or "nil"))
        Mountie.Print("Subzone Text: " .. (subzoneText or "nil"))
        Mountie.Print("Real Zone Text: " .. (realZoneText or "nil"))
        
        local finalMapID = mapID1 or mapID2
        if finalMapID then
            local mapInfo = C_Map.GetMapInfo(finalMapID)
            if mapInfo then
                Mountie.Print("Map ID " .. finalMapID .. ": " .. (mapInfo.name or "Unknown"))
                Mountie.Print("Map Type: " .. (mapInfo.mapType or "Unknown"))
                
                -- Show parent hierarchy
                local parent = mapInfo
                local level = 0
                while parent and parent.parentMapID and parent.parentMapID > 0 and level < 5 do
                    parent = C_Map.GetMapInfo(parent.parentMapID)
                    if parent then
                        level = level + 1
                        Mountie.Print("Parent " .. level .. ": " .. parent.parentMapID .. " (" .. (parent.name or "Unknown") .. ")")
                    end
                end
            else
                Mountie.Print("Could not get map info for ID " .. finalMapID)
            end
        else
            Mountie.Print("No valid map ID detected")
        end
        
    elseif command == "update-transmog" then
        Mountie.Print("Manually re-evaluating transmog rules...")
        
        -- Test if transmog system is working
        local testAppearance = Mountie.CaptureCurrentAppearance(false)
        if not testAppearance or not next(testAppearance) then
            Mountie.Print("Transmog detection not working properly.")
            Mountie.Print("Please visit a Transmogrifier vendor and open the transmog UI once to initialize the system.")
            Mountie.Print("After that, transmog-based packs will work automatically when changing transmogs.")
            return
        end
        
        Mountie.SelectActivePack()
        local selectedPacks = Mountie.runtime.selectedPacks or {}
        if #selectedPacks == 0 then
            Mountie.Print("No packs match current conditions")
            Mountie.Print("If you just changed transmog, try visiting a Transmogrifier vendor to refresh the system.")
        else
            Mountie.Print("Active packs after update:")
            for _, packData in ipairs(selectedPacks) do
                Mountie.Print("- " .. packData.pack.name .. " (score: " .. packData.score .. ")")
            end
        end
        
    elseif command == "replace-transmog" then
        local packName = args[2]
        local transmogName = args[3] or "Updated Transmog"
        local strictness = tonumber(args[4]) or 6
        
        if not packName then
            Mountie.Print("Usage: /mountie replace-transmog <pack_name> [transmog_name] [strictness]")
            return
        end
        
        -- Auto-initialize transmog system if needed
        if not C_AddOns.IsAddOnLoaded("Blizzard_Collections") then
            C_AddOns.LoadAddOn("Blizzard_Collections")
            Mountie.Print("Loading transmog system...")
        end
        
        -- First remove existing transmog rules from the pack
        local pack = Mountie.GetPack(packName)
        if not pack then
            Mountie.Print("Pack '" .. packName .. "' not found")
            return
        end
        
        -- Remove all custom_transmog rules
        local removedCount = 0
        for i = #pack.conditions, 1, -1 do
            if pack.conditions[i].type == "custom_transmog" then
                table.remove(pack.conditions, i)
                removedCount = removedCount + 1
            end
        end
        
        if removedCount > 0 then
            Mountie.Print("Removed " .. removedCount .. " existing transmog rule(s) from '" .. packName .. "'")
        end
        
        -- Add the new rule
        local appearance = Mountie.CaptureCurrentAppearance(false)
        Mountie.Print("Replacing with current appearance as '" .. transmogName .. "':")
        local filledSlots = 0
        for slot, appearanceID in pairs(appearance) do
            if appearanceID then
                filledSlots = filledSlots + 1
                Mountie.Print("  " .. slot .. ": " .. appearanceID)
            end
        end
        Mountie.Print("Total slots captured: " .. filledSlots)
        
        local success, message = Mountie.AddTransmogRule(packName, transmogName, false, strictness)
        Mountie.Print(message)
        
    elseif command == "init-transmog" then
        Mountie.Print("Initializing transmog system...")
        
        -- Force load the Collections addon
        if not C_AddOns.IsAddOnLoaded("Blizzard_Collections") then
            C_AddOns.LoadAddOn("Blizzard_Collections")
            Mountie.Print("Loaded Blizzard_Collections addon")
        else
            Mountie.Print("Blizzard_Collections addon already loaded")
        end
        
        -- Force initialize transmog UI and data
        Mountie.Print("Force-loading transmog UI...")
        
        -- Load the Collections UI
        CollectionsJournal_LoadUI()
        
        -- Open to Appearances tab to initialize transmog data
        local wasShown = CollectionsJournal and CollectionsJournal:IsShown()
        
        -- Open Collections journal if not already shown
        if not wasShown then
            ToggleCollectionsJournal()
        end
        
        -- Navigate to Appearances tab
        if CollectionsJournal and CollectionsJournalTab4 then
            CollectionsJournalTab4:Click()
        end
        
        -- Let the UI load and initialize
        C_Timer.After(1, function()
            -- Try to access wardrobe frame elements to trigger initialization
            if WardrobeFrame then
                -- Just accessing these elements should trigger initialization
                local _ = WardrobeCollectionFrame and WardrobeCollectionFrame.SetsCollectionFrame
            end
            
            -- Force a transmog data refresh
            if C_TransmogSets then
                C_TransmogSets.GetAllSets()
            end
            
            -- Close if it wasn't originally shown
            C_Timer.After(0.5, function()
                if not wasShown and CollectionsJournal then
                    CollectionsJournal:Hide()
                end
                
                Mountie.Print("Transmog UI initialization complete")
            end)
        end)
        
        -- Test transmog detection
        C_Timer.After(0.5, function()
            local testLoc = TransmogUtil and TransmogUtil.GetTransmogLocation(1, Enum.TransmogType.Appearance, Enum.TransmogModification.Main)
            if testLoc then
                local success = pcall(C_Transmog.GetSlotVisualInfo, testLoc)
                if success then
                    Mountie.Print("Transmog system initialized successfully!")
                else
                    Mountie.Print("Transmog system still not fully ready. Try manually opening Collections > Appearances.")
                end
            else
                Mountie.Print("TransmogUtil not available. Transmog detection may not work.")
            end
        end)
        
    elseif command == "test-parse" then
        Mountie.Print("Parsed arguments:")
        for i, arg in ipairs(args) do
            Mountie.Print(i .. ": '" .. arg .. "'")
        end
    
    elseif command == "share" then
        if not args[2] then
            Mountie.Print("Usage: /mountie share <pack_name>")
            return
        end
        local success, message = Mountie.TogglePackShared(args[2])
        Mountie.Print(message)
    
    elseif command == "fallback" then
        if not args[2] then
            Mountie.Print("Usage: /mountie fallback <pack_name>")
            Mountie.Print("Toggle a pack as the fallback pack (used when no rules match)")
            return
        end
        local success, message = Mountie.TogglePackFallback(args[2])
        Mountie.Print(message)
    
    elseif command == "debug-db" then
        Mountie.Print("Database Debug Info:")
        Mountie.Print("MountieDB type: " .. type(MountieDB))
        if MountieDB then
            Mountie.Print("MountieDB.sharedPacks type: " .. type(MountieDB.sharedPacks))
            if MountieDB.sharedPacks then
                Mountie.Print("Shared packs count: " .. #MountieDB.sharedPacks)
            else
                Mountie.Print("MountieDB.sharedPacks is nil!")
            end
        else
            Mountie.Print("MountieDB is nil!")
        end
    
    elseif command == "verbose-on" then
        MountieDB.settings.verboseMode = true
        Mountie.Print("Verbose mode: ON")

    elseif command == "verbose-off" then
        MountieDB.settings.verboseMode = false
        Mountie.Print("Verbose mode: OFF")
    
    elseif command == "test-scroll" then
        if not _G.MountieMainFrame then
            Mountie.Print("Open Mountie UI first")
            return
        end
        
        local packPanel = _G.MountieMainFrame.packPanel
        if not packPanel then
            Mountie.Print("Pack panel not found")
            return
        end
        
        -- Create a simple red test frame at the very top
        local testFrame = CreateFrame("Frame", nil, packPanel)
        testFrame:SetSize(300, 50)
        testFrame:SetPoint("TOPLEFT", packPanel, "TOPLEFT", 20, -80) -- Same position as the scroll frame
        
        local bg = testFrame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(testFrame)
        bg:SetColorTexture(1, 0, 0, 0.8) -- Bright red
        
        local text = testFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        text:SetPoint("CENTER", testFrame, "CENTER", 0, 0)
        text:SetText("TEST FRAME - TOP OF PACK PANEL")
        text:SetTextColor(1, 1, 1, 1)
        
        testFrame:Show()
        
        Mountie.Print("Created red test frame at top of pack panel")
        
        -- Auto-hide after 5 seconds
        C_Timer.After(5, function()
            testFrame:Hide()
            testFrame:SetParent(nil)
        end)

    else
        Mountie.Print("Mountie Commands:")
        Mountie.Print("/mountie (or /mountie ui) - Open main window")
        Mountie.Print("/mountie create <n> [description] - Create a new pack")
        Mountie.Print("/mountie delete <n> - Delete a pack")
        Mountie.Print("/mountie share <n> - Toggle pack between character-specific and account-wide")
        Mountie.Print("/mountie fallback <n> - Toggle pack as fallback (used when no rules match)")
        Mountie.Print("/mountie list - Show all packs for this character")
        Mountie.Print("/mountie characters - Show pack count across all characters")
        Mountie.Print("/mountie show <n> - Show mounts in a pack")
        Mountie.Print("/mountie add <pack> <mount_id> - Add mount to pack")
        Mountie.Print("/mountie remove <pack> <mount_id> - Remove mount from pack")
        Mountie.Print("/mountie mounts - Show your first 10 mounts")
        Mountie.Print("/mountie findmount <search> - Search for mounts")
        Mountie.Print("/mountie status - Show addon status")
        Mountie.Print("/mountie transmog - Show current transmog set")
        Mountie.Print("/mountie packs-status - Show matching packs and scores")
        Mountie.Print("/mountie test-transmog <pack> [name] [strictness] - Add transmog rule to pack")
        Mountie.Print("/mountie replace-transmog <pack> [name] [strictness] - Replace pack's transmog rules")
        Mountie.Print("/mountie update-transmog - Manually re-evaluate transmog rules")
        Mountie.Print("/mountie init-transmog - Initialize transmog system (run if detection not working)")
        Mountie.Print("/mountie debug-zone - Show detailed zone detection information")
        Mountie.Print("/mountie overlap-priority/intersection - Set overlap mode")
        Mountie.Print("/mountie flying-on/off - Toggle flying mount preference")
        Mountie.Print("/mountie verbose-on/off - Toggle verbose output")
        
        -- Only show debug commands if debug mode is enabled
        if MountieDB.settings.debugMode then
            Mountie.Print("---")
            Mountie.Print("Debug Commands (debug mode enabled):")
            Mountie.Print("/mountie debug-on/off - Toggle debug mode")
            Mountie.Print("/mountie debug-mount-types - Analyze mount type IDs")
            Mountie.Print("/mountie debug-faction-mounts - Analyze faction filtering")
            Mountie.Print("/mountie rebuild-transmog - Rebuild transmog cache")
        end
    end
end

-- Transmog Detection System
local function EnsureTransmogDataLoaded()
    -- Try to force load transmog UI components if needed
    if not C_AddOns.IsAddOnLoaded("Blizzard_Collections") then
        Mountie.Debug("Loading Blizzard_Collections addon...")
        C_AddOns.LoadAddOn("Blizzard_Collections")
    end
    
    -- Check if TransmogUtil is available
    if not _G.TransmogUtil then
        Mountie.Debug("TransmogUtil not available - transmog detection may not work properly")
        return false
    end
    
    -- Test if we can create a transmog location
    local success, testLoc = pcall(TransmogUtil.GetTransmogLocation, 1, Enum.TransmogType.Appearance, Enum.TransmogModification.Main)
    if not success or not testLoc then
        Mountie.Debug("TransmogLocation creation failed - transmog detection may not work properly")
        return false
    end
    
    return true
end

function Mountie.CaptureCurrentAppearance(includeWeapons)
    includeWeapons = includeWeapons or false
    
    -- Ensure transmog data is available
    if not EnsureTransmogDataLoaded() then
        Mountie.Print("Warning: Transmog system not fully loaded.")
        Mountie.Print("Visit a Transmogrifier vendor and open the transmog UI once, then try again.")
        return {}
    end
    
    local appearance = {}
    
    -- Define equipment slots to check
    local armorSlots = {
        head = INVSLOT_HEAD,
        shoulder = INVSLOT_SHOULDER,
        chest = INVSLOT_CHEST,
        waist = INVSLOT_WAIST,
        legs = INVSLOT_LEGS,
        feet = INVSLOT_FEET,
        wrist = INVSLOT_WRIST,
        hands = INVSLOT_HAND,
        back = INVSLOT_BACK,
        shirt = INVSLOT_BODY,
        tabard = INVSLOT_TABARD
    }
    
    local weaponSlots = {
        mainhand = INVSLOT_MAINHAND,
        offhand = INVSLOT_OFFHAND
    }
    
    -- Use the correct TransmogLocation approach to get actual transmog appearance IDs
    for slotName, slotID in pairs(armorSlots) do
        local transmogLocation = TransmogUtil.GetTransmogLocation(slotID, Enum.TransmogType.Appearance, Enum.TransmogModification.Main)
        if transmogLocation then
            local success, baseSourceID, baseVisualID, appliedSourceID, appliedVisualID = pcall(C_Transmog.GetSlotVisualInfo, transmogLocation)
            if success then
                -- Use appliedVisualID if available (transmog applied), otherwise baseVisualID (no transmog)
                appearance[slotName] = appliedVisualID or baseVisualID
            else
                -- Fallback to item ID if transmog API fails
                local itemID = GetInventoryItemID("player", slotID)
                appearance[slotName] = itemID
            end
        else
            appearance[slotName] = nil -- Empty slot
        end
    end
    
    -- Capture weapon appearance if requested  
    if includeWeapons then
        for slotName, slotID in pairs(weaponSlots) do
            local transmogLocation = TransmogUtil.GetTransmogLocation(slotID, Enum.TransmogType.Appearance, Enum.TransmogModification.Main)
            if transmogLocation then
                local success, baseSourceID, baseVisualID, appliedSourceID, appliedVisualID = pcall(C_Transmog.GetSlotVisualInfo, transmogLocation)
                if success then
                    -- Use appliedVisualID if available (transmog applied), otherwise baseVisualID (no transmog)
                    appearance[slotName] = appliedVisualID or baseVisualID
                else
                    -- Fallback to item ID if transmog API fails
                    local itemID = GetInventoryItemID("player", slotID)
                    appearance[slotName] = itemID
                end
            else
                appearance[slotName] = nil -- Empty slot
            end
        end
    end
    
    return appearance
end

function Mountie.MatchTransmogAppearance(savedAppearance, includeWeapons, strictness)
    local currentAppearance = Mountie.CaptureCurrentAppearance(includeWeapons)
    
    local matches = 0
    local totalSlots = 0
    
    -- Count matches for all saved slots
    for slotName, savedID in pairs(savedAppearance) do
        totalSlots = totalSlots + 1
        local currentID = currentAppearance[slotName]
        
        -- Match if both are nil (empty) or both have same appearance ID
        if (savedID == nil and currentID == nil) or (savedID == currentID) then
            matches = matches + 1
        end
    end
    
    -- Return whether we meet the strictness requirement
    return matches >= strictness, matches, totalSlots
end

function Mountie.AddTransmogRule(packName, transmogName, includeWeapons, strictness)
    local packs = Mountie.GetCharacterPacks()
    local pack = Mountie.GetPack(packName)
    
    if not pack then
        return false, "Pack '" .. packName .. "' not found"
    end
    
    -- Capture current appearance
    local appearance = Mountie.CaptureCurrentAppearance(includeWeapons)
    
    -- Create transmog rule
    local transmogRule = {
        type = "custom_transmog",
        name = transmogName,
        strictness = strictness,
        includeWeapons = includeWeapons,
        appearance = appearance,
        created = time()
    }
    
    -- Add to pack conditions
    pack.conditions = pack.conditions or {}
    table.insert(pack.conditions, transmogRule)
    
    -- Save the updated packs
    Mountie.SetCharacterPacks(packs)
    
    return true, "Transmog rule '" .. transmogName .. "' added to pack '" .. packName .. "'"
end

function Mountie.CheckTransmogRules()
    local packs = Mountie.GetCharacterPacks()
    local matchingPacks = {}
    
    for _, pack in ipairs(packs) do
        if pack.conditions then
            for _, condition in ipairs(pack.conditions) do
                if condition.type == "custom_transmog" then
                    local matches, matchCount, totalSlots = Mountie.MatchTransmogAppearance(
                        condition.appearance, 
                        condition.includeWeapons, 
                        condition.strictness
                    )
                    
                    if matches then
                        table.insert(matchingPacks, {
                            pack = pack,
                            rule = condition,
                            matchCount = matchCount,
                            totalSlots = totalSlots,
                            score = matchCount / totalSlots -- For priority calculation
                        })
                        
                        Mountie.Debug("Transmog rule '" .. condition.name .. "' matched: " .. 
                                    matchCount .. "/" .. totalSlots .. " pieces")
                    end
                end
            end
        end
    end
    
    return matchingPacks
end

-- Initialize addon when loaded
local function OnAddonLoaded(self, event, addonName)
    if addonName == "Mountie" then
        Mountie.Debug("Mountie loaded successfully!")
        Mountie.Print("v" .. Mountie.version .. " loaded. Type /mountie for commands.")
    end
end

-- Event frame setup
local eventFrame = CreateFrame("Frame")

local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "Mountie" then
            Mountie.Debug("Mountie loaded successfully!")
            Mountie.Print("v" .. Mountie.version .. " loaded. Type /mountie for commands.")
            
            -- Auto-initialize transmog system after a brief delay
            C_Timer.After(2, function()
                if not C_AddOns.IsAddOnLoaded("Blizzard_Collections") then
                    Mountie.Debug("Auto-loading Blizzard_Collections for transmog support...")
                    C_AddOns.LoadAddOn("Blizzard_Collections")
                end
            end)
            
            -- Initialize pack evaluation with retries for zone detection
            local function InitializePackEvaluation(attempt)
                attempt = attempt or 1
                C_Timer.After(1 + attempt, function()
                    local mapID = GetPlayerMapID() or C_Map.GetBestMapForUnit("player")
                    if mapID then
                        Mountie.Debug("Zone detection initialized successfully on attempt " .. attempt)
                        Mountie.SelectActivePack()
                    elseif attempt < 5 then
                        Mountie.Debug("Zone detection failed on attempt " .. attempt .. ", retrying...")
                        InitializePackEvaluation(attempt + 1)
                    else
                        Mountie.Debug("Zone detection failed after 5 attempts, will retry on events")
                    end
                end)
            end
            
            InitializePackEvaluation()
            
            -- Initialize minimap icon
            if Mountie.MinimapIcon then
                Mountie.MinimapIcon.Initialize()
            end
        end
    elseif event == "PLAYER_ENTERING_WORLD" or
           event == "ZONE_CHANGED" or
           event == "ZONE_CHANGED_NEW_AREA" then
        -- Evaluate active pack on relevant context changes
        C_Timer.After(0.2, Mountie.SelectActivePack)
    elseif event == "ZONE_CHANGED_INDOORS" then
        -- Handle indoor zone changes (like entering buildings/instances)
        C_Timer.After(0.5, Mountie.SelectActivePack)
    elseif event == "NEW_WMO_CHUNK" then
        -- Handle entering new world model chunks (can indicate zone changes)
        C_Timer.After(1, Mountie.SelectActivePack)
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        -- Re-evaluate packs when equipment/transmog changes
        C_Timer.After(0.5, Mountie.SelectActivePack)
    end
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
eventFrame:RegisterEvent("NEW_WMO_CHUNK")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:SetScript("OnEvent", OnEvent)

-- Register slash commands
SLASH_MOUNTIE1 = "/mountie"
SLASH_MOUNTIE2 = "/mt"
SlashCmdList["MOUNTIE"] = SlashHandler

Mountie.Debug("Core.lua loaded")