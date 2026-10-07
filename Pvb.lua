-- =============================================================================
-- TOON-STYLE MOBILE AUTOMATION DASHBOARD - v5.0
-- + Dynamic seed + gear discovery
-- + Brainrot favorite: dropdown list, fav selected, fav by weight (uses your FireServer(uuid) pattern)
-- + Skip out-of-stock to avoid notification spam, auto-refresh every 30s
-- =============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Config
local AUTO_BUY_DELAY = 5 -- seconds between auto-buy cycles, tweak as needed

-- Cleanup old GUI on re-execute
pcall(function()
    local old1 = CoreGui:FindFirstChild("CartoonAutomationDashboard")
    if old1 then old1:Destroy() end
    local old2 = PlayerGui:FindFirstChild("CartoonAutomationDashboard")
    if old2 then old2:Destroy() end
end)

local Theme = {
    -- Bright colorful mobile-friendly theme (Delta compatible)
    Blue = Color3.fromRGB(0, 170, 255), -- bright sky blue
    Dark = Color3.fromRGB(30, 30, 60), -- dark navy for text
    Bg = Color3.fromRGB(0, 200, 255), -- bright cyan bg
    Surface = Color3.fromRGB(255, 255, 255),
    SurfaceLight = Color3.fromRGB(240, 248, 255),
    Pink = Color3.fromRGB(255, 80, 180), -- hot pink
    Red = Color3.fromRGB(255, 60, 60), -- bright red
    Green = Color3.fromRGB(0, 220, 100), -- bright green
    LightGreen = Color3.fromRGB(50, 230, 120),
    Orange = Color3.fromRGB(255, 140, 0), -- bright orange
    Yellow = Color3.fromRGB(255, 210, 0), -- bright yellow
    Purple = Color3.fromRGB(150, 80, 255), -- bright purple
    Cyan = Color3.fromRGB(0, 220, 255),
    White = Color3.fromRGB(255, 255, 255),
    GrayText = Color3.fromRGB(100, 110, 130),
    TextDim = Color3.fromRGB(100, 110, 130),
    StarOrange = Color3.fromRGB(255, 150, 0),
    StarBg = Color3.fromRGB(255, 245, 200),
    ScrollBg = Color3.fromRGB(235, 245, 255),
    ScrollBar = Color3.fromRGB(255, 180, 0),
    Stroke = Color3.fromRGB(30, 30, 60),
    FontTitle = Enum.Font.FredokaOne,
    FontButton = Enum.Font.FredokaOne,
    FontBody = Enum.Font.GothamBold,
}

local function safeWaitForChild(parent, name, timeout)
    timeout = timeout or 5
    local ok, result = pcall(function()
        return parent:WaitForChild(name, timeout)
    end)
    if ok and result then return result end
    warn("[Dashboard] Missing: " .. tostring(name))
    return nil
end

local Remotes = safeWaitForChild(ReplicatedStorage, "Remotes", 10)
local MainGui = safeWaitForChild(PlayerGui, "Main", 10)

local function getRemote(name)
    if not Remotes then return nil end
    return safeWaitForChild(Remotes, name, 5)
end

local NPCRemote = getRemote("NPC")
local ConfirmSellRemote = getRemote("ConfirmSell")
local ItemSellRemote = getRemote("ItemSell")
local BuyGearRemote = getRemote("BuyGear")
local RestockRemote = getRemote("Restock")
local BuyItemRemote = getRemote("BuyItem")
local FavoriteRemote = getRemote("FavoriteItem")
local UpdateGearStocksRemote = getRemote("UpdateGearStocks")
local UpdatePlantStocksRemote = getRemote("UpdatePlantStocks")
-- SelectiveAssetService for brainrot data (from your snippet)
local RequestAssetRemote = nil
pcall(function()
    local sas = Remotes and Remotes:FindFirstChild("SelectiveAssetService")
    if sas then RequestAssetRemote = sas:FindFirstChild("RequestAsset") end
end)

local function fireSignalSafe(remote, ...)
    if typeof(firesignal) == "function" and remote and remote.OnClientEvent then
        local args = {...}
        pcall(function() firesignal(remote.OnClientEvent, table.unpack(args)) end)
    end
end

local function fireServerSafe(remote, ...)
    if remote then
        local args = {...}
        pcall(function() remote:FireServer(table.unpack(args)) end)
    end
end

-- Fallback seed list if dynamic discovery fails
local DEFAULT_SEEDS = {
    "Cactus Seed", "Carnivorous Plant Seed", "Cocotank Seed", "Corn Cobblazzio Seed",
    "Dragon Fruit Seed", "Eggplant Seed", "Grape Seed", "Kelp Katapulter Seed",
    "King Limone Seed", "Kiwi Cannoneer Seed", "Mango Seed", "Mr Carrot Seed",
    "Pumpkin Seed", "Shroombino Seed", "Starfruit Seed", "Strawberry Seed",
    "Sunflower Seed", "Tomatrio Seed", "Watermelon Seed", "White Lotus Seed"
}
local AvailableSeeds = DEFAULT_SEEDS
local SelectedSeeds = {}
local WasSelectAllChosen = false
local Busy = {}
local autoBuyEnabled = false

-- Gear shop state
local DEFAULT_GEARS = {"Frost Grenade", "Banana Gun", "Carrot Launcher", "Battery Pack", "Explosive Cannon"}
local AvailableGears = DEFAULT_GEARS
local SelectedGears = {}
local WasGearSelectAllChosen = false
local GearShopCache = {}
local autoBuyGearEnabled = false
local AUTO_BUY_GEAR_DELAY = 5

-- Brainrot favorite state
local AvailableBrainrots = {} -- list of {uuid, name, weight}
local SelectedBrainrots = {}
local BrainrotRowButtons = {}
local BrainrotCache = {}
local autoFavNewEnabled = false
local seenBrainrotUUIDs = {}
local autoConfirmSellEnabled = false

-- =============================================================================
-- GUI SETUP
-- =============================================================================
local parentGui = PlayerGui
pcall(function()
    if typeof(gethui) == "function" then parentGui = gethui() else parentGui = CoreGui end
end)
if not parentGui then parentGui = PlayerGui end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "CartoonAutomationDashboard"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = parentGui

local Frame = Instance.new("Frame")
Frame.Size = UDim2.new(0, 320, 0, 300)
Frame.Position = UDim2.new(0.5, -160, 0.5, -150)
Frame.BackgroundColor3 = Theme.Blue
Frame.BorderSizePixel = 4
Frame.BorderColor3 = Theme.Dark
Frame.Active = true
Frame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 18)
UICorner.Parent = Frame
-- premium border + subtle gradient
local FrameStroke = Instance.new("UIStroke")
FrameStroke.Color = Theme.Stroke
FrameStroke.Thickness = 1.5
FrameStroke.Transparency = 0.2
FrameStroke.Parent = Frame
local FrameGrad = Instance.new("UIGradient")
FrameGrad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Theme.Bg),
    ColorSequenceKeypoint.new(1, Theme.Surface)
}
FrameGrad.Rotation = 90
FrameGrad.Transparency = NumberSequence.new(0)
-- apply gradient via a background frame? Keep simple: skip gradient on main frame for perf


do -- custom touch + mouse drag
    local dragging = false
    local dragStart, startPos
    Frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = Frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            Frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 50)
Title.BackgroundColor3 = Theme.Pink
Title.BorderSizePixel = 0
Title.Text = "🌱 Plants Vs Brainrots"
Title.TextColor3 = Theme.White
Title.Font = Theme.FontTitle
Title.TextSize = 19
Title.Parent = Frame
-- pink to purple gradient for title bar
local TitleGrad = Instance.new("UIGradient")
TitleGrad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Theme.Pink),
    ColorSequenceKeypoint.new(1, Theme.Purple)
}
TitleGrad.Rotation = 15
TitleGrad.Parent = Title
-- subtle static glow (no animation to avoid perf issues)
local TitleGlow = Instance.new("UIStroke")
TitleGlow.Color = Theme.Pink
TitleGlow.Thickness = 2
TitleGlow.Transparency = 0.5
TitleGlow.Parent = Title
local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 20)
TitleCorner.Parent = Title
local TitleFix = Instance.new("Frame")
TitleFix.Size = UDim2.new(1, 0, 0, 20)
TitleFix.Position = UDim2.new(0, 0, 1, -20)
TitleFix.BackgroundColor3 = Theme.Pink
TitleFix.BorderSizePixel = 0
TitleFix.Parent = Title

local ToggleButton = Instance.new("TextButton")
ToggleButton.Size = UDim2.new(0, 35, 0, 35)
ToggleButton.Position = UDim2.new(1, -45, 0, 5)
ToggleButton.BackgroundColor3 = Theme.Red
ToggleButton.Text = "X"
ToggleButton.TextColor3 = Theme.White
ToggleButton.Font = Enum.Font.FredokaOne
ToggleButton.TextSize = 18
ToggleButton.Parent = Frame
local TCorner = Instance.new("UICorner")
TCorner.CornerRadius = UDim.new(0, 12)
TCorner.Parent = ToggleButton

local ScrollView = Instance.new("ScrollingFrame")
ScrollView.Size = UDim2.new(1, -20, 1, -65)
ScrollView.Position = UDim2.new(0, 10, 0, 55)
ScrollView.BackgroundTransparency = 1 -- keep transparent over dark bg
ScrollView.AutomaticCanvasSize = Enum.AutomaticSize.Y
ScrollView.CanvasSize = UDim2.new(0, 0, 0, 0)
ScrollView.ScrollBarThickness = 8
ScrollView.ScrollBarImageColor3 = Theme.ScrollBar
ScrollView.Parent = Frame

local Layout = Instance.new("UIListLayout")
Layout.Padding = UDim.new(0, 8)
Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.Parent = ScrollView

local function makeToonButton(text, btnColor, parent, layoutOrder)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 42)
    btn.BackgroundColor3 = btnColor
    btn.Text = text
    btn.TextColor3 = Theme.White
    btn.Font = Enum.Font.FredokaOne
    btn.TextSize = 14
    btn.BorderSizePixel = 0
    if layoutOrder then btn.LayoutOrder = layoutOrder end
    btn.Parent = parent
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 12) c.Parent = btn
    local stroke = Instance.new("UIStroke") stroke.Color = Theme.Dark stroke.Thickness = 1.2 stroke.Parent = btn
    return btn
end

-- (glow pulse removed for stability)

local function addCardShadow(frame)
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0,0,0)
    stroke.Transparency = 0.7
    stroke.Thickness = 2
    stroke.Parent = frame
end

-- =============================================================================
-- COMPONENT 1: SEEDS DROPDOWN (dynamic)
-- =============================================================================
local DropdownContainer = Instance.new("Frame")
DropdownContainer.Size = UDim2.new(1, 0, 0, 42)
DropdownContainer.BackgroundColor3 = Theme.Surface
DropdownContainer.BorderSizePixel = 0
DropdownContainer.ClipsDescendants = true
DropdownContainer.LayoutOrder = 1
DropdownContainer.Parent = ScrollView
local DCorn = Instance.new("UICorner") DCorn.CornerRadius = UDim.new(0, 12) DCorn.Parent = DropdownContainer

local DropdownHeader = Instance.new("TextButton")
DropdownHeader.Size = UDim2.new(1, 0, 0, 42)
DropdownHeader.BackgroundColor3 = Theme.Purple
DropdownHeader.Text = "🌱 SEED SHOP MENU (0)  ▼"
DropdownHeader.TextColor3 = Theme.White
DropdownHeader.Font = Enum.Font.FredokaOne
DropdownHeader.TextSize = 15
DropdownHeader.Parent = DropdownContainer

local DropdownScroll = Instance.new("ScrollingFrame")
DropdownScroll.Size = UDim2.new(1, 0, 0, 160)
DropdownScroll.Position = UDim2.new(0, 0, 0, 42)
DropdownScroll.BackgroundColor3 = Theme.ScrollBg
DropdownScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
DropdownScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
DropdownScroll.ScrollBarThickness = 6
DropdownScroll.Parent = DropdownContainer

local DropLayout = Instance.new("UIListLayout")
DropLayout.Padding = UDim.new(0, 3)
DropLayout.SortOrder = Enum.SortOrder.LayoutOrder
DropLayout.Parent = DropdownScroll

local UtilsBar = Instance.new("Frame")
UtilsBar.Size = UDim2.new(1, 0, 0, 35)
UtilsBar.BackgroundTransparency = 1
UtilsBar.LayoutOrder = 0
UtilsBar.Parent = DropdownScroll

local SelectAllBtn = Instance.new("TextButton")
SelectAllBtn.Size = UDim2.new(0.5, -4, 1, 0)
SelectAllBtn.BackgroundColor3 = Theme.LightGreen
SelectAllBtn.Text = "SELECT ALL"
SelectAllBtn.TextColor3 = Theme.White
SelectAllBtn.Font = Enum.Font.FredokaOne
SelectAllBtn.TextSize = 12
SelectAllBtn.Parent = UtilsBar
local SACorner = Instance.new("UICorner") SACorner.CornerRadius = UDim.new(0, 8) SACorner.Parent = SelectAllBtn

local ClearAllBtn = Instance.new("TextButton")
ClearAllBtn.Size = UDim2.new(0.5, -4, 1, 0)
ClearAllBtn.Position = UDim2.new(0.5, 4, 0, 0)
ClearAllBtn.BackgroundColor3 = Theme.Red
ClearAllBtn.Text = "CLEAR ALL"
ClearAllBtn.TextColor3 = Theme.White
ClearAllBtn.Font = Enum.Font.FredokaOne
ClearAllBtn.TextSize = 12
ClearAllBtn.Parent = UtilsBar
local CACorner = Instance.new("UICorner") CACorner.CornerRadius = UDim.new(0, 8) CACorner.Parent = ClearAllBtn

local DEBUG_STOCK = false -- set true to print shop structure in F9 console
local ShopCache = {}

local function getShopUI()
    if ShopCache.ui and ShopCache.ui.Parent then return ShopCache.ui end
    -- Priority 1: find seeds shop via "restock" text (visible in your screenshot: "New seeds restock In")
    pcall(function()
        for _, desc in ipairs(PlayerGui:GetDescendants()) do
            if desc:IsA("TextLabel") and not desc:IsDescendantOf(ScreenGui) then
                local t = (desc.Text or ""):lower()
                if t:find("seeds restock") or t:find("seed.*restock") then
                    -- climb to ScreenGui or large container
                    local p = desc.Parent
                    while p and p ~= PlayerGui do
                        if p:IsA("ScreenGui") then
                            ShopCache.ui = p
                            print("[Dashboard] ShopUI found via restock label:", p:GetFullName())
                            return
                        end
                        -- if it's a big frame with lots of children, likely the shop window
                        if p:IsA("Frame") and #p:GetDescendants() > 20 then
                            ShopCache.ui = p
                            print("[Dashboard] ShopUI found via restock container:", p:GetFullName())
                            return
                        end
                        p = p.Parent
                    end
                end
            end
        end
    end)
    if ShopCache.ui then return ShopCache.ui end
    local candidates = {}
    if MainGui then
        table.insert(candidates, MainGui:FindFirstChild("Shop"))
        table.insert(candidates, MainGui:FindFirstChild("Seeds"))
        table.insert(candidates, MainGui:FindFirstChild("SeedShop"))
        pcall(function()
            for _, d in ipairs(MainGui:GetDescendants()) do
                if d:IsA("GuiObject") and d.Name:lower():find("shop") and #d:GetDescendants() > 5 then
                    table.insert(candidates, d)
                    break
                end
            end
        end)
    end
    pcall(function()
        for _, child in ipairs(PlayerGui:GetChildren()) do
            if child:IsA("GuiObject") and child.Name:lower():find("shop") then
                table.insert(candidates, child)
            end
        end
    end)
    for _, ui in ipairs(candidates) do
        if ui then
            ShopCache.ui = ui
            print("[Dashboard] ShopUI found:", ui:GetFullName())
            return ui
        end
    end
    -- last resort: search entire PlayerGui for any [xN] stock labels and use their ancestor
    pcall(function()
        for _, desc in ipairs(PlayerGui:GetDescendants()) do
            if desc:IsA("TextLabel") and not desc:IsDescendantOf(ScreenGui) then
                local txt = desc.Text or ""
                if txt:match("%[[xX]%d+%]") then
                    local p = desc.Parent
                    for _ = 1, 5 do
                        if not p then break end
                        if p:IsA("ScreenGui") then
                            ShopCache.ui = p
                            print("[Dashboard] ShopUI found via [xN] label:", p:GetFullName())
                            return
                        end
                        p = p.Parent
                    end
                end
            end
        end
    end)
    if ShopCache.ui then return ShopCache.ui end
    ShopCache.ui = MainGui
    return ShopCache.ui
end

-- Generic shop scanner: finds any item with [xN] stock label (like your screenshot shows)
local function discoverShopItems()
    local shopUI = getShopUI()
    if not shopUI then return {} end
    local items, seen = {}, {}
    pcall(function()
        for _, desc in ipairs(shopUI:GetDescendants()) do
            if desc:IsA("TextLabel") and not desc:IsDescendantOf(ScreenGui) then
                local txt = desc.Text or ""
                -- match [x23], [x4], x9  (case-insensitive)
                local stockNum = txt:match("%[[xX](%d+)%]") or txt:match("^[xX](%d+)$") or txt:match("%s[xX](%d+)%s*$")
                if stockNum then
                    local container = desc.Parent
                    -- climb up to find item name
                    for _ = 1, 4 do
                        if not container or container == shopUI then break end
                        local bestName, bestLen = nil, 0
                        for _, sib in ipairs(container:GetDescendants()) do
                            if sib:IsA("TextLabel") and sib ~= desc and not sib:IsDescendantOf(ScreenGui) then
                                local t = (sib.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
                                -- skip stock labels, prices, empty
                                if #t > 2 and not t:match("%[[xX]%d+%]") and not t:match("%$") and not t:lower():find("stock") and #t < 60 then
                                    if #t > bestLen then bestName, bestLen = t, #t end
                                end
                            end
                        end
                        -- also try container name itself
                        if not bestName and container.Name and #container.Name > 2 and not container.Name:lower():find("frame") and not container.Name:lower():find("scroll") then
                            bestName = container.Name
                        end
                        if bestName and not seen[bestName] then
                            seen[bestName] = true
                            table.insert(items, {name = bestName, stock = tonumber(stockNum), frame = container, stockLabel = desc})
                            break
                        end
                        container = container.Parent
                    end
                end
            end
        end
    end)
    return items
end

local function discoverSeeds()
    local shopUI = getShopUI()
    if not shopUI then return DEFAULT_SEEDS end
    local seen, found = {}, {}
    pcall(function()
        for _, desc in ipairs(shopUI:GetDescendants()) do
            if desc:IsDescendantOf(ScreenGui) then continue end
            if desc:IsA("GuiObject") then
                local n = desc.Name
                if type(n) == "string" and n:match(" Seed$") and not seen[n] then
                    seen[n] = true
                    table.insert(found, n)
                end
            end
            if desc:IsA("TextLabel") then
                local t = desc.Text
                if type(t) == "string" and t:match(" Seed$") and not seen[t] then
                    seen[t] = true
                    table.insert(found, t)
                end
            end
        end
    end)
    if #found > 0 then
        table.sort(found)
        print("[Dashboard] Discovered " .. #found .. " seeds by name")
        return found
    end
    -- fallback 2: use generic shop items (your screenshot shows [x23] style)
    local shopItems = discoverShopItems()
    if #shopItems > 0 then
        local names = {}
        for _, it in ipairs(shopItems) do table.insert(names, it.name) end
        table.sort(names)
        print("[Dashboard] Discovered " .. #names .. " shop items via stock labels")
        -- cache frames/stocks for fast lookup
        for _, it in ipairs(shopItems) do
            ShopCache[it.name] = it.frame
            ShopCache["__stock_" .. it.name] = it.stock
            -- also keep label ref for live updates
            ShopCache["__label_" .. it.name] = it.stockLabel
        end
        return names
    end
    warn("[Dashboard] Seed discovery failed, using fallback list")
    return DEFAULT_SEEDS
end

local function extractNumber(text)
    if type(text) ~= "string" then return nil end
    -- try stock-specific patterns first
    local n = text:match("[Ss]tock%s*[:x]?%s*(%d+)")
        or text:match("(%d+)%s*[Ss]tock")
        or text:match("x%s*(%d+)")
        or text:match("(%d+)%s*x")
        or text:match("%[(%d+)%]")
        or text:match("(%d+)")
    return n and tonumber(n) or nil
end

local function findStockInSingleFrame(frame)
    if not frame then return nil end
    -- 1) attributes
    for _, attrName in ipairs({"Stock","Amount","Quantity","Count","Available","StockAmount"}) do
        local ok, val = pcall(function() return frame:GetAttribute(attrName) end)
        if ok and val and tonumber(val) then return tonumber(val) end
    end
    -- 2) direct well-named children
    for _, childName in ipairs({"Stock","Amount","Quantity","Count","StockLabel","AmountLabel","StockText","Qty"}) do
        local lbl = frame:FindFirstChild(childName)
        if lbl then
            if lbl:IsA("TextLabel") then
                local n = extractNumber(lbl.Text)
                if n then return n end
            elseif lbl:IsA("IntValue") or lbl:IsA("NumberValue") then
                return tonumber(lbl.Value)
            end
        end
    end
    -- 3) deep scan: any TextLabel whose name or text mentions stock
    for _, desc in ipairs(frame:GetDescendants()) do
        if desc:IsA("TextLabel") then
            local lname = desc.Name:lower()
            local ltext = (desc.Text or ""):lower()
            if lname:find("stock") or lname:find("amount") or lname:find("qty") or ltext:find("stock") then
                local n = extractNumber(desc.Text)
                if n then return n end
            end
        end
    end
    -- 4) fallback: look for a small standalone number label (e.g. "5") that isn't a price
    -- skip anything with $/coins/R$ to avoid grabbing price instead of stock
    for _, desc in ipairs(frame:GetDescendants()) do
        if desc:IsA("TextLabel") then
            local txt = desc.Text or ""
            if not txt:find("%$") and not txt:lower():find("coin") and not txt:lower():find("price") then
                if txt:match("^%s*%d+%s*$") then
                    local n = tonumber(txt:match("%d+"))
                    -- heuristic: stock is usually small (0-99), price is larger; prefer small numbers
                    if n and n <= 999 then return n end
                end
            end
        end
    end
    return nil
end

local function findSeedFrame(shopUI, seedName)
    if not shopUI then return nil end
    -- try exact, then case-insensitive, then without " Seed", then TextLabel text match
    local frame = shopUI:FindFirstChild(seedName, true)
    if frame then return frame end
    local lowerWanted = seedName:lower()
    for _, desc in ipairs(shopUI:GetDescendants()) do
        if desc:IsA("GuiObject") and not desc:IsDescendantOf(ScreenGui) then
            if desc.Name:lower() == lowerWanted then return desc end
            if desc:IsA("TextLabel") and desc.Text:lower() == lowerWanted then
                -- return the parent container, which likely holds the stock label
                return desc.Parent
            end
        end
    end
    -- try base name without " Seed" (some shops name frames "Cactus")
    local base = seedName:gsub(" Seed$", "")
    frame = shopUI:FindFirstChild(base, true)
    if frame then return frame end
    return nil
end

local function getSeedStock(seedName)
    -- 1) live label cache from discoverShopItems (most accurate, matches screenshot [x23])
    local cachedLabel = ShopCache["__label_" .. seedName]
    if cachedLabel and cachedLabel.Parent then
        local ok, n = pcall(function() return extractNumber(cachedLabel.Text) end)
        if ok and n then
            ShopCache["__stock_" .. seedName] = n
            return n
        end
    end
    local cachedStock = ShopCache["__stock_" .. seedName]
    -- don't return cached stock immediately, try live frame first for freshness
    -- but keep it as fallback

    local shopUI = getShopUI()
    if not shopUI then return cachedStock end
    local seedFrame = ShopCache[seedName]
    if not seedFrame or not seedFrame.Parent then
        seedFrame = findSeedFrame(shopUI, seedName)
        ShopCache[seedName] = seedFrame
        if DEBUG_STOCK and not seedFrame then
            warn("[Dashboard] No frame found for seed: " .. seedName)
        end
    end
    if seedFrame then
        local stock = findStockInSingleFrame(seedFrame)
        if stock then
            ShopCache["__stock_" .. seedName] = stock
            return stock
        end
        if seedFrame.Parent and seedFrame.Parent ~= shopUI then
            stock = findStockInSingleFrame(seedFrame.Parent)
            if stock then
                ShopCache["__stock_" .. seedName] = stock
                return stock
            end
        end
        if DEBUG_STOCK then
            warn("[Dashboard] No stock found for: " .. seedName .. " in " .. seedFrame:GetFullName())
            for _, d in ipairs(seedFrame:GetDescendants()) do
                if d:IsA("TextLabel") then
                    print("  label", d.Name, "=", d.Text)
                end
            end
        end
    end
    return cachedStock -- nil = unknown, shows as ? in UI
end

-- ================= GEAR SHOP HELPERS =================
local function getGearShopUI()
    if GearShopCache.ui and GearShopCache.ui.Parent then return GearShopCache.ui end
    pcall(function()
        for _, desc in ipairs(PlayerGui:GetDescendants()) do
            if desc:IsA("TextLabel") and not desc:IsDescendantOf(ScreenGui) then
                local t = (desc.Text or ""):lower()
                if t:find("gears restock") or t:find("gear.*restock") then
                    local p = desc.Parent
                    while p and p ~= PlayerGui do
                        if p:IsA("ScreenGui") then
                            GearShopCache.ui = p
                            print("[Dashboard] GearShopUI found via restock label:", p:GetFullName())
                            return
                        end
                        if p:IsA("Frame") and #p:GetDescendants() > 20 then
                            GearShopCache.ui = p
                            print("[Dashboard] GearShopUI found via restock container:", p:GetFullName())
                            return
                        end
                        p = p.Parent
                    end
                end
            end
        end
    end)
    if GearShopCache.ui then return GearShopCache.ui end
    -- fallback: same as seed shop but look for gear-like names
    return getShopUI()
end

local function discoverGears()
    local gearUI = getGearShopUI()
    if not gearUI then return DEFAULT_GEARS end
    local seen, items = {}, {}
    pcall(function()
        for _, desc in ipairs(gearUI:GetDescendants()) do
            if desc:IsDescendantOf(ScreenGui) then continue end
            if desc:IsA("TextLabel") then
                local low = (desc.Text or ""):lower()
                -- gear stock looks like "x2 in stock", "x0 in stock" (see your screenshots)
                if low:match("x%d+ in stock") then
                    local container = desc.Parent
                    for _ = 1, 4 do
                        if not container or container == gearUI then break end
                        local bestName, bestLen = nil, 0
                        for _, sib in ipairs(container:GetDescendants()) do
                            if sib:IsA("TextLabel") and sib ~= desc and not sib:IsDescendantOf(ScreenGui) then
                                local t = (sib.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
                                local lt = t:lower()
                                if #t > 2 and #t < 40 and not lt:find("in stock") and not t:find("%$") and not lt:find("damage") and not lt:find("throw") and not lt:find("shoot") and not lt:find("place down") and not lt:find("supercharge") and not lt:find("your inventory") and not lt:find("you bought") and not lt:find("restock") then
                                    if #t > bestLen then bestName, bestLen = t, #t end
                                end
                            end
                        end
                        if bestName and not seen[bestName] then
                            seen[bestName] = true
                            table.insert(items, {name = bestName, frame = container, stockLabel = desc})
                            break
                        end
                        container = container.Parent
                    end
                end
            end
        end
    end)
    if #items > 0 then
        local names = {}
        for _, it in ipairs(items) do
            table.insert(names, it.name)
            GearShopCache[it.name] = it.frame
            GearShopCache["__label_" .. it.name] = it.stockLabel
            local n = extractNumber(it.stockLabel.Text)
            if n then GearShopCache["__stock_" .. it.name] = n end
        end
        table.sort(names)
        print("[Dashboard] Discovered " .. #names .. " gears")
        return names
    end
    warn("[Dashboard] Gear discovery failed, using fallback")
    return DEFAULT_GEARS
end

local function getGearStock(gearName)
    local cachedLabel = GearShopCache["__label_" .. gearName]
    if cachedLabel and cachedLabel.Parent then
        local ok, n = pcall(function() return extractNumber(cachedLabel.Text) end)
        if ok and n then
            GearShopCache["__stock_" .. gearName] = n
            return n
        end
    end
    local cachedStock = GearShopCache["__stock_" .. gearName]
    local gearUI = getGearShopUI()
    if not gearUI then return cachedStock end
    local frame = GearShopCache[gearName]
    if not frame or not frame.Parent then
        -- try find by name
        pcall(function()
            frame = gearUI:FindFirstChild(gearName, true)
        end)
        GearShopCache[gearName] = frame
    end
    if frame then
        local stock = findStockInSingleFrame(frame)
        if stock then
            GearShopCache["__stock_" .. gearName] = stock
            return stock
        end
        if frame.Parent and frame.Parent ~= gearUI then
            stock = findStockInSingleFrame(frame.Parent)
            if stock then
                GearShopCache["__stock_" .. gearName] = stock
                return stock
            end
        end
    end
    return cachedStock
end

local RowButtons = {}
local function updateHeaderLabel()
    local count = 0
    for _, s in pairs(SelectedSeeds) do if s then count += 1 end end
    DropdownHeader.Text = "🌱 SEED SHOP MENU (" .. tostring(count) .. ")  ▼"
end

local function updateRow(seedName)
    local row = RowButtons[seedName]
    if not row then return end
    local stock = getSeedStock(seedName)
    local stockText = (stock == nil) and "?" or tostring(stock)
    if SelectedSeeds[seedName] then
        row.Text = "   ⭐  " .. seedName .. "  [Stock: " .. stockText .. "]"
        row.TextColor3 = Theme.StarOrange
        row.BackgroundColor3 = Theme.StarBg
    else
        row.Text = "   ❌  " .. seedName .. "  [Stock: " .. stockText .. "]"
        row.TextColor3 = Theme.GrayText
        row.BackgroundColor3 = Theme.White
    end
end

local function refreshAllRows()
    for _, seedName in ipairs(AvailableSeeds) do updateRow(seedName) end
    updateHeaderLabel()
end

local function clearSeedRows()
    for _, row in pairs(RowButtons) do pcall(function() row:Destroy() end) end
    table.clear(RowButtons)
    table.clear(SelectedSeeds)
    table.clear(ShopCache)
    ShopCache.ui = nil
end

local function buildSeedRows()
    clearSeedRows()
    AvailableSeeds = discoverSeeds()
    for i, seedName in ipairs(AvailableSeeds) do
        SelectedSeeds[seedName] = false
        local Row = Instance.new("TextButton")
        Row.Size = UDim2.new(1, 0, 0, 38)
        Row.BackgroundColor3 = Theme.White
        Row.TextColor3 = Theme.GrayText
        Row.Font = Enum.Font.FredokaOne
        Row.TextSize = 13
        Row.TextXAlignment = Enum.TextXAlignment.Left
        Row.LayoutOrder = i + 1
        Row.Parent = DropdownScroll
        local _s = getSeedStock(seedName)
        Row.Text = "   ❌  " .. seedName .. "  [Stock: " .. ((_s == nil) and "?" or tostring(_s)) .. "]"
        Row.MouseButton1Click:Connect(function()
            SelectedSeeds[seedName] = not SelectedSeeds[seedName]
            WasSelectAllChosen = false
            updateRow(seedName)
            updateHeaderLabel()
        end)
        RowButtons[seedName] = Row
    end
    WasSelectAllChosen = false
    refreshAllRows()
end

-- initial build (dynamic)
buildSeedRows()

SelectAllBtn.MouseButton1Click:Connect(function()
    WasSelectAllChosen = true
    for _, s in ipairs(AvailableSeeds) do SelectedSeeds[s] = true end
    refreshAllRows()
end)
ClearAllBtn.MouseButton1Click:Connect(function()
    WasSelectAllChosen = false
    for _, s in ipairs(AvailableSeeds) do SelectedSeeds[s] = false end
    refreshAllRows()
end)

local dropdownOpen = false
DropdownHeader.MouseButton1Click:Connect(function()
    dropdownOpen = not dropdownOpen
    local targetSize = dropdownOpen and UDim2.new(1, 0, 0, 205) or UDim2.new(1, 0, 0, 42)
    TweenService:Create(DropdownContainer, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = targetSize}):Play()
end)

-- =============================================================================
-- COMPONENT 1b: GEAR DROPDOWN (scrollable, select all)
-- =============================================================================
local GearDropdownContainer = Instance.new("Frame")
GearDropdownContainer.Size = UDim2.new(1, 0, 0, 42)
GearDropdownContainer.BackgroundColor3 = Theme.Surface
GearDropdownContainer.BorderSizePixel = 0
GearDropdownContainer.ClipsDescendants = true
GearDropdownContainer.LayoutOrder = 4
GearDropdownContainer.Parent = ScrollView
local GDCorn = Instance.new("UICorner") GDCorn.CornerRadius = UDim.new(0, 12) GDCorn.Parent = GearDropdownContainer

local GearDropdownHeader = Instance.new("TextButton")
GearDropdownHeader.Size = UDim2.new(1, 0, 0, 42)
GearDropdownHeader.BackgroundColor3 = Theme.Orange
GearDropdownHeader.Text = "⚙️ GEAR SHOP MENU (0)  ▼"
GearDropdownHeader.TextColor3 = Theme.White
GearDropdownHeader.Font = Enum.Font.FredokaOne
GearDropdownHeader.TextSize = 15
GearDropdownHeader.Parent = GearDropdownContainer

local GearDropdownScroll = Instance.new("ScrollingFrame")
GearDropdownScroll.Size = UDim2.new(1, 0, 0, 160)
GearDropdownScroll.Position = UDim2.new(0, 0, 0, 42)
GearDropdownScroll.BackgroundColor3 = Theme.ScrollBg
GearDropdownScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
GearDropdownScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
GearDropdownScroll.ScrollBarThickness = 6
GearDropdownScroll.Parent = GearDropdownContainer

local GearDropLayout = Instance.new("UIListLayout")
GearDropLayout.Padding = UDim.new(0, 3)
GearDropLayout.SortOrder = Enum.SortOrder.LayoutOrder
GearDropLayout.Parent = GearDropdownScroll

local GearUtilsBar = Instance.new("Frame")
GearUtilsBar.Size = UDim2.new(1, 0, 0, 35)
GearUtilsBar.BackgroundTransparency = 1
GearUtilsBar.LayoutOrder = 0
GearUtilsBar.Parent = GearDropdownScroll

local GearSelectAllBtn = Instance.new("TextButton")
GearSelectAllBtn.Size = UDim2.new(0.5, -4, 1, 0)
GearSelectAllBtn.BackgroundColor3 = Theme.LightGreen
GearSelectAllBtn.Text = "SELECT ALL"
GearSelectAllBtn.TextColor3 = Theme.White
GearSelectAllBtn.Font = Enum.Font.FredokaOne
GearSelectAllBtn.TextSize = 12
GearSelectAllBtn.Parent = GearUtilsBar
local GSACorner = Instance.new("UICorner") GSACorner.CornerRadius = UDim.new(0, 8) GSACorner.Parent = GearSelectAllBtn

local GearClearAllBtn = Instance.new("TextButton")
GearClearAllBtn.Size = UDim2.new(0.5, -4, 1, 0)
GearClearAllBtn.Position = UDim2.new(0.5, 4, 0, 0)
GearClearAllBtn.BackgroundColor3 = Theme.Red
GearClearAllBtn.Text = "CLEAR ALL"
GearClearAllBtn.TextColor3 = Theme.White
GearClearAllBtn.Font = Enum.Font.FredokaOne
GearClearAllBtn.TextSize = 12
GearClearAllBtn.Parent = GearUtilsBar
local GCACorner = Instance.new("UICorner") GCACorner.CornerRadius = UDim.new(0, 8) GCACorner.Parent = GearClearAllBtn

local GearRowButtons = {}

local function updateGearHeader()
    local count = 0
    for _, s in pairs(SelectedGears) do if s then count += 1 end end
    GearDropdownHeader.Text = "⚙️ GEAR SHOP MENU (" .. tostring(count) .. ")  ▼"
end

local function updateGearRow(gearName)
    local row = GearRowButtons[gearName]
    if not row then return end
    local stock = getGearStock(gearName)
    local stockText = (stock == nil) and "?" or tostring(stock)
    if SelectedGears[gearName] then
        row.Text = "   ⭐  " .. gearName .. "  [Stock: " .. stockText .. "]"
        row.TextColor3 = Theme.StarOrange
        row.BackgroundColor3 = Theme.StarBg
    else
        row.Text = "   ❌  " .. gearName .. "  [Stock: " .. stockText .. "]"
        row.TextColor3 = Theme.GrayText
        row.BackgroundColor3 = Theme.White
    end
end

local function refreshGearRows()
    for _, n in ipairs(AvailableGears) do updateGearRow(n) end
    updateGearHeader()
end

local function clearGearRows()
    for _, row in pairs(GearRowButtons) do pcall(function() row:Destroy() end) end
    table.clear(GearRowButtons)
    table.clear(SelectedGears)
    table.clear(GearShopCache)
    GearShopCache.ui = nil
end

local function buildGearRows()
    clearGearRows()
    AvailableGears = discoverGears()
    for i, gearName in ipairs(AvailableGears) do
        SelectedGears[gearName] = false
        local Row = Instance.new("TextButton")
        Row.Size = UDim2.new(1, 0, 0, 38)
        Row.BackgroundColor3 = Theme.White
        Row.TextColor3 = Theme.GrayText
        Row.Font = Enum.Font.FredokaOne
        Row.TextSize = 13
        Row.TextXAlignment = Enum.TextXAlignment.Left
        Row.LayoutOrder = i + 1
        Row.Parent = GearDropdownScroll
        local _s = getGearStock(gearName)
        Row.Text = "   ❌  " .. gearName .. "  [Stock: " .. ((_s == nil) and "?" or tostring(_s)) .. "]"
        Row.MouseButton1Click:Connect(function()
            SelectedGears[gearName] = not SelectedGears[gearName]
            WasGearSelectAllChosen = false
            updateGearRow(gearName)
            updateGearHeader()
        end)
        GearRowButtons[gearName] = Row
    end
    WasGearSelectAllChosen = false
    refreshGearRows()
end

buildGearRows()

GearSelectAllBtn.MouseButton1Click:Connect(function()
    WasGearSelectAllChosen = true
    for _, n in ipairs(AvailableGears) do SelectedGears[n] = true end
    refreshGearRows()
end)
GearClearAllBtn.MouseButton1Click:Connect(function()
    WasGearSelectAllChosen = false
    for _, n in ipairs(AvailableGears) do SelectedGears[n] = false end
    refreshGearRows()
end)

local gearDropdownOpen = false
GearDropdownHeader.MouseButton1Click:Connect(function()
    gearDropdownOpen = not gearDropdownOpen
    local targetSize = gearDropdownOpen and UDim2.new(1, 0, 0, 205) or UDim2.new(1, 0, 0, 42)
    TweenService:Create(GearDropdownContainer, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = targetSize}):Play()
end)

-- =============================================================================
-- COMPONENT 2: ACTION HUB
-- =============================================================================
local function setBusy(k, v) Busy[k] = v end
local function isBusy(k) return Busy[k] == true end

-- Auto-refresh both shops every 30s (replaces manual refresh buttons)
task.spawn(function()
    while true do
        task.wait(30)
        pcall(function()
            refreshAllRows()
            refreshGearRows()
        end)
    end
end)

local function doBuyOnce(isAuto)
    local boughtAny = false
    fireSignalSafe(RestockRemote, "Seeds")
    task.wait(0.2)
    for seedName, isSelected in pairs(SelectedSeeds) do
        if isSelected then
            local stock = getSeedStock(seedName)
            -- skip out-of-stock entirely to avoid fake notification spam
            if stock ~= nil and stock <= 0 then
                -- print("[Dashboard] Skipping " .. seedName .. " - out of stock")
            elseif isAuto and stock == nil then
                -- in auto mode, don't guess when stock is unknown (?), prevents spam
            else
                local purchaseCount = 1
                if WasSelectAllChosen then
                    if stock then
                        purchaseCount = math.clamp(stock, 1, 10)
                    else
                        purchaseCount = 1
                    end
                end
                if purchaseCount > 0 then
                    boughtAny = true
                    print("[Dashboard] Purchasing " .. seedName .. " x" .. tostring(purchaseCount))
                    for _ = 1, purchaseCount do
                        if isAuto and not autoBuyEnabled then return boughtAny end
                        fireSignalSafe(BuyItemRemote, seedName)
                        task.wait(0.05)
                        fireServerSafe(BuyItemRemote, seedName, true)
                        task.wait(0.1)
                    end
                end
            end
        end
    end
    task.wait(0.1)
    fireSignalSafe(UpdatePlantStocksRemote)
    refreshAllRows()
    return boughtAny
end


local AutoBuyBtn = makeToonButton("🔁 AUTO-BUY: OFF", Theme.Purple, ScrollView, 3)
AutoBuyBtn.MouseButton1Click:Connect(function()
    autoBuyEnabled = not autoBuyEnabled
    if autoBuyEnabled then
        AutoBuyBtn.Text = "🔁 AUTO-BUY: ON (" .. tostring(AUTO_BUY_DELAY) .. "s)"
        AutoBuyBtn.BackgroundColor3 = Theme.LightGreen
        task.spawn(function()
            while autoBuyEnabled do
                if not isBusy("buySeeds") then
                    setBusy("buySeeds", true)
                    local ok, err = pcall(function() doBuyOnce(true) end)
                    if not ok then warn("[AutoBuy] " .. tostring(err)) end
                    setBusy("buySeeds", false)
                end
                -- interruptible wait
                for _ = 1, AUTO_BUY_DELAY * 10 do
                    if not autoBuyEnabled then break end
                    task.wait(0.1)
                end
            end
        end)
    else
        AutoBuyBtn.Text = "🔁 AUTO-BUY: OFF"
        AutoBuyBtn.BackgroundColor3 = Theme.Purple
    end
end)

local function doBuyGearOnce(isAuto)
    local boughtAny = false
    fireSignalSafe(RestockRemote, "Gears")
    task.wait(0.15)
    for gearName, isSelected in pairs(SelectedGears) do
        if isSelected then
            local stock = getGearStock(gearName)
            if stock ~= nil and stock <= 0 then
                -- out of stock, skip to avoid spam
            elseif isAuto and stock == nil then
                -- skip unknown in auto to avoid spam
            else
                boughtAny = true
                print("[Dashboard] Buying gear: " .. gearName .. (stock and (" x" .. tostring(math.clamp(stock,1,5))) or ""))
                -- buy up to stock count, capped at 5 to avoid spam-kick
                local count = 1
                if stock then count = math.clamp(stock, 1, 5) end
                for _ = 1, count do
                    if isAuto and not autoBuyGearEnabled then return boughtAny end
                    fireSignalSafe(BuyGearRemote, gearName)
                    task.wait(0.05)
                    -- BuyGear remote per your provided path: ReplicatedStorage.Remotes.BuyGear
                    -- some games want FireServer(gearName), some want FireServer(gearName, true)
                    fireServerSafe(BuyGearRemote, gearName)
                    task.wait(0.1)
                end
            end
        end
    end
    task.wait(0.1)
    fireSignalSafe(UpdateGearStocksRemote)
    refreshGearRows()
    return boughtAny
end


local AutoBuyGearBtn = makeToonButton("🔁 AUTO-BUY GEAR: OFF", Theme.Purple, ScrollView, 6)
AutoBuyGearBtn.MouseButton1Click:Connect(function()
    autoBuyGearEnabled = not autoBuyGearEnabled
    if autoBuyGearEnabled then
        AutoBuyGearBtn.Text = "🔁 AUTO-BUY GEAR: ON (" .. tostring(AUTO_BUY_GEAR_DELAY) .. "s)"
        AutoBuyGearBtn.BackgroundColor3 = Theme.LightGreen
        task.spawn(function()
            while autoBuyGearEnabled do
                if not isBusy("buyGear") then
                    setBusy("buyGear", true)
                    local ok, err = pcall(function() doBuyGearOnce(true) end)
                    if not ok then warn("[AutoBuyGear] " .. tostring(err)) end
                    setBusy("buyGear", false)
                end
                for _ = 1, AUTO_BUY_GEAR_DELAY * 10 do
                    if not autoBuyGearEnabled then break end
                    task.wait(0.1)
                end
            end
        end)
    else
        AutoBuyGearBtn.Text = "🔁 AUTO-BUY GEAR: OFF"
        AutoBuyGearBtn.BackgroundColor3 = Theme.Purple
    end
end)

local autoSellEnabled = false
local SellWeightThreshold = 75 -- shared, updated by WeightBox
local AutoSellBtn = makeToonButton("💰 AUTO SELL: OFF", Theme.Yellow, ScrollView, 7)
AutoSellBtn.MouseButton1Click:Connect(function()
    autoSellEnabled = not autoSellEnabled
    if autoSellEnabled then
        AutoSellBtn.Text = "💰 AUTO SELL: ON (5s)"
        AutoSellBtn.BackgroundColor3 = Theme.LightGreen
        -- auto-enable confirm so sales go through
        if not autoConfirmSellEnabled then
            autoConfirmSellEnabled = true
            AutoConfirmBtn.Text = "✅ AUTO CONFIRM SELL: ON"
            AutoConfirmBtn.BackgroundColor3 = Theme.LightGreen
        end
        print("[Dashboard] Auto-sell enabled every 5s with weight protection")
        task.spawn(function()
            while autoSellEnabled do
                -- 1. Scan inventory and protect brainrots above weight threshold
                local threshold = SellWeightThreshold
                local ok, latest = pcall(discoverBrainrots)
                if ok and latest then
                    for _, b in ipairs(latest) do
                        if b.weight and b.weight >= threshold then
                            pcall(function() favoriteBrainrot(b.uuid) end)
                        end
                    end
                end
                task.wait(0.5) -- let favorites register
                -- 2. Sell - full sequence for all rarities
                if not isBusy("sell") then
                    setBusy("sell", true)
                    pcall(function()
                        fireSignalSafe(NPCRemote, "Barry", { Type = "Sell" })
                        task.wait(0.3)
                        -- Proactively confirm all rarities (Secret/Boss/Limited/Forbidden/Godly first)
                        for _, rarity in ipairs({"Secret", "Boss", "Limited", "Forbidden", "Godly", "Mythic", "Legendary", "Epic", "Rare", "Common"}) do
                            fireServerSafe(ConfirmSellRemote, "Brainrot", rarity, true, true)
                            task.wait(0.08)
                        end
                        task.wait(0.2)
                        fireServerSafe(ItemSellRemote)
                        print("[Dashboard] Auto-sell cycle completed")
                    end)
                    setBusy("sell", false)
                end
                -- interruptible 5s wait
                for _ = 1, 50 do
                    if not autoSellEnabled then break end
                    task.wait(0.1)
                end
            end
        end)
    else
        AutoSellBtn.Text = "💰 AUTO SELL: OFF"
        AutoSellBtn.BackgroundColor3 = Theme.Yellow
        print("[Dashboard] Auto-sell disabled")
    end
end)

local AutoConfirmBtn = makeToonButton("✅ AUTO CONFIRM SELL: OFF", Theme.Purple, ScrollView, 8)
AutoConfirmBtn.MouseButton1Click:Connect(function()
    autoConfirmSellEnabled = not autoConfirmSellEnabled
    if autoConfirmSellEnabled then
        AutoConfirmBtn.Text = "✅ AUTO CONFIRM SELL: ON"
        AutoConfirmBtn.BackgroundColor3 = Theme.LightGreen
        print("[Dashboard] Auto-confirm sell enabled for Limited/Boss/Secret")
    else
        AutoConfirmBtn.Text = "✅ AUTO CONFIRM SELL: OFF"
        AutoConfirmBtn.BackgroundColor3 = Theme.Purple
        print("[Dashboard] Auto-confirm sell disabled")
    end
end)

-- Auto-confirm listener: watches for server sell prompts and instantly confirms
pcall(function()
    if ConfirmSellRemote and ConfirmSellRemote.OnClientEvent then
        ConfirmSellRemote.OnClientEvent:Connect(function(...)
            if not autoConfirmSellEnabled then return end
            local args = {...}
            local kind = args[1]
            local rarity = args[2]
            if kind == "Brainrot" and type(rarity) == "string" then
                print("[Dashboard] Auto-confirming " .. tostring(rarity))
                task.wait(0.15)
                pcall(function()
                    ConfirmSellRemote:FireServer("Brainrot", rarity, true, true)
                end)
            end
        end)
        print("[Dashboard] Auto-confirm ready")
    end
end)

-- GUI watcher for sell confirm dialog (Yes/No popup)
task.spawn(function()
    while true do
        task.wait(0.4)
        if autoConfirmSellEnabled then
            pcall(function()
                for _, desc in ipairs(PlayerGui:GetDescendants()) do
                    if desc:IsA("TextLabel") then
                        local txt = string.lower(desc.Text or "")
                        if string.find(txt, "sell your brainrot") then
                            local rarity = string.match(desc.Text or "", '"([^"]+)"')
                            if rarity then
                                print("[Dashboard] Sell dialog: " .. rarity)
                                if rarity == "Secret" or rarity == "Boss" or rarity == "Limited" or rarity == "Forbidden" or rarity == "Godly" then
                                    if typeof(firesignal) == "function" and ConfirmSellRemote and ConfirmSellRemote.OnClientEvent then
                                        pcall(function()
                                            firesignal(ConfirmSellRemote.OnClientEvent, "Brainrot", rarity, true)
                                        end)
                                        task.wait(0.05)
                                    end
                                end
                                pcall(function()
                                    ConfirmSellRemote:FireServer("Brainrot", rarity, true, true)
                                end)
                                -- Try to click Yes button in same dialog
                                local parent = desc.Parent
                                if parent then
                                    for _, b in ipairs(parent:GetDescendants()) do
                                        if b:IsA("TextButton") and string.lower(b.Text or "") == "yes" and b.Visible then
                                            pcall(function()
                                                if firesignal then firesignal(b.MouseButton1Click) end
                                            end)
                                            break
                                        end
                                    end
                                end
                            end
                            break
                        end
                    end
                end
            end)
        end
    end
end)

-- ================= BRAINROT FAVORITE (improved) =================
local function isUUID(str)
    return type(str) == "string" and str:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") ~= nil
end

-- Load valid brainrot names from your path: ReplicatedStorage.CmdrClient.Types.BrainrotName
local ValidBrainrotNames = {}
pcall(function()
    local cmdr = ReplicatedStorage:FindFirstChild("CmdrClient")
    local types = cmdr and cmdr:FindFirstChild("Types")
    local bn = types and types:FindFirstChild("BrainrotName")
    if bn then
        if bn:IsA("ModuleScript") then
            local ok, res = pcall(require, bn)
            if ok and type(res) == "table" then
                for k, v in pairs(res) do
                    if type(v) == "string" then ValidBrainrotNames[v] = true end
                    if type(k) == "string" and type(v) ~= "string" then ValidBrainrotNames[k] = true end
                end
            end
        elseif bn:IsA("Folder") then
            for _, child in ipairs(bn:GetChildren()) do
                if child:IsA("StringValue") then
                    ValidBrainrotNames[child.Value] = true
                else
                    ValidBrainrotNames[child.Name] = true
                end
            end
        else
            -- StringValue or other
            local ok, val = pcall(function() return bn.Value end)
            if ok and type(val) == "string" then ValidBrainrotNames[val] = true end
        end
    end
    local c = 0 for _ in pairs(ValidBrainrotNames) do c += 1 end
    if c > 0 then print("[Dashboard] Loaded " .. c .. " brainrot names from CmdrClient.Types.BrainrotName") end
end)

local function isValidBrainrotName(name)
    if not name then return false end
    if next(ValidBrainrotNames) == nil then return true end -- no list loaded, accept anything
    return ValidBrainrotNames[name] == true
end

local function discoverBrainrots()
    local found, seen = {}, {}
    pcall(function()
        for _, desc in ipairs(PlayerGui:GetDescendants()) do
            if desc:IsDescendantOf(ScreenGui) then continue end
            local uuid = nil
            pcall(function()
                uuid = desc:GetAttribute("UUID") or desc:GetAttribute("Uuid") or desc:GetAttribute("ID") or desc:GetAttribute("Id")
            end)
            if not uuid and isUUID(desc.Name) then uuid = desc.Name end
            if uuid and isUUID(uuid) and not seen[uuid] then
                seen[uuid] = true
                -- find display name
                local bname = nil
                local weight = nil
                pcall(function()
                    local c = desc
                    for _ = 1, 3 do
                        if not c then break end
                        for _, sib in ipairs(c:GetDescendants()) do
                            if sib:IsA("TextLabel") then
                                local t = (sib.Text or ""):gsub("^%s+",""):gsub("%s+$","")
                                -- prefer exact match from CmdrClient.Types.BrainrotName
                                if isValidBrainrotName(t) and next(ValidBrainrotNames) ~= nil then
                                    bname = t
                                    break
                                end
                                if #t > 2 and #t < 50 and not t:find("KG") and not t:find("%$") and not t:lower():find("weight") then
                                    if not bname or #t > #bname then bname = t end
                                end
                                -- weight label like "123 KG" or "1.2k KG"
                                local w = t:match("(%d+%.?%d*)%s*[Kk][Gg]")
                                if w and not weight then weight = tonumber(w) end
                            end
                        end
                        if bname and next(ValidBrainrotNames) ~= nil and ValidBrainrotNames[bname] then break end
                        if bname then break end
                        c = c.Parent
                    end
                    local wa = desc:GetAttribute("Weight") or desc:GetAttribute("KG") or desc:GetAttribute("Mass")
                    if wa then weight = tonumber(wa) or weight end
                    -- also check for BrainrotName attribute directly
                    pcall(function()
                        local bnAttr = desc:GetAttribute("BrainrotName") or desc:GetAttribute("Name")
                        if bnAttr and isValidBrainrotName(tostring(bnAttr)) then bname = tostring(bnAttr) end
                    end)
                end)
                table.insert(found, {uuid = uuid, name = bname or (uuid:sub(1,8) .. "..."), weight = weight})
            end
        end
    end)
    -- also try garden/plot objects in workspace? skip for now
    table.sort(found, function(a,b) return (a.name or "") < (b.name or "") end)
    print("[Dashboard] Discovered " .. #found .. " brainrots")
    return found
end

local function favoriteBrainrot(uuid)
    if not uuid then return false end
    -- your working snippet: FireServer(uuid) - no firesignal needed
    local ok = pcall(function()
        FavoriteRemote:FireServer(uuid)
    end)
    if not ok then
        -- fallback via safe wrapper
        fireServerSafe(FavoriteRemote, uuid)
    end
    return true
end

-- Brainrot dropdown UI
-- Brainrot backend (no dropdown UI - auto-scan only)
local function updateBrainrotHeader() end
local function updateBrainrotRow(uuid) end
local function refreshBrainrotRows()
    -- no UI, just keep AvailableBrainrots fresh
end
local function buildBrainrotRows()
    AvailableBrainrots = discoverBrainrots()
end
local function buildBrainrotRowsPreserve(oldSel)
    AvailableBrainrots = discoverBrainrots()
end
buildBrainrotRows()

-- Weight threshold + auto-favorite toggle (simplified)
local WeightInputFrame = Instance.new("Frame")
WeightInputFrame.Size = UDim2.new(1, 0, 0, 48)
WeightInputFrame.BackgroundColor3 = Theme.Surface
WeightInputFrame.LayoutOrder = 10
WeightInputFrame.Parent = ScrollView
local WCFG = Instance.new("UICorner") WCFG.CornerRadius = UDim.new(0, 12) WCFG.Parent = WeightInputFrame

local WeightLabel = Instance.new("TextLabel")
WeightLabel.Size = UDim2.new(0.4, 0, 1, 0)
WeightLabel.Position = UDim2.new(0, 12, 0, 0)
WeightLabel.BackgroundTransparency = 1
WeightLabel.Text = "Min KG:"
WeightLabel.TextColor3 = Theme.Dark
WeightLabel.Font = Enum.Font.FredokaOne
WeightLabel.TextSize = 14
WeightLabel.TextXAlignment = Enum.TextXAlignment.Left
WeightLabel.Parent = WeightInputFrame

local WeightBox = Instance.new("TextBox")
WeightBox.Size = UDim2.new(0.55, -12, 1, 0)
WeightBox.Position = UDim2.new(0.45, 0, 0, 0)
WeightBox.BackgroundTransparency = 1
WeightBox.Text = "75"
WeightBox.TextColor3 = Theme.Dark
WeightBox.Font = Enum.Font.FredokaOne
WeightBox.TextSize = 18
WeightBox.PlaceholderText = "KG"
WeightBox.ClearTextOnFocus = false
WeightBox.TextXAlignment = Enum.TextXAlignment.Right
WeightBox.Parent = WeightInputFrame
-- keep shared threshold in sync
WeightBox:GetPropertyChangedSignal("Text"):Connect(function()
    SellWeightThreshold = tonumber(WeightBox.Text) or 1000
end)

local AutoFavNewBtn = makeToonButton("⭐ AUTO FAVORITE: OFF", Theme.Purple, ScrollView, 11)
AutoFavNewBtn.MouseButton1Click:Connect(function()
    autoFavNewEnabled = not autoFavNewEnabled
    if autoFavNewEnabled then
        table.clear(seenBrainrotUUIDs)
        for _, b in ipairs(discoverBrainrots()) do
            seenBrainrotUUIDs[b.uuid] = true
        end
        local threshold = tonumber(WeightBox.Text) or 1000
        AutoFavNewBtn.Text = "⭐ AUTO FAVORITE: ON (" .. tostring(threshold) .. " KG+)"
        AutoFavNewBtn.BackgroundColor3 = Theme.LightGreen
        print("[Dashboard] Auto-favorite enabled, threshold " .. threshold .. " KG")
        task.spawn(function()
            while autoFavNewEnabled do
                local currentThreshold = tonumber(WeightBox.Text) or 1000
                local expected = "⭐ AUTO FAVORITE: ON (" .. tostring(currentThreshold) .. " KG+)"
                if AutoFavNewBtn.Text ~= expected then
                    AutoFavNewBtn.Text = expected
                end
                local ok, latest = pcall(discoverBrainrots)
                if ok and latest then
                    for _, b in ipairs(latest) do
                        if not seenBrainrotUUIDs[b.uuid] then
                            seenBrainrotUUIDs[b.uuid] = true
                            if b.weight and b.weight >= currentThreshold then
                                print("[Dashboard] New " .. (b.name or b.uuid:sub(1,8)) .. " [" .. tostring(b.weight) .. " KG] -> favoriting")
                                favoriteBrainrot(b.uuid)
                                task.wait(0.2)
                            end
                            pcall(function()
                                -- preserve selections while adding new
                                local oldSel = {}
                                for k,v in pairs(SelectedBrainrots) do oldSel[k]=v end
                                buildBrainrotRowsPreserve(oldSel)
                            end)
                        end
                    end
                end
                task.wait(1)
            end
        end)
    else
        AutoFavNewBtn.Text = "⭐ AUTO FAVORITE: OFF"
        AutoFavNewBtn.BackgroundColor3 = Theme.Purple
        print("[Dashboard] Auto-favorite disabled")
    end
end)

-- Auto-scan brainrot list every 3s so dropdown stays fresh without button
task.spawn(function()
    while true do
        task.wait(3)
        pcall(function()
            local oldSel = {}
            for k,v in pairs(SelectedBrainrots) do oldSel[k]=v end
            -- only rebuild if count changed to avoid flicker
            local latest = discoverBrainrots()
            if #latest ~= #AvailableBrainrots then
                buildBrainrotRowsPreserve(oldSel)
            else
                refreshBrainrotRows()
            end
        end)
    end
end)

-- Leaf minimize button (replaces bar minimize)
-- Simple minimize circle (tap to restore)
local MinCircle = Instance.new("TextButton")
MinCircle.Name = "MinCircle"
MinCircle.Size = UDim2.new(0, 55, 0, 55)
MinCircle.Position = UDim2.new(0, 1, 0.5, -27)
MinCircle.BackgroundColor3 = Theme.Pink
MinCircle.Text = "🌱"
MinCircle.TextSize = 28
MinCircle.Font = Enum.Font.FredokaOne
MinCircle.TextColor3 = Theme.White
MinCircle.Visible = false
MinCircle.Active = true
MinCircle.Parent = ScreenGui
local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(1, 0)
MinCorner.Parent = MinCircle

ToggleButton.MouseButton1Click:Connect(function()
    Frame.Visible = false
    MinCircle.Visible = true
end)

MinCircle.MouseButton1Click:Connect(function()
    MinCircle.Visible = false
    Frame.Visible = true
end)

print("[Plants Vs Brainrots v6.3 Loaded] Seeds: " .. #AvailableSeeds .. " Gears: " .. #AvailableGears .. " Brainrots: " .. #AvailableBrainrots)
