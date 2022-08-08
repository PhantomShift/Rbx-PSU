local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Http = game:GetService("HttpService")

local StarterPlayerScripts = game.StarterPlayer.StarterPlayerScripts

local function getForkedFolder()
	if StarterPlayerScripts:FindFirstChild("_Forked") then
		return StarterPlayerScripts._Forked
	end
	local forked = Instance.new("Folder")
	forked.Name = "_Forked"
	forked.Parent = StarterPlayerScripts
	return forked
end

local BASE_URL = "https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/scripts/PlayerScripts/StarterPlayerScripts/"
local API_URL = "https://api.github.com/repos/MaximumADHD/Roblox-Client-Tracker/commits?path=scripts/PlayerScripts/StarterPlayerScripts/"

local PATHS = {
	PlayerModule = "PlayerModule.module.lua",
	CameraModule = "PlayerModule.module/CameraModule.lua",
	ControlModule = "PlayerModule.module/ControlModule.lua"
}
local DEPENDS = {
	PlayerModule = {},
	CameraModule = {"PlayerModule"},
	ControlModule = {"PlayerModule"}
}

-- For now this is just hard coded to replace the three main ones that are present;
-- Will probably have to update if I need specific submodules to be overridden for whatever reason
local LOADER_SOURCE = [[
local Player = game.Players.LocalPlayer
local PlayerScripts = Player.PlayerScripts
local PlayerModule = PlayerScripts:WaitForChild("PlayerModule")
local CameraModule = PlayerModule:WaitForChild("CameraModule")
local ControlModule = PlayerModule:WaitForChild("ControlModule")


local Forked = PlayerScripts:WaitForChild("_Forked")
local ForkedPlayerModule = Forked:WaitForChild("PlayerModule")
if Forked and ForkedPlayerModule then
	if ForkedPlayerModule:FindFirstChild("CameraModule") then
		for i, child in pairs(CameraModule:GetChildren()) do
			child.Parent = Forked.PlayerModule.CameraModule
		end		
	else
		CameraModule.Parent = ForkedPlayerModule
	end
	
	if ForkedPlayerModule:FindFirstChild("ControlModule") then
		for i, child in pairs(ControlModule:GetChildren()) do
			child.Parent = Forked.PlayerModule.ControlModule
		end
	else
		ControlModule.Parent = ForkedPlayerModule
	end

	PlayerModule.Parent, ForkedPlayerModule.Parent = nil, PlayerModule.Parent
end

require(script.Parent:WaitForChild("PlayerModule"))
]]

local function getLastCommitDate(moduleName: string) : string
	local r, e
	-- Can get rate limited if you do it too often;
	-- presumably you'd only be updating every once in a while, but something to keep in mind
	pcall(function()
		r, e = Http:GetAsync(API_URL..PATHS[moduleName], false)
	end)
	if not r then warn(e) return "unknown" end
	
	local response = Http:JSONDecode(r)
	return response[1].commit.committer.date
end

local function grabModule(moduleName: string, parent: Instance)
	local Module = parent:FindFirstChild(moduleName)
	if Module then return Module end
	
	local r, e = Http:GetAsync(BASE_URL..PATHS[moduleName])
	local date = getLastCommitDate(moduleName)
	Module = Instance.new("ModuleScript")
	Module.Name = moduleName
	Module.Source = r
	Module:SetAttribute("LastUpdate", date)
	if parent then Module.Parent = parent end
	
	return Module
end

local function updateModule(moduleName: string)
	assert(PATHS[moduleName], ("Module %s is not currently implemented for updating"):format(moduleName))
	
	local parent = getForkedFolder()
	for i, name in pairs(DEPENDS[moduleName]) do
		parent = grabModule(name, parent)
	end
	local module = grabModule(moduleName, parent)
	local date = getLastCommitDate(moduleName)
	if module:GetAttribute("LastUpdate") ~= date then
		local r, e = Http:GetAsync(BASE_URL..PATHS[moduleName])
		module.Source = r
		module:SetAttribute("LastUpdate", date)
		warn(("Module %s has been changed"):format(moduleName))
		ChangeHistoryService:SetWaypoint(("Updated player module %s"):format(moduleName))
	end
end

local scriptIcon = "rbxassetid://4458901886"
local toolbar: PluginToolbar = plugin:CreateToolbar("Player Script Updater")

local updateAll = toolbar:CreateButton("Update All", "Update all scripts to latest", scriptIcon)
updateAll.ClickableWhenViewportHidden = true
updateAll.Click:Connect(function()
	for name, _ in pairs(PATHS) do
		updateModule(name)
	end
end)

local generateLoader = toolbar:CreateButton("Generate Loader", "Generate PlayerScriptsLoader which loads the modules in PlayerScripts._Forked", scriptIcon)
generateLoader.ClickableWhenViewportHidden = true
generateLoader.Click:Connect(function()
	if StarterPlayerScripts:FindFirstChild("PlayerScriptsLoader") then
		StarterPlayerScripts:FindFirstChild("PlayerScriptsLoader"):Destroy()
	end
	local loader = Instance.new("LocalScript")
	loader.Name = "PlayerScriptsLoader"
	loader.Source = LOADER_SOURCE
	loader.Parent = StarterPlayerScripts
	ChangeHistoryService:SetWaypoint("Generated new PlayerScriptsLoader")
end)

local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Float,
	true,
	false,
	200,
	300,
	150,
	150
)

local widget: DockWidgetPluginGui = plugin:CreateDockWidgetPluginGui("PlayerScriptUpdater", widgetInfo)
widget.Title = "Player Script Updater"
local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.Parent = widget
local listlayout = Instance.new("UIListLayout")
listlayout.FillDirection = Enum.FillDirection.Vertical
listlayout.SortOrder = Enum.SortOrder.LayoutOrder
listlayout.Parent = bg

local function generateRow(name: string, date: string?, button: boolean?, order: number?)
	local container = Instance.new("Frame")
	container.Name = name
	container.Size = UDim2.new(1, 0, 0, 20)

	local label = Instance.new("TextLabel")
	label.Text = name
	label.Size = UDim2.new(0.35, 0, 1, 0)

	local lastUpdate = Instance.new("TextLabel")
	lastUpdate.Name = "LastUpdate"
	lastUpdate.Text = if date then date else "unknown"
	lastUpdate.Size = UDim2.new(0.35, 0, 1, 0)
	lastUpdate.Position = UDim2.new(0.35, 0, 0, 0)

	
	local update = if button then Instance.new("TextButton") else Instance.new("TextLabel")
	update.Name = "Update"
	update.Text = "Update"
	update.Size = UDim2.new(0.3, 0, 1, 0)
	update.Position = UDim2.new(0.7, 0, 0, 0)
	
	label.Parent = container
	lastUpdate.Parent = container
	update.Parent = container
	
	if order then
		container.SelectionOrder = order
	end

	container.Parent = bg
	
	return container
end

generateRow("Module", "Last Updated", false, 1)
for name, path in pairs(PATHS) do
	local module = getForkedFolder():FindFirstChild(name, true)
	local container = generateRow(name, if module then module:GetAttribute("LastUpdate") else "unknown", true)
	local lastUpdate = container:FindFirstChild("LastUpdate")
	
	container:FindFirstChild("Update").Activated:Connect(function()
		updateModule(name)
		lastUpdate.Text = getForkedFolder():FindFirstChild(name, true):GetAttribute("LastUpdate") or "unknown"
	end)
	if module then
		module:GetAttributeChangedSignal("LastUpdate"):Connect(function()
			lastUpdate.Text = module:GetAttribute("LastUpdate") or "unknown"
		end)
	end
	StarterPlayerScripts.DescendantAdded:Connect(function(descendant)
		if descendant.Name == name then
			lastUpdate.Text = descendant:GetAttribute("LastUpdate") or "unknown"
			descendant:GetAttributeChangedSignal("LastUpdate"):Connect(function()
				lastUpdate.Text = descendant:GetAttribute("LastUpdate") or "unknown"
			end)
		end
	end)
end

local function syncGuiColors(objects)
	local function setColors()
		for _, guiObject in pairs(objects) do
			if not guiObject:IsA("GuiObject") then continue end
			-- Sync background color
			guiObject.BackgroundColor3 = settings().Studio.Theme:GetColor(Enum.StudioStyleGuideColor.MainBackground)
			-- Sync text color
			if guiObject:IsA("TextButton") or guiObject:IsA("TextLabel") or guiObject:IsA("TextBox") then
				guiObject.TextColor3 = settings().Studio.Theme:GetColor(Enum.StudioStyleGuideColor.MainText)
			end
		end
	end
	-- Run 'setColors()' function to initially sync colors
	setColors()
	-- Connect 'ThemeChanged' event to the 'setColors()' function
	settings().Studio.ThemeChanged:Connect(setColors)
end

-- Run 'syncGuiColors()' function to sync colors of provided objects
syncGuiColors(widget:GetDescendants())

local openMenu = toolbar:CreateButton("Toggle Menu", "View and update specific modules", scriptIcon)
openMenu.ClickableWhenViewportHidden = true
openMenu.Click:Connect(function() widget.Enabled = not widget.Enabled end)
