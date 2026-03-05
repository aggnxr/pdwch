-- ==================== THE MASTER PRODUKSI v174.7 ====================
-- FOCUS: USERNAME LOCK + SYNC REPAIR
-- STATUS: PRODUCTION READY (SECURITY MODE)

local CONFIG = {
    WEBSITE_URL = "https://roblox.pdwch.id",
    VERSION = "v175.2 (STACK FIX) BYPASS",
    POLL_INTERVAL = 8,
    SYNC_INTERVAL = 60,
    DELAY_TRADE = 10,
    REJOIN_DELAY = 10,
    ACCEPT_DELAY = 2.5,
    DEBUG = false,
    QUERY_BUDGET = 1, -- Silent Mode
    MIN_HANDSHAKE = 0.5,
    FORCE_REMOTE = "", -- Fetched from Cloud
    FORCE_ACCEPT_REMOTE = "", -- Fetched from Cloud
    ALLOWED_USERS = {"pdwstore", "aggnars"} -- USERNAME YANG BOLEH EXECUTE
}

-- ==================== SECURITY LOCK ====================
local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local isAuthorized = false
for _, name in ipairs(CONFIG.ALLOWED_USERS) do
    if LP.Name:lower() == name:lower() then
        isAuthorized = true
        break
    end
end

if not isAuthorized then
    LP:Kick("🚫 UNAUTHORIZED USER: Script locked to authorized bot accounts only.")
    return
end

-- ==================== FISHIT MAPPING ====================
local FISHIT = {
    { code = "secret", ids = {"82", "158", "187", "359", "136", "292", "293", "248", "156", "379", "450"}, price = 1000, category = "SECRET", gameCategory = "Fish", displayName = "Secret Tumbal" },
    { code = "kraken", ids = {"159"}, price = 2000, category = "SECRET", gameCategory = "Fish", displayName = "Robot Kraken" },
    { code = "maja1", ids = {"269"}, price = 2000, category = "SECRET", gameCategory = "Fish", displayName = "Elshark Gran Maja" },
    { code = "maja2", ids = {"661"}, price = 2000, category = "SECRET", gameCategory = "Fish", displayName = "Elpirate Gran Maja" },
    { code = "leviathan", ids = {"626"}, price = 10000, category = "SECRET", gameCategory = "Fish", displayName = "Leviathan" },
    { code = "ancient", ids = {"345"}, price = 10000, category = "SECRET", gameCategory = "Fish", displayName = "Ancient Lochness Monster" },
    { code = "evolved", ids = {"558"}, price = 1000, category = "ENCHANT STONE", gameCategory = "Enchant Stones", displayName = "Evolved Enchant Stone" },
    { code = "candy", ids = {"714"}, price = 1000, category = "ENCHANT STONE", gameCategory = "Enchant Stones", displayName = "Candy Enchant Stone" },
    { code = "ruby", ids = {"243"}, price = 20000, category = "MISSION", gameCategory = "Fish", displayName = "Ruby Gemstone" },
    { code = "sacred", ids = {"283"}, price = 5000, category = "MISSION", gameCategory = "Fish", displayName = "Sacred Guardian Squid" },
    { code = "dino", ids = {"228"}, price = 10000, category = "MISSION", gameCategory = "Fish", displayName = "Lochness Monster" }
}

-- ==================== SERVICES ====================
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local http = request or http.request or (http and http.request) or (syn and syn.request)
if not http then error("❌ No HTTP support!") end

-- Anti-AFK (Stealthier)
task.spawn(function()
    pcall(function() for _, v in ipairs(getconnections(LP.Idled)) do v:Disable() end end)
    while true do
        task.wait(math.random(200, 400))
        pcall(function()
            local cam = workspace.CurrentCamera
            if cam then cam.CFrame = cam.CFrame * CFrame.Angles(0, math.rad(0.001), 0) end
        end)
    end
end)

-- Net Locator
local function findNetFolder()
    local tryCount = 0
    while tryCount < 3 do
        local paths = { RS:FindFirstChild("Packages"), RS:FindFirstChild("RemoteFunction") and RS, RS:FindFirstChild("net") and RS }
        for _, root in ipairs(paths) do
            if root then
                local index = root:FindFirstChild("_Index")
                if index then
                    for _, child in ipairs(index:GetChildren()) do
                        if child.Name:find("sleitnick_net") then
                            local net = child:FindFirstChild("net")
                            if net then return net end
                        end
                    end
                end
                local net = root:FindFirstChild("net")
                if net then return net end
            end
        end
        tryCount = tryCount + 1
        task.wait(1)
    end
    return nil
end

-- ==================== SESSION STATE ====================
_G.STEALTH_CACHE_V2 = _G.STEALTH_CACHE_V2 or { verifiedRemote = nil, candidates = {}, lastSync = 0 }
local state = _G.STEALTH_CACHE_V2

local function syncRemotes()
    if CONFIG.DEBUG then print("🌐 Checking Cloud for Remote Updates...") end
    local ok, res = pcall(function() 
        return http({ Url = CONFIG.WEBSITE_URL .. "/api/bot/remotes", Method = "GET" }) 
    end)
    
    if ok and res and res.Body then
        local ok2, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
        if ok2 and data then
            local newTrade = data.trade_remote or data.trade or ""
            local newAccept = data.accept_remote or data.accept or ""
            
            if newTrade ~= "" and newTrade ~= CONFIG.FORCE_REMOTE then
                CONFIG.FORCE_REMOTE = newTrade
                if CONFIG.DEBUG then print("🎯 Cloud-Sync: Trade Remote Updated -> " .. newTrade) end
            end
            
            if newAccept ~= "" and newAccept ~= CONFIG.FORCE_ACCEPT_REMOTE then
                CONFIG.FORCE_ACCEPT_REMOTE = newAccept
                if CONFIG.DEBUG then print("🛡️ Cloud-Sync: Accept Remote Updated -> " .. newAccept) end
                -- Re-trigger listener if it changes
                pcall(function() _G.startAcceptListener() end)
            end
            state.lastSync = tick()
        end
    end
end
_G.syncRemotes = syncRemotes -- Accessible globally

local function startAcceptListener()
    if CONFIG.FORCE_ACCEPT_REMOTE == "" then 
        if CONFIG.DEBUG then print("� Ghost Mode: Skipping automatic acceptor binding.") end
        return 
    end
    
    local netFolder = findNetFolder()
    local rf = netFolder and netFolder:FindFirstChild(CONFIG.FORCE_ACCEPT_REMOTE)
    
    if rf then
        pcall(function()
            rf.OnClientInvoke = function(...)
                task.wait(CONFIG.ACCEPT_DELAY)
                return true
            end
            print("�️ Stealth Accept Bound: " .. rf.Name)
        end)
    else
        warn("⚠️ Force Accept Remote not found: " .. CONFIG.FORCE_ACCEPT_REMOTE)
    end
end

local function surgicalInvoke(targetPlayer, itemUuid)
    if CONFIG.FORCE_REMOTE == "" then 
        warn("🚫 [STOP] Ghost Mode requires CONFIG.FORCE_REMOTE to be set!")
        return false, "NoRemoteConfigured" 
    end
    
    local netFolder = findNetFolder()
    local rf = netFolder and netFolder:FindFirstChild(CONFIG.FORCE_REMOTE)
    
    if not rf then
        warn("❌ Force Remote not found: " .. CONFIG.FORCE_REMOTE)
        return false, "RemoteNotFound"
    end

    local ok, result = pcall(function() return rf:InvokeServer(targetPlayer.UserId, itemUuid, 1) end)
    if ok then return true, result end
    return false, "InvokeFail"
end

-- Utils
local function findPlayer(username)
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower() == username:lower() then return p end
    end
    return nil
end

local function updateOrderStatus(orderId, status, amount)
    pcall(function()
        http({ Url = CONFIG.WEBSITE_URL .. "/api/bot/orders/" .. orderId, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode({ status = status, amount = amount }) })
    end)
end

-- ==================== ORDER ENGINE (V174.4 SILENT) ====================
local function fetchAllOrders()
    local endpoints = {
        CONFIG.WEBSITE_URL .. "/api/bot/orders?status=processing",
        CONFIG.WEBSITE_URL .. "/api/bot/orders?status=pending"
    }
    local allItems = {}
    local seenIds = {}
    for _, url in ipairs(endpoints) do
        local ok, res = pcall(function() return http({ Url = url, Method = "GET" }) end)
        if ok and res and res.Body then
            local ok2, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
            if ok2 and data then
                local list = data.orders or data.data or data
                if type(list) == "table" then
                    for _, item in ipairs(list) do
                        local oid = item.order_id or item.id or item.uuid
                        if oid and not seenIds[oid] then
                            seenIds[oid] = true
                            table.insert(allItems, item)
                        end
                    end
                end
            end
        end
        task.wait(1)
    end
    return allItems
end

local function processOrders()
    if CONFIG.DEBUG then print("📡 Scanning (" .. CONFIG.VERSION .. ")...") end
    local orders = fetchAllOrders()
    if not orders or #orders == 0 then return end
    if CONFIG.DEBUG then print("📦 Detected " .. #orders .. " orders.") end
    for _, order in ipairs(orders) do
        local targetPlayer = findPlayer(order.username)
        if not targetPlayer then continue end
        local fishit = nil
        local key = (order.item_code or order.item_name or ""):upper()
        for _, f in ipairs(FISHIT) do if f.code:upper() == key or f.displayName:upper() == key then fishit = f break end end
        if not fishit then continue end
        if CONFIG.DEBUG then print(string.format("🚀 [GO] %s -> %s", order.username, fishit.displayName)) end
        local oid = order.order_id or order.id or order.uuid
        if order.status == "pending" then updateOrderStatus(oid, "processing", order.amount) end
        if LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
            local char = targetPlayer.Character or targetPlayer.CharacterAdded:Wait()
            local hrp = char:WaitForChild("HumanoidRootPart", 5)
            if hrp then
                local offset = Vector3.new(math.random(-20, 20)/10, 0, math.random(-20, 20)/10)
                LP.Character.HumanoidRootPart.CFrame = hrp.CFrame * CFrame.new(0, 0, 6) * CFrame.new(offset)
            end
        end
        task.wait(math.random(30, 50)/10)
        local total, traded = tonumber(order.amount) or 0, 0
        local rot = 1
        while traded < total do
            local Replion = require(RS.Packages.Replion).Client:GetReplion("Data") or require(RS.Packages.Replion).Client:WaitReplion("Data", 5)
            if not Replion then break end
            local inv, ids = Replion:GetExpect("Inventory").Items, {}
            for _, item in ipairs(inv) do
                for _, id in ipairs(fishit.ids) do if tostring(item.Id) == id then table.insert(ids, item) break end end
            end
            if #ids == 0 then break end
            local targetItem = ids[((rot - 1) % #ids) + 1]
            targetPlayer = findPlayer(order.username)
            if not targetPlayer then break end
            local ok, res = surgicalInvoke(targetPlayer, targetItem.UUID)
            if ok and (res == true or res == "Success") then
                traded = traded + 1
                updateOrderStatus(oid, "processing", total - traded)
                task.wait(CONFIG.DELAY_TRADE + math.random(1, 4))
            else
                task.wait(10)
                break 
            end
        end
        if traded >= total then 
            updateOrderStatus(oid, "completed") 
            if CONFIG.DEBUG then print("✅ Trade Completed. Auto-Respawning...") end
            task.wait(2)
            pcall(function() LP.Character:BreakJoints() end)
        end
    end
end

local function syncStock()
    if CONFIG.DEBUG then print("📦 Initializing Stock Sync...") end
    
    local ok, Replion = pcall(function() 
        return require(RS.Packages.Replion).Client:GetReplion("Data") or require(RS.Packages.Replion).Client:WaitReplion("Data", 10)
    end)
    
    if not ok or not Replion then 
        if CONFIG.DEBUG then warn("❌ Sync fail: Data Replion not ready.") end
        return 
    end

    local invOk, data = pcall(function() return Replion:GetExpect("Inventory") end)
    if not (invOk and data and data.Items) then 
        if CONFIG.DEBUG then warn("❌ Sync fail: Inventory items not found.") end
        return 
    end

    local inv, stockList = data.Items, {}
    for _, fishit in ipairs(FISHIT) do
        local count = 0
        for _, item in ipairs(inv) do
            local isFav = item.Favorited == true or item.Favorite == true
            if not isFav then
                for _, id in ipairs(fishit.ids) do
                    if tostring(item.Id) == id then 
                        local qty = tonumber(item.Amount or item.Quantity or item.Count or 1)
                        count = count + qty 
                        break 
                    end
                end
            end
        end
        -- SEND AS ARRAY TO PRESERVE PRIORITY & USE DISPLAY NAME
        table.insert(stockList, {
            name = fishit.displayName,
            stock = count,
            price = fishit.price,
            category = fishit.category
        })
    end

    local postOk, response = pcall(function()
        return http({ 
            Url = CONFIG.WEBSITE_URL .. "/api/stock/sync", 
            Method = "POST", 
            Headers = {["Content-Type"] = "application/json"}, 
            Body = HttpService:JSONEncode({ stocks = stockList }) 
        })
    end)

    if CONFIG.DEBUG then
        if postOk and response then
            print("📡 Sync Success: " .. tostring(response.StatusCode) .. " (" .. tostring(#inv) .. " items scanned)")
        else
            warn("❌ Sync Http Fail: " .. tostring(response))
        end
    end
end

-- MAIN LOOP
task.wait(5)
if CONFIG.DEBUG then print("🚀 Stealth Bot Active! (GHOST MODE v4.3)") end
pcall(syncRemotes)
startAcceptListener()

-- Decoupled Sync Thread (Remotes & Stock)
task.spawn(function()
    while true do
        task.wait(300) -- Sync Remotes every 5 mins
        pcall(syncRemotes)
        pcall(syncStock)
    end
end)

while true do
    task.wait(math.random(20, 50)/10)
    pcall(processOrders)
    task.wait(CONFIG.POLL_INTERVAL + math.random(1, 5))
end
