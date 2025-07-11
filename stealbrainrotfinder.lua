-- i could definitely have made this so much better but i have no passion for this dog ass game so got lazy with code

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
    baseenabled = false,
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

local function scanbase()
    if not cfg.baseenabled then return end
    
    local plots = svc.Workspace:FindFirstChild("Plots")
    if not plots then return end
    
    for _, plot in pairs(plots:GetChildren()) do
        if plot:IsA("Model") then
            local owner = ""
            local plotsign = plot:FindFirstChild("PlotSign")
            if plotsign and plotsign:FindFirstChild("SurfaceGui") then
                local frame = plotsign.SurfaceGui:FindFirstChild("Frame")
                if frame and frame:FindFirstChild("TextLabel") then
                    owner = frame.TextLabel.Text
                end
            end
            
            if owner ~= svc.Players.LocalPlayer.Name then
                local podiums = plot:FindFirstChild("AnimalPodiums")
                if podiums then
                    for _, podium in pairs(podiums:GetChildren()) do
                        if podium:IsA("Model") then
                            local base = podium:FindFirstChild("Base")
                            if base then
                                local spawn = base:FindFirstChild("Spawn")
                                if spawn and spawn:FindFirstChild("Attachment") then
                                    local overhead = spawn.Attachment:FindFirstChild("AnimalOverhead")
                                    if overhead then
                                        local displayname = overhead:FindFirstChild("DisplayName")
                                        local mutation = overhead:FindFirstChild("Mutation")
                                        
                                        if displayname and displayname.Text ~= "" then
                                            local key = plot.Name .. "_" .. podium.Name
                                            if not cfg.found[key] then
                                                local notify, info = false, {title = "", desc = ""}
                                                local brainrotname = displayname.Text
                                                local muttext = mutation and mutation.Text or ""
                                                
                                                for _, brainrot in pairs(cfg.selected.brainrots) do
                                                    if brainrotname == brainrot then
                                                        notify, info.title = true, "Base Brainrot Found"
                                                        info.desc = "Owner: " .. owner .. "\nName: " .. brainrot
                                                        if muttext ~= "" then
                                                            info.desc = info.desc .. "\nMutation: " .. muttext
                                                        end
                                                        break
                                                    end
                                                end
                                                
                                                if not notify and cfg.mutenabled and muttext ~= "" then
                                                    for _, mut in pairs(cfg.selected.mutations) do
                                                        if muttext == mut then
                                                            notify, info.title = true, "Base Mutation Found"
                                                            info.desc = "Owner: " .. owner .. "\nBrainrot: " .. brainrotname .. "\nMutation: " .. mut
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
                        end
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

local function togglebase(state)
    cfg.baseenabled = state
    if state then
        cfg.cons.basescan = svc.RunService.Heartbeat:Connect(scanbase)
    else
        if cfg.cons.basescan then cfg.cons.basescan:Disconnect() end
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

local scanner = win:Section({Title = "scanner", Opened = true})
local main = scanner:Tab({Title = "brainrot finder", Icon = "target"})
local base = scanner:Tab({Title = "base brainrot finder", Icon = "home"})
local opts = win:Section({Title = "options"}):Tab({Title = "settings", Icon = "settings"})

local animaldrop

main:Button({Title = "refresh", Callback = function() 
    getbrainrots()
    brainrotdrop:Refresh(cfg.brainrots)
    basebrainrotdrop:Refresh(cfg.brainrots)
end})

main:Button({Title = "hop", Callback = hop})
main:Button({Title = "test", Callback = function() sendhook("test", "working") end})

base:Button({Title = "test", Callback = function() sendhook("test", "working") end})

local cfgmgr = win.ConfigManager
local config = cfgmgr:CreateConfig("brainrot")

local webhookinput = main:Input({
    Title = "webhook url",
    Placeholder = "discord webhook",
    Callback = function(v) cfg.webhook = v end
})

local brainrotdrop = main:Dropdown({
    Title = "Brainrots",
    Values = cfg.brainrots,
    Multi = true,
    AllowNone = true,
    Callback = function(v) cfg.selected.brainrots = v end
})

local mutationdrop = main:Dropdown({
    Title = "mutations",
    Values = cfg.mutations,
    Multi = true,
    AllowNone = true,
    Callback = function(v) cfg.selected.mutations = v end
})

local scannertoggle = main:Toggle({Title = "scanner", Callback = toggle})
local mutationtoggle = main:Toggle({Title = "mutations", Callback = function(v) cfg.mutenabled = v end})

local basewebhook = base:Input({
    Title = "webhook url",
    Placeholder = "discord webhook", 
    Callback = function(v) cfg.webhook = v end
})

local basebrainrotdrop = base:Dropdown({
    Title = "Brainrots",
    Values = cfg.brainrots,
    Multi = true,
    AllowNone = true,
    Callback = function(v) cfg.selected.brainrots = v end
})

local basemutationdrop = base:Dropdown({
    Title = "mutations",
    Values = cfg.mutations,
    Multi = true,
    AllowNone = true,
    Callback = function(v) cfg.selected.mutations = v end
})

local basescannertoggle = base:Toggle({Title = "base scanner", Callback = togglebase})
local basemutationtoggle = base:Toggle({Title = "mutations", Callback = function(v) cfg.mutenabled = v end})

local hopslider = opts:Slider({
    Title = "hop interval",
    Value = {Min = 60, Max = 600, Default = 300},
    Callback = function(v) cfg.hoptime = v end
})

config:Register("webhook", webhookinput)
config:Register("brainrots", brainrotdrop)
config:Register("mutations", mutationdrop)
config:Register("scanner", scannertoggle)
config:Register("mutationenabled", mutationtoggle)
config:Register("basewebhook", basewebhook)
config:Register("basebrainrots", basebrainrotdrop)
config:Register("basemutations", basemutationdrop)
config:Register("basescanner", basescannertoggle)
config:Register("basemutationenabled", basemutationtoggle)
config:Register("hopinterval", hopslider)

opts:Button({Title = "save config", Callback = function() config:Save() end})
opts:Button({Title = "load config", Callback = function() config:Load() end})

win:OnClose(function()
    for _, con in pairs(cfg.cons) do
        if typeof(con) == "RBXScriptConnection" then
            con:Disconnect()
        else
            task.cancel(con)
        end
    end
end)
