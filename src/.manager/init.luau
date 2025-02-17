--[[

    $$\      $$\                 $$\           $$\           $$\      $$\
    $$$\    $$$ |                $$ |          $$ |          $$$\    $$$ |
    $$$$\  $$$$ | $$$$$$\   $$$$$$$ |$$\   $$\ $$ | $$$$$$\  $$$$\  $$$$ | $$$$$$\  $$$$$$$\   $$$$$$\   $$$$$$\   $$$$$$\   $$$$$$\
    $$\$$\$$ $$ |$$  __$$\ $$  __$$ |$$ |  $$ |$$ |$$  __$$\ $$\$$\$$ $$ | \____$$\ $$  __$$\  \____$$\ $$  __$$\ $$  __$$\ $$  __$$\
    $$ \$$$  $$ |$$ /  $$ |$$ /  $$ |$$ |  $$ |$$ |$$$$$$$$ |$$ \$$$  $$ | $$$$$$$ |$$ |  $$ | $$$$$$$ |$$ /  $$ |$$$$$$$$ |$$ |  \__|
    $$ |\$  /$$ |$$ |  $$ |$$ |  $$ |$$ |  $$ |$$ |$$   ____|$$ |\$  /$$ |$$  __$$ |$$ |  $$ |$$  __$$ |$$ |  $$ |$$   ____|$$ |
    $$ | \_/ $$ |\$$$$$$  |\$$$$$$$ |\$$$$$$  |$$ |\$$$$$$$\ $$ | \_/ $$ |\$$$$$$$ |$$ |  $$ |\$$$$$$$ |\$$$$$$$ |\$$$$$$$\ $$ |
    \__|     \__| \______/  \_______| \______/ \__| \_______|\__|     \__| \_______|\__|  \__| \_______| \____$$ | \_______|\__|
    By @crusherfire & modified by @thecasualdev                                                         $$\   $$ |
                                                                                                        \$$$$$$  |
                                                                                                         \______/

    ModuleManager is just a fancy name for a module loader,
    The purpose of a rewrite was so I could open it up and have a better understanding if I ever wished to expand on it.

    original: https://create.roblox.com/store/asset/17428442767

--]]

local SETTINGS = {
	FOLDER_SEARCH_DEPTH = 1,
	VERBOSE_LOADING = false,
	WAIT_FOR_SERVER = true,
}

local Local = {}
local Shared = {}

-- Fetch Service
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Variables
Shared.Tracker = {
	LOAD = {},
	INIT = {},
	STRT = {},
}

Shared.TrackerForActors = {
	LOAD = {},
	INIT = {},
	STRT = {},
}

local IsClient = RunService:IsClient()
local ActorForServer = script.ActorForServer
local ActorForClient = script.ActorForClient

local ACTOR_PARENT = if IsClient then Players.LocalPlayer.PlayerScripts else ServerScriptService

local PRINT_IDENTIFIER = if IsClient then "[C]" else "[S]"
local LOADED_IDENTIFIER = if IsClient then "Client" else "Server"

-- Main Function

function Shared.Start(container: Instance)
	local start_time = tick()

	if IsClient and SETTINGS.WAIT_FOR_SERVER and not workspace:GetAttribute("ServerLoaded") then
		workspace:GetAttributeChangedSignal("ServerLoaded"):Wait()
	end

	if not RunService:IsStudio() and SETTINGS.VERBOSE_LOADING then
		warn("!!WARNING!! -- VERBOSE LOADING STILL ENABLED -- !!WARNING!!")
	end

	if SETTINGS.VERBOSE_LOADING then
		Local.Warn("LOADING MODULES")
		Local.RecursiveSearch(container, 0, SETTINGS.FOLDER_SEARCH_DEPTH, Local.LoadModule)

		Local.Warn("INITIALIZING MODULES")
		for module, _ in Shared.Tracker.INIT do
			Local.InitializeModule(Shared.Tracker.LOAD[module], module)
		end

		Local.Warn("STARTING MODULES")
		for module, _ in Shared.Tracker.STRT do
			Local.StartModule(Shared.Tracker.LOAD[module], module)
		end

		Local.Warn(`{LOADED_IDENTIFIER:upper()} FINISHED LOADING`)
	else
		Local.RecursiveSearch(container, 0, SETTINGS.FOLDER_SEARCH_DEPTH, Local.LoadModule)

		for module, _ in Shared.Tracker.INIT do
			Local.InitializeModule(Shared.Tracker.LOAD[module], module)
		end

		for module, _ in Shared.Tracker.STRT do
			Local.StartModule(Shared.Tracker.LOAD[module], module)
		end
	end

	Local.Print(
		`{LOADED_IDENTIFIER} successfully loaded {Local.CountDictionary(Shared.Tracker.LOAD)} modules, it {Local.Time(
			start_time,
			tick()
		)}`
	)
	workspace:SetAttribute(`{LOADED_IDENTIFIER}Loaded`, true)
end

-- Private Functions

function Local.LoadModule(module: ModuleScript)
	local start_time = tick()

	if module:GetAttribute("Parallel") then
		local new_actor: Actor = if IsClient then ActorForClient:Clone() else ActorForServer:Clone()
		local actor_script = new_actor:FindFirstChildWhichIsA("BaseScript")

		Local.Print(module, module.Name, actor_script)

		actor_script.Name = `Required{module.Name}`
		new_actor.Parent = ACTOR_PARENT

		if not actor_script:GetAttribute("Loaded") then
			actor_script:GetAttributeChangedSignal("Loaded"):Wait()
		end

		new_actor:SendMessage("RequireModule", module)

		if SETTINGS.VERBOSE_LOADING then
			Local.Print(("Loading PARALLEL module '%s'"):format(module.Name))
		end

		if not actor_script:GetAttribute("Required") then
			actor_script:GetAttributeChangedSignal("Required"):Wait()
		end

		local end_time = tick()

		if SETTINGS.VERBOSE_LOADING then
			if actor_script:GetAttribute("Errored") then
				Local.Warn(`>> Failed to load PARALLEL module {module.Name}`, Local.Time(start_time, end_time))
			else
				Local.Print(`>> Loaded PARALLEL module {module.Name}`, Local.Time(start_time, end_time))
			end
		end

		Shared.TrackerForActors.LOAD[module] = new_actor

		Shared.Tracker.LOAD[module] = true
		Shared.Tracker.INIT[module] = true
		Shared.Tracker.STRT[module] = true

		return
	end

	if SETTINGS.VERBOSE_LOADING then
		Local.Print(("Loading module %q"):format(module.Name))
	end

	local success, response = pcall(function()
		local LoadedModule = require(module)

		Shared.Tracker.LOAD[module] = LoadedModule

		if LoadedModule.Init then
			Shared.Tracker.INIT[module] = false
		end
		if LoadedModule.Start then
			Shared.Tracker.STRT[module] = false
		end
	end)

	local end_time = tick()

	if not SETTINGS.VERBOSE_LOADING then
		return
	end

	if success then
		Local.Print(`>> Loaded module {module.Name}`, Local.Time(start_time, end_time))
	else
		Local.Warn(`>> Failed to load module {module.Name} got response: {response}`, Local.Time(start_time, end_time))
	end
end

function Local.InitializeModule(loaded_module, module: ModuleScript)
	local start_time = tick()

	if Shared.TrackerForActors.LOAD[module] then
		local actor_script = Shared.TrackerForActors.LOAD[module]:FindFirstChildWhichIsA("BaseScript")
		Shared.TrackerForActors.LOAD[module]:SendMessage("InitModule")

		if SETTINGS.VERBOSE_LOADING then
			Local.Print(("Initializing PARALLEL module '%s'"):format(actor_script.Name))
		end

		if not actor_script:GetAttribute("Initialized") then
			actor_script:GetAttributeChangedSignal("Initialized"):Wait()
		end

		if SETTINGS.VERBOSE_LOADING then
			if actor_script:GetAttribute("Errored") then
				Local.Warn(`>> Failed to init PARALLEL module {actor_script.Name}`, Local.Time(start_time, tick()))
			else
				Local.Print(`>> Initialized PARALLEL module {actor_script.Name}`, Local.Time(start_time, tick()))
			end
		end

		return
	end

	if not loaded_module.Init then
		return
	end

	if SETTINGS.VERBOSE_LOADING then
		Local.Print(("Initializing module '%s'"):format(module.Name))
	end

	local success, response = pcall(function()
		loaded_module:Init()
		Shared.Tracker.INIT[module] = true
	end)

	if not SETTINGS.VERBOSE_LOADING then
		return
	end

	if success then
		Local.Print(`>> Initialized module {module.Name}`, Local.Time(start_time, tick()))
	else
		Local.Warn(`>> Failed to init module {module.Name} got response: {response}`, Local.Time(start_time, tick()))
	end
end

function Local.StartModule(loaded_module, module: ModuleScript)
	local start_time = tick()

	if Shared.TrackerForActors.LOAD[module] then
		local actor_script = Shared.TrackerForActors.LOAD[module]:FindFirstChildWhichIsA("BaseScript")
		Shared.TrackerForActors.LOAD[module]:SendMessage("StartModule")

		if SETTINGS.VERBOSE_LOADING then
			Local.Print(("Starting PARALLEL module '%s'"):format(actor_script.Name))
		end

		if not actor_script:GetAttribute("Started") then
			actor_script:GetAttributeChangedSignal("Started"):Wait()
		end

		if SETTINGS.VERBOSE_LOADING then
			if actor_script:GetAttribute("Errored") then
				Local.Warn(`>> Failed to start PARALLEL module {actor_script.Name}`, Local.Time(start_time, tick()))
			else
				Local.Print(`>> Started PARALLEL module {actor_script.Name}`, Local.Time(start_time, tick()))
			end
		end

		return
	end

	if not loaded_module.Start then
		return
	end

	if SETTINGS.VERBOSE_LOADING then
		Local.Print(("Starting module '%s'"):format(module.Name))
	end

	local success, response = pcall(function()
		loaded_module:Start()
		Shared.Tracker.STRT[module] = true
	end)

	if not SETTINGS.VERBOSE_LOADING then
		return
	end

	if success then
		Local.Print(`>> Started module {module.Name}`, Local.Time(start_time, tick()))
	else
		Local.Warn(`>> Failed to start module {module.Name} got response: {response}`, Local.Time(start_time, tick()))
	end
end

-- RecursiveSearch is exactly what it says on the box.
-- A simple loop checks what type of instance it is, and the current search depth.
-- If it is a File, it checks the current depth and will determine
-- If it is a ModuleScript, it runs the function defined by callback (LoadModule function)
function Local.RecursiveSearch(
	container: Instance,
	current_depth: number,
	max_depth: number,
	callback: (module: ModuleScript) -> nil
)
	for _, child: Instance in container:GetChildren() do
		if child:IsA("Folder") then
			if current_depth >= max_depth then
				continue
			end
			Local.RecursiveSearch(child, current_depth + 1, max_depth, callback)
		elseif child:IsA("ModuleScript") then
			callback(child)
		end
	end
end

-- Custom print functions to make the console organised
function Local.Print(...)
	print(PRINT_IDENTIFIER, ...)
end
function Local.Warn(...)
	warn(PRINT_IDENTIFIER, ...)
end

function Local.Time(start_time: number, end_time: number)
	return ("took %.3fms"):format(end_time - start_time)
end

function Local.CountDictionary(dictionary)
	local count = 0

	for _, _ in pairs(dictionary) do
		count += 1
	end

	return count
end

return Shared
