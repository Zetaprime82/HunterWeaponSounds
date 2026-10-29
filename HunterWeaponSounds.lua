-- Hunter Weapon Sounds - core
-- Plays custom shoot + reload sounds for hunter ranged weapons.
-- Each weapon (gun / bow / crossbow) has 3 shoot slots and 3 reload slots.
-- Slots can be changed in the menu (Options > AddOns > Hunter Weapon Sounds,
-- /hws, or the minimap button) and can point to your own sounds.

local ADDON_NAME, ns = ...
local PATH = "Interface\\AddOns\\HunterWeaponSounds\\"

ns.WEAPONS = { "GUN", "BOW", "CROSSBOW" }
ns.WEAPON_LABEL = { GUN = "Gun", BOW = "Bow", CROSSBOW = "Crossbow" }
ns.CHANNELS = { "SFX", "Master", "Ambience", "Dialog" }

------------------------------------------------------------------------
-- Built-in sounds (files in the Sounds folder)
------------------------------------------------------------------------
ns.BUILTIN = {
    "m4a1_weaponfire_01.ogg", "m4a1_weaponfire_02.ogg", "m4a1_weaponfire_03.ogg",
    "m4a1_reload_01.ogg", "m4a1_reload_02.ogg", "m4a1_reload_03.ogg",
    "bowrelease_01.ogg", "bowrelease_02.ogg", "bowrelease_03.ogg",
    "bowpullback_01.ogg", "bowpullback_02.ogg", "bowpullback_03.ogg",
    "crossbowshoot_01.ogg", "crossbowshoot_02.ogg", "crossbowshoot_03.ogg",
    "crossbowload_01.ogg", "crossbowload_02.ogg", "crossbowload_03.ogg",
}
-- file names used by version 1.0 / 1.1 -> current names (keeps old saved settings working)
local RENAMED = {}
for i = 1, 3 do
    local n = "_0" .. i .. ".ogg"
    RENAMED["spell_ro_pistolshot_cast" .. n] = "m4a1_weaponfire" .. n
    RENAMED["spell_hu_blunderbuss_weaponfire" .. n] = "m4a1_weaponfire" .. n
    RENAMED["spell_hu_blunderbuss_reload" .. n] = "m4a1_reload" .. n
    RENAMED["spell_hu_bowrelease" .. n] = "bowrelease" .. n
    RENAMED["spell_hu_bowpullback" .. n] = "bowpullback" .. n
    RENAMED["spell_hu_crossbowshoot" .. n] = "crossbowshoot" .. n
    RENAMED["spell_hu_crossbowload" .. n] = "crossbowload" .. n
end
local BUILTIN_SET = {}
for _, n in ipairs(ns.BUILTIN) do BUILTIN_SET[n:lower()] = n end

-- Default slot assignment (what you get on first run / "Reset to defaults")
ns.DEFAULT_SLOTS = {
    GUN = {
        shoot  = { "m4a1_weaponfire_01.ogg", "m4a1_weaponfire_02.ogg", "m4a1_weaponfire_03.ogg" },
        reload = { "m4a1_reload_01.ogg", "m4a1_reload_02.ogg", "m4a1_reload_03.ogg" },
        delay  = 0.45,
    },
    BOW = {
        shoot  = { "bowrelease_01.ogg", "bowrelease_02.ogg", "bowrelease_03.ogg" },
        reload = { "bowpullback_01.ogg", "bowpullback_02.ogg", "bowpullback_03.ogg" },
        delay  = 0.40,
    },
    CROSSBOW = {
        shoot  = { "crossbowshoot_01.ogg", "crossbowshoot_02.ogg", "crossbowshoot_03.ogg" },
        reload = { "crossbowload_01.ogg", "crossbowload_02.ogg", "crossbowload_03.ogg" },
        delay  = 0.50,
    },
}

------------------------------------------------------------------------
-- Which spells count as "firing the weapon" (edit if a shot is silent / doubles)
------------------------------------------------------------------------
local SHOT_SPELLS = {
    [75] = true,     -- Auto Shot
    [3044] = true,   -- Arcane Shot (classic)
    [185358] = true, -- Arcane Shot
    [2643] = true,   -- Multi-Shot
    [19434] = true,  -- Aimed Shot
    [56641] = true,  -- Steady Shot
    [193455] = true, -- Cobra Shot
    [53351] = true,  -- Kill Shot
    [20736] = true,  -- Distracting Shot
    [53209] = true,  -- Chimaera Shot (Wrath)
    -- Retail
    [257620] = true, -- Multi-Shot
    [320976] = true, -- Kill Shot
    [342049] = true, -- Chimaera Shot
    [212431] = true, -- Explosive Shot
    [217200] = true, -- Barbed Shot
    [257044] = true, -- Rapid Fire
    [392060] = true, -- Wailing Arrow
}
-- Extra shot spells you add yourself with /hws addspell <id> are saved in the database

------------------------------------------------------------------------
-- Stock game sounds to mute (FileDataIDs, verified against the community
-- listfile). Muted for everyone, incl. other players / NPCs.
------------------------------------------------------------------------
local MUTE_IDS = {
    567617, 567718, 567721, 567722, 567719, 567720, 567723,
    921248, 921250, 921252, 921254, 921256, 921258,
    925279, 925281, 925283, 925285, 925287, 925289,
    567673, 567674, 567682,
    567675, 567676, 567677, 567678, 567679, 567683,
    922086, 922088, 922090, 922092, 922094,
    925291, 925293, 925295, 925297, 925299, 925301, 925303, 925305,
    925549, 925551, 925553, 925555, 925557, 925559,
    925307, 925309, 925311, 925313, 925315, 925317,
}

------------------------------------------------------------------------
-- Saved settings
------------------------------------------------------------------------
local WEAPON_SUBCLASS = { [2] = "BOW", [3] = "GUN", [18] = "CROSSBOW" }
local SLOTS = { INVSLOT_RANGED or 18, INVSLOT_MAINHAND or 16 }
local db
local lastIndex = {}
local mutedNow = false

function ns.Print(msg)
    print("|cff66ccffHunter Weapon Sounds:|r " .. tostring(msg))
end

local function CopyDefaults(w)
    local d = ns.DEFAULT_SLOTS[w]
    return {
        shoot = { d.shoot[1], d.shoot[2], d.shoot[3] },
        reload = { d.reload[1], d.reload[2], d.reload[3] },
        delay = d.delay,
    }
end

local function InitDB()
    HunterWeaponSoundsDB = HunterWeaponSoundsDB or {}
    db = HunterWeaponSoundsDB
    if db.enabled == nil then db.enabled = true end
    if db.mute == nil then db.mute = true end
    db.channel = db.channel or "SFX"
    if db.useTransmog == nil then db.useTransmog = true end
    db.forceType = db.forceType or "AUTO"
    db.custom = db.custom or {}
    db.extraSpells = db.extraSpells or {}
    for i = #db.custom, 1, -1 do -- drop old built-in names that were saved as "custom"
        if RENAMED[db.custom[i]] or BUILTIN_SET[db.custom[i]:lower()] then table.remove(db.custom, i) end
    end
    db.minimap = db.minimap or { hide = false, angle = 215 }
    db.weapons = db.weapons or {}
    for _, w in ipairs(ns.WEAPONS) do
        local cfg = db.weapons[w]
        if not cfg then
            db.weapons[w] = CopyDefaults(w)
        else
            cfg.shoot = cfg.shoot or {}
            cfg.reload = cfg.reload or {}
            cfg.delay = tonumber(cfg.delay) or ns.DEFAULT_SLOTS[w].delay
            for i = 1, 3 do
                cfg.shoot[i] = RENAMED[cfg.shoot[i] or ""] or cfg.shoot[i]
                cfg.reload[i] = RENAMED[cfg.reload[i] or ""] or cfg.reload[i]
                if cfg.shoot[i] == nil then cfg.shoot[i] = ns.DEFAULT_SLOTS[w].shoot[i] end
                if cfg.reload[i] == nil then cfg.reload[i] = ns.DEFAULT_SLOTS[w].reload[i] end
            end
        end
    end
    ns.db = db
end

------------------------------------------------------------------------
-- Sound resolving / playing
-- An entry can be:
--   a built-in file name            -> Sounds\<name>
--   a plain file name (your own)    -> CustomSounds\<name>
--   a number                        -> a game FileDataID
--   a path containing \ or /        -> used as-is (e.g. Interface\AddOns\Other\x.ogg)
------------------------------------------------------------------------
function ns.IsBuiltin(entry)
    return entry and BUILTIN_SET[entry:lower()] ~= nil
end

function ns.Resolve(entry)
    if not entry then return nil end
    entry = entry:gsub("^%s+", ""):gsub("%s+$", "")
    if entry == "" then return nil end
    local num = tonumber(entry)
    if num then return num end
    if entry:find("[\\/]") then return (entry:gsub("/", "\\")) end
    local builtin = BUILTIN_SET[entry:lower()]
    if builtin then return PATH .. "Sounds\\" .. builtin end
    return PATH .. "CustomSounds\\" .. entry
end

-- returns true if the client says it can play it
function ns.PlayEntry(entry)
    local target = ns.Resolve(entry)
    if not target then return false end
    local ok, willPlay = pcall(PlaySoundFile, target, db and db.channel or "SFX")
    return ok and (willPlay ~= false)
end

local function Pick(weapon, kind)
    local slots = db.weapons[weapon][kind]
    local list = {}
    for i = 1, 3 do
        local e = slots[i]
        if e and e:match("%S") then list[#list + 1] = e end
    end
    local n = #list
    if n == 0 then return nil end
    local key = weapon .. kind
    local i = n > 1 and math.random(n) or 1
    if n > 1 and i == lastIndex[key] then i = (i % n) + 1 end
    lastIndex[key] = i
    return list[i]
end

function ns.PlayShoot(weapon)
    local e = Pick(weapon, "shoot")
    if e then ns.PlayEntry(e) end
end

function ns.PlayReload(weapon)
    local e = Pick(weapon, "reload")
    if e then ns.PlayEntry(e) end
end

function ns.PlayShotSequence(weapon)
    ns.PlayShoot(weapon)
    C_Timer.After(db.weapons[weapon].delay or 0.45, function()
        if db.enabled then ns.PlayReload(weapon) end
    end)
end

function ns.TestWeapon(weapon)
    ns.PlayShoot(weapon)
    C_Timer.After(1.4, function() ns.PlayReload(weapon) end)
end

------------------------------------------------------------------------
-- Settings helpers used by the menu
------------------------------------------------------------------------
function ns.SetSlot(weapon, kind, i, value)
    value = (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
    db.weapons[weapon][kind][i] = value
end

function ns.SetDelay(weapon, value)
    value = tonumber(value)
    if not value then return false end
    db.weapons[weapon].delay = math.max(0, math.min(3, value))
    return true
end

function ns.ResetWeapon(weapon)
    db.weapons[weapon] = CopyDefaults(weapon)
end

function ns.FindCustom(name)
    for i, n in ipairs(db.custom) do
        if n:lower() == name:lower() then return i end
    end
end

-- returns ok, message
function ns.AddCustom(name)
    name = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then return false, "Type a file name or a sound ID first." end
    if ns.IsBuiltin(name) then return false, "That is already a built-in sound." end
    if ns.FindCustom(name) then return false, "Already in your list." end
    local willPlay = ns.PlayEntry(name)
    table.insert(db.custom, name)
    if willPlay then
        return true, "Added. (Playing it now.)"
    end
    return true, "Added, but the game could not find it. Files you add to the CustomSounds folder only load after a full game restart."
end

function ns.RemoveCustom(name)
    local i = ns.FindCustom(name)
    if i then table.remove(db.custom, i) end
end

function ns.ApplyMute()
    if not MuteSoundFile or not UnmuteSoundFile then return end
    local want = (db.enabled and db.mute) and true or false
    if want == mutedNow then return end
    for _, id in ipairs(MUTE_IDS) do
        if want then MuteSoundFile(id) else UnmuteSoundFile(id) end
    end
    mutedNow = want
end

-- What the item really is (its stats / item class)
local function InstantType(itemID)
    local getInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not getInstant or not itemID then return nil end
    local _, _, _, _, _, classID, subClassID = getInstant(itemID)
    if classID == 2 then return WEAPON_SUBCLASS[subClassID] end
end

local function RealType(slot)
    return InstantType(GetInventoryItemID("player", slot))
end

-- What the weapon LOOKS like (transmog).
-- WoW Forever's transmog API is new and may differ from retail, so several
-- independent methods are tried one after another; the first that gives a
-- weapon type wins. Each method is wrapped in pcall so an API change can
-- never cause an error. `trace` (optional table) collects what each method saw.
local function SafeCall(fn, ...)
    if type(fn) ~= "function" then return false end
    return pcall(fn, ...)
end

local function Note(trace, text)
    if trace then trace[#trace + 1] = text end
end

local function Num(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return tonumber(v)
end

-- Turn a transmog sourceID (itemModifiedAppearanceID) into GUN / BOW / CROSSBOW
local function SourceToType(sourceID, trace)
    if not sourceID or sourceID == 0 then return nil end
    -- 1) source -> item -> item class/subclass
    if C_Transmog and C_Transmog.GetItemIDForSource then
        local ok, itemID = SafeCall(C_Transmog.GetItemIDForSource, sourceID)
        local t = ok and InstantType(itemID)
        Note(trace, ("   source %s -> itemID %s -> %s"):format(tostring(sourceID), tostring(ok and itemID), tostring(t)))
        if t then return t end
    end
    -- 2) source info (itemID / category)
    local T = Enum and Enum.TransmogCollectionType
    local function ByCategory(cat)
        if not (T and cat) then return nil end
        if T.Gun and cat == T.Gun then return "GUN" end
        if T.Bow and cat == T.Bow then return "BOW" end
        if T.Crossbow and cat == T.Crossbow then return "CROSSBOW" end
    end
    if C_TransmogCollection and C_TransmogCollection.GetSourceInfo then
        local ok, info = SafeCall(C_TransmogCollection.GetSourceInfo, sourceID)
        if ok and type(info) == "table" then
            local t = InstantType(info.itemID or info.itemId) or ByCategory(info.categoryID or info.category)
            Note(trace, ("   GetSourceInfo itemID=%s category=%s -> %s"):format(
                tostring(info.itemID), tostring(info.categoryID or info.category), tostring(t)))
            if t then return t end
        else
            Note(trace, "   GetSourceInfo gave nothing")
        end
    end
    -- 3) appearance source info (has itemSubclass / category / itemLink)
    if C_TransmogCollection and C_TransmogCollection.GetAppearanceSourceInfo then
        local ok, info = SafeCall(C_TransmogCollection.GetAppearanceSourceInfo, sourceID)
        if ok and type(info) == "table" then
            local t = (info.itemSubclass and WEAPON_SUBCLASS[info.itemSubclass])
                or ByCategory(info.category or info.categoryID)
            if not t and info.itemLink then t = InstantType(info.itemLink) end
            Note(trace, ("   GetAppearanceSourceInfo subclass=%s category=%s -> %s"):format(
                tostring(info.itemSubclass), tostring(info.category), tostring(t)))
            if t then return t end
        else
            Note(trace, "   GetAppearanceSourceInfo gave nothing")
        end
    end
    return nil
end

-- Compact one-level dump of a value for the diagnostic report
local function Dump(v)
    if type(v) ~= "table" then
        local ok, str = pcall(tostring, v)
        return ok and (type(v) .. ":" .. str) or "?"
    end
    local parts = {}
    for k, val in pairs(v) do
        if type(val) ~= "table" and type(val) ~= "function" then
            local ok, str = pcall(tostring, val)
            parts[#parts + 1] = tostring(k) .. "=" .. (ok and str or "?")
        end
    end
    table.sort(parts)
    return "{" .. table.concat(parts, ", ") .. "}"
end

-- The transmog "location" argument. TransmogUtil is not always loaded (on Retail
-- it can be missing until the Collections window has been opened), so a plain
-- table with the same fields is offered as well.
local function BuildLocations(slot)
    local list = {}
    local E = Enum or {}
    local tType = (E.TransmogType and E.TransmogType.Appearance) or 0
    local tMod = (E.TransmogModification and E.TransmogModification.Main) or 0
    if TransmogUtil and TransmogUtil.GetTransmogLocation then
        local ok, loc = SafeCall(TransmogUtil.GetTransmogLocation, slot, tType, tMod)
        if ok and loc then list[#list + 1] = { loc, "TransmogUtil" } end
    end
    list[#list + 1] = { { slotID = slot, type = tType, modification = tMod }, "plain table" }
    return list
end

-- Method A: C_Transmog.GetSlotVisualInfo (retail style)
local function MethodSlotVisual(slot, trace)
    if not (C_Transmog and C_Transmog.GetSlotVisualInfo) then
        Note(trace, "A: C_Transmog.GetSlotVisualInfo not present")
        return nil
    end
    local tried = {}
    for _, sl in ipairs({ slot, 16, 18 }) do
        if not tried[sl] then
            tried[sl] = true
            for _, entry in ipairs(BuildLocations(sl)) do
                local loc, how = entry[1], entry[2]
                local ok, r1, r2, r3, r4, r5, r6, r7, r8 = SafeCall(C_Transmog.GetSlotVisualInfo, loc)
                if ok and r1 ~= nil then
                    local applied, hidden
                    if type(r1) == "table" then
                        applied, hidden = Num(r1.appliedSourceID), r1.isHideVisual
                    else
                        applied, hidden = Num(r3), r8
                    end
                    Note(trace, ("A: slot %d via %s -> %s applied=%s hidden=%s"):format(
                        sl, how, type(r1) == "table" and Dump(r1) or Dump(r1) .. "," .. Dump(r2) .. "," .. Dump(r3),
                        tostring(applied), tostring(hidden)))
                    if applied and applied ~= 0 and not hidden then
                        local t = SourceToType(applied, trace)
                        if t then return t end
                    end
                else
                    Note(trace, ("A: slot %d via %s -> %s"):format(sl, how, ok and "returned nothing" or "error"))
                end
            end
        end
    end
    return nil
end

-- Method B: the outfit system (newer clients)
local function MethodOutfit(slot, trace)
    local O = C_TransmogOutfitInfo
    if not (O and O.GetViewedOutfitSlotInfo and O.GetTransmogOutfitSlotFromInventorySlot
        and Enum and Enum.TransmogType and Enum.TransmogModification) then
        Note(trace, "B: outfit API not present")
        return nil
    end
    for _, sl in ipairs({ slot, 16 }) do
        local okS, outfitSlot = SafeCall(O.GetTransmogOutfitSlotFromInventorySlot, sl)
        if okS and outfitSlot ~= nil then
            local ok, info = SafeCall(O.GetViewedOutfitSlotInfo, outfitSlot,
                Enum.TransmogType.Appearance, Enum.TransmogModification.Main)
            if ok and type(info) == "table" then
                local id = Num(info.transmogID)
                Note(trace, ("B: slot %d outfitSlot=%s transmogID=%s transmogrified=%s"):format(
                    sl, tostring(outfitSlot), tostring(id), tostring(info.isTransmogrified)))
                if id and id ~= 0 and info.isTransmogrified ~= false then
                    local t = SourceToType(id, trace)
                    if t then return t end
                end
            else
                Note(trace, ("B: slot %d GetViewedOutfitSlotInfo gave nothing"):format(sl))
            end
        end
    end
    return nil
end

-- Method C: read the item tooltip ("Transmogrified to: <item name>")
local function MethodTooltip(slot, trace)
    if not (C_TooltipInfo and C_TooltipInfo.GetInventoryItem) then
        Note(trace, "C: tooltip API not present")
        return nil
    end
    local ok, data = SafeCall(C_TooltipInfo.GetInventoryItem, "player", slot)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then
        Note(trace, "C: no tooltip data")
        return nil
    end
    local header = (TRANSMOGRIFIED_HEADER or "Transmogrified to:"):gsub("[:%s]+$", ""):lower()
    local found
    for i, line in ipairs(data.lines) do
        local text = line.leftText
        if text and not (issecretvalue and issecretvalue(text)) then
            local low = text:lower()
            if found == nil and low:find(header, 1, true) then
                -- the item name is on the same line (after a newline) or the next one
                local after = text:match("\n(.+)$") or (data.lines[i + 1] and data.lines[i + 1].leftText)
                found = after or false
            end
        end
    end
    if found then
        found = found:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        local t = InstantType(found)
        if not t then
            -- name lookup needs the item cached; try the item-name API as well
            local getInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
            local okI, id = SafeCall(getInstant, found)
            if okI then t = InstantType(id) end
        end
        if not t then
            local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
            if getInfo then
                local okG, r = pcall(function() return { getInfo(found) } end)
                if okG and type(r) == "table" and r[12] == 2 and WEAPON_SUBCLASS[r[13]] then
                    t = WEAPON_SUBCLASS[r[13]]
                end
            end
        end
        Note(trace, ("C: tooltip says transmogrified to '%s' -> %s"):format(tostring(found), tostring(t)))
        return t
    end
    Note(trace, "C: tooltip has no transmog line")
    return nil
end

local function AppearanceType(slot, trace)
    return MethodSlotVisual(slot, trace) or MethodOutfit(slot, trace) or MethodTooltip(slot, trace)
end

-- Detection results are cached for a few seconds (and cleared whenever your
-- gear changes) so firing a shot never does the full lookup every time.
local cache = {}
function ns.InvalidateDetectCache() cache.t = nil end

-- returns final, real, appearance, trace
-- (final is nil if no hunter ranged weapon is equipped)
function ns.DetectWeapon(wantTrace)
    local trace = wantTrace and {} or nil
    local real, look
    local now = GetTime and GetTime() or 0
    if not wantTrace and cache.t and (now - cache.t) < 3 and cache.useT == db.useTransmog then
        real, look = cache.real, cache.look
    else
        for _, slot in ipairs(SLOTS) do
            local r = RealType(slot)
            if r then
                real = r
                Note(trace, ("equipped in slot %d: %s"):format(slot, r:lower()))
                look = db.useTransmog and AppearanceType(slot, trace) or nil
                break
            end
        end
        if not wantTrace then
            cache.t, cache.useT, cache.real, cache.look = now, db.useTransmog, real, look
        end
    end
    if not real then return nil, nil, nil, trace end
    local final = real
    if db.forceType ~= "AUTO" and ns.WEAPON_LABEL[db.forceType] then
        final = db.forceType
    elseif look then
        final = look
    end
    return final, real, look, trace
end

-- Text report that can be copied from the menu (Weapon report button)
function ns.BuildReport()
    local L = {}
    local function add(t) L[#L + 1] = t end
    local ver, build, _, iface = "?", "?", "?", "?"
    if GetBuildInfo then ver, build, _, iface = GetBuildInfo() end
    add("Hunter Weapon Sounds report")
    add(("client %s build %s interface %s"):format(tostring(ver), tostring(build), tostring(iface)))
    add(("settings: followTransmog=%s forceType=%s enabled=%s"):format(
        tostring(db.useTransmog), tostring(db.forceType), tostring(db.enabled)))
    local function has(v) return v and "yes" or "NO" end
    add("APIs: TransmogUtil=" .. has(TransmogUtil and TransmogUtil.GetTransmogLocation)
        .. " GetSlotVisualInfo=" .. has(C_Transmog and C_Transmog.GetSlotVisualInfo)
        .. " GetItemIDForSource=" .. has(C_Transmog and C_Transmog.GetItemIDForSource)
        .. " GetSourceInfo=" .. has(C_TransmogCollection and C_TransmogCollection.GetSourceInfo)
        .. " GetAppearanceSourceInfo=" .. has(C_TransmogCollection and C_TransmogCollection.GetAppearanceSourceInfo)
        .. " OutfitInfo=" .. has(C_TransmogOutfitInfo)
        .. " TooltipInfo=" .. has(C_TooltipInfo and C_TooltipInfo.GetInventoryItem)
        .. " GetItemInfoInstant=" .. has((C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant))
    local getInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    for _, slot in ipairs({ 16, 17, 18 }) do
        local id = GetInventoryItemID and GetInventoryItemID("player", slot)
        local cls, sub = "-", "-"
        if id and getInstant then
            local _, _, _, _, _, c, sc = getInstant(id)
            cls, sub = tostring(c), tostring(sc)
        end
        add(("slot %d: itemID=%s class=%s subclass=%s"):format(slot, tostring(id), cls, sub))
    end
    add("--- detection ---")
    local final, real, look, trace = ns.DetectWeapon(true)
    for _, line in ipairs(trace or {}) do add(line) end
    add(("RESULT equipped=%s looks like=%s using=%s"):format(tostring(real), tostring(look), tostring(final)))
    return table.concat(L, "\n")
end

function ns.GetWeaponType()
    return (ns.DetectWeapon())
end

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        if (...) ~= ADDON_NAME then return end
        InitDB()
        self:UnregisterEvent("ADDON_LOADED")
        self:RegisterEvent("PLAYER_LOGIN")
        self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        for _, e in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "TRANSMOGRIFY_SUCCESS", "TRANSMOG_COLLECTION_UPDATED",
                             "TRANSMOG_OUTFITS_CHANGED", "PLAYER_ENTERING_WORLD" }) do
            pcall(self.RegisterEvent, self, e)
        end
        if ns.InitOptions then ns.InitOptions() end
    elseif event == "PLAYER_LOGIN" then
        ns.ApplyMute()
    elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "TRANSMOGRIFY_SUCCESS"
        or event == "TRANSMOG_COLLECTION_UPDATED" or event == "TRANSMOG_OUTFITS_CHANGED"
        or event == "PLAYER_ENTERING_WORLD" then
        ns.InvalidateDetectCache()
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if not db.enabled then return end
        local _, _, spellID = ...
        if issecretvalue and issecretvalue(spellID) then
            if ns.debugCasts then ns.Print("cast seen, but the game hides its spell ID (secret value)") end
            return
        end
        local isShot = SHOT_SPELLS[spellID] or db.extraSpells[spellID]
        if ns.debugCasts then
            ns.Print(("you cast spell %s -> %s"):format(tostring(spellID), isShot and "counts as a shot" or "ignored (use /hws addspell " .. tostring(spellID) .. " if it should play a sound)"))
        end
        if not isShot then return end
        local weapon = ns.GetWeaponType()
        if weapon then ns.PlayShotSequence(weapon) end
    end
end)

------------------------------------------------------------------------
-- Slash commands
------------------------------------------------------------------------
SLASH_HUNTERWEAPONSOUNDS1 = "/hws"
SLASH_HUNTERWEAPONSOUNDS2 = "/hunterweaponsounds"
SlashCmdList["HUNTERWEAPONSOUNDS"] = function(msg)
    if not db then return end
    local cmd, arg = (msg or ""):lower():match("^(%S*)%s*(%S*)")
    if cmd == "" or cmd == "menu" or cmd == "config" then
        if ns.ToggleWindow then ns.ToggleWindow() end
    elseif cmd == "options" then
        if ns.OpenSettings then ns.OpenSettings() end
    elseif cmd == "on" then
        db.enabled = true; ns.ApplyMute(); ns.Print("enabled")
    elseif cmd == "off" then
        db.enabled = false; ns.ApplyMute(); ns.Print("disabled (default sounds restored)")
    elseif cmd == "mute" then
        if arg == "on" or arg == "off" then
            db.mute = (arg == "on"); ns.ApplyMute()
            ns.Print("muting default weapon sounds: " .. arg)
        else
            ns.Print("usage: /hws mute on|off")
        end
    elseif cmd == "debug" then
        ns.debugCasts = not ns.debugCasts
        ns.Print("cast debug " .. (ns.debugCasts and "ON: every spell you cast prints its ID. Fire your weapon now." or "off"))
    elseif cmd == "addspell" or cmd == "removespell" then
        local id = tonumber(arg)
        if not id then
            ns.Print("usage: /hws " .. cmd .. " <spellID>   (use /hws debug to see spell IDs)")
        elseif cmd == "addspell" then
            db.extraSpells[id] = true; ns.Print("spell " .. id .. " now plays weapon sounds")
        else
            db.extraSpells[id] = nil; ns.Print("spell " .. id .. " removed from your extra shots")
        end
    elseif cmd == "transmog" then
        if arg == "on" or arg == "off" then
            db.useTransmog = (arg == "on"); ns.InvalidateDetectCache()
            ns.Print("sounds follow transmog appearance: " .. arg)
        else
            ns.Print("usage: /hws transmog on|off")
        end
    elseif cmd == "type" then
        local v = arg:upper()
        if v == "AUTO" or ns.WEAPON_LABEL[v] then
            db.forceType = v
            ns.Print("weapon type: " .. (v == "AUTO" and "auto" or ns.WEAPON_LABEL[v]:lower()))
        else
            ns.Print("usage: /hws type auto|gun|bow|crossbow")
        end
    elseif cmd == "report" then
        if ns.ShowReport then ns.ShowReport(ns.BuildReport()) end
    elseif cmd == "detect" then
        local final, real, look, trace = ns.DetectWeapon(true)
        for _, line in ipairs(trace or {}) do ns.Print(line) end
        ns.Print(("equipped: %s | looks like (transmog): %s | using sounds for: %s"):format(
            real and ns.WEAPON_LABEL[real]:lower() or "no ranged weapon",
            look and ns.WEAPON_LABEL[look]:lower() or "not transmogged / unknown",
            final and ns.WEAPON_LABEL[final]:lower() or "none"))
    elseif cmd == "minimap" then
        db.minimap.hide = not db.minimap.hide
        if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
        ns.Print("minimap button " .. (db.minimap.hide and "hidden" or "shown"))
    elseif cmd == "test" then
        local t = 0
        for _, w in ipairs(ns.WEAPONS) do
            C_Timer.After(t, function() ns.Print("Testing " .. ns.WEAPON_LABEL[w]:lower()); ns.TestWeapon(w) end)
            t = t + 3
        end
    else
        ns.Print("/hws  open the menu   |  /hws options  open Options > AddOns page")
        ns.Print("/hws on | off | test | mute on|off | transmog on|off | type auto|gun|bow|crossbow | detect | report | debug | addspell <id> | removespell <id> | minimap")
        ns.Print(("status: %s, mute defaults: %s, current weapon: %s"):format(
            db.enabled and "on" or "off", db.mute and "on" or "off",
            (ns.GetWeaponType() or "none"):lower()))
    end
end
