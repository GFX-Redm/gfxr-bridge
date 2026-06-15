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

--- Get the detected framework name ("vorp" | "rsg" | "redem" | nil).
---@return string|nil
exports('GetFramework', function()
    return Bridge.FrameworkName
end)

--- Framework-agnostic admin check. True for: the server console (src 0), any
--- player with the `command` ACE (txAdmin / console-granted admins), or whose
--- framework group is admin/superadmin/mod.
---@param source number
---@return boolean
exports('IsAdmin', function(source)
    if not source or source == 0 then return true end
    if IsPlayerAceAllowed(source, 'command') then return true end
    local ok, player = pcall(function() return exports['gfxr-bridge']:GetPlayer(source) end)
    if ok and player then
        local group = player.group
            or (player.PlayerData and player.PlayerData.group)
            or (player.PlayerData and player.PlayerData.metadata and player.PlayerData.metadata.group)
        if group == 'admin' or group == 'superadmin' or group == 'mod' or group == 'moderator' then
            return true
        end
    end
    return false
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
    if Bridge.FrameworkName == "vorp" or Bridge.FrameworkName == "redem" then
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

--- Get player bank balance, framework-agnostic.
--- RSG and RedEM expose a bank balance natively. VORP core has NO standardized
--- bank balance (banking is a separate optional resource, not on the character
--- object), so VORP returns 0 — scripts needing VORP banking must query that
--- resource directly. (Confirmed via gfxr-bridge-expert + cached VORP refs.)
---@param source number
---@return number
exports('GetBank', function(source)
    if Bridge.FrameworkName == "rsg" then
        local player = exports['gfxr-bridge']:GetPlayer(source)
        if player then
            return player.PlayerData.money.bank or 0
        end
    elseif Bridge.FrameworkName == "redem" then
        local player = exports['gfxr-bridge']:GetPlayer(source)
        if player then
            return player.bankmoney or 0
        end
    end
    -- VORP: no standardized core bank balance.
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

--- Alias for GetInventory (UI scripts expect Bridge:GetItems)
---@param source number
---@return table
exports('GetItems', function(source)
    return exports['gfxr-bridge']:GetInventory(source)
end)

--- Get a specific item by slot (best-effort, framework-dependent)
---@param source number
---@param slot number
---@return table|nil
exports('GetItemBySlot', function(source, slot)
    if Bridge.InventoryName == "vorp_inventory" then
        local ok, item = pcall(function()
            return exports.vorp_inventory:getItemInSlot(source, slot)
        end)
        if ok then return item end
    elseif Bridge.InventoryName == "rsg-inventory" then
        local player = exports['gfxr-bridge']:GetPlayer(source)
        if player and player.PlayerData and player.PlayerData.items then
            for _, it in pairs(player.PlayerData.items) do
                if (it.slot or it.position) == slot then return it end
            end
        end
    elseif Bridge.InventoryName == "redemrp_inventory" then
        local inv = exports.redemrp_inventory:getInventory(source) or {}
        for _, it in pairs(inv) do
            if (it.slot or it.position) == slot then return it end
        end
    end
    return nil
end)

--- Use an item (manually triggers the framework's use handler, if exposed)
---@param source number
---@param item string
---@return boolean
exports('UseItem', function(source, item)
    if Bridge.InventoryName == "vorp_inventory" then
        local ok = pcall(function() exports.vorp_inventory:useItem(source, item, nil) end)
        return ok
    elseif Bridge.InventoryName == "rsg-inventory" then
        local ok = pcall(function() exports['rsg-inventory']:UseItem(source, item) end)
        return ok
    elseif Bridge.InventoryName == "redemrp_inventory" then
        local ok = pcall(function() exports.redemrp_inventory:useItem(source, item) end)
        return ok
    end
    return false
end)

--- Update metadata on a specific item instance (where supported)
---@param source number
---@param slot number
---@param metadata table
---@return boolean
exports('SetItemMetadata', function(source, slot, metadata)
    if Bridge.InventoryName == "vorp_inventory" then
        local ok = pcall(function()
            exports.vorp_inventory:setItemMetadata(source, slot, metadata)
        end)
        return ok
    elseif Bridge.InventoryName == "rsg-inventory" then
        local ok = pcall(function()
            exports['rsg-inventory']:SetItemMetadata(source, slot, metadata)
        end)
        return ok
    end
    return false
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

-- ══════════════════════════════════════════
-- NEEDS / METABOLISM
-- ══════════════════════════════════════════

--- Get player needs (hunger / thirst / stress), framework-agnostic.
--- All values are normalized to 0-100 integers. Frameworks without a
--- "stress" concept (VORP) return stress = 0.
---@param source number
---@return table {hunger:number, thirst:number, stress:number}
exports('GetNeeds', function(source)
    if Bridge.FrameworkName == "vorp" then
        -- VORP: hunger/thirst are NOT plain fields on the character — vorp_metabolism
        -- persists them in the character's `status` JSON (UserCharacter.setStatus /
        -- UserCharacter.status), keyed `Hunger`/`Thirst`/`Metabolism` on a 0-1000 scale.
        -- We decode it and normalize to 0-100. VORP core has no stress concept.
        -- (Source: VORPCORE/vorp_metabolism server/server.lua + client/apiCalls.lua —
        --  cached at .claude/refs/cache/vorp-metabolism.md.)
        local player = exports['gfxr-bridge']:GetPlayer(source)
        if player then
            local raw = player.status
            if type(raw) == "string" and raw ~= "" then
                local ok, s = pcall(json.decode, raw)
                if ok and type(s) == "table" then
                    return {
                        hunger = math.floor((s.Hunger or 0) / 10),
                        thirst = math.floor((s.Thirst or 0) / 10),
                        stress = 0,
                    }
                end
            elseif type(raw) == "table" then
                -- Some VORP builds expose status as an already-decoded table.
                return {
                    hunger = math.floor((raw.Hunger or 0) / 10),
                    thirst = math.floor((raw.Thirst or 0) / 10),
                    stress = 0,
                }
            end
            return { hunger = 0, thirst = 0, stress = 0 }
        end
    elseif Bridge.FrameworkName == "rsg" then
        -- RSG: hunger/thirst/stress in PlayerData.metadata.
        local player = exports['gfxr-bridge']:GetPlayer(source)
        if player and player.PlayerData and player.PlayerData.metadata then
            local md = player.PlayerData.metadata
            return {
                hunger = md.hunger or 0,
                thirst = md.thirst or 0,
                stress = md.stress or 0,
            }
        end
    elseif Bridge.FrameworkName == "redem" then
        -- RedEM:RP: structure varies by build — values may be nested in a
        -- `status` table or set directly on the player object.
        local player = exports['gfxr-bridge']:GetPlayer(source)
        if player then
            local status = player.status
            return {
                hunger = (status and status.hunger) or player.hunger or 0,
                thirst = (status and status.thirst) or player.thirst or 0,
                stress = (status and status.stress) or player.stress or 0,
            }
        end
    end
    return { hunger = 0, thirst = 0, stress = 0 }
end)

-- Server callback backing the client OnNeedsChange RedEM fallback poll (RSG reads
-- metadata client-side and VORP listens to vorp_metabolism events, so only RedEM
-- uses this). Registered via the bridge's own callback system.
exports['gfxr-bridge']:RegisterCallback('gfxr-bridge:getNeeds', function(src)
    return exports['gfxr-bridge']:GetNeeds(src)
end)
