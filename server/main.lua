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
        -- Guncel API: exports.redem_roleplay:RedEM().GetPlayer(src). Eski
        -- `redemrp` kaynaginin `getPlayerFromId` export'u guncel surumde YOK.
        if Bridge.FrameworkResource == "redem_roleplay" then
            local ok, RedEM = pcall(function() return exports.redem_roleplay:RedEM() end)
            return ok and RedEM and RedEM.GetPlayer and RedEM.GetPlayer(source) or nil
        end
        local ok, player = pcall(function() return exports.redemrp:getPlayerFromId(source) end)
        return ok and player or nil
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

--- The player's PERMISSION GROUP as the framework itself stores it.
---
--- VORP keeps two: the ACCOUNT group (`users.group`, what vorp_admin reads by
--- default) and the CHARACTER group (`characters.group`, vorp_admin's
--- `UseCharactersAdmin = true` mode). `useCharacter` picks between them; the
--- other frameworks only have one, so the flag is ignored there.
---
--- ⚠️ Kept separate from `IsAdmin`: that one answers "may this player do admin
--- things at all", this one returns the RAW group so a caller can map it to its
--- own role table (gfxr-admin does exactly that).
---@param source number
---@param useCharacter boolean|nil VORP only: read the character group instead of the account group
---@return string|nil
exports('GetGroup', function(source, useCharacter)
    if not source or source == 0 then return nil end

    if Bridge.FrameworkName == "vorp" then
        local core = GetCore()
        if not core then return nil end
        local user = core.getUser(source)
        if not user then return nil end
        if useCharacter then
            local char = user.getUsedCharacter
            return char and char.group or nil
        end
        return user.getGroup
    elseif Bridge.FrameworkName == "rsg" then
        local core = GetCore()
        if not core then return nil end
        local player = core.Functions.GetPlayer(source)
        if not player or not player.PlayerData then return nil end
        return player.PlayerData.group
            or (player.PlayerData.metadata and player.PlayerData.metadata.group)
    elseif Bridge.FrameworkName == "redem" then
        local player = exports['gfxr-bridge']:GetPlayer(source)
        return player and (player.group or (player.getGroup and player.getGroup())) or nil
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
                -- VORP'ta `identifier` HESAP (steam:...), `charIdentifier` KARAKTER kimligi.
                -- Karakter bazli olmali: aksi halde ayni hesabin tum karakterleri envanteri,
                -- postayi vb. paylasir ve migrasyon anahtarlari (player:<charidentifier>) tutmaz.
                return char and char.charIdentifier and tostring(char.charIdentifier) or nil
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
            -- ⚠️ KARAKTER kimligi: RedEM'de `identifier` HESABIN steam kimligi,
            -- tum karakterler paylasir; karakter `charid` (1, 2, ...). RedEM'in
            -- kendi envanteri de `identifier .. "_" .. charid` ile anahtarliyor
            -- (redemrp_inventory user_inventory). Migrasyon da bu bicimi yaziyor.
            local charid = player.charid or (player.GetActiveCharacter and player.GetActiveCharacter())
            if player.identifier and charid then return tostring(player.identifier) .. "_" .. tostring(charid) end
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
                if player.addGold then player.addGold(amount) end
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
                if player.removeGold then player.removeGold(amount) end
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

--- ══════════════════════════════════════════════════════════════════
--- ENVANTER ISTATISTIKLERI (SUNUCU GENELI)
---
--- ⚠️ TEK EXPORT, `kind` ile dallanir. Bunlar ayni tablo ailesi uzerinde
--- ayni framework dalini paylasan dort sorgu; dort ayri export yazmak ayni
--- "hangi framework" merdivenini dort kez kopyalamak demekti.
---
--- kind:
---   'summary'  -> { items, stacks, distinct, players, stashes }
---   'items'    -> { { name, total, holders }, ... }        (params.search)
---   'players'  -> { { owner, name, total, distinct }, ... }
---   'stashes'  -> { { stash, total, distinct }, ... }
---   'holders'  -> { { owner, name, total }, ... }          (params.item)
---
--- ⚠️ VARSAYIMLARINI KENDI DOGRULAR. RSG kurulumunun envanter semasini
--- yerinde goremedim; kod once tablonun VAR OLUP OLMADIGINI sorar ve yoksa
--- `nil` doner. Uydurulmus bir sorguyu calistirmak konsola kirmizi hata
--- basar ve panelde sessizce sifir gosterirdi.
--- ══════════════════════════════════════════════════════════════════

--- Bir tablo bu veritabaninda var mi?
---@param name string
---@return boolean
local function tableExists(name)
    local rows = exports['gfxr-bridge']:ExecuteSql(
        'SELECT COUNT(*) AS c FROM information_schema.TABLES' ..
        ' WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?', { name })
    return rows ~= nil and rows[1] ~= nil and (tonumber(rows[1].c) or 0) > 0
end

--- VORP: character_inventories(character_id, amount, inventory_type, item_name)
--- `inventory_type = 'default'` oyuncunun kendi envanteri, digerleri depo.
---@param kind string
---@param params table
---@return table|nil
local function vorpInventoryStats(kind, params)
    local limit = math.floor(tonumber(params.limit) or 50)
    local offset = math.floor(tonumber(params.offset) or 0)
    local CI = '`character_inventories`'

    if kind == "summary" then
        local rows = exports['gfxr-bridge']:ExecuteSql(
            'SELECT SUM(amount) AS items, COUNT(*) AS stacks,' ..
            ' COUNT(DISTINCT item_name) AS distinctItems,' ..
            " COUNT(DISTINCT CASE WHEN inventory_type = 'default' THEN character_id END) AS players," ..
            " COUNT(DISTINCT CASE WHEN inventory_type <> 'default' THEN inventory_type END) AS stashes" ..
            ' FROM ' .. CI)
        local row = rows and rows[1]
        if not row then return nil end
        return {
            items    = tonumber(row.items) or 0,
            stacks   = tonumber(row.stacks) or 0,
            distinct = tonumber(row.distinctItems) or 0,
            players  = tonumber(row.players) or 0,
            stashes  = tonumber(row.stashes) or 0,
        }

    elseif kind == "items" then
        local search = params.search
        local rows
        if type(search) == "string" and search ~= "" then
            rows = exports['gfxr-bridge']:ExecuteSql(
                'SELECT item_name AS name, SUM(amount) AS total,' ..
                ' COUNT(DISTINCT character_id) AS holders FROM ' .. CI ..
                ' WHERE item_name LIKE ? GROUP BY item_name ORDER BY total DESC LIMIT ? OFFSET ?',
                { "%" .. search .. "%", limit, offset })
        else
            rows = exports['gfxr-bridge']:ExecuteSql(
                'SELECT item_name AS name, SUM(amount) AS total,' ..
                ' COUNT(DISTINCT character_id) AS holders FROM ' .. CI ..
                ' GROUP BY item_name ORDER BY total DESC LIMIT ? OFFSET ?', { limit, offset })
        end
        local out = {}
        for _, row in pairs(rows or {}) do
            out[#out + 1] = { name = row.name, total = tonumber(row.total) or 0,
                              holders = tonumber(row.holders) or 0 }
        end
        return out

    elseif kind == "players" then
        -- ⚠️ `identifier` de dondurulur: `character_id` VORP'un KARAKTER
        -- kimligi, panelin oyuncu profili ise oyuncunun hesap kimligini
        -- bekliyor. Ikisini birbirine baglayan tek sutun bu.
        local rows = exports['gfxr-bridge']:ExecuteSql(
            'SELECT ci.character_id AS owner, SUM(ci.amount) AS total,' ..
            ' COUNT(DISTINCT ci.item_name) AS distinctItems,' ..
            ' c.identifier AS identifier,' ..
            " CONCAT(COALESCE(c.firstname,''), ' ', COALESCE(c.lastname,'')) AS name" ..
            ' FROM ' .. CI .. ' ci' ..
            ' LEFT JOIN `characters` c ON c.charidentifier = ci.character_id' ..
            " WHERE ci.inventory_type = 'default'" ..
            ' GROUP BY ci.character_id, name, identifier ORDER BY total DESC LIMIT ? OFFSET ?',
            { limit, offset })
        local out = {}
        for _, row in pairs(rows or {}) do
            out[#out + 1] = {
                owner = tostring(row.owner), name = row.name,
                identifier = row.identifier,
                total = tonumber(row.total) or 0,
                distinct = tonumber(row.distinctItems) or 0,
            }
        end
        return out

    elseif kind == "stashes" then
        -- ⚠️ VORP'ta deponun "sahibi" diye bir sutun YOK: `inventory_type`
        -- onu kaydeden scriptin verdigi serbest bir kimlik. Sahiplik
        -- uydurmak yerine ICINE EN COK KOYAN karakteri gosteriyoruz —
        -- bu gercekten tabloda duran bir bilgi.
        local rows = exports['gfxr-bridge']:ExecuteSql(
            'SELECT ci.inventory_type AS stash, SUM(ci.amount) AS total,' ..
            ' COUNT(DISTINCT ci.item_name) AS distinctItems,' ..
            ' COUNT(DISTINCT ci.character_id) AS contributors' ..
            ' FROM ' .. CI .. ' ci' ..
            " WHERE ci.inventory_type <> 'default'" ..
            ' GROUP BY ci.inventory_type ORDER BY total DESC LIMIT ? OFFSET ?',
            { limit, offset })
        local out = {}
        for _, row in pairs(rows or {}) do
            out[#out + 1] = {
                stash = row.stash, total = tonumber(row.total) or 0,
                distinct = tonumber(row.distinctItems) or 0,
                contributors = tonumber(row.contributors) or 0,
            }
        end
        return out

    elseif kind == "holders" then
        local item = params.item
        if type(item) ~= "string" or item == "" then return {} end
        local rows = exports['gfxr-bridge']:ExecuteSql(
            'SELECT ci.character_id AS owner, ci.inventory_type AS stash,' ..
            ' SUM(ci.amount) AS total, c.identifier AS identifier,' ..
            " CONCAT(COALESCE(c.firstname,''), ' ', COALESCE(c.lastname,'')) AS name" ..
            ' FROM ' .. CI .. ' ci' ..
            ' LEFT JOIN `characters` c ON c.charidentifier = ci.character_id' ..
            ' WHERE ci.item_name = ?' ..
            ' GROUP BY ci.character_id, ci.inventory_type, name, identifier ORDER BY total DESC LIMIT ?',
            { item, limit })
        local out = {}
        for _, row in pairs(rows or {}) do
            out[#out + 1] = {
                owner = tostring(row.owner), name = row.name,
                identifier = row.identifier,
                stash = row.stash ~= "default" and row.stash or nil,
                total = tonumber(row.total) or 0,
            }
        end
        return out
    end

    return nil
end

--- Server-wide inventory statistics.
---@param kind string 'summary'|'items'|'players'|'stashes'|'holders'
---@param params table|nil
---@return table|nil nil when the framework/inventory is not supported
exports('GetInventoryStats', function(kind, params)
    params = type(params) == "table" and params or {}

    if Bridge.FrameworkName == "vorp" then
        if not tableExists("character_inventories") then return nil end
        return vorpInventoryStats(kind, params)
    end

    -- ⚠️ RSG/RedEM: envanter semasini yerinde DOGRULAYAMADIM. RSG'de esyalar
    -- `players.inventory` JSON sutununda ve depolar `stashitems` tablosunda
    -- durur; MySQL JSON toplamayla bunlari toplamak mumkun ama sema
    -- kurulumdan kuruluma degisiyor. Dogrulanmamis bir sorgu calistirmak
    -- konsola kirmizi hata basar ve panelde sessizce sifir gosterirdi —
    -- panel bunun yerine "desteklenmiyor" diyor.
    return nil
end)

--- ══════════════════════════════════════════════════════════════════
--- EKONOMI TOPLAMLARI (SUNUCU GENELI)
---
--- ⚠️ BAGLI OYUNCULARIN degil, TUM KARAKTERLERIN toplami. Bagli olanlari
--- toplamak gece 3'te "sunucuda 40 dolar var" derdi; bu sayinin tek anlamli
--- hali veritabanindaki butun karakterleri kapsamasi.
---
--- ⚠️ Para turleri SABIT DEGIL: RSG'de sunucu sahibi kendi turunu ekleyebiliyor
--- (`RSGConfig.Money.MoneyTypes`) ve para tek bir JSON sutununda duruyor.
--- Sabit bir "cash + bank" listesi yazmak, o sunucularin parasinin bir
--- kismini gorunmez kilardi — tur listesini CALISMA ZAMANINDA okuyoruz.
--- ══════════════════════════════════════════════════════════════════

--- Server-wide money totals across every character.
---@return table|nil { [moneyType] = total, ... } plus `characters` count
exports('GetEconomyTotals', function()
    if Bridge.FrameworkName == "vorp" then
        local rows = exports['gfxr-bridge']:ExecuteSql(
            'SELECT COUNT(*) AS chars, SUM(`money`) AS cash, SUM(`gold`) AS gold, SUM(`rol`) AS rol FROM `characters`')
        local row = rows and rows[1]
        if not row then return nil end
        return {
            characters = tonumber(row.chars) or 0,
            totals     = {
                cash = tonumber(row.cash) or 0.0,
                gold = tonumber(row.gold) or 0.0,
                rol  = tonumber(row.rol) or 0.0,
            },
        }

    elseif Bridge.FrameworkName == "rsg" then
        local core = GetCore()
        local types = core and core.Config and core.Config.Money
            and core.Config.Money.MoneyTypes or { cash = 0, bank = 0 }

        -- Tur adlari sunucu yapilandirmasindan geliyor; SQL'e gomulmeden ONCE
        -- suzuluyor. Yapilandirma dosyasi guvenilir kabul edilse de bir
        -- sutun adi enjeksiyonu icin acik birakmak gereksiz bir risk.
        local keys = {}
        for name in pairs(types) do
            if type(name) == "string" and name:match("^[%w_]+$") then
                keys[#keys + 1] = name
            end
        end
        table.sort(keys)
        if #keys == 0 then return nil end

        local parts = { 'COUNT(*) AS chars' }
        for _, name in ipairs(keys) do
            parts[#parts + 1] = ("SUM(JSON_EXTRACT(`money`, '$.%s')) AS `%s`"):format(name, name)
        end

        local rows = exports['gfxr-bridge']:ExecuteSql(
            'SELECT ' .. table.concat(parts, ', ') .. ' FROM `players`')
        local row = rows and rows[1]
        if not row then return nil end

        local totals = {}
        for _, name in ipairs(keys) do
            totals[name] = tonumber(row[name]) or 0.0
        end
        return { characters = tonumber(row.chars) or 0, totals = totals }
    end

    -- RedEM: karakter tablosunun semasi dogrulanmadi; uydurma bir sorgu
    -- hata basar ve panelde sifir gosterirdi.
    return nil
end)

--- Sunucuda KULLANIMDA olan meslek adlari.
---
--- ⚠️ FRAMEWORK'LERDE MERKEZI BIR MESLEK LISTESI YOK (VORP'ta yok; meslek
--- karakter satirinda serbest metin). O yuzden burada dondurulen sey
--- "tanimli meslekler" degil, GERCEKTEN ATANMIS olanlardir. Panel bunu
--- sunucu sahibinin config listesiyle birlestirir: henuz kimseye verilmemis
--- bir meslek yalnizca config'ten gelir.
---
--- ⚠️ RSG'de kaynak SQL DEGIL, `RSGCore.Shared.Jobs` tablosudur — meslekler
--- orada tanimli ve etiketleriyle birlikte gelir.
---@return table<string,string>|nil  { [ad] = etiket } ; framework bilinmiyorsa nil
exports('GetJobs', function()
    if Bridge.FrameworkName == "vorp" then
        local out = {}

        -- ⚠️ BIRINCIL KAYNAK: vorp_core'un KAYIT DEFTERI. VORP scriptleri
        -- mesleklerini calisma aninda buraya kaydediyor (config/jobs.lua yalnizca
        -- elle eklenenler icin). vorp_core bu okumayi acikca admin scriptleri
        -- icin sunuyor — kendi yorumu: "to get it into your admin scripts".
        --
        -- Bu olmadan liste yalnizca ATANMIS mesleklerden kuruluyordu: tek bir
        -- oyuncuya sheriff verilmis bir sunucuda acilir kutuda yalnizca
        -- "sheriff" gorunuyordu, digerleri hic secilemiyordu.
        -- ⚠️ TIP KONTROLU YAPMA. `core.GetRegisteredJobs` kaynaklar arasi bir
        -- FONKSIYON REFERANSI ve FiveM onu bir tabloya sariyor:
        --     type(core.GetRegisteredJobs) == 'table'
        --     tostring -> { __cfx_functionReference = "vorp_core:..." }
        -- Yani `type(...) == 'function'` kontrolu HER ZAMAN basarisiz olur ve
        -- kayit defteri hic okunmaz (olculdu: liste yalnizca karakter
        -- tablosundan gelen tek meslegi gosteriyordu). Dogru yol cagirip
        -- sonuca bakmak.
        local ok, core = pcall(function() return exports.vorp_core:GetCore() end)
        if ok and type(core) == 'table' then
            local okJobs, jobs = pcall(function() return core.GetRegisteredJobs() end)
            if okJobs and type(jobs) == 'table' then
                for name, def in pairs(jobs) do
                    -- ⚠️ VORP'UN KENDI ORNEK KAYDI ELENIYOR. vorp_core kutudan
                    -- `config/jobs.lua` icinde bir ORNEK meslekle geliyor ve o
                    -- ornegin isareti `RESOURCE = "my_script"`. Kayit defterine
                    -- girdigi icin panelde gercek meslegin yaninda ikinci bir
                    -- kayit olarak gorunuyordu (`vorp_police` -> "Police" ve
                    -- ornek -> "police"); yetkili yanlis olani secerse hicbir
                    -- scriptin tanimadigi bir meslek atanmis olurdu.
                    --
                    -- ⚠️ COZUM SUNUCU SAHIBININ DOSYASINI DUZENLEMEK DEGIL:
                    -- bu kayit VORP ile birlikte geliyor, yani HER kurulumda
                    -- var. Alicidan kendi paketini degistirmesini istemek
                    -- yerine burada eleniyor. "my_script" VORP'un kendi
                    -- ornek isareti, uydurma bir eslesme degil.
                    local placeholder = type(def) == 'table' and def.RESOURCE == 'my_script'
                    if type(name) == 'string' and name ~= '' and not placeholder then
                        out[name] = name
                    end
                end
            end
        end

        -- ⚠️ IKINCIL: kullanimda olup KAYITLI OLMAYANLAR. Elle veya eski bir
        -- script tarafindan verilmis bir meslek defterde olmayabilir; listede
        -- gorunmezse yetkili onu bir daha atayamaz.
        local rows = exports['gfxr-bridge']:ExecuteSql(
            "SELECT DISTINCT `job` FROM `characters` WHERE `job` IS NOT NULL AND `job` <> ''")
        for _, row in ipairs(rows or {}) do
            if type(row.job) == 'string' and row.job ~= '' and out[row.job] == nil then
                out[row.job] = row.job
            end
        end

        -- ⚠️ ISSIZ HER ZAMAN LISTEDE. VORP'un varsayilan meslegi
        -- (`config.lua` -> initJob = "unemployed") kayit defterine GIRMIYOR:
        -- hicbir script onu kaydetmiyor, yeni oyuncuya dogrudan atanıyor.
        -- Listeye elle eklenmezse yetkili birinin meslegini ALAMAZ — meslek
        -- vermek mumkun, geri almak degil. Zaten varsa uzerine yazmiyoruz.
        if out['unemployed'] == nil then out['unemployed'] = 'unemployed' end

        return out

    elseif Bridge.FrameworkName == "rsg" then
        -- ⚠️ RSG'de kaynak SQL DEGIL, cekirdegin paylasilan tablosu.
        -- `core.Shared.Jobs` bir VERI tablosu (fonksiyon degil), o yuzden
        -- kaynaklar arasi sorunsuz geciyor — VORP'taki fonksiyon referansi
        -- tuzagi burada yok.
        local core = GetCore()
        local jobs = core and core.Shared and core.Shared.Jobs
        if type(jobs) ~= 'table' then return nil end

        local out = {}
        for name, def in pairs(jobs) do
            out[name] = (type(def) == 'table' and def.label) or name
        end

        -- RSG'nin varsayilan meslegi de 'unemployed' ve o da Shared.Jobs
        -- icinde tanimli OLMAYABILIR; ayni gerekce.
        if out['unemployed'] == nil then out['unemployed'] = 'unemployed' end
        return out
    end

    -- RedEM: meslek semasi dogrulanmadi; uydurma bir sorgu hata basar ve
    -- panelde bos bir liste gosterirdi. Bilmiyorsak nil demek dogrusu.
    return nil
end)

--- ══════════════════════════════════════════════════════════════════
--- KARAKTER (isim, yas, takma ad, aciklama, XP)
---
--- ⚠️ ALAN KUMESI FRAMEWORK'E GORE DEGISIR ve `editable` bunu ACIKCA
--- bildirir. Cagiran taraf kendi listesini varsaymaz: RSG'de takma ad ve
--- karakter aciklamasi YOK, VORP'ta dogum tarihi yok (yas var). Desteklenmeyen
--- bir alani yine de gostermek, kullanicinin doldurup kaydettigi ve HICBIR
--- SEY OLMAYAN bir kutu demekti.
---
---   VORP  : Character.Firstname/Lastname/NickName/Age/Gender/
---           CharDescription/Xp + SaveCharacterInDb()
---   RSG   : PlayerData.charinfo (firstname/lastname/birthdate/gender)
---           + SetPlayerData + Save()
---   RedEM : yalnizca OKUNUR — yazma API'si dogrulanamadi, uydurmak
---           sessizce kaybolan bir "kaydet" dugmesi uretirdi.
--- ══════════════════════════════════════════════════════════════════

--- VORP erisimcisi guvenli cagri.
---
--- ⚠️ pcall SART: vorp_core'un RemoveXp yolu `self.Xp` FONKSIYONUNU bir
--- SAYIYLA eziyor (character.lua "self.Xp = self.xp - quantity"). O karakterde
--- `player.Xp(value)` cagrisi "attempt to call a number" ile patlar; bu yuzden
--- erisimci calismazsa ham alana yaziyoruz — SaveCharacterInDb zaten ham
--- alani okur.
---@param player table
---@param accessor string
---@param rawField string
---@param value any
local function vorpSet(player, accessor, rawField, value)
    local fn = player[accessor]
    if type(fn) == "function" then
        local ok = pcall(fn, value)
        if ok then return true end
    end
    player[rawField] = value
    return true
end

--- Read a player's character sheet.
---@param source number
---@return table|nil { fields = table, editable = string[] }
exports('GetCharacter', function(source)
    local player = exports['gfxr-bridge']:GetPlayer(source)
    if not player then return nil end

    if Bridge.FrameworkName == "vorp" then
        return {
            fields = {
                firstname   = player.firstname,
                lastname    = player.lastname,
                nickname    = player.nickname,
                age         = tonumber(player.age),
                gender      = player.gender,
                description = player.charDescription,
                xp          = tonumber(player.xp) or 0,
            },
            editable = { "firstname", "lastname", "nickname", "age", "gender", "description", "xp" },
        }
    elseif Bridge.FrameworkName == "rsg" then
        local ci = player.PlayerData and player.PlayerData.charinfo or {}
        return {
            fields = {
                firstname = ci.firstname,
                lastname  = ci.lastname,
                birthdate = ci.birthdate,
                -- RSG cinsiyeti sayi tutar (0/1); panel metin bekliyor.
                gender    = tostring(ci.gender or 0),
            },
            editable = { "firstname", "lastname", "birthdate", "gender" },
        }
    elseif Bridge.FrameworkName == "redem" then
        return {
            fields   = { firstname = player.firstname, lastname = player.lastname },
            editable = {},   -- yazma API'si dogrulanmadi
        }
    end
    return nil
end)

--- Write character fields. Only supported keys are applied.
---@param source number
---@param fields table
---@return boolean ok, table applied
exports('SetCharacter', function(source, fields)
    if type(fields) ~= "table" then return false, {} end

    local player = exports['gfxr-bridge']:GetPlayer(source)
    if not player then return false, {} end

    local applied = {}

    if Bridge.FrameworkName == "vorp" then
        local MAP = {
            firstname   = { "Firstname", "firstname" },
            lastname    = { "Lastname", "lastname" },
            nickname    = { "NickName", "nickname" },
            age         = { "Age", "age" },
            gender      = { "Gender", "gender" },
            description = { "CharDescription", "charDescription" },
            xp          = { "Xp", "xp" },
        }
        for key, target in pairs(MAP) do
            local value = fields[key]
            if value ~= nil then
                vorpSet(player, target[1], target[2], value)
                applied[#applied + 1] = key
            end
        end
        if #applied > 0 and type(player.SaveCharacterInDb) == "function" then
            player.SaveCharacterInDb()
        end
        return #applied > 0, applied

    elseif Bridge.FrameworkName == "rsg" then
        local ci = player.PlayerData and player.PlayerData.charinfo
        if not ci then return false, {} end

        for _, key in ipairs({ "firstname", "lastname", "birthdate", "gender" }) do
            if fields[key] ~= nil then
                -- Cinsiyet RSG'de SAYI: metin yazmak karakter olusturma
                -- ekranini ve kiyafet scriptlerini bozar.
                ci[key] = (key == "gender") and (tonumber(fields[key]) or 0) or fields[key]
                applied[#applied + 1] = key
            end
        end

        if #applied > 0 then
            player.Functions.SetPlayerData("charinfo", ci)
            player.Functions.Save()
        end
        return #applied > 0, applied
    end

    -- RedEM ve bilinmeyen framework: yazma yok.
    return false, {}
end)

--- ══════════════════════════════════════════════════════════════════
--- WHITELIST
---
--- ⚠️ YALNIZCA FRAMEWORK'UN KENDI whitelist'i. Bir framework whitelist
--- kavramini tasimiyorsa burasi `false` doner ve cagiran taraf kendi
--- listesini kurar — koprunun isi olmayan bir kavrami TAKLIT ETMEK,
--- sunucunun gercek whitelist'i yaninda ikinci bir dogruluk kaynagi
--- yaratirdi.
---
---   VORP  : `whitelist` tablosu + `Core.Whitelist` API'si (vorp_core
---           baglanti aninda kendisi zorluyor).
---   RSG   : whitelist kavrami YOK.
---   RedEM : whitelist kavrami YOK.
--- ══════════════════════════════════════════════════════════════════

--- Does the running framework have its own whitelist?
---@return boolean
exports('WhitelistSupported', function()
    return Bridge.FrameworkName == "vorp"
end)

--- List whitelist entries (framework table).
---@param search string|nil
---@param limit number|nil
---@param offset number|nil
---@return table rows { { identifier, status, discord, firstConnection }, ... }
exports('WhitelistList', function(search, limit, offset)
    if Bridge.FrameworkName ~= "vorp" then return {} end

    limit = math.floor(tonumber(limit) or 50)
    offset = math.floor(tonumber(offset) or 0)

    local rows
    if type(search) == "string" and search ~= "" then
        local like = "%" .. search .. "%"
        rows = exports['gfxr-bridge']:ExecuteSql(
            'SELECT identifier, status, discordid, firstconnection FROM `whitelist`' ..
            ' WHERE identifier LIKE ? OR discordid LIKE ? ORDER BY id DESC LIMIT ? OFFSET ?',
            { like, like, limit, offset })
    else
        rows = exports['gfxr-bridge']:ExecuteSql(
            'SELECT identifier, status, discordid, firstconnection FROM `whitelist`' ..
            ' ORDER BY id DESC LIMIT ? OFFSET ?', { limit, offset })
    end

    local out = {}
    for _, row in pairs(rows or {}) do
        out[#out + 1] = {
            identifier      = row.identifier,
            -- ⚠️ oxmysql TINYINT(1)'i BOOLEAN olarak dondurebiliyor; iki
            -- bicimi de kabul ediyoruz (bkz. gfxr-admin SqlBool dersi).
            status          = row.status == true or tonumber(row.status) == 1,
            discord         = row.discordid,
            firstConnection = row.firstconnection == true or tonumber(row.firstconnection) == 1,
        }
    end
    return out
end)

--- Whitelist / un-whitelist one identifier.
---@param identifier string
---@param status boolean
---@return boolean handled
--- Framework whitelist'i GERCEKTEN zorluyor mu?
---
--- ⚠️ NEDEN GEREKLI: VORP'un whitelist tablosu HER ZAMAN var, ama vorp_core
--- ona yalnizca kendi `Config.Whitelist` acikken bakiyor. Kapaliyken tablo
--- doluyor, panel "framework whitelist" diyor, yonetici kisi ekliyor —
--- ve sunucu HERKESE acik kalmaya devam ediyor. Hicbir yerde hata yok;
--- koruma oldugu SANILAN bir sey hic yok. Panelin bunu soyleyebilmesi icin
--- durumu okuyabilmesi gerekiyor.
---
--- ⚠️ SALT OKUMA. vorp_core'un dosyasi OKUNUR, degistirilmez: musterinin
--- kendi paketinde hicbir degisiklik yapilmadan calismak zorundayiz.
---
--- ⚠️ Bulunamazsa `nil` doner — `false` DEGIL. "Bilmiyorum" ile "kapali"
--- ayni sey degil; panel bilinmeyen durumda yanlis bir guvence de,
--- yanlis bir alarm da vermemeli.
---@return boolean|nil
exports('WhitelistEnforced', function()
    if Bridge.FrameworkName ~= "vorp" then return nil end

    local text = LoadResourceFile('vorp_core', 'config/config.lua')
    if type(text) ~= "string" or text == "" then return nil end

    -- Yorum satirlarini ele: "-- Whitelist = true" ornegi degeri bozardi.
    for line in text:gmatch("[^\r\n]+") do
        local body = line:match("^%s*(.-)%s*$")
        if not body:match("^%-%-") then
            local value = body:match("^Whitelist%s*=%s*([%a]+)")
                or body:match("^Config%.Whitelist%s*=%s*([%a]+)")
            if value then return value == "true" end
        end
    end
    return nil
end)

--- Framework whitelist'in ANAHTAR OLARAK kullandigi kimlik turu.
---
--- ⚠️ Onemli: vorp_core whitelist'i STEAM kimligiyle ariyor
--- (`GetPlayerIdentifierByType(src, 'steam')`). Listeye `license:...` yazmak
--- sessizce ise yaramaz — satir tabloya girer, eslesme HIC olmaz. Panel
--- ekleme alaninda bunu soyleyebilsin diye bildiriliyor.
---@return string|nil
exports('WhitelistIdentityKind', function()
    if Bridge.FrameworkName ~= "vorp" then return nil end
    return "steam"
end)

exports('WhitelistSet', function(identifier, status)
    if Bridge.FrameworkName ~= "vorp" then return false end
    if type(identifier) ~= "string" or identifier == "" then return false end

    local core = GetCore()
    if not core or not core.Whitelist then return false end

    if status then
        core.Whitelist.whitelistUser(identifier)
    else
        core.Whitelist.unWhitelistUser(identifier)
    end
    return true
end)

--- ══════════════════════════════════════════════════════════════════
--- ITEM CATALOG
---
--- ⚠️ FRAMEWORKLER BUNU AYNI YERDE TUTMUYOR — tek bir yaklasim ise yaramaz:
---   * VORP  : VERITABANINDA. `vorp_inventory` acilista `SELECT * FROM items`
---             cekiyor (server/services/itemsDatabase.lua). Sutunlar:
---             item, label, limit, type, usable, can_remove, metadata.
---   * RSG   : LUA TABLOSUNDA. `rsg-core/shared/items.lua` -> `RSGShared.Items`
---             (Core.Shared.Items). Veritabaniyla ilgisi yok.
---   * RedEM : envanter kaynagina gore degisiyor; DB'de `items` tablosu
---             varsayiliyor, yoksa bos donuyor.
---
--- ⚠️ Sonuc ONBELLEKLENIR. VORP tarafi SQL turu; katalog 500+ satir olabiliyor
--- ve bir arama kutusu her tusa basista bunu cekemez.
--- ══════════════════════════════════════════════════════════════════

local itemCatalog = nil

--- Every item DEFINED on the server (not a player's inventory).
---@param refresh boolean|nil rebuild the cache
---@return table rows { { name, label }, ... }  (never nil)
exports('GetItemCatalog', function(refresh)
    if itemCatalog and not refresh then return itemCatalog end

    local out = {}

    if Bridge.FrameworkName == "rsg" then
        local core = GetCore()
        local shared = core and core.Shared or nil
        for key, item in pairs((shared and shared.Items) or {}) do
            local name = item.name or key
            if type(name) == "string" and name ~= "" then
                out[#out + 1] = { name = name, label = item.label or name }
            end
        end
    else
        -- VORP ve RedEM: veritabani.
        local ok, rows = pcall(function()
            return exports['gfxr-bridge']:ExecuteSql('SELECT `item`, `label` FROM `items`', {})
        end)
        if ok and type(rows) == "table" then
            for _, row in pairs(rows) do
                if type(row.item) == "string" and row.item ~= "" then
                    out[#out + 1] = { name = row.item, label = row.label or row.item }
                end
            end
        end
    end

    table.sort(out, function(a, b) return a.name < b.name end)
    itemCatalog = out
    return out
end)

--- ══════════════════════════════════════════════════════════════════
--- WEAPONS
---
--- ⚠️ SILAHLAR ESYA DEGIL. VORP ve RedEM silahlari ayri bir tabloda, kendi
--- API'siyle tutuyor (`createWeapon` / `giveWeapon`); `AddItem` ile silah
--- vermeye calismak sessizce hicbir sey yapmiyor. RSG ise silahi normal bir
--- envanter kalemi olarak tutuyor, orada `AddItem` DOGRU cagri.
---
--- Bu ayrimi feature scriptlere birakmiyoruz: golden rule 2 geregi onlar
--- framework adini hic gormemeli.
--- ══════════════════════════════════════════════════════════════════

--- Give a weapon to a player.
---@param source number
---@param weapon string weapon name (e.g. "WEAPON_REVOLVER_CATTLEMAN")
---@param ammo number|nil starting ammo
---@return boolean handled
exports('AddWeapon', function(source, weapon, ammo)
    if type(weapon) ~= "string" or weapon == "" then return false end
    ammo = tonumber(ammo) or 0

    if Bridge.InventoryName == "vorp_inventory" then
        -- vorp_inventory:createWeapon(source, name, ammoTable, components, comps, serial, custom_label)
        exports.vorp_inventory:createWeapon(source, weapon, { ammo }, {})
        return true
    elseif Bridge.InventoryName == "rsg-inventory" then
        -- RSG: silah normal bir kalem; mermi meta'da tasiniyor.
        exports['rsg-inventory']:AddItem(source, string.lower(weapon), 1, false, { ammo = ammo })
        return true
    elseif Bridge.InventoryName == "redemrp_inventory" then
        exports.redemrp_inventory:giveWeapon(source, weapon, ammo)
        return true
    end
    return false
end)

--- Remove a weapon from a player.
---@param source number
---@param weapon string weapon name or serial
---@return boolean handled
exports('RemoveWeapon', function(source, weapon)
    if type(weapon) ~= "string" or weapon == "" then return false end

    if Bridge.InventoryName == "vorp_inventory" then
        -- VORP silahi SERI NUMARASIYLA siliyor; ada gore silmek icin once
        -- oyuncunun silahlarini bulup eslesenin id'sini gecmek gerekiyor.
        local list = exports.vorp_inventory:getUserWeapons(source) or {}
        local removed = false
        for _, entry in pairs(list) do
            local name = entry.name or entry.weapon or (entry.getName and entry:getName())
            if type(name) == "string" and string.lower(name) == string.lower(weapon) then
                exports.vorp_inventory:deleteWeapon(source, entry.id or entry.serial)
                removed = true
            end
        end
        return removed
    elseif Bridge.InventoryName == "rsg-inventory" then
        exports['rsg-inventory']:RemoveItem(source, string.lower(weapon), 1)
        return true
    elseif Bridge.InventoryName == "redemrp_inventory" then
        exports.redemrp_inventory:removeWeapon(source, weapon)
        return true
    end
    return false
end)

--- List a player's weapons.
---@param source number
---@return table rows  { { name, ammo, serial } , ... }  (never nil)
exports('GetWeapons', function(source)
    local out = {}

    if Bridge.InventoryName == "vorp_inventory" then
        for _, entry in pairs(exports.vorp_inventory:getUserWeapons(source) or {}) do
            out[#out + 1] = {
                name   = entry.name or entry.weapon,
                ammo   = entry.ammo,
                serial = entry.id or entry.serial,
            }
        end
    elseif Bridge.InventoryName == "rsg-inventory" then
        -- RSG'de silah envanterin icinde: adi `weapon_` ile baslayanlari ayikla.
        for _, item in pairs(exports['gfxr-bridge']:GetItems(source) or {}) do
            local name = item.name
            if type(name) == "string" and string.sub(name, 1, 7) == "weapon_" then
                out[#out + 1] = { name = name, ammo = item.info and item.info.ammo, serial = item.slot }
            end
        end
    elseif Bridge.InventoryName == "redemrp_inventory" then
        for _, entry in pairs(exports.redemrp_inventory:getUserWeapons(source) or {}) do
            out[#out + 1] = { name = entry.name, ammo = entry.ammo, serial = entry.id }
        end
    end

    return out
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

--- vorp_inventory export ADLARI SURUME GORE DEGISIYOR ve olmayan bir export
--- cagrisi HATA firlatir ("No such export ..."), yani cagiran sorgunun tamami
--- coker. Gercek ornek: bu kurulumda `getInventory` yok, `getUserInventoryItems`
--- var — oyuncu profili acildiginda panel hata bildirimi basiyordu.
--- Burada isim listesi sirayla denenir, hicbiri yoksa sessizce nil doner.
---@param names string[] denenecek export adlari (once GUNCEL isim)
---@return boolean ok, any result
local function vorpInventoryCall(names, ...)
    local args = { ... }
    for _, name in ipairs(names) do
        local ok, result = pcall(function()
            return exports.vorp_inventory[name](exports.vorp_inventory, table.unpack(args))
        end)
        if ok then return true, result end
    end
    return false, nil
end

--- Get full player inventory
---@param source number
---@return table
exports('GetInventory', function(source)
    if Bridge.InventoryName == "vorp_inventory" then
        -- yeni surum: getUserInventoryItems · eski surum: getInventory
        local ok, items = vorpInventoryCall({ 'getUserInventoryItems', 'getInventory' }, source)
        return (ok and items) or {}
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
        local ok, item = vorpInventoryCall({ 'getItemInSlot', 'getItemBySlot' }, source, slot)
        if ok and item then return item end
        -- Bu surumde slot export'u yok: envanteri cekip slot alanindan bul.
        local hasInv, items = vorpInventoryCall({ 'getUserInventoryItems', 'getInventory' }, source)
        if hasInv and type(items) == 'table' then
            for _, it in pairs(items) do
                if (it.slot or it.position) == slot then return it end
            end
        end
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
        local ok = vorpInventoryCall({ 'useItem', 'UseItem' }, source, item, nil)
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
                grade = tonumber(player.jobgrade) or 0,
            }
        end
    end
    return nil
end)

--- Set player job
---@param source number
---@param job string
---@param grade number|nil
--- Oyuncuyu FRAMEWORK'UN KENDI YOLUYLA dirilt.
---
--- ⚠️ NEDEN GEREKLI: ped'i native ile diriltmek (`NetworkResurrectLocalPlayer`)
--- karakteri ayaga kaldiriyor ama framework'un OLUM DURUMUNU birakmiyor.
--- VORP'ta olculdu: `vorp_core/client/respawnsystem.lua` olurken kendi
--- scripted kamerasini kuruyor (`StartDeathCam` -> `RenderScriptCams(true)`)
--- ve yalnizca kendi `ResurrectPlayer` yolu `EndDeathCam()` cagiriyor.
--- Native diriltme o bayragi (`setDead`) hic gormedigi icin oyuncu
--- hareket edebiliyor ama KAMERA CESETTE takili kaliyor, HUD kapali kaliyor
--- ve sunucu hala "olu" biliyor.
---
--- ⚠️ Framework'un dosyasi DEGISTIRILMIYOR: VORP zaten `Core.Player.Revive`
--- diye acik bir API veriyor (server/apicontroller.lua) ve o kendi
--- `vorp_core:Client:OnPlayerRevive` olayini tetikliyor.
---
--- ⚠️ Basarisizlik SESSIZ DEGIL: `false` donuyor ki cagiran taraf native
--- diriltmeye dusebilsin. Framework yoksa ya da API degistiyse oyuncu
--- diriltilmeden kalmamali.
---@param source number
---@return boolean frameworkun kendi yolu kullanildi mi
exports('Revive', function(source)
    if not source then return false end

    if Bridge.FrameworkName == "vorp" then
        local ok, core = pcall(function() return exports.vorp_core:GetCore() end)
        if not ok or type(core) ~= "table" then return false end
        -- ⚠️ TIP KONTROLU YAPMA: cross-resource fonksiyon referansi bir TABLO
        -- icinde geliyor, `type(x) == "function"` HER ZAMAN false doner
        -- (ayni tuzak GetRegisteredJobs'ta da yasandi).
        local okRevive = pcall(function() core.Player.Revive(source, true) end)
        return okRevive == true

    elseif Bridge.FrameworkName == "rsg" then
        -- RSG'de diriltme ambulans/olum betiginde; cekirdegin kendi olayi bu.
        local okEvt = pcall(function()
            TriggerClientEvent('hospital:client:Revive', source)
        end)
        return okEvt == true

    elseif Bridge.FrameworkName == "redem" then
        local okEvt = pcall(function()
            TriggerClientEvent('redemrp_respawn:Revive', source)
        end)
        return okEvt == true
    end

    return false
end)

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
            if player.SetJob then player.SetJob(job) elseif player.setJob then player.setJob(job) end
            if grade and player.SetJobGrade then player.SetJobGrade(grade) end
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
