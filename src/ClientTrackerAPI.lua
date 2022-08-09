local Http = game:GetService("HttpService")

local API = {}

API.BASE_URL = "https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/scripts/PlayerScripts/StarterPlayerScripts/"
API.API_URL = "https://api.github.com/repos/MaximumADHD/Roblox-Client-Tracker/commits?path=scripts/PlayerScripts/StarterPlayerScripts/"

API.PATHS = {
	PlayerModule = "PlayerModule.module.lua",
	CameraModule = "PlayerModule.module/CameraModule.lua",
	ControlModule = "PlayerModule.module/ControlModule.lua"
}
API.DEPENDS = {
	PlayerModule = {},
	CameraModule = {"PlayerModule"},
	ControlModule = {"PlayerModule"}
}

local MAX_ATTEMPTS = 4
local function AttemptGetAsync(url: string, nocache: boolean?, headers: any)
    local success, result
    for i = 1, MAX_ATTEMPTS do
        success, result = pcall(Http.GetAsync, Http, url, if nocache == nil then false else nocache, headers)
        if success then return result, nil end
        if result:find("HTTP 429") then return false, result end
        wait(1)
    end
end

function API.getLastCommitDate(moduleName: string) : string
	-- Can get rate limited if you do it too often;
	-- presumably you'd only be updating every once in a while, but something to keep in mind
	local result, error = AttemptGetAsync(API.API_URL..API.PATHS[moduleName], false)
	if not result then warn(error) return "unknown" end
	
	local response = Http:JSONDecode(result)
	return response[1].commit.committer.date
end

function API.attemptGetScriptSource(moduleName: string)
    return AttemptGetAsync(API.BASE_URL..API.PATHS[moduleName])
end

return API