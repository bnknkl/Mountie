-- Mountie: Mount List (scrolling list of mounts)
Mountie.Debug("UI/MountList.lua loading...")

local function buildOwnedTable()
    local t = {}
    local ids = C_MountJournal.GetMountIDs()
    for _, id in ipairs(ids) do
        local name, spellID, icon, active, isUsable, sourceType, isFavorite, _, _, _, isCollected =
            C_MountJournal.GetMountInfoByID(id)
        local creatureDisplayInfoID, description, source, isSelfMount, mountTypeID =
            C_MountJournal.GetMountInfoExtraByID(id)

        t[#t+1] = {
            id = id,
            name = name or ("Mount "..id),
            icon = icon,
            isCollected = not not isCollected,
            isFavorite = not not isFavorite,
            isUsable = not not isUsable,
            sourceText = source or "",
            sourceType = sourceType,  -- numeric
            mountTypeID = mountTypeID,
            spellID = spellID,
        }
    end
    table.sort(t, function(a,b) return a.name < b.name end)
    return t
end

-- Very small helper to match “source” filters the UI uses
local function matchesSourceFilter(row, filterValue)
    if filterValue == "all" or not filterValue then return true end
    if filterValue == "favorites" then
        return row.isFavorite
    elseif filterValue == "drop" then
        -- heuristic: source text contains drop-y words
        local s = string.lower(row.sourceText or "")
        return s:find("drop") or s:find("boss") or s:find("loot") or s:find("rare")
    elseif filterValue == "vendor" then
        local s = string.lower(row.sourceText or "")
        return s:find("vendor") or s:find("purchase") or s:find("purchase")
    end
    return true
end

-- Exposed: creates the scroll list frame
function MountieUI.CreateMountList(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -60)
    scroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -30, 10)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(300, 1)
    scroll:SetScrollChild(content)

    scroll.content = content
    scroll.buttons = {}  -- rows
    scroll.rows = 0

    return scroll
end

-- Row factory
local function acquireRow(list, index)
    local row = list.buttons[index]
    if row then return row end

    row = CreateFrame("Button", nil, list.content, "BackdropTemplate")
    row:SetSize(300, 28)
    row:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    row:SetBackdropColor(0.06, 0.06, 0.10, 0.75)
    row:SetBackdropBorderColor(0.25, 0.25, 0.35, 0.9)

    if index == 1 then
        row:SetPoint("TOPLEFT", list.content, "TOPLEFT", 0, 0)
    else
        row:SetPoint("TOPLEFT", list.buttons[index-1], "BOTTOMLEFT", 0, -2)
    end

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(24, 24)
    row.icon:SetPoint("LEFT", row, "LEFT", 6, 0)

    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.nameText:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.nameText:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.nameText:SetJustifyH("LEFT")

    -- basic tooltip + drag stub (PackPanel checks .isDragging)
    row:EnableMouse(true)
    row:RegisterForDrag("LeftButton")
    row:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.10, 0.10, 0.18, 0.85)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.data and self.data.spellID then
            GameTooltip:SetMountBySpellID(self.data.spellID)
        elseif self.data then
            GameTooltip:SetText(self.data.name or "Mount", 1,1,1)
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.06, 0.06, 0.10, 0.75)
        GameTooltip:Hide()
    end)
    row:SetScript("OnDragStart", function(self)
        self.isDragging = true
        -- We don’t need to set a real cursor payload; your PackPanel just checks the flag.
    end)
    row:SetScript("OnDragStop", function(self)
        self.isDragging = false
    end)
    row:SetScript("OnClick", function(self)
        if self.data and self.data.id then
            Mountie.Print("Mount ID " .. self.data.id .. ": " .. (self.data.name or "Unknown"))
        end
    end)

    list.buttons[index] = row
    return row
end

-- Exposed: repopulate list based on filters/search
function MountieUI.UpdateMountList(list, showUnowned, searchText, sourceFilter)
    searchText = string.lower(tostring(searchText or ""))

    local data = buildOwnedTable()
    local filtered = {}
    for _, row in ipairs(data) do
        if (showUnowned or row.isCollected) and matchesSourceFilter(row, sourceFilter) then
            if searchText == "" or string.find(string.lower(row.name), searchText, 1, true) then
                filtered[#filtered+1] = row
            end
        end
    end

    -- ensure enough rows
    for i = 1, #filtered do
        local r = acquireRow(list, i)
        local d = filtered[i]
        r.data = d
        r.icon:SetTexture(d.icon)
        r.nameText:SetText(d.name .. (d.isFavorite and "  |TInterface\\COMMON\\ReputationStar:0|t" or ""))
        if d.isCollected then
            r.nameText:SetTextColor(0.95, 0.95, 0.95, 1)
        else
            r.nameText:SetTextColor(0.6, 0.6, 0.6, 1)
        end
        r:Show()
    end

    -- hide extra rows
    for i = #filtered + 1, #list.buttons do
        list.buttons[i]:Hide()
        list.buttons[i].data = nil
        list.buttons[i].isDragging = false
    end

    -- content height
    local rows = #filtered
    local contentHeight = math.max(rows * 30, 1)
    list.content:SetHeight(contentHeight)
end

Mountie.Debug("UI/MountList.lua loaded")
