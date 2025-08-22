BINDING_HEADER_MOUNTIE = "Mountie"
BINDING_NAME_MOUNTIE_SUMMON = "Summon from active pack"

Mountie   = Mountie   or {}
MountieUI = MountieUI or {}

local function GetCharacterKey()
    local name = UnitName("player")
    local realm = GetRealmName()
    return name .. "-" .. realm
end

MountieDB = MountieDB or {}
local function MigrateOldData()
    if MountieDB.packs and type(MountieDB.packs) == "table" and #MountieDB.packs > 0 then
        Mountie.Debug("Migrating old pack data to character-specific format...")
        
        MountieDB.characters = MountieDB.characters or {}
        local charKey = GetCharacterKey()
        
        MountieDB.characters[charKey] = {
            packs = MountieDB.packs,
            created = time(),
            migrated = true
        }
        
        -- Remove old packs array
        MountieDB.packs = nil
        
        Mountie.Debug("Migrated " .. #MountieDB.characters[charKey].packs .. " packs to character: " .. charKey)
    end
end

if not MountieDB then
    MountieDB = {}
end

if not MountieDB.characters then
    MountieDB.characters = {}
end

if not MountieDB.sharedPacks then
    MountieDB.sharedPacks = {}
end

if not MountieDB.settings then
    MountieDB.settings = {
        debugMode = false,
        verboseMode = false,
        preferFlyingMounts = true,
        packOverlapMode = "priority",
        rulePriorities = {
            transmog = 100,
            zone = 50,
        }
    }
end

local function InitializeCharacterData()
    MigrateOldData()
    
    local charKey = GetCharacterKey()
    if not MountieDB.characters[charKey] then
        MountieDB.characters[charKey] = {
            packs = {},
            created = time()
        }
        Mountie.Debug("Initialized data for character: " .. charKey)
    end
end

-- Get current character's pack data (character-specific only)
function Mountie.GetCharacterPacks()
    InitializeCharacterData()
    local charKey = GetCharacterKey()
    return MountieDB.characters[charKey].packs
end

-- Set current character's pack data (character-specific only)
function Mountie.SetCharacterPacks(packs)
    InitializeCharacterData()
    local charKey = GetCharacterKey()
    MountieDB.characters[charKey].packs = packs
end

-- Get all packs available to current character (character-specific + shared)
function Mountie.GetAllAvailablePacks()
    InitializeCharacterData()
    local allPacks = {}
    
    -- Add character-specific packs
    local charPacks = Mountie.GetCharacterPacks()
    for _, pack in ipairs(charPacks) do
        pack.isShared = false -- Mark as character-specific
        table.insert(allPacks, pack)
    end
    
    -- Add shared packs
    if MountieDB.sharedPacks then
        for _, pack in ipairs(MountieDB.sharedPacks) do
            pack.isShared = true -- Mark as shared
            table.insert(allPacks, pack)
        end
    end
    
    return allPacks
end

-- Toggle a pack's shared status
function Mountie.TogglePackShared(packName)
    local pack = nil
    local wasShared = false
    local sourceIndex = nil
    
    -- First check if it's currently in character-specific packs
    local charPacks = Mountie.GetCharacterPacks()
    for i, p in ipairs(charPacks) do
        if p.name == packName then
            pack = p
            sourceIndex = i
            wasShared = false
            break
        end
    end
    
    -- If not found, check shared packs
    if not pack and MountieDB.sharedPacks then
        for i, p in ipairs(MountieDB.sharedPacks) do
            if p.name == packName then
                pack = p
                sourceIndex = i
                wasShared = true
                break
            end
        end
    end
    
    if not pack then
        return false, "Pack '" .. packName .. "' not found"
    end
    
    if wasShared then
        -- Move from shared to character-specific
        table.remove(MountieDB.sharedPacks, sourceIndex)
        pack.isShared = false
        table.insert(charPacks, pack)
        Mountie.SetCharacterPacks(charPacks)
        return true, "Pack '" .. packName .. "' is now character-specific"
    else
        -- Move from character-specific to shared
        table.remove(charPacks, sourceIndex)
        Mountie.SetCharacterPacks(charPacks)
        pack.isShared = true
        
        -- Ensure MountieDB and shared packs table exist
        if not MountieDB then
            MountieDB = {}
        end
        if not MountieDB.sharedPacks then
            MountieDB.sharedPacks = {}
        end
        
        -- Debug output
        Mountie.Debug("Moving pack '" .. packName .. "' to shared storage")
        Mountie.Debug("MountieDB.sharedPacks type: " .. type(MountieDB.sharedPacks))
        
        table.insert(MountieDB.sharedPacks, pack)
        return true, "Pack '" .. packName .. "' is now shared account-wide"
    end
end

-- Get a pack by name (searches both character and shared)
function Mountie.GetPackByName(packName)
    -- Check character-specific packs first
    local charPacks = Mountie.GetCharacterPacks()
    for _, pack in ipairs(charPacks) do
        if pack.name == packName then
            pack.isShared = false
            return pack
        end
    end
    
    -- Check shared packs
    if MountieDB.sharedPacks then
        for _, pack in ipairs(MountieDB.sharedPacks) do
            if pack.name == packName then
                pack.isShared = true
                return pack
            end
        end
    end
    
    return nil
end

-- Debug (dev-only, respects /mountie debug-on|off)
function Mountie.Debug(msg)
    if MountieDB and MountieDB.settings and MountieDB.settings.debugMode then
        DEFAULT_CHAT_FRAME:AddMessage("|cff66cfffMountie|r [debug]: " .. tostring(msg))
    end
end

-- Branded chat output (player-facing)
do
    local PREFIX = "|cff66cfffMountie|r"
    function Mountie.Print(...)
        local parts = {}
        for i = 1, select("#", ...) do
            parts[#parts+1] = tostring(select(i, ...))
        end
        DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. ": " .. table.concat(parts, " "))
    end
end

function Mountie.VerbosePrint(...)
    -- Debug the verbose check
    local verboseEnabled = MountieDB and MountieDB.settings and MountieDB.settings.verboseMode
    Mountie.Debug("VerbosePrint called - verboseMode: " .. tostring(verboseEnabled))
    
    if verboseEnabled then
        local parts = {}
        for i = 1, select("#", ...) do
            parts[#parts+1] = tostring(select(i, ...))
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff66cfffMountie|r: " .. table.concat(parts, " "))
    else
        Mountie.Debug("VerbosePrint suppressed (verbose mode off)")
    end
end

-- String trim helper (Lua has no string.trim)
function Mountie.Trim(s)
    if type(s) ~= "string" then return "" end
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- Small helpers
function Mountie.TableRemoveByIndex(t, idx)
    if type(t) == "table" and idx and t[idx] then
        table.remove(t, idx)
        return true
    end
    return false
end

Mountie.Debug("Utils.lua loaded")