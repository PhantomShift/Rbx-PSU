local Player = game.Players.LocalPlayer
local PlayerScripts = Player.PlayerScripts

local Forked = PlayerScripts:WaitForChild("_Forked")

local function getNameTo(descendant: Instance, ancestor: Instance)
	local result = descendant.Name
	if descendant == ancestor then return descendant end
	descendant = descendant.Parent
	while descendant and descendant ~= game and descendant ~= ancestor do
		result = descendant.Name.."."..result
		descendant = descendant.Parent
	end
	
	return result
end

for _, descendant in pairs(PlayerScripts:GetDescendants()) do
	local forked = Forked:FindFirstChild(descendant.Name, true)
	if forked and getNameTo(forked, Forked) == getNameTo(descendant, PlayerScripts) then
		for _, child in pairs(descendant:GetChildren()) do
			if not forked:FindFirstChild(child.Name) then
				child.Parent = forked
			end
		end
	end
end

for _, child in pairs(Forked:GetChildren()) do
	local original = PlayerScripts:FindFirstChild(child.Name)
	if original then original:Destroy() end
	child.Parent = PlayerScripts
	require(child)
end