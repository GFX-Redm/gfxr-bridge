Bridge = {}

local currentResourceName = GetCurrentResourceName()

-- Framework detection
local Frameworks = {
    { name = "vorp", resource = "vorp_core" },
    { name = "rsg",  resource = "rsg-core" },
    { name = "redem", resource = "redemrp" },
}

-- Inventory detection
local Inventories = {
    { name = "vorp_inventory", resource = "vorp_inventory" },
    { name = "rsg-inventory",  resource = "rsg-inventory" },
    { name = "redemrp_inventory", resource = "redemrp_inventory" },
}

-- SQL detection
local SQLScripts = {
    { name = "oxmysql",       resource = "oxmysql" },
    { name = "ghmattimysql",  resource = "ghmattimysql" },
    { name = "mysql-async",   resource = "mysql-async" },
}

function Bridge.Init()
    -- Detect framework
    for _, fw in ipairs(Frameworks) do
        if GetResourceState(fw.resource) == "started" then
            Bridge.FrameworkName = fw.name
            Bridge.FrameworkResource = fw.resource
            break
        end
    end

    -- Detect inventory
    for _, inv in ipairs(Inventories) do
        if GetResourceState(inv.resource) == "started" then
            Bridge.InventoryName = inv.name
            Bridge.InventoryResource = inv.resource
            break
        end
    end

    -- Detect SQL
    for _, sql in ipairs(SQLScripts) do
        if GetResourceState(sql.resource) == "started" then
            Bridge.SQLName = sql.name
            Bridge.SQLResource = sql.resource
            break
        end
    end

    local side = IsDuplicityVersion() and "SERVER" or "CLIENT"
    print(("^2[gfxr-bridge] %s initialized^0"):format(side))
    print(("^3  Framework: %s^0"):format(Bridge.FrameworkName or "Not found"))
    print(("^3  Inventory: %s^0"):format(Bridge.InventoryName or "Not found"))
    print(("^3  SQL: %s^0"):format(Bridge.SQLName or "Not found"))
end

--- Get the raw framework object
---@return any
function Bridge.GetFrameworkObject()
    if Bridge.FrameworkName == "vorp" then
        return exports.vorp_core:GetCore()
    elseif Bridge.FrameworkName == "rsg" then
        return exports['rsg-core']:GetCoreObject()
    elseif Bridge.FrameworkName == "redem" then
        return exports.redemrp:getCore()
    end
    return nil
end

--- Table utility
function Bridge.TableSize(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

Citizen.CreateThread(function()
    Bridge.Init()
end)
