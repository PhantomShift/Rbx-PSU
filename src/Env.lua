local DEFAULT_ENV = [[
return {
    -- Whether or not to skip viewing differences on updated modules
    skipDifferencePrompt = false,

    -- Skip update check and ALWAYS replace forked module with one grabbed from Roblox Client Tracker
    alwaysUpdate = false,

    -- Use ServerScriptService to pull up a temporary script that displays the changes made
    -- instead of using the difference viewer widget
    -- Highlighting differences is unfortunately not supported,
    -- but changes made to the temporary script will be applied
    -- No effect if skipDifferencePrompt is true
    scriptEditorServiceBeta = false,

    -- Use the unified different viewer instead of the split viewer
    -- (Changes are all in one page instead of two)
    unifiedDiffPrompt = false
}
]]

local environment = game:GetService("AnalyticsService"):FindFirstChild("RobloxPSU_Environment")
if not environment then
    environment = Instance.new("ModuleScript")
    environment.Name = "RobloxPSU_Environment"
    environment.Source = DEFAULT_ENV
    environment.Parent = game:GetService("AnalyticsService")
end
if environment:FindFirstChild("ModuleScript") then
    environment.ModuleScript:Destroy()
end
local proxyEnvironment = Instance.new("ModuleScript")
proxyEnvironment.Source = environment.Source
proxyEnvironment.Archivable = false
proxyEnvironment.Parent = environment

environment:GetPropertyChangedSignal("Source"):Connect(function()
    local success = pcall(require, environment)
    if success then
        proxyEnvironment:Destroy()
        proxyEnvironment = Instance.new("ModuleScript")
        proxyEnvironment.Source = environment.Source
        proxyEnvironment.Archivable = false
        proxyEnvironment.Parent = environment
    end
end)

-- Returns environment variable for Rbx-PSU  
-- Environment variables can be set via the `Environment` toolbar button
return function(variable: "skipDifferencePrompt" | "alwaysUpdate" | "scriptEditorServiceBeta" | "unifiedDiffPrompt")
    return require(proxyEnvironment)[variable]
end