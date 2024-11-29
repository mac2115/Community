local Workspace = game:GetService("Workspace")
local PlayerGui = game:GetService("Players").LocalPlayer
local CoreGui = game:GetService("CoreGui")
local genv = getgenv()

genv.AstLoaded = false

local loading = tick()

local SharedRequires = {}
setmetatable(SharedRequires, {
	__metatable = "Secure",
	__index = function(t, k)
		return rawget(t, k)
	end,
})

SharedRequires["Services"] = {}

SharedRequires["Services"]["Table"] = {}

SharedRequires["Services"].DumpServices = function()
	for _, service in pairs(game:GetChildren()) do
		table.insert(SharedRequires["Services"]["Table"], service)
	end
end

SharedRequires["Services"].GetService = function(name)
	for _, v in pairs(SharedRequires["Services"].Table) do
		if rawequal(name, v.ClassName) then
			return v
		end
	end
end

SharedRequires["Maid"] = {}

SharedRequires["Maid"].Cleanup = function()
	for i, v in genv.Connections do
		v:Disconnect()
	end

	SharedRequires = {}
	genv.Drawings = {}
	genv.Remotes = {}
	genv.Settings = {}
	genv.Hooks = {}
	genv.Connections = {}
	genv.States = {}
	genv.NpcList = {}
	genv.Moblist = {}
end

SharedRequires["Maid"].Setup = function()
	genv.NpcList = {}
	genv.Remotes = {}
	genv.Settings = {
		Autoparry = { Toggle = false, Delay = 0 },
		NoFallDamage = true,
		ESP = { Name = true, NameColor = Color3.fromRGB(255, 255, 255) },
		NoFog = true,
	}

	genv.Hooks = {}
	genv.States = { Tweening = false }
	genv.Connections = {}
	setmetatable(genv.Settings, {
		__metatable = "Locked",
		__index = function(t, k)
			return rawget(t, k)
		end,
	})

	setmetatable(genv.Hooks, {
		__metatable = "Locked",
		__index = function(t, k)
			return rawget(t, k)
		end,
	})

	setmetatable(genv.States, {
		__metatable = "Locked",
		__index = function(t, k)
			return rawget(t, k)
		end,
	})
	setmetatable(genv.Connections, {
		__metatable = "Locked",
		__index = function(t, k)
			return rawget(t, k)
		end,
	})
end

SharedRequires["Env"] = {}

SharedRequires["Env"].Pcall = function(func, ...)
	local c = clonefunction(pcall)
	return c
end

SharedRequires["Env"].loadstr = function(link)
	local ref = clonefunction(loadstring)
	return ref(game:HttpGet(link))()
end

SharedRequires["Env"].croutinelib = function()
	local lib = {}
	setmetatable(lib, {
		__metatable = "Locked",
		__index = function(t, k)
			return rawget(t, k)
		end,
		__newindex = function(t, k, v)
			return rawset(t, k, v)
		end,
	})

	for i, v in pairs(coroutine) do
		if type(v) == "function" then
			local c = clonefunction(v)
			rawset(lib, i, c)
		end
	end
	return lib
end

SharedRequires["Env"].getnamecallmethod = function()
	local c = clonefunction(getnamecallmethod)
	return c()
end

SharedRequires["Env"].SecureHelper = function(originalFunc, args)
	return originalFunc(unpack(args))
end

SharedRequires["Env"].SecureCall = function(originalFunc, Env, ...) -- i need to add the context changing for secure call
	local args = { ... }

	if not rawequal(type(originalFunc), "function") then
		return
	end

	if not rawequal(type(Env), "instance") then
		return SharedRequires["Env"].SecureHelper(originalFunc, args)
	end

	Env = getsenv(Env)
	setfenv(SharedRequires["Env"].SecureCall, Env)

	local result = SharedRequires["Env"].SecureHelper(originalFunc, args)
	setfenv(SharedRequires.Env.SecureHelper, {})
	return result
end

local Services = SharedRequires["Services"]
local Maid = SharedRequires["Maid"]
local LuaEnv = SharedRequires["Env"]
local croutine = LuaEnv.croutinelib()
local SecureCall = SharedRequires["Env"].SecureCall
local loadstr = SharedRequires["Env"].loadstr
local Pcall = SharedRequires["Env"].Pcall
local getcallmethod = SharedRequires["Env"].getnamecallmethod

SharedRequires["Bypasses"] = {}

Maid.Setup()

Services.DumpServices()

local Players = Services.GetService("Players")
local plr = Players.LocalPlayer

local ReplicatedStorage = Services.GetService("ReplicatedStorage")
local ReplicatedFirst = Services.GetService("ReplicatedFirst")
local RunService = Services.GetService("RunService")
local UserInputService = Services.GetService("UserInputService")
local TweenService = Services.GetService("TweenService")
local Stats = Services.GetService("Stats")
local Lighting = Services.GetService("Lighting")
local VirtualInputManager = Services.GetService("VirtualInputManager")

do -- ESP definition (Credits to Aztup for his sick ESP and math calcs!)
	local wtp_func = clonefunction(Instance.new("Camera").WorldToViewportPoint)
	local vectorToWorldSpace = CFrame.new().VectorToWorldSpace
	local getMouseLocation = clonefunction(UserInputService.GetMouseLocation)
	local lerp = Color3.new().lerp

	genv.Settings.ESP = {
		Text = false,
		TextColor = Color3.fromRGB(255, 255, 255),
		Size = 14,
		Box = false,
		BoxColor = Color3.fromRGB(255, 255, 255),
		Healthbar = false,
		Tracer = false,
		TracerColor = Color3.fromRGB(255, 255, 255),
	}

	SharedRequires["PLAYER ESP BUILDER"] = (function()
		local EntityESP = {}
		EntityESP.__index = EntityESP

		local healthBarOffsetTopRight, healthBarOffsetBottomLeft
		local healthBarValueOffsetTopRight, healthBarValueOffsetBottomLeft
		local labelOffset, tracerOffset
		local boxOffsetTopRight, boxOffsetBottomLeft

		function EntityESP.New(player)
			local self = setmetatable({}, EntityESP)

			self._player = player

			self._label = Drawing.new("Text")
			self._label.Visible = false
			self._label.Center = true
			self._label.Outline = true
			self._label.OutlineColor = Color3.fromRGB(0, 0, 0)
			self._label.Text = ""
			self._label.Size = genv.Settings.ESP.Size
			self._label.Color = genv.Settings.ESP.TextColor

			self._line = Drawing.new("Line")
			self._line.Visible = false
			self._line.Color = genv.Settings.ESP.TracerColor

			self._box = Drawing.new("Quad")
			self._box.Visible = false
			self._box.Thickness = 1
			self._box.Filled = false
			self._box.Color = genv.Settings.ESP.BoxColor

			self._healthBar = Drawing.new("Quad")
			self._healthBar.Visible = false
			self._healthBar.Thickness = 1
			self._healthBar.Filled = false
			self._healthBar.Color = Color3.fromRGB(255, 255, 255)

			self._healthBarValue = Drawing.new("Quad")
			self._healthBarValue.Visible = false
			self._healthBarValue.Thickness = 1
			self._healthBarValue.Filled = true
			self._healthBarValue.Color = Color3.fromRGB(0, 255, 0)

			return self
		end

		function EntityESP:Update()
			local camera = Workspace.CurrentCamera

			if not camera then
				self:Hide()
				return
			end

			if not self._label then
				return
			end

			if not self._player then
				return
			end

			local rootPart = self._player:FindFirstChild("HumanoidRootPart")

			local rootPartPosition = rootPart and rootPart.Position or self._player:GetPivot().Position

			local labelpos, onscreen = wtp_func(camera, rootPartPosition + labelOffset)

			if not onscreen then
				self:Hide()
				return
			end

			local text = self:Plugin()

			if not text then
				self:Hide()
				return
			end

			if genv.Settings.ESP.Text then
				self._label.Position = Vector2.new(labelpos.X, labelpos.Y)
				self._label.Visible = genv.Settings.ESP.Text
				self._label.Text = text
				self._label.Color = genv.Settings.ESP.TextColor
			else
				self._label.Visible = false
			end

			local box, healthBar, healthBarValue = self._box, self._healthBar, self._healthBarValue

			local line = self._line

			if genv.Settings.ESP.Box then
				local boxTopRight = wtp_func(camera, rootPartPosition + boxOffsetTopRight)
				local boxBottomLeft = wtp_func(camera, rootPartPosition + boxOffsetBottomLeft)

				local topRightX, topRightY = boxTopRight.X, boxTopRight.Y
				local bottomLeftX, bottomLeftY = boxBottomLeft.X, boxBottomLeft.Y

				box.Visible = true

				box.PointA = Vector2.new(topRightX, topRightY)
				box.PointB = Vector2.new(bottomLeftX, topRightY)
				box.PointC = Vector2.new(bottomLeftX, bottomLeftY)
				box.PointD = Vector2.new(topRightX, bottomLeftY)
				box.Color = genv.Settings.ESP.BoxColor
			else
				box.Visible = false
			end

			local floatHealth = self._player.Humanoid.Health
			floatHealth = math.floor(floatHealth)

			if genv.Settings.ESP.Healthbar then
				local healthBarValueHealth = (1 - (floatHealth / 100)) * 7.4

				local healthBarTopRight = wtp_func(camera, rootPartPosition + healthBarOffsetTopRight)
				local healthBarBottomLeft = wtp_func(camera, rootPartPosition + healthBarOffsetBottomLeft)

				local healthBarTopRightX, healthBarTopRightY = healthBarTopRight.X, healthBarTopRight.Y
				local healthBarBottomLeftX, healthBarBottomLeftY = healthBarBottomLeft.X, healthBarBottomLeft.Y

				local healthBarValueTopRight = wtp_func(
					camera,
					rootPartPosition + healthBarValueOffsetTopRight - self:ConvertVector(0, healthBarValueHealth, 0)
				)
				local healthBarValueBottomLeft = wtp_func(camera, rootPartPosition - healthBarValueOffsetBottomLeft)

				local healthBarValueTopRightX, healthBarValueTopRightY =
					healthBarValueTopRight.X, healthBarValueTopRight.Y
				local healthBarValueBottomLeftX, healthBarValueBottomLeftY =
					healthBarValueBottomLeft.X, healthBarValueBottomLeft.Y

				healthBar.Visible = onscreen
				healthBar.Color = Color3.fromRGB(0, 0, 0)

				healthBar.PointA = Vector2.new(healthBarTopRightX, healthBarTopRightY)
				healthBar.PointB = Vector2.new(healthBarBottomLeftX, healthBarTopRightY)
				healthBar.PointC = Vector2.new(healthBarBottomLeftX, healthBarBottomLeftY)
				healthBar.PointD = Vector2.new(healthBarTopRightX, healthBarBottomLeftY)

				healthBarValue.Visible = onscreen
				healthBarValue.Color = lerp(Color3.fromRGB(192, 57, 43), Color3.fromRGB(39, 174, 96), floatHealth / 100)

				healthBarValue.PointA = Vector2.new(healthBarValueTopRightX, healthBarValueTopRightY)
				healthBarValue.PointB = Vector2.new(healthBarValueBottomLeftX, healthBarValueTopRightY)
				healthBarValue.PointC = Vector2.new(healthBarValueBottomLeftX, healthBarValueBottomLeftY)
				healthBarValue.PointD = Vector2.new(healthBarValueTopRightX, healthBarValueBottomLeftY)
			else
				healthBar.Visible = false
				healthBarValue.Visible = false
			end

			if genv.Settings.ESP.Tracer then
				local linePosition = wtp_func(camera, rootPartPosition + tracerOffset)
				line.Visible = true

				line.From = genv.Settings.ESP.UnlockTracers and getMouseLocation(UserInputService) or self._viewportSize
				line.To = Vector2.new(linePosition.X, linePosition.Y)
				line.Color = genv.Settings.ESP.TracerColor
			else
				line.Visible = false
			end
		end

		function EntityESP:Hide()
			if not self._label then
				return
			end

			self._label.Visible = false
			self._box.Visible = false
			self._healthBar.Visible = false
			self._healthBarValue.Visible = false
			self._line.Visible = false
		end

		function EntityESP:ConvertVector(...)
			return vectorToWorldSpace(Workspace.CurrentCamera.CFrame, Vector3.new(...))
		end

		function EntityESP:Destroy()
			if not self._label then
				return
			end

			self._label:Destroy()
			self._box:Destroy()
			self._healthBar:Destroy()
			self._healthBarValue:Destroy()
			self._line:Destroy()
		end

		function EntityESP:Plugin()
			if not Players:GetPlayerFromCharacter(self._player) then
				return false
			end

			return Players:GetPlayerFromCharacter(self._player).Name
		end

		function EntityESP:CustomUpdate() end

		local function UpdateESP()
			labelOffset = EntityESP:ConvertVector(0, 3.25, 0)
			tracerOffset = EntityESP:ConvertVector(0, -4.5, 0)

			boxOffsetTopRight = EntityESP:ConvertVector(2.5, 3, 0)
			boxOffsetBottomLeft = EntityESP:ConvertVector(-2.5, -4.5, 0)

			healthBarOffsetTopRight = EntityESP:ConvertVector(-3, 3, 0)
			healthBarOffsetBottomLeft = EntityESP:ConvertVector(-3.5, -4.5, 0)

			healthBarValueOffsetTopRight = EntityESP:ConvertVector(-3.05, 2.95, 0)
			healthBarValueOffsetBottomLeft = EntityESP:ConvertVector(3.45, 4.45, 0)

			local viewportSize = Workspace.CurrentCamera.ViewportSize
			EntityESP._viewportSize = Vector2.new(viewportSize.X / 2, viewportSize.Y - 10)
		end

		RunService:BindToRenderStep("ESP_UPDATER", Enum.RenderPriority.Camera.Value, UpdateESP)

		return EntityESP
	end)()
end

local Framework = require(ReplicatedFirst.Framework)

local LoadModule = debug.getupvalue(Framework.require, 1)

local Container = debug.getupvalue(LoadModule, 1)

local Libraries = Container.Libraries

local Globals = Framework.Configs.Globals
local World = Framework.Libraries.World
local Network = Framework.Libraries.Network
local Cameras = Framework.Libraries.Cameras
local Bullets = Framework.Libraries.Bullets
local Interface = Framework.Libraries.Interface
local Resources = Framework.Libraries.Resources
local Raycasting = Framework.Libraries.Raycasting

do -- bypasses definition
	SharedRequires["Bypasses"] = (function()
		local Bypasses = {}

		function Bypasses:CrashBypass()
			local oldNamecall
			local function onNamecall(self, ...)
				if getnamecallmethod() == "GetChildren" and (self == ReplicatedFirst or self == ReplicatedStorage) then
					return task.wait(9e9)
				end

				return oldNamecall(self, ...)
			end

			oldNamecall = hookmetamethod(game, "__namecall", onNamecall)
		end

		function Bypasses:NetworkSandbox()
			local BannedReasons = { "Sorry Mate, Wrong Path :/", "Camera Report", "Ping" }

			local oldSend

			local onSend = function(self, Reason, ...)
				if table.find(BannedReasons, Reason) then
					return
				end

				local args = { ... }

				if Reason == "Character State Report" then
					if getgenv().Settings.NoSpread then
						args[2] = true
						args[7] = true
					end
				end

				return oldSend(self, Reason, unpack(args))
			end

			oldSend = hookfunction(Network.Send, onSend)
		end

		return Bypasses
	end)()

	local Bypasses = SharedRequires["Bypasses"]

	Bypasses:CrashBypass()
	Bypasses:NetworkSandbox()
end

do --ESP Handling
	local ESP_Library = SharedRequires["PLAYER ESP BUILDER"]
	local Entity_List = {}

	local unload_list = {}

	local function onNewEntity(player)
		if Players:GetPlayerFromCharacter(player) then
			local esp_entity = ESP_Library.New(player)

			unload_list[player] = function()
				esp_entity:Destroy()
				table.remove(Entity_List, table.find(Entity_List, esp_entity))
			end

			table.insert(Entity_List, esp_entity)
		end
	end

	local function onRemove(player)
		if unload_list[player] then
			unload_list[player]()
			unload_list[player] = nil
		end
	end

	Workspace.Characters.ChildAdded:connect(onNewEntity)
	Workspace.Characters.ChildRemoved:connect(onRemove)

	for i, v in pairs(Workspace.Characters:GetChildren()) do
		if v == plr.Character then
			continue
		end

		onNewEntity(v)
	end

	local last_update = 0
	local interval = 10 / 1000

	RunService.RenderStepped:Connect(function()
		if tick() - last_update > interval then
			for _, entity in Entity_List do
				entity:Update()
			end
		end
	end)
end

do -- Silent aim Builder
	genv.Settings.SilentAim = { Toggle = false, AimBone = "Head", UseFov = false }

	local wtp_func = clonefunction(Instance.new("Camera").WorldToViewportPoint)

	function NoRecoil()
		local getFireImpulse = debug.getupvalue(Bullets.Fire, 6)

		if not getFireImpulse then
			return plr:Kick("No GetFireImpulse func ")
		end

		local oldGetImpulse

		local onGetImpulse = function(self, ...)
			if getgenv().Settings.NoRecoil then
				return 0
			end

			return oldGetImpulse(self, ...)
		end

		oldGetImpulse = hookfunction(getFireImpulse, onGetImpulse)
	end

	NoRecoil()

	function Nospread()
		local getSpredAngle = debug.getupvalue(Bullets.Fire, 1)
		debug.setupvalue(Bullets.Fire, 1, function(Character, Camera, Weapon, ...)
			local OldMoveState = Character.MoveState
			local OldZooming = Character.Zooming
			local OldFirstPerson = Camera.FirstPerson
			local OldSpread = Weapon.RecoilData.SpreadBase

			if genv.Settings.NoSpread then
				Character.Movestate = "Walking"
				Character.Zooming = true
				Camera.FirstPerson = true

				setreadonly(Weapon.RecoilData, false)
				Weapon.RecoilData.SpreadBase = 0
				setreadonly(Weapon.RecoilData, true)

				local result = getSpredAngle(Character, Camera, Weapon, ...)

				Character.MoveState = OldMoveState
				Character.Zooming = OldZooming
				Camera.FirstPerson = OldFirstPerson
				setreadonly(Weapon.RecoilData, false)
				Weapon.RecoilData.SpreadBase = OldSpread
				setreadonly(Weapon.RecoilData, true)

				return result
			end
			return getSpredAngle(Character, Camera, Weapon, ...)
		end)
	end

	Nospread()

	function SilentAim()
		local function GetClosestPlayer()
			if not plr.Character or not plr.Character:FindFirstChild("HumanoidRootPart") then
				return
			end

			local max = genv.Settings.SilentAim.UseFov and genv.Setitngs.SilentAim.Fov or math.huge
			local find

			local camera = Workspace.CurrentCamera

			local screen_center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)

			if not camera then
				return
			end

			for _, player in pairs(Workspace.Characters:GetChildren()) do
				if not player then
					continue
				end

				local pos, onscreen = wtp_func(camera, player.HumanoidRootPart.Position)

				if not onscreen then
					continue
				end

				local vector = Vector2.new(pos.X, pos.Y)

				local dist = (vector - screen_center).Magnitude

				if dist < max then
					max = dist
					find = player
				end
			end

			return find
		end

		local function Predict(object) -- to be solved yet
			local predicted_position
			return predicted_position
		end

		local FireFunc = Bullets.Fire

		local oldFire

		local function onFire(self, ...)
			local target = GetClosestPlayer()

			local args = { ... }

			local origin = args[4]

			if genv.Settings.SilentAim.Toggle and target and target.Head then
				args[5] = (target.Head.Position - origin).Unit
			end

			return oldFire(self, unpack(args))
		end

		oldFire = hookfunction(FireFunc, onFire)
	end

	SilentAim()
end

do --//Zombie stuff
	genv.Settings.AntiZombie = true

	function AntiZombie()
		if
			not plr.Character
			or not plr.Character:FindFirstChild("HumanoidRootPart")
			or not genv.Settings.AntiZombie
		then
			return
		end

		local function GetClosest()
			local max = 250
			local find
			local dist
			for i, v in pairs(Workspace.Zombies.Mobs:GetChildren()) do
				if v:FindFirstChild("HumanoidRootPart") and v.PrimaryPart then
					dist = (plr.Character.HumanoidRootPart.Position - v.HumanoidRootPart.Position).Magnitude

					if dist < max then
						find = v
						max = dist
					end
				end
			end
			return find
		end

		local zombie = GetClosest()

		if not zombie then
			return
		end

		if isnetworkowner(zombie.PrimaryPart) then
			zombie.PrimaryPart.Anchored = true
		end
	end

	table.insert(genv.Connections, RunService.Heartbeat:connect(AntiZombie))
end

--//Movement

local Noclip
do
	genv.Settings.Speed = { Speed = 20 }

	--xz Vector3.new(1,0,1)
	function Speed(Delta)
		if not plr.Character or not genv.Settings.Speed.Toggle then
			return
		end

		plr.Character.HumanoidRootPart.CFrame += plr.Character.Humanoid.MoveDirection * Delta * genv.Settings.Speed.Speed
	end

	local bodyparts = { "Head", "HumanoidRootPart", "Left Arm", "Right Arm", "LeftHand", "RightHand", "Torso" }

	Noclip = function()
		while true do
			task.wait()
			if not plr.Character then
				break
			end

			if not genv.Settings.Noclip then
				for i, v in pairs(plr.Character:GetChildren()) do
					if table.find(bodyparts, v.Name) then
						v.CanCollide = true
					end
				end
				break
			end

			for i, v in pairs(plr.Character:GetChildren()) do
				if table.find(bodyparts, v.Name) then
					v.CanCollide = not genv.Settings.Noclip
				end
			end
		end
	end

	table.insert(genv.Connections, RunService.Heartbeat:connect(Speed))
end

--//Ui library

local library = loadstring(game:GetObjects("rbxassetid://7657867786")[1].Source)()
local Wait = library.subs.Wait -- Only returns if the GUI has not been terminated. For 'while Wait() do' loops

local Window = library:CreateWindow({
	Name = "Apocalypse Rising",
	Themeable = {
		Info = "Discord Server: VzYTJ7Y",
		Background = "",
	},
})

local Main = Window:CreateTab({
	Name = "Main",
})

local Section = Main:CreateSection({
	Name = "Main",
})

Section:AddToggle({
	Name = "Silent Aim Toggle",
	Flag = "",
	Callback = function(state)
		genv.Settings.SilentAim.Toggle = state
	end,
})

Section:AddToggle({
	Name = "NoSpread Toggle",
	Flag = "",
	Callback = function(state)
		genv.Settings.NoSpread = state
	end,
})

Section:AddToggle({
	Name = "NoRecoil Toggle",
	Flag = "",
	Callback = function(state)
		genv.Settings.NoRecoil = state
	end,
})

Section:AddDropdown({
	Name = "Aimbone",
	List = { "Head", "HumanoidRootPart", "RightArm", "LeftArm", "LeftLeg", "RightLeg" },
	Multi = false,
	Callback = function(option)
		genv.Settings.SilentAim.AimBone = option
	end,
})

Section:AddToggle({
	Name = "Usefov Toggle",
	Flag = "",
	Callback = function(state)
		genv.Settings.SilentAim.UseFov = state
	end,
})

Section:AddSlider({
	Name = "Fov",
	Flag = "",
	Value = 25,
	Precise = 2,
	Min = 0,
	Max = 360,
	Format = function(state)
		genv.Settings.SilentAim.Fov = state
		return state
	end,
})

local Section = Main:CreateSection({
	Name = "Movement",
})

-- Section:AddToggle({
-- 	Name = "Speed Toggle",
-- 	Flag = "",
-- 	Callback = function(state)
-- 		genv.Settings.Speed.Toggle = state
-- 	end,
-- })

-- Section:AddSlider({
-- 	Name = "Speed",
-- 	Flag = "",
-- 	Value = 18,
-- 	Precise = 2,
-- 	Min = 0,
-- 	Max = 100,
-- 	Format = function(state)
-- 		genv.Settings.Speed.Speed = state
-- 		return state
-- 	end,
-- })

Section:AddToggle({
	Name = "Noclip Toggle",
	Flag = "",
	Callback = function(state)
		genv.Settings.Noclip = state
		Noclip()
	end,
})

local Section = Main:CreateSection({
	Name = "Misc",
})

Section:AddToggle({
	Name = "Anti Zombie Toggle",
	Flag = "",
	Callback = function(state)
		genv.Settings.AntiZombie = state
	end,
})

local Visuals = Window:CreateTab({
	Name = "Visuals",
})

local Section = Visuals:CreateSection({
	Name = "Main",
})

Section:AddToggle({
	Name = "Text ESP Toggle",
	Flag = "",
	Callback = function(state)
		genv.Settings.ESP.Text = state
	end,
})

Section:AddColorPicker({
	Name = "Text Color",
	Callback = function(value)
		genv.Settings.ESP.TextColor = value
	end,
})

Section:AddToggle({
	Name = "Healthbar ESP Toggle",
	Flag = "",
	Callback = function(state)
		genv.Settings.ESP.Healthbar = state
	end,
})

Section:AddToggle({
	Name = "Box ESP Toggle",
	Flag = "",
	Callback = function(state)
		genv.Settings.ESP.Box = state
	end,
})

Section:AddColorPicker({
	Name = "Box Color",
	Callback = function(value)
		genv.Settings.ESP.BoxColor = value
	end,
})

Section:AddToggle({
	Name = "Tracer ESP Toggle",
	Flag = "",
	Callback = function(state)
		genv.Settings.ESP.Tracer = state
	end,
})

Section:AddToggle({
	Name = "Unlock Tracer Toggle",
	Flag = "",
	Callback = function(state)
		genv.Settings.ESP.UnlockTracers = state
	end,
})

Section:AddColorPicker({
	Name = "Tracer Color",
	Callback = function(value)
		genv.Settings.ESP.TracerColor = value
	end,
})
