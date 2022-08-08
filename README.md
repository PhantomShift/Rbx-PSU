# Rbx-PSU
Roblox Player Script Updater (Rbx PSU), a simple plugin for grabbing the latest versions of Roblox client modules

This plugin was created because, for whatever reason, a recent Roblox update has forcefully closed off access to the Camera module unless you fork the code yourself (see [here](https://devforum.roblox.com/t/recent-issue-with-player-camera-module/1911851)), which I personally found to be an inconvenience. Admittedly it's a somewhat minor inconvenience but still an inconvenience nonetheless, and sends us developers conflicting signals about whether or not their updated PlayerModule API is meant to be used at all.

The plugin is a relatively simple tool, grabbing the latest versions of the Player, Camera and Control modules from the [Roblox Client Tracker](https://github.com/MaximumADHD/Roblox-Client-Tracker) if outdated and a small macro for generating a new PlayerScriptsLoader to enable the use of the grabbed scripts. I may add support for more modules in the future if requested or I need the functionality myself.

The plugin itself is freely available [here](https://www.roblox.com/library/10517423170/Player-Script-Updater), but if you prefer to see the code yourself and even make edits to it (feel free to do so), the plugin is self-contained in the `PlayerScriptsUpdater.lua` file. If you aren't familiar with loading plugin scripts locally, open up the script in Studio, right click, and select "Save as Local Plugin..." and save. The plugin will become immediately available to use.
