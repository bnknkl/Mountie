-- Mountie: Custom Mount Pack Manager
print("Mountie.lua starting to load...")

-- Initialize addon namespace
local Mountie = {}
print("Mountie namespace created")

-- Database for storing pack data
MountieDB = MountieDB or {
    packs = {},
    settings = {
        debugMode = false
    }
}
print("MountieDB initialized")

-- Pack Management Functions
function Mountie.CreatePack(name, description)
    if not name or name == "" then
        return false, "Pack name cannot be empty"
    end
    
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
        created = time()
    }
    
    table.insert(MountieDB.packs, newPack)
    Debug("Created pack: " .. name)
    return true, "Pack '" .. name .. "' created successfully"
end

function Mountie.DeletePack(name)
    for i, pack in ipairs(MountieDB.packs) do
        if pack.name == name then
            table.remove(MountieDB.packs, i)
            Debug("Deleted pack: " .. name)
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

-- Debug function
local function Debug(msg)
    if MountieDB.settings.debugMode then
        print("[Mountie Debug] " .. msg)
    end
end

-- Initialize addon when loaded
local function OnAddonLoaded(self, event, addonName)
    if addonName == "Mountie" then
        Debug("Mountie loaded successfully!")
        print("Mountie v1.0.0 loaded. Type /mountie for commands.")
    end
end

-- Slash command handler
local function SlashHandler(msg)
    local args = {}
    for word in string.gmatch(msg, "%S+") do
        table.insert(args, word)
    end
    
    local command = string.lower(args[1] or "")
    
    if command == "debug" then
        MountieDB.settings.debugMode = not MountieDB.settings.debugMode
        print("Mountie debug mode: " .. (MountieDB.settings.debugMode and "ON" or "OFF"))
        
    elseif command == "status" then
        print("Mountie Status:")
        print("- Total packs: " .. #MountieDB.packs)
        print("- Debug mode: " .. (MountieDB.settings.debugMode and "ON" or "OFF"))
        
    elseif command == "test" then
        local allMountIDs = C_MountJournal.GetMountIDs()
        local ownedCount = 0
        
        for _, mountID in ipairs(allMountIDs) do
            local _, _, _, _, isUsable, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(mountID)
            if isCollected then
                ownedCount = ownedCount + 1
            end
        end
        
        print("Total mounts in game: " .. #allMountIDs)
        print("Mounts you own: " .. ownedCount)
        Debug("Mount API test successful")
        
    elseif command == "create" then
        if not args[2] then
            print("Usage: /mountie create <pack_name> [description]")
            return
        end
        
        local packName = args[2]
        local description = table.concat(args, " ", 3) -- Everything after pack name
        local success, message = Mountie.CreatePack(packName, description)
        print(message)
        
    elseif command == "delete" then
        if not args[2] then
            print("Usage: /mountie delete <pack_name>")
            return
        end
        
        local success, message = Mountie.DeletePack(args[2])
        print(message)
        
    elseif command == "list" then
        local packs = Mountie.ListPacks()
        if #packs == 0 then
            print("No packs created yet. Use /mountie create <name> to make one!")
        else
            print("Your mount packs:")
            for _, pack in ipairs(packs) do
                local mountCount = #pack.mounts
                print("- " .. pack.name .. " (" .. mountCount .. " mounts)")
                if pack.description ~= "" then
                    print("  " .. pack.description)
                end
            end
        end
        
    else
        print("Mountie Commands:")
        print("/mountie create <name> [description] - Create a new pack")
        print("/mountie delete <name> - Delete a pack")
        print("/mountie list - Show all packs")
        print("/mountie status - Show addon status")
        print("/mountie debug - Toggle debug mode")
        print("/mountie test - Test mount API")
    end
end

-- Event frame setup
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", OnAddonLoaded)

-- Register slash commands
SLASH_MOUNTIE1 = "/mountie"
SLASH_MOUNTIE2 = "/mt"
SlashCmdList["MOUNTIE"] = SlashHandler

-- Export to global namespace for later expansion
_G.Mountie = Mountie
print("Mountie exported to global namespace successfully!")