-- gfxr-bridge Client
-- Framework-agnostic client-side abstractions for RedM

local Core = nil

local function GetCore()
    if Core then return Core end
    Core = Bridge.GetFrameworkObject()
    return Core
end

--- Get the detected framework name ("vorp" | "rsg" | "redem" | nil).
---@return string|nil
exports('GetFramework', function()
    return Bridge.FrameworkName
end)

--- Send a framework-agnostic notification to the local player
---@param message string
---@param type string|nil "success"|"error"|"info"|nil
exports('Notify', function(message, type)
    if Bridge.FrameworkName == "vorp" then
        local core = GetCore()
        if core then
            TriggerEvent("vorp:TipRight", message, 3000)
        end
    elseif Bridge.FrameworkName == "rsg" then
        local core = GetCore()
        if core and core.Functions then
            core.Functions.Notify(message, type or "primary", 3000)
        end
    elseif Bridge.FrameworkName == "redem" then
        TriggerEvent("redemrp:notification", message)
    else
        print(("[gfxr-bridge] Notify: %s"):format(message))
    end
end)

--- Get normalized player data
---@return table|nil
exports('GetPlayerData', function()
    if Bridge.FrameworkName == "vorp" then
        -- VORP has NO client `GetUser` export (that is server-side only; the client
        -- vorp_core only exports `GetCore`). The selected character is mirrored into
        -- the `LocalPlayer.state.Character` statebag by vorp_core server/class/user.lua
        -- (re-set on every money/job change, so reads are always current). Fields:
        -- Group, FirstName, LastName, Job, JobLabel, Grade, Gender, Age, Money, Gold,
        -- Rol, CharId. Returns nil until a character is selected so callers never throw.
        local char = LocalPlayer and LocalPlayer.state and LocalPlayer.state.Character
        if char then
            return {
                identifier = char.CharId,
                name = (char.FirstName or "") .. " " .. (char.LastName or ""),
                firstname = char.FirstName,
                lastname = char.LastName,
                job = char.Job,
                jobLabel = char.JobLabel,
                jobGrade = char.Grade,
                money = char.Money,
                gold = char.Gold,
                rol = char.Rol,
                group = char.Group,
            }
        end
    elseif Bridge.FrameworkName == "rsg" then
        local core = GetCore()
        if core then
            local pData = core.Functions.GetPlayerData()
            -- Early in load (or before character select) RSG returns a partial table
            -- with no charinfo/job/money yet. Guard every nested field so the export
            -- returns nil (like the VORP branch) instead of throwing
            -- "attempt to index a nil value (field 'charinfo')".
            if not pData or not pData.charinfo then return nil end
            local ci    = pData.charinfo
            local job   = pData.job or {}
            local grade = job.grade or {}
            local money = pData.money or {}
            return {
                identifier = pData.citizenid,
                name = (ci.firstname or "") .. " " .. (ci.lastname or ""),
                firstname = ci.firstname,
                lastname = ci.lastname,
                job = job.name,
                jobLabel = job.label,
                jobGrade = grade.level,
                money = money.cash,
                gold = money.bloodmoney or 0,
                bank = money.bank or 0,
                group = job.name,
            }
        end
    elseif Bridge.FrameworkName == "redem" then
        local user = exports.redemrp:getPlayer()
        if user then
            return {
                identifier = user.identifier,
                name = user.firstname .. " " .. user.lastname,
                firstname = user.firstname,
                lastname = user.lastname,
                job = user.job,
                money = user.money,
                gold = user.gold or 0,
                bank = user.bankmoney or 0,
                group = user.group,
            }
        end
    end
    return nil
end)

--- Trigger a framework-agnostic server callback
---@param name string
---@param ... any
---@return any
exports('TriggerCallback', function(name, ...)
    if Bridge.FrameworkName == "rsg" then
        local core = GetCore()
        if core then
            local p = promise:new()
            core.Functions.TriggerCallback(name, function(result)
                p:resolve(result)
            end, ...)
            return Citizen.Await(p)
        end
    else
        -- Generic callback pattern
        local id = GetRandomIntInRange(0, 999999)
        local eventName = "gfxr-bridge:cb:response:" .. id
        local p = promise:new()
        RegisterNetEvent(eventName)
        local handler = AddEventHandler(eventName, function(...)
            p:resolve(...)
        end)
        SetTimeout(15000, function()
            p:resolve(nil)
            RemoveEventHandler(handler)
        end)
        TriggerServerEvent("gfxr-bridge:cb:request", name, id, {...})
        local result = Citizen.Await(p)
        RemoveEventHandler(handler)
        return result
    end
end)

--- Get player job info
---@return table|nil {name, label, grade}
exports('GetPlayerJob', function()
    local data = exports['gfxr-bridge']:GetPlayerData()
    if data then
        return {
            name = data.job,
            label = data.jobLabel or data.job,
            grade = data.jobGrade or 0,
        }
    end
    return nil
end)

--- Check if player has a specific job
---@param jobName string
---@return boolean
exports('HasJob', function(jobName)
    local job = exports['gfxr-bridge']:GetPlayerJob()
    return job and job.name == jobName or false
end)

-- ══════════════════════════════════════════
-- MONEY CHANGE (client, event-driven)
-- ══════════════════════════════════════════

-- Lets feature scripts react to money changes instead of polling the server.
-- RSG fires a native client event; VORP/RedEM have none, so we diff the LOCAL
-- (client-cached) character object on a low-rate loop — never a server round-trip.

local moneyChangeCbs = {}
local lastMoney = nil
local moneyWatcherStarted = false

--- Read the current {cash, gold, bank} from the local player data (no server call).
local function readMoney()
    local d = exports['gfxr-bridge']:GetPlayerData()
    if not d then return nil end
    return { cash = d.money or 0, gold = d.gold or 0, bank = d.bank or 0 }
end

local function dispatchMoney(m)
    lastMoney = m
    for _, cb in ipairs(moneyChangeCbs) do
        cb(m)
    end
end

local function startMoneyWatcher()
    if moneyWatcherStarted then return end
    moneyWatcherStarted = true

    if Bridge.FrameworkName == "rsg" then
        -- RSG fires this on every cash/bank/bloodmoney change.
        RegisterNetEvent('RSGCore:Client:OnMoneyChange', function()
            local m = readMoney()
            if m then dispatchMoney(m) end
        end)
    else
        -- VORP / RedEM: no native client money event. Diff the local character
        -- object on a low-rate loop (local read only; no server traffic).
        CreateThread(function()
            while true do
                Wait(1500)
                local m = readMoney()
                if m and (not lastMoney
                    or m.cash ~= lastMoney.cash
                    or m.gold ~= lastMoney.gold
                    or m.bank ~= lastMoney.bank) then
                    dispatchMoney(m)
                end
            end
        end)
    end
end

--- Register a callback fired when the local player's money changes.
--- The callback receives a normalized table `{ cash, gold, bank }` (bank = 0
--- where the framework has no bank, e.g. VORP). It also fires once immediately
--- with the current snapshot so callers get an initial value.
---@param cb function
exports('OnMoneyChange', function(cb)
    table.insert(moneyChangeCbs, cb)
    startMoneyWatcher()
    local m = readMoney()
    if m then cb(m) end
end)

-- ══════════════════════════════════════════
-- NEEDS CHANGE (client, event-driven + RedEM fallback)
-- ══════════════════════════════════════════

-- Reactive hunger/thirst/stress updates, mirroring OnMoneyChange and matching how
-- the established RedM HUDs work (event-driven, no server polling):
--   RSG   -> read client metadata + listen to RSGCore:Client:OnPlayerMetadata
--   VORP  -> listen to vorp_metabolism's value events (Hunger/Thirst, 0-1000 -> /10)
--   RedEM -> no client needs event exists -> a single low-rate server poll
-- Only RedEM polls (it exposes no change signal); RSG/VORP never hit the server.

local needsChangeCbs = {}
local lastNeeds = nil
local needsWatcherStarted = false

--- RSG: read current hunger/thirst/stress from local metadata (0-100, no round-trip).
local function readRsgNeeds()
    local core = GetCore()
    if not core then return nil end
    local pd = core.Functions.GetPlayerData()
    if not pd or not pd.metadata then return nil end
    return {
        hunger = math.floor(pd.metadata.hunger or 0),
        thirst = math.floor(pd.metadata.thirst or 0),
        stress = math.floor(pd.metadata.stress or 0),
    }
end

local function dispatchNeeds(n)
    if not n then return end
    lastNeeds = n
    for _, cb in ipairs(needsChangeCbs) do
        cb(n)
    end
end

local function startNeedsWatcher()
    if needsWatcherStarted then return end
    needsWatcherStarted = true

    if Bridge.FrameworkName == "rsg" then
        -- RSG: SetMetaData has no dedicated event, but every PlayerData change
        -- (incl. metadata hunger/thirst/stress) re-fires SetPlayerData. Verified
        -- in rsg-core server/player.lua (UpdatePlayerData -> SetPlayerData).
        RegisterNetEvent('RSGCore:Player:SetPlayerData', function()
            dispatchNeeds(readRsgNeeds())
        end)
    elseif Bridge.FrameworkName == "vorp" then
        -- VORP: vorp_metabolism drains client-side SILENTLY (no per-tick event),
        -- but exposes current values via the local `vorpmetabolism:getValue(key,cb)`
        -- event (verified in client/apiCalls.lua + main.lua). Read on a low-rate
        -- CLIENT-LOCAL loop (no server round-trip), 0-1000 -> /10. Also refresh
        -- instantly on the explicit-change / item-use events.
        local function readVorp()
            local hunger, thirst
            TriggerEvent('vorpmetabolism:getValue', 'Hunger', function(v) hunger = v end)
            TriggerEvent('vorpmetabolism:getValue', 'Thirst', function(v) thirst = v end)
            if hunger == nil and thirst == nil then return nil end -- metabolism absent
            return {
                hunger = math.floor((hunger or 0) / 10),
                thirst = math.floor((thirst or 0) / 10),
                stress = 0,
            }
        end
        local function applyVorp()
            local n = readVorp()
            if n and (not lastNeeds
                or n.hunger ~= lastNeeds.hunger
                or n.thirst ~= lastNeeds.thirst) then
                dispatchNeeds(n)
            end
        end
        RegisterNetEvent('vorpmetabolism:setValue', applyVorp)
        RegisterNetEvent('vorpmetabolism:changeValue', applyVorp)
        RegisterNetEvent('vorpmetabolism:useItem', applyVorp)
        CreateThread(function()
            while true do
                applyVorp()
                Wait(2000) -- catches the silent client-side drain; local read only
            end
        end)
    else
        -- RedEM / unknown: no client needs signal -> low-rate server poll (the
        -- only framework that hits the server, because it exposes no change event).
        CreateThread(function()
            while true do
                local n = exports['gfxr-bridge']:TriggerCallback('gfxr-bridge:getNeeds')
                if type(n) == "table" and (not lastNeeds
                    or n.hunger ~= lastNeeds.hunger
                    or n.thirst ~= lastNeeds.thirst
                    or n.stress ~= lastNeeds.stress) then
                    dispatchNeeds(n)
                end
                Wait(3000)
            end
        end)
    end
end

--- Register a callback fired when the local player's needs change.
--- cb receives a normalized `{ hunger, thirst, stress }` (0-100). Fires once with
--- an initial snapshot where available (RSG client read; VORP on first event;
--- RedEM on first poll). Event-driven on RSG/VORP; RedEM polls.
---@param cb function
exports('OnNeedsChange', function(cb)
    table.insert(needsChangeCbs, cb)
    startNeedsWatcher()
    if Bridge.FrameworkName == "rsg" then
        local n = readRsgNeeds()
        if n then cb(n) end
    elseif lastNeeds then
        cb(lastNeeds)
    end
end)

-- ══════════════════════════════════════════
-- PLAYER LOADED EVENT
-- ══════════════════════════════════════════

local playerLoaded = false

local function OnPlayerLoaded()
    if playerLoaded then return end
    playerLoaded = true
    TriggerEvent('gfxr-bridge:playerLoaded')
end

-- VORP
RegisterNetEvent('vorp:SelectedCharacter', function()
    OnPlayerLoaded()
end)

-- RSG
RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    OnPlayerLoaded()
end)

-- RedEM
RegisterNetEvent('redemrp:playerLoaded', function()
    OnPlayerLoaded()
end)

-- Fallback ONLY for unknown frameworks. For VORP/RSG/RedEM we must NOT use
-- `playerSpawned` — it fires when the ped spawns into the world (which on VORP
-- can happen during the character-selection camera, BEFORE a character is
-- actually picked), firing OnPlayerLoaded too early and showing feature UIs
-- (e.g. the HUD) over the selection screen. Those frameworks fire their own
-- "character selected" event above, and the startup poll below is the safety net.
AddEventHandler('playerSpawned', function()
    if Bridge.FrameworkName then return end
    Wait(2000)
    OnPlayerLoaded()
end)

-- Mid-session resource restart: the framework's "character selected" event has
-- ALREADY fired (when the player first picked their character), so it will not
-- fire again just because gfxr-bridge restarted — leaving `playerLoaded` stuck
-- false and any OnPlayerLoaded subscriber (e.g. the HUD) never running. So on
-- bridge start, detect an already-loaded character and fire OnPlayerLoaded now.
CreateThread(function()
    -- Try briefly: covers both fresh start (char not yet selected -> the events
    -- above handle it) and a restart while already in-world.
    for _ = 1, 40 do -- ~20s max
        if playerLoaded then return end
        local loaded = false
        if Bridge.FrameworkName == "vorp" then
            loaded = (LocalPlayer and LocalPlayer.state and LocalPlayer.state.Character) ~= nil
        elseif Bridge.FrameworkName == "rsg" then
            local core = GetCore()
            local pData = core and core.Functions and core.Functions.GetPlayerData()
            loaded = pData ~= nil and pData.citizenid ~= nil
        elseif Bridge.FrameworkName == "redem" then
            loaded = exports.redemrp:getPlayer() ~= nil
        end
        if loaded then
            OnPlayerLoaded()
            return
        end
        Wait(500)
    end
end)

--- Register a callback for when player character is loaded
---@param cb function
exports('OnPlayerLoaded', function(cb)
    if playerLoaded then
        cb()
    else
        AddEventHandler('gfxr-bridge:playerLoaded', cb)
    end
end)
