-- gfxr-bridge Server
-- Framework-agnostic server-side abstractions for RedM

local Core = nil

local function GetCore()
    if Core then return Core end
    Core = Bridge.GetFrameworkObject()
    return Core
end

-- ══════════════════════════════════════════
-- PLAYER
-- ══════════════════════════════════════════

--- Get framework player object
---@param source number
---@return any
exports('GetPlayer', function(source)
    if Bridge.FrameworkName == "vorp" then
        local core = GetCore()
        if core then
            local user = core.getUser(source)
            return user and user.getUsedCharacter or nil
        end
    elseif Bridge.FrameworkName == "rsg" then
        local core = GetCore()
        if core then
            return core.Functions.GetPlayer(source)
        end
    elseif Bridge.FrameworkName == "redem" then
        return exports.redemrp:getPlayerFromId(source)
    end
    return nil
end)

--- Get player identifier (citizenid / charid / identifier)
---@param source number
---@return string|nil
exports('GetIdentifier', function(source)
    if Bridge.FrameworkName == "vorp" then
        local core = GetCore()
        if core then
            local user = core.getUser(source)
            if user then
                local char = user.getUsedCharacter
                return char and char.identifier or nil
            end
        end
    elseif Bridge.FrameworkName == "rsg" then
        local player = exports['gfxr-bridge']:GetPlayer(source)
        if player then
            return player.PlayerData.citizenid
        end
    elseif Bridge.FrameworkName == "redem" then
        local player = exports['gfxr-bridge']:GetPlayer(source)
        if player then
            return player.identifier
        end
    end
    -- Fallback: license identifier
    for i = 0, GetNumPlayerIdentifiers(source) - 1 do
        local id = GetPlayerIdentifier(source, i)
        if string.find(id, "license:") then
            return id
        end
    end
    return nil
end)

--- Get player display name
---@param source number
---@return string
exports('GetPlayerName', function(source)
    if Bridge.FrameworkName == "vorp" then
        local player = exports['gfxr-bridge']:GetPlayer(source)
        if player then
            return player.firstname .. " " .. player.lastname
        end
    elseif Bridge.FrameworkName == "rsg" then
        local player = exports['gfxr-bridge']:GetPlayer(source)
        if player then
            local ci = player.PlayerData.charinfo
            return ci.firstname .. " " .. ci.lastname
        end
    elseif Bridge.FrameworkName == "redem" then
        local player = exports['gfxr-bridge']:GetPlayer(source)
        if player then
            return player.firstname .. " " .. player.lastname
        end
    end
    return GetPlayerName(source) or "Unknown"
end)

-- ══════════════════════════════════════════
-- MONEY
-- ══════════════════════════════════════════

--- Add money to player
---@param source number
---@param amount number
---@param type string "cash"|"gold"|"bank"|"rol"
exports('AddMoney', function(source, amount, type)
    type = type or "cash"
    if Bridge.FrameworkName == "vorp" then
        local player = exports['gfxr-bridge']:GetPlayer(source)
        if player then
            if type == "cash" or type == "money" then
                player.addCurrency(0, amount)
            elseif type == "gold" then
                player.addCurrency(1, amount)
            elseif type == "rol" then
                player.addCurrency(2, amount)
            end
        end
    elseif Bridge.FrameworkName == "rsg" then
        local player = exports['gfxr-bridge']:GetPlayer(source)
        if player then
            if type == "cash" or type == "money" then
                player.Functions.AddMoney("cash", amount)
            elseif type == "gold" or type == "bloodmoney" then
                player.Functions.AddMoney("bloodmoney", amount)
            elseif type == "bank" then
                player.Functions.AddMoney("bank", amount)
            end
        end
    elseif Bridge.FrameworkName == "redem" then
        local player = exports['gfxr-bridge']:GetPlayer(source)
        if player then
            if type == "cash" or type == "money" then
                player.addMoney(amount)
            elseif type == "gold" then
                player.addGold(amount)
            elseif type == "bank" or type == "bankmoney" then
                player.addBankMoney(amount)
            end
        end
    end
end)

--- Remove money from player
---@param source number
---@param amount number
---@param type string "cash"|"gold"|"bank"|"rol"
exports('RemoveMoney', function(source, amount, type)
    type = type or "cash"
    if Bridge.FrameworkName == "vorp" then
        local player = exports['gfxr-bridge']:GetPlayer(source)
        if player then
            if type == "cash" or type == "money" then
                player.removeCurrency(0, amount)
            elseif type == "gold" then
                player.removeCurrency(1, amount)
            elseif type == "rol" then
                player.removeCurrency(2, amount)
            end
        end
    elseif Bridge.FrameworkName == "rsg" then
        local player = exports['gfxr-bridge']:GetPlayer(source)
        if player then
            if type == "cash" or type == "money" then
                player.Functions.RemoveMoney("cash", amount)
            elseif type == "gold" or type == "bloodmoney" then
                player.Functions.RemoveMoney("bloodmoney", amount)
            elseif type == "bank" then
                player.Functions.RemoveMoney("bank", amount)
            end
        end
    elseif Bridge.FrameworkName == "redem" then
        local player = exports['gfxr-bridge']:GetPlayer(source)
        if player then
            if type == "cash" or type == "money" then
                player.removeMoney(amount)
            elseif type == "gold" then
                player.removeGold(amount)
            elseif type == "bank" or type == "bankmoney" then
                player.removeBankMoney(amount)
            end
        end
    end
end)

--- Check if player has enough money
---@param source number
---@param amount number
---@param type string "cash"|"gold"|"bank"|"rol"
---@return boolean
exports('HasMoney', function(source, amount, type)
    local current = exports['gfxr-bridge']:GetMoney(source, type)
    return current >= amount
end)

--- Get player money amount
---@param source number
---@param type string "cash"|"gold"|"bank"|"rol"
---@return number
exports('GetMoney', function(source, type)
    type = type or "cash"
    if Bridge.FrameworkName == "vorp" then
        local player = exports['gfxr-bridge']:GetPlayer(source)
        if player then
            if type == "cash" or type == "money" then
                return player.money or 0
            elseif type == "gold" then
                return player.gold or 0
            elseif type == "rol" then
                return player.rol or 0
            end
        end
    elseif Bridge.FrameworkName == "rsg" then
        local player = exports['gfxr-bridge']:GetPlayer(source)
        if player then
            if type == "cash" or type == "money" then
                return player.PlayerData.money.cash or 0
            elseif type == "gold" or type == "bloodmoney" then
                return player.PlayerData.money.bloodmoney or 0
            elseif type == "bank" then
                return player.PlayerData.money.bank or 0
            end
        end
    elseif Bridge.FrameworkName == "redem" then
        local player = exports['gfxr-bridge']:GetPlayer(source)
        if player then
            if type == "cash" or type == "money" then
                return player.money or 0
            elseif type == "gold" then
                return player.gold or 0
            elseif type == "bank" or type == "bankmoney" then
                return player.bankmoney or 0
            end
        end
    end
    return 0
end)

-- ══════════════════════════════════════════
-- INVENTORY
-- ══════════════════════════════════════════

--- Add item to player inventory
---@param source number
---@param item string
---@param count number
---@param meta table|nil
exports('AddItem', function(source, item, count, meta)
    if Bridge.InventoryName == "vorp_inventory" then
        exports.vorp_inventory:addItem(source, item, count, meta)
    elseif Bridge.InventoryName == "rsg-inventory" then
        exports['rsg-inventory']:AddItem(source, item, count, false, meta)
    elseif Bridge.InventoryName == "redemrp_inventory" then
        exports.redemrp_inventory:addItem(source, item, count, meta)
    end
end)

--- Remove item from player inventory
---@param source number
---@param item string
---@param count number
exports('RemoveItem', function(source, item, count)
    if Bridge.InventoryName == "vorp_inventory" then
        exports.vorp_inventory:subItem(source, item, count)
    elseif Bridge.InventoryName == "rsg-inventory" then
        exports['rsg-inventory']:RemoveItem(source, item, count)
    elseif Bridge.InventoryName == "redemrp_inventory" then
        exports.redemrp_inventory:removeItem(source, item, count)
    end
end)

--- Check if player has item
---@param source number
---@param item string
---@param count number|nil
---@return boolean
exports('HasItem', function(source, item, count)
    count = count or 1
    local itemCount = exports['gfxr-bridge']:GetItemCount(source, item)
    return itemCount >= count
end)

--- Get item count
---@param source number
---@param item string
---@return number
exports('GetItemCount', function(source, item)
    if Bridge.InventoryName == "vorp_inventory" then
        local itemData = exports.vorp_inventory:getItemCount(source, nil, item)
        return itemData or 0
    elseif Bridge.InventoryName == "rsg-inventory" then
        local itemData = exports['rsg-inventory']:GetItemByName(source, item)
        return itemData and itemData.amount or 0
    elseif Bridge.InventoryName == "redemrp_inventory" then
        local itemData = exports.redemrp_inventory:getItem(source, item)
        return itemData and itemData.amount or 0
    end
    return 0
end)

--- Get full player inventory
---@param source number
---@return table
exports('GetInventory', function(source)
    if Bridge.InventoryName == "vorp_inventory" then
        return exports.vorp_inventory:getInventory(source) or {}
    elseif Bridge.InventoryName == "rsg-inventory" then
        local player = exports['gfxr-bridge']:GetPlayer(source)
        if player then
            return player.PlayerData.items or {}
        end
    elseif Bridge.InventoryName == "redemrp_inventory" then
        return exports.redemrp_inventory:getInventory(source) or {}
    end
    return {}
end)

--- Register a useable item
---@param item string
---@param handler function
exports('RegisterItem', function(item, handler)
    if Bridge.FrameworkName == "vorp" then
        exports.vorp_inventory:registerUsableItem(item, function(data)
            handler(data.source, data)
        end)
    elseif Bridge.FrameworkName == "rsg" then
        local core = GetCore()
        if core then
            core.Functions.CreateUseableItem(item, handler)
        end
    elseif Bridge.FrameworkName == "redem" then
        exports.redemrp:registerUsableItem(item, handler)
    end
end)

-- ══════════════════════════════════════════
-- CALLBACKS
-- ══════════════════════════════════════════

local registeredCallbacks = {}

--- Register a server callback
---@param name string
---@param cb function
exports('RegisterCallback', function(name, cb)
    if Bridge.FrameworkName == "rsg" then
        local core = GetCore()
        if core then
            core.Functions.CreateCallback(name, cb)
        end
    else
        registeredCallbacks[name] = cb
    end
end)

-- Generic callback handler for non-RSG frameworks
RegisterNetEvent("gfxr-bridge:cb:request", function(name, id, args)
    local src = source
    if registeredCallbacks[name] then
        local result = registeredCallbacks[name](src, table.unpack(args or {}))
        TriggerClientEvent("gfxr-bridge:cb:response:" .. id, src, result)
    end
end)

-- ══════════════════════════════════════════
-- NOTIFICATION (Server -> Client)
-- ══════════════════════════════════════════

--- Send notification to a specific player from server
---@param source number
---@param message string
---@param type string|nil
exports('Notify', function(source, message, type)
    if Bridge.FrameworkName == "vorp" then
        TriggerClientEvent("vorp:TipRight", source, message, 3000)
    elseif Bridge.FrameworkName == "rsg" then
        TriggerClientEvent('rsg-core:Notify', source, message, type or "primary", 3000)
    elseif Bridge.FrameworkName == "redem" then
        TriggerClientEvent("redemrp:notification", source, message)
    end
end)

-- ══════════════════════════════════════════
-- DATABASE
-- ══════════════════════════════════════════

--- Execute SQL query
---@param query string
---@param params table|nil
---@return any
exports('ExecuteSql', function(query, params)
    local p = promise:new()
    if Bridge.SQLName == "oxmysql" then
        exports.oxmysql:execute(query, params or {}, function(data)
            p:resolve(data)
        end)
    elseif Bridge.SQLName == "ghmattimysql" then
        exports.ghmattimysql:execute(query, params or {}, function(data)
            p:resolve(data)
        end)
    elseif Bridge.SQLName == "mysql-async" then
        MySQL.Async.fetchAll(query, params or {}, function(data)
            p:resolve(data)
        end)
    else
        p:resolve(nil)
    end
    return Citizen.Await(p)
end)

-- ══════════════════════════════════════════
-- JOB
-- ══════════════════════════════════════════

--- Get player job
---@param source number
---@return table|nil {name, label, grade}
exports('GetPlayerJob', function(source)
    if Bridge.FrameworkName == "vorp" then
        local player = exports['gfxr-bridge']:GetPlayer(source)
        if player then
            return {
                name = player.job,
                label = player.joblabel or player.job,
                grade = player.jobgrade or 0,
            }
        end
    elseif Bridge.FrameworkName == "rsg" then
        local player = exports['gfxr-bridge']:GetPlayer(source)
        if player then
            local job = player.PlayerData.job
            return {
                name = job.name,
                label = job.label,
                grade = job.grade.level,
            }
        end
    elseif Bridge.FrameworkName == "redem" then
        local player = exports['gfxr-bridge']:GetPlayer(source)
        if player then
            return {
                name = player.job,
                label = player.job,
                grade = 0,
            }
        end
    end
    return nil
end)

--- Set player job
---@param source number
---@param job string
---@param grade number|nil
exports('SetPlayerJob', function(source, job, grade)
    grade = grade or 0
    if Bridge.FrameworkName == "vorp" then
        local player = exports['gfxr-bridge']:GetPlayer(source)
        if player then
            player.setJob(job)
            player.setJobGrade(grade)
        end
    elseif Bridge.FrameworkName == "rsg" then
        local player = exports['gfxr-bridge']:GetPlayer(source)
        if player then
            player.Functions.SetJob(job, grade)
        end
    elseif Bridge.FrameworkName == "redem" then
        local player = exports['gfxr-bridge']:GetPlayer(source)
        if player then
            player.setJob(job)
        end
    end
end)
