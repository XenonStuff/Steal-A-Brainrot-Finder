-- idc if you use this but if u implement it into your own script, please give credits.

local ui = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local svc = setmetatable({}, {
    __index = function(t, k)
        local s = game:GetService(k)
        t[k] = s
        return s
    end
})

local cfg = {
    enabled = false,
    mutenabled = false,
    webhook = "",
    hoptime = 300,
    brainrots = {},
    mutations = {"Gold", "Diamond", "Rainbow", "Candy"},
    selected = {brainrots = {}, mutations = {}},
    found = {},
    cons = {}
}

local function getbrainrots()
    cfg.brainrots = {}
    local path = svc.ReplicatedStorage:FindFirstChild("Models")
    if path and path:FindFirstChild("Animals") then
        for _, v in pairs(path.Animals:GetChildren()) do
            if v:IsA("Model") then
                cfg.brainrots[#cfg.brainrots + 1] = v.Name
            end
        end
    end
    return cfg.brainrots
end

local function sendhook(title, desc)
    if cfg.webhook == "" then return end
    spawn(function()
        request({
            Url = cfg.webhook,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = svc.HttpService:JSONEncode({
                embeds = {{
                    title = title,
                    description = desc,
                    color = 0x00ff00
                }}
            })
        })
    end)
end

local function hop()
    local servers = {}
    local ok, data = pcall(function()
        return request({
            Url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Desc&limit=100",
            Method = "GET"
        }).Body
    end)
    
    if ok then
        local decoded = pcall(svc.HttpService.JSONDecode, svc.HttpService, data)
        if decoded then
            local body = svc.HttpService:JSONDecode(data)
            if body.data then
                for _, server in pairs(body.data) do
                    if server.playing < server.maxPlayers and server.id ~= game.JobId then
                        servers[#servers + 1] = server.id
                    end
                end
            end
        end
    end
    
    if #servers > 0 then
        svc.TeleportService:TeleportToPlaceInstance(game.PlaceId, servers[math.random(#servers)], svc.Players.LocalPlayer)
    end
end

local function scan()
    local moving = svc.Workspace:FindFirstChild("MovingAnimals")
    if not moving then return end
    
    for _, model in pairs(moving:GetChildren()) do
        if model:IsA("Model") then
            local idx, mut = model:GetAttribute("Index"), model:GetAttribute("Mutation")
            if idx then
                local key = tostring(model:GetDebugId())
                if not cfg.found[key] then
                    local notify, info = false, {title = "", desc = ""}
                    
                                         for _, brainrot in pairs(cfg.selected.brainrots) do
                         if idx == brainrot then
                             notify, info.title, info.desc = true, "Brainrot Found", "Name: " .. brainrot .. (mut and "\nMutation: " .. mut or "")
                             break
                         end
                     end
                    
                    if not notify and cfg.mutenabled and mut then
                        for _, mutation in pairs(cfg.selected.mutations) do
                                                         if mut == mutation then
                                 notify, info.title, info.desc = true, "Mutation Found", "Brainrot: " .. idx .. "\nMutation: " .. mut
                                 break
                             end
                        end
                    end
                    
                    if notify then
                        cfg.found[key] = true
                        sendhook(info.title, info.desc)
                        ui:Notify({Title = info.title, Content = info.desc, Duration = 8})
                    end
                end
            end
        end
    end
end

local function toggle(state)
    cfg.enabled = state
    if state then
        cfg.cons.scan = svc.RunService.Heartbeat:Connect(scan)
        cfg.cons.hop = task.spawn(function()
            while cfg.enabled do
                task.wait(cfg.hoptime)
                if cfg.enabled then hop() end
            end
        end)
    else
        if cfg.cons.scan then cfg.cons.scan:Disconnect() end
        if cfg.cons.hop then task.cancel(cfg.cons.hop) end
    end
end

getbrainrots()

local win = ui:CreateWindow({
    Title = "Brainrot Finder",
    Icon = "search",
    Folder = "scanner",
    Size = UDim2.fromOffset(520, 420),
    Theme = "Dark"
})

local main = win:Section({Title = "scanner", Opened = true}):Tab({Title = "main", Icon = "target"})
local opts = win:Section({Title = "options"}):Tab({Title = "settings", Icon = "settings"})

local animaldrop

main:Input({
    Title = "webhook url",
    Placeholder = "discord webhook",
    Callback = function(v) cfg.webhook = v end
})

animaldrop = main:Dropdown({
    Title = "Brainrots",
    Values = cfg.brainrots,
    Multi = true,
    AllowNone = true,
    Callback = function(v) cfg.selected.brainrots = v end
})

main:Dropdown({
    Title = "mutations", 
    Values = cfg.mutations,
    Multi = true,
    AllowNone = true,
    Callback = function(v) cfg.selected.mutations = v end
})

main:Toggle({Title = "scanner", Callback = toggle})
main:Toggle({Title = "mutations", Callback = function(v) cfg.mutenabled = v end})

main:Button({Title = "refresh", Callback = function() 
    getbrainrots()
    animaldrop:Refresh(cfg.brainrots)
end})

main:Button({Title = "hop", Callback = hop})
main:Button({Title = "test", Callback = function() sendhook("test", "working") end})

opts:Slider({
    Title = "hop interval",
    Value = {Min = 60, Max = 600, Default = 300},
    Callback = function(v) cfg.hoptime = v end
})

win:OnClose(function()
    for _, con in pairs(cfg.cons) do
        if typeof(con) == "RBXScriptConnection" then
            con:Disconnect()
        else
            task.cancel(con)
        end
    end
end)
