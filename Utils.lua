-- Mountie: Utility Functions

-- Keybinding labels
BINDING_HEADER_MOUNTIE = "Mountie"
BINDING_NAME_MOUNTIE_SUMMON = "Summon from active pack"

-- Initialize global addon namespaces early
Mountie   = Mountie   or {}
MountieUI = MountieUI or {}

-- Get character-specific key for database
local function GetCharacterKey()
    local name = UnitName("player")
    local realm = GetRealmName()
    return name .. "-" .. realm
end

-- Enhanced database initialization with character-specific data
MountieDB = MountieDB or {}

-- Migrate old data structure if needed
local function MigrateOldData()
    -- If we have old-style packs directly in MountieDB, migrate them
    if MountieDB.packs and type(MountieDB.packs) == "table" and #MountieDB.packs > 0 then
        Mountie.Debug("Migrating old pack data to character-specific format...")
        
        -- Ensure characters table exists
        MountieDB.characters = MountieDB.characters or {}
        
        -- Get current character key
        local charKey = UnitName("player") .. "-" .. GetRealmName()
        
        -- Move old packs to current character
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

-- Initialize database structure
if not MountieDB.characters then
    MountieDB.characters = {}
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

-- Initialize character-specific data
local function InitializeCharacterData()
    -- Migrate old data first if needed
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

-- Get current character's pack data
function Mountie.GetCharacterPacks()
    InitializeCharacterData()
    local charKey = GetCharacterKey()
    return MountieDB.characters[charKey].packs
end

-- Set current character's pack data
function Mountie.SetCharacterPacks(packs)
    InitializeCharacterData()
    local charKey = GetCharacterKey()
    MountieDB.characters[charKey].packs = packs
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