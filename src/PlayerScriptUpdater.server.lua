local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ScriptEditorService = game:GetService("ScriptEditorService")

local Diff = require(script.Parent.Diff)
local Utils = require(script.Parent.Utils)
local ClientTrackerAPI = require(script.Parent.ClientTrackerAPI)

local applyThemeWidget = require(script.Parent.ApplyThemeWidget)

local StarterPlayerScripts = game.StarterPlayer.StarterPlayerScripts

local IS_LOCAL = false -- Toggle for development to differentiate between locally installed and online version of plugin
local BASE_URL = ClientTrackerAPI.BASE_URL
local PATHS = ClientTrackerAPI.PATHS
local DEPENDS = ClientTrackerAPI.DEPENDS

local function getForkedFolder()
	if StarterPlayerScripts:FindFirstChild("_Forked") then
		return StarterPlayerScripts._Forked
	end
	local forked = Instance.new("Folder")
	forked.Name = "_Forked"
	forked.Parent = StarterPlayerScripts
	return forked
end

local LOADER = script.Parent.PlayerScriptsLoader

local function grabModule(moduleName: string, parent: Instance)
	local Module = parent:FindFirstChild(moduleName)
	if Module then return Module end
	
	local r, e = ClientTrackerAPI.attemptGetScriptSource(moduleName)
	if not r then error(("Failed to grab script from Roblox Client Tracker, error: %s"):format(e)) end
	local date = ClientTrackerAPI.getLastCommitDate(moduleName)
	Module = Instance.new("ModuleScript")
	Module.Name = moduleName
	Module.Source = r
	Module:SetAttribute("LastUpdate", date)
	if parent then Module.Parent = parent end
	
	return Module
end

local function createDifferencePrompt(original, new)
	local difference = Diff.getMultiLineDiff(original, new)
	local diffText = ""
	for _, diff in pairs(difference) do
		diffText ..= ("%s%s\n"):format(diff.token, diff.str)
	end
	local widgetInfo = DockWidgetPluginGuiInfo.new(
		Enum.InitialDockState.Float,
		true,
		true,
		200,
		300,
		150,
		150
	)
	local widget: DockWidgetPluginGui = plugin:CreateDockWidgetPluginGui("PlayerScriptUpdaterChanges", widgetInfo)
	widget.Title = "Changes"
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	
	local label = Instance.new("TextLabel")
	label.Text = "Script changes detected, view difference?"
	label.TextSize = 10
	label.TextWrapped = true
	label.Size = UDim2.new(1, 0, 0, 50)
	
	local no = Instance.new("TextButton")
	no.Text = "No"
	no.Size = UDim2.new(0, 70, 0, 40)
	no.AnchorPoint = Vector2.new(0, 1)
	no.Position = UDim2.new(0, 30, 1, -30)
	
	local yes = Instance.new("TextButton")
	yes.Text = "Yes"
	yes.Size = UDim2.new(0, 70, 0, 40)
	yes.AnchorPoint = Vector2.new(1, 1)
	yes.Position = UDim2.new(1, -30, 1, -30)
	
	no.Parent = bg
	yes.Parent = bg
	label.Parent = bg
	bg.Parent = widget
	
	applyThemeWidget(widget)
	
	widget:BindToClose(function()
		widget:Destroy()
	end)
	
	local bind = Instance.new("BindableEvent")
	--widget.AncestryChanged:Once(function() bind:Fire(false) end)
	widget:BindToClose(function() bind:Fire(false) end)
	local noConn = no.Activated:Connect(function() bind:Fire(false) end)
	local yesConn = yes.Activated:Connect(function() bind:Fire(true) end)
	local accepted = bind.Event:Wait()
	widget.Enabled = false
	--widget:Destroy()
	
	if accepted then
		local temp = Instance.new("ModuleScript")
		temp.Name = "Changes"
		--temp.Source = new
		temp.Source = Diff.TOKEN_KEYS..diffText
		temp.Parent = workspace
		plugin:OpenScript(temp)
		Utils.waitForCondition(ScriptEditorService.TextDocumentDidClose, function(doc)
			return doc == ScriptEditorService:FindScriptDocument(temp)
		end)
		temp:Destroy()
	end
	
	label.Text = "Accept changes to script?"
	widget.Enabled = true
	local acceptChanges = bind.Event:Wait()
	
	noConn:Disconnect()
	yesConn:Disconnect()
	
	widget:Destroy()
	return acceptChanges
end

local function updateModule(moduleName: string)
	assert(PATHS[moduleName], ("Module %s is not currently implemented for updating"):format(moduleName))
	
	local parent = getForkedFolder()
	for _, name in pairs(DEPENDS[moduleName]) do
		parent = grabModule(name, parent)
	end
	local module = grabModule(moduleName, parent)
	local date = ClientTrackerAPI.getLastCommitDate(moduleName)
	if module:GetAttribute("LastUpdate") ~= date then
		local r, e = ClientTrackerAPI.attemptGetScriptSource(moduleName)
		if not r then error(("Failed to grab script from Roblox Client Tracker, error: %s"):format(e)) end
		local acceptChanges = createDifferencePrompt(module.Source, r)
		if not acceptChanges then return end
		module.Source = r
		module:SetAttribute("LastUpdate", date)
		warn(("Module %s has been changed"):format(moduleName))
		ChangeHistoryService:SetWaypoint(("Updated player module %s"):format(moduleName))
	end
end

local scriptIcon = "rbxassetid://4458901886"
local toolbar: PluginToolbar = plugin:CreateToolbar(if IS_LOCAL then "(Local) Player Script Updater" else "Player Script Updater")

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
	local loader = LOADER:Clone()
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
widget.Title = if IS_LOCAL then "(Local) Player Script Updater" else "Player Script Updater"
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

	local label = Instance.new("TextBox")
	label.Text = name
	label.Size = UDim2.new(0.35, 0, 1, 0)
	label.TextEditable = false
	label.ClearTextOnFocus = false

	local lastUpdate = Instance.new("TextBox")
	lastUpdate.Name = "LastUpdate"
	lastUpdate.Text = if date then date else "unknown"
	lastUpdate.Size = UDim2.new(0.35, 0, 1, 0)
	lastUpdate.Position = UDim2.new(0.35, 0, 0, 0)
	lastUpdate.TextEditable = false
	lastUpdate.ClearTextOnFocus = false

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

applyThemeWidget(widget)

local openMenu = toolbar:CreateButton("Toggle Menu", "View and update specific modules", scriptIcon)
openMenu.ClickableWhenViewportHidden = true
openMenu.Click:Connect(function() widget.Enabled = not widget.Enabled end)