local Utils = require(script.Parent.Utils)

local TEXT_GUIS = {
	TextButton = true,
	TextLabel = true,
	TextBox = true
}

local function setThemeColors(object: GuiObject)
	if not object:IsA("GuiObject") then return end
	if object:GetAttribute("BackgroundColor3") then
		object.BackgroundColor3 = object:GetAttribute("BackgroundColor3")
	elseif object:IsA("GuiButton") then
		object.BackgroundColor3 = settings().Studio.Theme:GetColor(Enum.StudioStyleGuideColor.MainButton)
		object.BorderColor3 = settings().Studio.Theme:GetColor(Enum.StudioStyleGuideColor.ButtonBorder)
		if not object:FindFirstChildOfClass("UICorner") then
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.25, 0)
			corner.Parent = object
		end
	else	
		object.BackgroundColor3 = settings().Studio.Theme:GetColor(Enum.StudioStyleGuideColor.MainBackground)
		object.BorderColor3 = settings().Studio.Theme:GetColor(Enum.StudioStyleGuideColor.Border)
	end
	if object:IsA("TextButton") then
		object.TextColor3 = settings().Studio.Theme:GetColor(Enum.StudioStyleGuideColor.ButtonText)
		object.TextSize = 18
		object.Font = Enum.Font.SourceSansSemibold
		object.TextStrokeColor3 = Color3.new()
		object.TextStrokeTransparency = 0.85
	elseif TEXT_GUIS[object.ClassName] then
		if object:GetAttribute("Font") then object.Font = Enum.Font[object:GetAttribute("Font")] end
		object.TextColor3 = settings().Studio.Theme:GetColor(Enum.StudioStyleGuideColor.MainText)
	end
	if object:GetAttribute("TextSize") then object.TextSize = object:GetAttribute("TextSize") end
end

local function applySyncThemeColors(object: GuiObject)
	local function applyTheme()
		setThemeColors(object)
		for _, guiObject: GuiObject in pairs(object:GetDescendants()) do
			if not guiObject:IsA("GuiObject") then continue end
			setThemeColors(guiObject)
		end
	end
	applyTheme()

	local connection = settings().Studio.ThemeChanged:Connect(applyTheme)
	coroutine.wrap(function()
		Utils.waitForCondition(object.AncestryChanged, function()
			return if object.Parent then true else false
		end)
		connection:Disconnect()
	end)()
end

local function applyThemeWidget(toApply: DockWidgetPluginGui)
	for _, child in pairs(toApply:GetChildren()) do
		if not child:IsA("GuiObject") then continue end
		applySyncThemeColors(child)
	end
	toApply.ChildAdded:Connect(applySyncThemeColors)
end

return applyThemeWidget