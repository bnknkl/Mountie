-- Mountie: Utility Functions

-- Keybinding labels
BINDING_HEADER_MOUNTIE = "Mountie"
BINDING_NAME_MOUNTIE_SUMMON = "Summon from active pack"

-- Initialize global addon namespaces early
Mountie   = Mountie   or {}
MountieUI = MountieUI or {}

-- Database initialization
MountieDB = MountieDB or {
    packs = {},
    settings = {
        debugMode = false,
        preferFlyingMounts = true,
        packOverlapMode = "priority", -- "priority" or "intersection"
        rulePriorities = {
            transmog = 100,
            zone = 50,
            -- Future: time = 25, dungeon = 75, etc.
        }
    }
}

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

-- String trim helper (Lua has no string.trim)
function Mountie.Trim(s)
    if type(s) ~= "string" then return "" end
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

function MountieUI.GetDraggingMountID()
    local list = Mountie.runtime and Mountie.runtime.mountList
    if not list or not list.buttons then return nil end

    for _, row in ipairs(list.buttons) do
        if row and row.isDragging and row.data and row.data.id then
            return row.data.id
        end
    end
    return nil
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
