repeat task.wait() until game:IsLoaded()

local GuiService = game:GetService("GuiService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

if not getgenv().void_notified then
    getgenv().void_notified = true
    pcall(function()
        if writefile and isfile and not isfile("void_v3.png") then
            pcall(function()
                local imgData = game:HttpGet("https://raw.githubusercontent.com/Dhanniii/V-rejoin/main/void_v3.png")
                writefile("void_v3.png", imgData)
            end)
        end

        local iconAsset = ""
        if getcustomasset and isfile and isfile("void_v3.png") then
            pcall(function()
                iconAsset = getcustomasset("void_v3.png")
            end)
        end

        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Void's",
            Text = "Version 1.0.0",
            Icon = iconAsset,
            Duration = 3
        })
    end)
end

pcall(function()
    if writefile then
        writefile("void_ingame.txt", tostring(os.time()))
    end
end)

local isRejoining = false

local function triggerRejoin()
    if isRejoining then return end
    isRejoining = true
    pcall(function()
        if writefile then
            writefile("void_error_flag.txt", "ERROR")
        end
        if LocalPlayer then
            LocalPlayer:Kick("Auto Rejoin")
        end
    end)
end

GuiService.ErrorMessageChanged:Connect(function(msg)
    if msg and #msg > 0 then
        triggerRejoin()
    end
end)

TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errorMessage)
    if player == LocalPlayer then
        task.wait(1)
        triggerRejoin()
    end
end)

task.spawn(function()
    local promptOverlay = CoreGui:WaitForChild("RobloxPromptGui", 10) and CoreGui.RobloxPromptGui:WaitForChild("promptOverlay", 10)
    if promptOverlay then
        promptOverlay.ChildAdded:Connect(function(child)
            if child.Name == "ErrorPrompt" then
                triggerRejoin()
            end
        end)

        if promptOverlay:FindFirstChild("ErrorPrompt") then
            triggerRejoin()
        end
    end

    while task.wait(3) do
        pcall(function()
            if writefile then
                writefile("void_ingame.txt", tostring(os.time()))
            end
            if promptOverlay and promptOverlay:FindFirstChild("ErrorPrompt") then
                triggerRejoin()
            end
        end)
    end
end)
