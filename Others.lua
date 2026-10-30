-- Hunter Weapon Sounds - other hunters (best effort)
-- Plays your custom sounds when OTHER hunters fire, and mutes the stock sounds
-- while this is on. The game only tells addons about casts of units it exposes:
-- party / raid members, your target / focus, and anyone with a visible nameplate.
-- A hunter the game does not expose (e.g. a stranger without a nameplate) cannot
-- be heard by the addon and will be silent while this option is on.

local ADDON_NAME, ns = ...

local frame = CreateFrame("Frame")
local cache = {}          -- guid -> { type = "GUN"/"BOW"/"CROSSBOW", t = time }
ns._otherCache = cache   -- exposed for testing
local lastPlay = {}       -- guid -> time of last sound (de-duplicates unit tokens)
local pendingGUID, pendingUnit, lastInspect = nil, nil, 0
local MAX_RANGE_SQ = 40 * 40

local function Now() return GetTime and GetTime() or 0 end
local function Readable(v) return v ~= nil and not (issecretvalue and issecretvalue(v)) end

------------------------------------------------------------------------
-- Which weapon does that hunter hold? (needs an inspect; cached per player)
------------------------------------------------------------------------
local function WeaponFromInventory(unit)
    for _, slot in ipairs({ 16, 18 }) do
        local ok, id = pcall(GetInventoryItemID, unit, slot)
        if ok and id then
            local t = ns.InstantType(id)
            if t then return t end
        end
    end
end

local function LookFromInspect()
    if not (C_TransmogCollection and C_TransmogCollection.GetInspectItemTransmogInfoList) then return nil end
    local ok, list = pcall(C_TransmogCollection.GetInspectItemTransmogInfoList)
    if not ok or type(list) ~= "table" then return nil end
    for _, slot in ipairs({ 16, 18 }) do
        local info = list[slot]
        local src = type(info) == "table" and info.appearanceID
        if src and src ~= 0 then
            local t = ns.SourceToType(src)
            if t then return t end
        end
    end
end

local function QueueInspect(unit, guid)
    if not (NotifyInspect and CanInspect) then return end
    if pendingGUID or (Now() - lastInspect) < 3 then return end
    if InspectFrame and InspectFrame.IsShown and InspectFrame:IsShown() then return end
    local ok, can = pcall(CanInspect, unit)
    if not (ok and can) then return end
    pendingGUID, pendingUnit, lastInspect = guid, unit, Now()
    pcall(NotifyInspect, unit)
    C_Timer.After(5, function()
        if pendingGUID == guid then pendingGUID, pendingUnit = nil, nil end
    end)
end

local function OnInspectReady(guid)
    if not pendingGUID or guid ~= pendingGUID then return end
    local unit = pendingUnit
    pendingGUID, pendingUnit = nil, nil
    if not (unit and UnitGUID(unit) == guid) then
        unit = UnitTokenFromGUID and UnitTokenFromGUID(guid) or nil
    end
    if not unit then return end
    local t = LookFromInspect() or WeaponFromInventory(unit)
    if t then cache[guid] = { type = t, t = Now() } end
    if ClearInspectPlayer then pcall(ClearInspectPlayer) end
end

local function FallbackWeapon()
    local db = ns.db
    if db.otherType ~= "AUTO" and ns.WEAPON_LABEL[db.otherType] then return db.otherType end
    return ns.GetWeaponType() or "GUN"
end

------------------------------------------------------------------------
-- A unit finished a cast
------------------------------------------------------------------------
local seenOther, seenHunter = 0, 0

local function Why(unit, text)
    if ns.debugCasts then ns.Print(("others: %s -> %s"):format(tostring(unit), text)) end
end

local function OnCast(unit, _, spellID)
    local db = ns.db
    if not (db and db.enabled and db.others) then return end
    if type(unit) ~= "string" or unit == "player" then return end
    seenOther = seenOther + 1

    local okP, isPlayer = pcall(UnitIsPlayer, unit)
    if not (okP and isPlayer) then
        if ns.debugCasts and seenOther % 25 == 0 then
            ns.Print(("others: %d casts seen from other units so far, %d from hunters"):format(seenOther, seenHunter))
        end
        return
    end
    if UnitIsUnit and UnitIsUnit(unit, "player") then return end
    local _, class = UnitClass(unit)
    if class ~= "HUNTER" then
        if ns.debugCasts and seenOther % 25 == 0 then
            ns.Print(("others: %d casts seen from other units so far, %d from hunters"):format(seenOther, seenHunter))
        end
        return
    end
    seenHunter = seenHunter + 1

    if not Readable(spellID) then
        -- The game hides other players' spell IDs here, so shots cannot be told apart
        -- from other casts. Replacing them is impossible; switch the option off so
        -- the stock sounds come back instead of leaving every other hunter silent.
        Why(unit, "hunter cast seen, but the game hides the spell ID (secret value)")
        db.others = false
        ns.ApplyMute(true)
        if ns.RefreshMenu then ns.RefreshMenu() end
        ns.Print("This game version hides other players' spell IDs, so other hunters' shots can't be told apart from their other spells. \"Replace other hunters' sounds\" has been turned off and their normal game sounds are back. Your own shots still use your sounds.")
        return
    end
    if not ns.IsShotSpell(spellID) then
        Why(unit, ("hunter cast spell %s: not a shot (/hws addspell %s if it should be)"):format(tostring(spellID), tostring(spellID)))
        return
    end

    local guid = UnitGUID(unit)
    if not Readable(guid) then Why(unit, "hunter's GUID is hidden (secret value)") return end
    local now = Now()
    if lastPlay[guid] and (now - lastPlay[guid]) < 0.15 then return end

    if UnitDistanceSquared then
        local ok, d, calc = pcall(UnitDistanceSquared, unit)
        if ok and Readable(d) and calc ~= false and type(d) == "number" and d > MAX_RANGE_SQ then
            Why(unit, ("shot ignored, hunter is %d yards away (limit 40)"):format(math.floor(math.sqrt(d))))
            return
        end
    end

    local entry = cache[guid]
    local weapon = entry and entry.type
    local how = "inspected"
    if not weapon then
        QueueInspect(unit, guid)
        weapon = FallbackWeapon()
        how = "not inspected yet, using fallback"
    end
    lastPlay[guid] = now
    Why(unit, ("shot -> playing %s sounds (%s)"):format(weapon:lower(), how))
    ns.PlayShotSequence(weapon)
end

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        OnCast(...)
    elseif event == "INSPECT_READY" then
        OnInspectReady((...))
    end
end)

-- turn the listening on / off with the option (the cast event fires for every
-- unit in view, so it is only registered while it is needed)
function ns.UpdateOthers()
    if ns.db and ns.db.enabled and ns.db.others then
        frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        frame:RegisterEvent("INSPECT_READY")
    else
        frame:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        frame:UnregisterEvent("INSPECT_READY")
    end
end

function ns.OthersStatus()
    local db = ns.db
    ns.Print(("others: option %s, listening for other players' casts: %s"):format(
        db.others and "ON" or "OFF", (db.enabled and db.others) and "yes" or "no"))
    if db.others then
        ns.Print("others: fire at / stand near a hunter in your party, or target one; lines starting with 'others:' show what happens to each shot")
    end
end
