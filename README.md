# Rbx-PSU
Roblox Player Script Updater (Rbx PSU), a simple plugin for grabbing the latest versions of Roblox client modules

This plugin was created because, for whatever reason, a recent Roblox update has forcefully closed off access to the Camera module unless you fork the code yourself (see [here](https://devforum.roblox.com/t/recent-issue-with-player-camera-module/1911851)), which I personally found to be an inconvenience. Admittedly it's a somewhat minor inconvenience but still an inconvenience nonetheless, and sends us developers conflicting signals about whether or not their updated PlayerModule API is meant to be used at all.

The plugin is a relatively simple tool, grabbing the latest versions of the Player, Camera and Control modules from the [Roblox Client Tracker](https://github.com/MaximumADHD/Roblox-Client-Tracker) if outdated and a small macro for generating a new PlayerScriptsLoader to enable the use of the grabbed scripts. I may add support for more modules in the future if requested or I need the functionality myself.

The plugin itself is freely available [here](https://www.roblox.com/library/10517423170/Player-Script-Updater), but if you prefer to see the code yourself and even make edits to it (feel free to do so), the plugin is contained in the `src` directory. Once you have the folder in Studio, right click and select "Save as Local Plugin..."

There are two main ways of getting the folder:
### Studio Commandline
Copy and paste the following code into Studio's command line interface. Requires Http access, though the plugin itself requires it as well so this should be on anyways. This will create the folder with all the scripts within in `ServerStorage`.
```lua
local Http = game:GetService("HttpService")
local response = Http:GetAsync("https://api.github.com/repos/PhantomShift/Rbx-PSU/contents/src")
local tbl = Http:JSONDecode(response)

local targetFolder = Instance.new("Folder")
targetFolder.Name = "PlayerScriptUpdater"
targetFolder.Parent = game.ServerStorage

for _, file in ipairs(tbl) do
    if file.type == "file" then
        local split = file.name:split(".")
        if split[2] == "meta" then continue end
        local scr = if split[2] == "server" then Instance.new("Script") elseif split[2] == "client" then Instance.new("LocalScript") else Instance.new("ModuleScript")
        if scr:IsA("LocalScript") then scr.Disabled = true end

        scr.Name = file.name:split(".")[1]
        scr.Source = Http:GetAsync(file.download_url)
        scr.Parent = targetFolder
    end
end
```
### Rojo
If you have [rojo cli](https://github.com/rojo-rbx/rojo) installed, you can just clone the repo and build it using the project json.
```bash
git clone https://github.com/PhantomShift/Rbx-PSU
cd Rbx-PSU
rojo build rbxpsu.project.json --output "PlayerScriptUpdater.rbxmx"
```
Alternatively, if using the VSCode extension, open the shortcuts, run `>Rojo: Build with project file...` and select `rbxpsu.project.json`.