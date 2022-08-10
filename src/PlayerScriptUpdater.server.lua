local ChangeHistoryService = game:GetService("ChangeHistoryService")

local Maid = require(script.Parent.Maid)
local Diff = require(script.Parent.Diff)
local Utils = require(script.Parent.Utils)
local ClientTrackerAPI = require(script.Parent.ClientTrackerAPI)
local Env = require(script.Parent.Env)

local applyThemeWidget = require(script.Parent.ApplyThemeWidget)

local StarterPlayerScripts = game.StarterPlayer.StarterPlayerScripts

local IS_LOCAL = false -- Toggle for development to differentiate between locally installed and online version of plugin
local BASE_URL = ClientTrackerAPI.BASE_URL
local PATHS = ClientTrackerAPI.PATHS
local DEPENDS = ClientTrackerAPI.DEPENDS

local PluginCurrentlyProcessing = false

local function getStudiothemeColor(color: Enum.StudioStyleGuideColor)
	return settings().Studio.Theme:GetColor(color)
end

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

local function createDifferencePrompt(original: string, new: string, moduleName: string)
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
	local labelText = if Env("skipDifferencePrompt") then "Script changes detected for %s, apply changes?"
					  elseif Env("scriptEditorServiceBeta") then "Script changes detected for %s, view and edit changes?"
					  else "Script changes detected for %s, view changes?"
	label.Text = labelText:format(moduleName)
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
	bind.Parent = widget
	widget:BindToClose(function() bind:Fire(false) end)
	no.Activated:Connect(function() bind:Fire(false) end)
	yes.Activated:Connect(function() bind:Fire(true) end)
	local accepted = bind.Event:Wait()
	widget.Enabled = false
	
	if Env("skipDifferencePrompt") then
		widget:Destroy()
		return accepted, new
	end
	
	if accepted then
		if Env("scriptEditorServiceBeta") then
			local ScriptEditorService = game:GetService("ScriptEditorService")
			local temp = Instance.new("ModuleScript")
			temp.Name = ("Updated %s | Changes Save | Close to Continue"):format(moduleName)
			temp.Source = new
			temp.Archivable = false
			temp.Parent = workspace
			plugin:OpenScript(temp)
			Utils.waitForCondition(ScriptEditorService.TextDocumentDidClose, function(doc)
				return doc == ScriptEditorService:FindScriptDocument(temp)
			end)
			new = temp.Source
			temp:Destroy()
		else
			local difference = Diff.getMultiLineDiff(original, new)
			-- Render difference prompt
			local diffWidget: DockWidgetPluginGui = plugin:CreateDockWidgetPluginGui("ScriptDifferencesPrompt", widgetInfo)
			diffWidget.Title = ("Changes to %s | Close to Continue"):format(moduleName)

			if Env("unifiedDiffPrompt") then
				local container = Instance.new("ScrollingFrame")
				container.Size = UDim2.fromScale(1, 1)
				container.AutomaticCanvasSize = Enum.AutomaticSize.XY
				local listlayout = Instance.new("UIListLayout")
				listlayout.Parent = container
				listlayout.SortOrder = Enum.SortOrder.LayoutOrder
				for i, diff in ipairs(difference) do
					local row = Instance.new("Frame")
					row.LayoutOrder = i
					row.Size = UDim2.new(1, 0, 0, 20)
					row.AutomaticSize = Enum.AutomaticSize.X
					row:SetAttribute("BackgroundColor3", settings().Studio.Theme:GetColor(
						if diff.token == Diff.INSERT_TOKEN then Enum.StudioStyleGuideColor.DiffTextAdditionBackground
						elseif diff.token == Diff.REMOVE_TOKEN then Enum.StudioStyleGuideColor.DiffTextDeletionBackground
						else Enum.StudioStyleGuideColor.DiffTextNoChangeBackground
					))
					local box = Instance.new("TextBox")
					box.Text = diff.str:gsub("\t", "    ")
					box.Size = UDim2.new(1, -50, 1, 0)
					box.AutomaticSize = Enum.AutomaticSize.X
					box.Position = UDim2.fromOffset(50, 0)
					box.BackgroundTransparency = 1
					box.TextEditable = false
					box.ClearTextOnFocus = false
					box.TextXAlignment = Enum.TextXAlignment.Left
					box:SetAttribute("Font", Enum.Font.SourceSansSemibold.Name)
					box:SetAttribute("TextSize", 18)
					local line = Instance.new("TextBox")
					line.Text = tostring(i)
					line.Size = UDim2.new(0, 30, 1, 0)
					line.Position = UDim2.fromOffset(20, 0)
					line.BackgroundTransparency = 1
					line.TextEditable = false
					line.ClearTextOnFocus = false
					local token = Instance.new("TextLabel")
					token.Text = diff.token
					token.Size = UDim2.new(0, 20, 1, 0)
					token.BackgroundTransparency = 1
		
					line.Parent = row
					token.Parent = row
					box.Parent = row
		
					row.Parent = container
				end
				container.Parent = diffWidget
				applyThemeWidget(diffWidget)
				diffWidget:BindToClose(function() diffWidget:Destroy() end)
				diffWidget.AncestryChanged:Wait()
			else

				local container = Instance.new("ScrollingFrame")
				container.Size = UDim2.new(1, 0, 1, -20)
				container.ScrollingDirection = Enum.ScrollingDirection.Y
				-- container.AutomaticCanvasSize = Enum.AutomaticSize.XY
				local originalFrame = Instance.new("ScrollingFrame")
				originalFrame.ScrollingDirection = Enum.ScrollingDirection.X
				originalFrame.Size = UDim2.fromScale(0.5, 1)
				originalFrame.AutomaticCanvasSize = Enum.AutomaticSize.X
				originalFrame.AutomaticSize = Enum.AutomaticSize.Y
				originalFrame.ScrollBarThickness = 0
				local newFrame = originalFrame:Clone()
				newFrame.Position = UDim2.fromScale(0.5, 0)
				local originalListlayout = Instance.new("UIListLayout")
				originalListlayout.Parent = originalFrame
				originalListlayout.SortOrder = Enum.SortOrder.LayoutOrder
				local newListLayout = originalListlayout:Clone()
				newListLayout.Parent = newFrame
	
				local scrollBar = Instance.new("Frame")
				scrollBar.Size = UDim2.new(1, 0, 0, 20)
				scrollBar:SetAttribute("BackgroundColor3", getStudiothemeColor(Enum.StudioStyleGuideColor.ScrollBarBackground))
				scrollBar.AnchorPoint = Vector2.new(0, 1)
				scrollBar.Position = UDim2.fromScale(0, 1)
				local hiddenScroll = Instance.new("Frame")
				hiddenScroll.Size = UDim2.new(1, -40, 1, 0)
				hiddenScroll.AnchorPoint = Vector2.new(0.5, 0.5)
				hiddenScroll.Position = UDim2.fromScale(0.5, 0.5)
				hiddenScroll.Active = false
				hiddenScroll.BackgroundTransparency = 1
				hiddenScroll.Parent = scrollBar
				local scroll = Instance.new("Frame")
				scroll.Active = false
				scroll.Size = UDim2.new(0, 40, 1, 0)
				scroll:SetAttribute("BackgroundColor3", getStudiothemeColor(Enum.StudioStyleGuideColor.ScrollBar))
				scroll.AnchorPoint = Vector2.new(0.5, 0)
				scroll.Parent = hiddenScroll
	
				local baseRow = Instance.new("Frame")
				baseRow.Size = UDim2.new(1, 0, 0, 20)
				baseRow.AutomaticSize = Enum.AutomaticSize.X
				local baseBox = Instance.new("TextBox")
				-- baseBox.Text = diff.str:gsub("\t", "    ")
				baseBox.Size = UDim2.new(2.2, -50, 1, 0)
				baseBox.AutomaticSize = Enum.AutomaticSize.X
				baseBox.Position = UDim2.fromOffset(50, 0)
				baseBox.BackgroundTransparency = 1
				baseBox.TextEditable = false
				baseBox.ClearTextOnFocus = false
				baseBox.TextXAlignment = Enum.TextXAlignment.Left
				baseBox:SetAttribute("Font", Enum.Font.SourceSansSemibold.Name)
				baseBox:SetAttribute("TextSize", 18)
				local baseNumber = baseBox:Clone()
				baseNumber.Size = UDim2.new(0, 40, 1, 0)
				baseNumber.Position = UDim2.new(0, 0)
				baseNumber.TextXAlignment = Enum.TextXAlignment.Right
	
				local originalLines = original:split("\n")
				local newLines = new:split("\n")
				local origCalcLine = 1
				local newCalcLine = 1
				for i, diff in ipairs(difference) do
					local originalLineNumber = table.find(originalLines, diff.str, origCalcLine)
					local newLineNumber = table.find(newLines, diff.str, newCalcLine)

					if diff.token == Diff.INSERT_TOKEN then
						if difference[i-1].token == Diff.REMOVE_TOKEN then
							newFrame:FindFirstChild(tostring(i - 1)):Destroy()
							newCalcLine -= 1
						end
						local newRow = baseRow:Clone()
						newRow.Name = i
						newRow.LayoutOrder = i
						newRow:SetAttribute("BackgroundColor3", getStudiothemeColor(Enum.StudioStyleGuideColor.DiffTextAdditionBackground))
						local newBox = baseBox:Clone()
						newBox.Text = diff.str:gsub("\t", "    ")
						local newNumber = baseNumber:Clone()
						newNumber.Text = newLineNumber

						local originalRow = baseRow:Clone()
						originalRow.Name = i
						originalRow.LayoutOrder = i
	
						newBox.Parent = newRow
						newNumber.Parent = newRow
						newRow.Parent = newFrame
						originalRow.Parent = originalFrame

						newCalcLine += 1
					elseif diff.token == Diff.REMOVE_TOKEN then
						local newRow = baseRow:Clone()
						newRow.Name = i
						newRow.LayoutOrder = i
						
						local originalRow = baseRow:Clone()
						originalRow.Name = i
						originalRow.LayoutOrder = i
						originalRow:SetAttribute("BackgroundColor3", getStudiothemeColor(Enum.StudioStyleGuideColor.DiffTextDeletionBackground))
						local originalBox = baseBox:Clone()
						originalBox.Text = diff.str:gsub("\t", "    ")
						local originalNumber = baseNumber:Clone()
						originalNumber.Text = originalLineNumber
	
						newRow.Parent = newFrame
						originalBox.Parent = originalRow
						originalNumber.Parent = originalRow
						originalRow.Parent = originalFrame

						origCalcLine += 1
					else
						if difference[i-2] and difference[i-2].token == Diff.REMOVE_TOKEN and difference[i-1].token == Diff.INSERT_TOKEN then
							originalFrame:FindFirstChild(tostring(i - 1)):Destroy()
							origCalcLine -= 1
						end
						local newRow = baseRow:Clone()
						newRow.Name = i
						newRow.LayoutOrder = i
						newRow:SetAttribute("BackgroundColor3", getStudiothemeColor(Enum.StudioStyleGuideColor.DiffTextNoChangeBackground))
						local newBox = baseBox:Clone()
						newBox.Text = diff.str:gsub("\t", "    ")
						newBox.Parent = newRow

						local originalRow = newRow:Clone()

						local newNumber = baseNumber:Clone()
						newNumber.Text = newLineNumber
						local originalNumber = baseNumber:Clone()
						originalNumber.Text = originalLineNumber

						
						newNumber.Parent = newRow
						newRow.Parent = newFrame
						originalNumber.Parent = originalRow
						originalRow.Parent = originalFrame

						newCalcLine += 1
						origCalcLine += 1
					end
				end
	
				container.CanvasSize = UDim2.new(1, 0, 0, newFrame.AbsoluteSize.Y)
				originalFrame.Parent = container
				newFrame.Parent = container
				container.Parent = diffWidget
				scrollBar.Parent = diffWidget
				
				applyThemeWidget(diffWidget)
				diffWidget:BindToClose(function() diffWidget:Destroy() end)
				
				local function getScrollPercent(mousePosX: number)
					return (mousePosX - hiddenScroll.AbsolutePosition.X) / hiddenScroll.AbsoluteSize.X
				end
				local function changeScrollPosition(num: number)
					num = math.clamp(num, 0, 1)
					scroll.Position = UDim2.fromScale(num, 0)
					newFrame.CanvasPosition = newFrame.AbsoluteCanvasSize * Vector2.new(num, 0) / 2
					originalFrame.CanvasPosition = originalFrame.AbsoluteCanvasSize * Vector2.new(num, 0) / 2
				end
				local scrollMaid = Maid.new()
				scrollMaid.InputBegan = scrollBar.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						changeScrollPosition(getScrollPercent(input.Position.X))
						scrollMaid.MouseMoved = Maid.new()
						for _, descendant in pairs(diffWidget:GetDescendants()) do
							if not descendant:IsA("GuiObject") then continue end
							scrollMaid.MouseMoved:GiveTask(descendant.InputChanged:Connect(function(input)
								if input.UserInputType == Enum.UserInputType.MouseMovement then
									changeScrollPosition(getScrollPercent(input.Position.X))
								end
							end))
						end
					end
				end)
				scrollMaid.InputEnded = scrollBar.InputEnded:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						scrollMaid.MouseMoved = nil
					end
				end)
				scrollMaid.Scrolled = scrollBar.InputChanged:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseWheel then
						changeScrollPosition(scroll.Position.X.Scale + 0.2 * input.Position.Z)
					end
				end)
				
				diffWidget.AncestryChanged:Wait()
				scrollMaid:Destroy()
			end
		end
	end
	
	label.Text = ("Accept changes to %s?"):format(moduleName)
	widget.Enabled = true
	local acceptChanges = bind.Event:Wait()
	
	widget:Destroy()
	return acceptChanges, new
end

local function updateModule(moduleName: string)
	assert(PATHS[moduleName], ("Module %s is not currently implemented for updating"):format(moduleName))
	
	local parent = getForkedFolder()
	for _, name in pairs(DEPENDS[moduleName]) do
		parent = grabModule(name, parent)
	end
	local module = grabModule(moduleName, parent)

	local date = ClientTrackerAPI.getLastCommitDate(moduleName)
	if Env("alwaysUpdate") or module:GetAttribute("LastUpdate") ~= date then
		local r, e = ClientTrackerAPI.attemptGetScriptSource(moduleName)
		if not r then error(("Failed to grab script from Roblox Client Tracker, error: %s"):format(e)) end
		if not Env("alwaysUpdate") then
			local acceptChanges, edited = createDifferencePrompt(module.Source, r, moduleName)
			if not acceptChanges then return end
			r = edited
		end
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
	if PluginCurrentlyProcessing then return end
	PluginCurrentlyProcessing = true
	for name, _ in pairs(PATHS) do
		updateModule(name)
	end
	PluginCurrentlyProcessing = false
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
	local updateButton = container:FindFirstChild("Update")
	updateButton.Text = if module then "Update" else "Grab"
	
	updateButton.Activated:Connect(function()
		if PluginCurrentlyProcessing then return end
		PluginCurrentlyProcessing = true
		updateModule(name)
		PluginCurrentlyProcessing = false
		lastUpdate.Text = getForkedFolder():FindFirstChild(name, true):GetAttribute("LastUpdate") or "unknown"
		updateButton.Text = "Update"
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
	StarterPlayerScripts.DescendantRemoving:Connect(function(descendant)
		if descendant.Name == name then
			lastUpdate.Text = "unknown"
			updateButton.Text = "Grab"
		end
	end)
end

applyThemeWidget(widget)

local openMenu = toolbar:CreateButton("Toggle Menu", "View and update specific modules", scriptIcon)
openMenu.ClickableWhenViewportHidden = true
openMenu.Click:Connect(function() widget.Enabled = not widget.Enabled end)

local openEnv = toolbar:CreateButton("Environment", "View and change current environment variables", scriptIcon)
openEnv.ClickableWhenViewportHidden = true
openEnv.Click:Connect(function()
	pcall(function()
		plugin:OpenScript(game:GetService("AnalyticsService"):FindFirstChild("RobloxPSU_Environment"))
	end)
end)