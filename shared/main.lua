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

--- Envanter tespiti. Ayri fonksiyon, cunku envanter kaynagi bridge'e BAGIMLI:
--- bridge restart edildiginde bagimlilar durur ve Init sirasinda 'stopped' gorunur;
--- asagidaki onResourceStart kancasi onlar acilinca tespiti tekrarlar.
function Bridge.DetectInventory()
    for _, inv in ipairs(Inventories) do
        if GetResourceState(inv.resource) == "started" then
            Bridge.InventoryName = inv.name
            Bridge.InventoryResource = inv.resource
            return Bridge.InventoryName
        end
    end
    -- gfxr-inventory orijinal envanterin yerine gecebilir (`provide 'vorp_inventory'`,
    -- `rsg-inventory`, `redemrp_inventory`). O zaman KAYNAK adi eslesmez ama export
    -- yuzeyi aynidir; framework'e gore isimlendirip mevcut dallarin calismasini saglariz.
    if GetResourceState("gfxr-inventory") == "started" then
        local provided = { vorp = "vorp_inventory", rsg = "rsg-inventory", redem = "redemrp_inventory" }
        Bridge.InventoryName = provided[Bridge.FrameworkName]
        Bridge.InventoryResource = "gfxr-inventory"
    end
    return Bridge.InventoryName
end

function Bridge.Init()
    -- Detect framework
    for _, fw in ipairs(Frameworks) do
        if GetResourceState(fw.resource) == "started" then
            Bridge.FrameworkName = fw.name
            Bridge.FrameworkResource = fw.resource
            break
        end
    end

    Bridge.DetectInventory()

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

-- Envanter bridge'den SONRA baslar (dependency). Init sirasinda kapali gorunuyorsa
-- kaynak acildiginda tespiti tekrarla; yoksa InventoryName nil kalir ve bridge'in
-- item exportlari (AddItem/RemoveItem/GetInventory) hicbir dala girmez.
AddEventHandler(IsDuplicityVersion() and 'onResourceStart' or 'onClientResourceStart', function(res)
    if res == currentResourceName or Bridge.InventoryName then return end
    -- ⚠️ Olay tetiklendiginde kaynagin durumu HENUZ 'started' olmayabiliyor;
    -- ayni karede GetResourceState 'starting' donuyor ve tespit bos donuyordu.
    -- Bir kare bekleyip tekrar bakiyoruz.
    CreateThread(function()
        Wait(0)
        if Bridge.InventoryName then return end
        if Bridge.DetectInventory() then
            print(("^3[gfxr-bridge] Inventory: %s (%s gec basladi)^0"):format(Bridge.InventoryName, res))
        end
    end)
end)

-- ⚠️ SON CARE: envanter tespiti KACIRILIRSA bridge'in item export'lari (AddItem,
-- RemoveItem, GetInventory...) hicbir dala girmez ve sessizce bos doner —
-- panelde "oyuncunun envanteri bos" gorunur, hicbir hata da yazilmaz. Olay
-- kancasina guvenmek yetmiyor (kaynak sirasi, ge basla, restart), bu yuzden
-- acilistan sonra 30 saniye boyunca tespit tekrar denenir.
CreateThread(function()
    for _ = 1, 60 do
        if Bridge.InventoryName then return end
        Wait(500)
        if Bridge.DetectInventory() then
            print(("^3[gfxr-bridge] Inventory: %s (gec tespit)^0"):format(Bridge.InventoryName))
            return
        end
    end
    print("^1[gfxr-bridge] Inventory: tespit edilemedi — item export'lari bos donecek.^0")
end)

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
