-- gfxr-bridge Client
-- Framework-agnostic client-side abstractions for RedM

local Core = nil

local function GetCore()
    if Core then return Core end
    Core = Bridge.GetFrameworkObject()
    return Core
end

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
        local user = exports.vorp_core:GetUser()
        if user then
            local char = user.getUsedCharacter
            return {
                identifier = char.identifier,
                name = char.firstname .. " " .. char.lastname,
                firstname = char.firstname,
                lastname = char.lastname,
                job = char.job,
                jobLabel = char.joblabel,
                jobGrade = char.jobgrade,
                money = char.money,
                gold = char.gold,
                rol = char.rol,
                group = char.group,
            }
        end
    elseif Bridge.FrameworkName == "rsg" then
        local core = GetCore()
        if core then
            local pData = core.Functions.GetPlayerData()
            return {
                identifier = pData.citizenid,
                name = pData.charinfo.firstname .. " " .. pData.charinfo.lastname,
                firstname = pData.charinfo.firstname,
                lastname = pData.charinfo.lastname,
                job = pData.job.name,
                jobLabel = pData.job.label,
                jobGrade = pData.job.grade.level,
                money = pData.money.cash,
                gold = pData.money.bloodmoney or 0,
                group = pData.job.name,
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
    if Bridge.FrameworkName == "vorp" then
        local result = nil
        local finished = false
        TriggerServerEvent("vorp:serverCallback", name, function(...)
            result = ...
            finished = true
        end, ...)
        while not finished do Wait(0) end
        return result
    elseif Bridge.FrameworkName == "rsg" then
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

-- Fallback for other frameworks
AddEventHandler('playerSpawned', function()
    Wait(2000)
    OnPlayerLoaded()
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
