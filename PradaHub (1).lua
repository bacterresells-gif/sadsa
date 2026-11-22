local genv = _G
pcall(function()
if getgenv then
genv = getgenv() or _G
end
end)
for _, name in ipairs({ "BloomInstance" }) do
local prev = genv[name]
if prev and prev.unload then
pcall(prev.unload)
end
end
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local UIS = UserInputService
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local clock = os.clock
local Running = true
local Connections = {}
local function track(connection)
Connections[#Connections + 1] = connection
return connection
end
local function clamp(v, a, b)
if v < a then return a end
if v > b then return b end
return v
end
local Config = {
ui = { scale = 1.0, alpha = 0.75, keybind = Enum.KeyCode.RightShift, visible = true },
aimbot = { enabled = false, smoothness = 0.28, range = 70, onlyWithBall = true },
autoShoot = { enabled = false, method = "Auto", range = 55, cooldown = 0.9, holdTime = 0.55,
holdWhenContested = true, maxContest = 100, threeOnly = true,
zeroContest = true, rightMoment = true },
autoGreen = { enabled = true, rainbow = false, mode = "Meter", timing = 520, adaptive = true, target = 1.43,
compensatePing = true, perfect = -1.5, meterType = "Vertical", vTime = 0.52, vPing = 0.05, holdMax = 530, leadMs = 0, highFps = true },
dribble = { enabled = false, speed = 34, glide = false, fast = false, rate = 8, macro = { enabled = false, preset = "Crossover", trigger = 40, cooldown = 1.1 } },
pins = { green = false, guard = false, rebound = false, block = false, aim = false, arc = false, glide = false, fast = false, speed = false, size = 46 },
autoGuard = { enabled = false, speed = 21, distance = 6.5, predict = 0.18, pressure = 0.4, range = 25 },
autoSteal = { enabled = false, range = 7.5, cooldown = 0.45, smart = true },
defVis = { target = false, reach = false },
antiSteal = { enabled = false, range = 9, rate = 0.16, speed = 34 },
autoPlay = { enabled = false, shotDistance = 24, speed = 30, driveTime = 5, dribbleMoves = true, avoid = true,
comboMoves = 3, comboDelay = 0.28, shootContest = 0, showLine = true },
rimBackoff = { enabled = true, distance = 6, farDistance = 16, speed = 18 },
chase = { enabled = false, speed = 34, predict = 0.25, maxDistance = 120, steal = true, stealRange = 7.5 },
openSpot = { enabled = false, maxMove = 40, cooldown = 1.2, extra = 1, delay = 1.5 },
contest = { enabled = true, outline = false, closeDist = 5, farDist = 14 },
misc = { hideName = false },
offense = { style = "Smart", curve = true, findOpen = true, lateClock = true, lateClockSec = 14,
midRange = 15, dunkRange = 8, smartDunk = true },
block = { enabled = false, ignoreFakes = true, fakeWait = 0.25, chaseDunks = true, follow = true, speed = 30, jumpRange = 9, range = 90 },
rebound = { enabled = false, boxOut = true, speed = 34, range = 45, tp = true },
move = { stamina = false, build99 = false, noSlow = false, floor = 22, boost = false, boostSpeed = 30, antiAnkle = false,
speedMode = "Normal", speedPct = 50, jumpShot = false, jumpHeight = 4 },
afk = { enabled = false, tp = true, blacktop = false, park = false, mode = "Blacktop 1v1", reexecute = true, loader = "BloomHub.lua", interval = 6 },
farm = { enabled = false, openDist = 16, autoDefense = true, autoReady = true, antiAfk = true, speed = 24,
shootRange = 24, forceAfter = 6, stamina = true },
visual = { brightness = 0, saturation = 0 },
hud = { showStats = true, showGrade = false },
fb = { sound = false, flash = false, hit = false },
music = { source = "", name = "", volume = 0.6, video = true, list = "", sel = "", loop = "Off" },
theme = { accent = "Default", background = "Black" },
openMeter = { enabled = false, scale = 1 },
tag = { enabled = false, text = "script in bio" },
arc = { enabled = false },
overlay = { watermark = false, list = false },
keys = { green = "", guard = "", rebound = "", aim = "", block = "" },
slots = { slot = "Slot 1" },
match = { only = false },
users = { show = true, share = true },
settings = { name = "default", autoLoad = false, autoName = "", hideName = false, invisible = false },
perf = { lowGraphics = false, flatten = false, fpsCap = false, fpsValue = 60, lowCpu = false, mobile = false, pingTrim = false },
}
local Contest = { percent = 0, dist = nil }
local function contestPercent(dist)
local close = Config.contest.closeDist
local far = math.max(Config.farm.enabled and Config.farm.openDist or Config.contest.farDist, Config.contest.farDist, close + 1)
if dist <= close then return 100 end
if dist >= far then return 0 end
return math.floor((1 - (dist - close) / (far - close)) * 100 + 0.5)
end
local Record, Off, Def, Mv, Afk, Match, notify, Scan, Farm
local function openLimit()
if Off and Off.late() then return 100 end
if Config.autoShoot.zeroContest then return 0 end
return Config.autoPlay.shootContest
end
local Backoff = { target = nil }
local AutoPlay = { startedAt = 0, lastTick = 0, lastMove = 0, comboLeft = 0, flip = 1,
comboDir = Vector3.new(0, 0, -1), inRange = false }
local function envFn(name)
local ok, fn = pcall(function()
return genv[name]
end)
if ok and type(fn) == "function" then
return fn
end
ok, fn = pcall(function()
return getfenv()[name]
end)
if ok and type(fn) == "function" then
return fn
end
return nil
end
local function mouseDown()
local fn = envFn("mouse1press")
if fn then
pcall(fn)
return true
end
return pcall(function()
local vim = game:GetService("VirtualInputManager")
vim:SendMouseButtonEvent(0, 0, 0, true, game, 0)
end)
end
local function mouseUp()
local fn = envFn("mouse1release")
if fn then
pcall(fn)
return true
end
return pcall(function()
local vim = game:GetService("VirtualInputManager")
vim:SendMouseButtonEvent(0, 0, 0, false, game, 0)
end)
end
local function getCharacter()
local chars = Workspace:FindFirstChild("Characters")
if chars then
local char = chars:FindFirstChild(LocalPlayer.Name)
if char and char:IsA("Model") then
return char
end
end
return LocalPlayer.Character
end
local function getRoot()
local char = getCharacter()
if not char then return nil end
return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
end
local function getHumanoid()
local char = getCharacter()
if not char then return nil end
return char:FindFirstChildOfClass("Humanoid")
end
local function getProxy()
local proxy = Workspace:FindFirstChild("ProxyCharacter")
if not proxy then return nil end
return proxy, proxy:FindFirstChild("MovementVelocity"), proxy:FindFirstChild("MovementGyro")
end
local function getState()
local proxy = Workspace:FindFirstChild("ProxyCharacter")
if proxy and proxy:GetAttribute("CanMove") ~= nil then
return proxy
end
local char = getCharacter()
if not char then return nil end
if char:GetAttribute("CanMove") ~= nil or char:GetAttribute("WalkSpeed") ~= nil then
return char
end
for _, child in ipairs(char:GetChildren()) do
if child:GetAttribute("CanMove") ~= nil or child:GetAttribute("WalkSpeed") ~= nil then
return child
end
end
return nil
end
local function setGoal(goal)
if not goal then return end
local state = getState()
if not state then return end
local existing = state:GetAttribute("Goal")
local value = CFrame.new(goal.Position)
if typeof(existing) == "Vector3" then
value = goal.Position
end
genv.__BloomGoal = goal.Position
pcall(function() state:SetAttribute("Goal", value) end)
end
local RemotePaths = {
shoot = { "InputService", "Shoot" },
steal = { "InputService", "Steal" },
dribble = { "InputService", "Dribble" },
sprint = { "InputService", "Sprint" },
holdG = { "InputService", "HoldG" },
moveDirection = { "InputService", "MoveDirection" },
feedback = { "InterfaceService", "ShowFeedback" },
block = { "InputService", "Block" },
jump = { "InputService", "Jump" },
greenWindow = { "MeterService", "UpdateGreenWindow" },
meterRegister = { "MeterService", "RegisterPacket" },
output = { "InputService", "Output" },
}
local RemoteCache = {}
local RemoteMiss
local function remoteRoot()
local aero = ReplicatedStorage:FindFirstChild("Aero")
return aero and aero:FindFirstChild("AeroRemoteServices")
end
local function resolveRemote(key)
local cached = RemoteCache[key]
if cached and cached.Parent then return cached end
local path = RemotePaths[key]
if not path then return nil end
local node = remoteRoot()
for _, name in ipairs(path) do
node = node and node:FindFirstChild(name)
if not node then break end
end
if not node then
RemoteMiss = RemoteMiss or {}
if clock() - (RemoteMiss[key] or -10) < 3 then return nil end
RemoteMiss[key] = clock()
for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
if d.Name == path[#path] and (d:IsA("RemoteEvent") or d:IsA("UnreliableRemoteEvent") or d:IsA("RemoteFunction")) then
node = d
break
end
end
if not node then return nil end
end
if node:IsA("RemoteEvent") or node:IsA("UnreliableRemoteEvent") or node:IsA("RemoteFunction") then
RemoteCache[key] = node
return node
end
return nil
end
local function remote(key)
return resolveRemote(key)
end
local function fireRemote(key, ...)
local rem = resolveRemote(key)
if not rem then return false end
local args = { ... }
local ok = pcall(function()
if rem:IsA("RemoteFunction") then
rem:InvokeServer(unpack(args))
elseif rem:IsA("BindableEvent") then
rem:Fire(unpack(args))
else
rem:FireServer(unpack(args))
end
end)
return ok
end
local function scanRemotes()
table.clear(RemoteCache)
for key in pairs(RemotePaths) do
resolveRemote(key)
end
end
task.spawn(function()
for _ = 1, 60 do
if remoteRoot() then break end
task.wait(0.5)
end
pcall(scanRemotes)
end)
local Ball = { part = nil, owner = nil, held = false, at = 0 }
local Extra = {}
local function getAttributesFolder(char)
return char and char:FindFirstChild("Attributes")
end
local function ballValueOf(char)
local holder = getAttributesFolder(char)
local value = holder and holder:FindFirstChild("Basketball")
if value and value:IsA("ObjectValue") then
return value.Value
end
return nil
end
local function heldPhysics(char)
local hrp = char and char:FindFirstChild("HumanoidRootPart")
local weld = hrp and hrp:FindFirstChild("Basketball")
if weld and weld:IsA("Motor6D") and weld.Part1 then
return weld.Part1
end
return nil
end
local function hasBall()
local char = getCharacter()
if not char then return false end
local held = heldPhysics(char) or ballValueOf(char)
if held then
Ball.part = held
Ball.owner = LocalPlayer
Ball.held = true
return true
end
local state = getState()
if state and state:GetAttribute("Basketball") then
Ball.owner = LocalPlayer
Ball.held = true
return true
end
return false
end
local SameTeamCache = { at = -10, count = 0 }
local function sameTeam(model, myTeam)
local now = clock()
if now - SameTeamCache.at > 0.5 then
SameTeamCache.at = now
local chars = Workspace:FindFirstChild("Characters")
SameTeamCache.count = chars and #chars:GetChildren() or 0
end
if SameTeamCache.count <= 2 then return false end
local theirTeam = model:GetAttribute("Team")
return myTeam ~= nil and theirTeam ~= nil and myTeam == theirTeam
end
local function findHandlerRaw()
local chars = Workspace:FindFirstChild("Characters")
if not chars then return nil end
local me = getCharacter()
local myTeam = me and me:GetAttribute("Team")
local others = {}
local anyHolder
local myRoot = getRoot()
local limit = (Match and Match.state == "Match") and 120 or Config.autoGuard.range
for _, model in ipairs(chars:GetChildren()) do
local theirRoot = model:IsA("Model") and model:FindFirstChild("HumanoidRootPart")
if myRoot and theirRoot and (theirRoot.Position - myRoot.Position).Magnitude > limit then
elseif model:IsA("Model") and model.Name ~= LocalPlayer.Name and not sameTeam(model, myTeam) then
others[#others + 1] = model
local held = heldPhysics(model) or ballValueOf(model)
if not held then
local deep = model:FindFirstChild("Basketball", true)
if deep and deep:IsA("Motor6D") and deep.Part1 then held = deep.Part1 end
end
if held or model:GetAttribute("Basketball") then
local player = Players:GetPlayerFromCharacter(model) or Players:FindFirstChild(model.Name)
return model, player, held
end
elseif model:IsA("Model") and model.Name ~= LocalPlayer.Name and not anyHolder then
local held = heldPhysics(model) or ballValueOf(model)
if held or model:GetAttribute("Basketball") then anyHolder = { model, held } end
end
end
if anyHolder and not (Match and Match.state == "Match") then
local model = anyHolder[1]
return model, Players:GetPlayerFromCharacter(model) or Players:FindFirstChild(model.Name), anyHolder[2]
end
if not hasBall() then
local folder = Workspace:FindFirstChild("Basketballs")
local candidates = folder and folder:GetChildren() or {}
if Ball.part and Ball.part.Parent then candidates[#candidates + 1] = Ball.part end
for _, item in ipairs(candidates) do
local ball = item:IsA("BasePart") and item or item:FindFirstChildWhichIsA("BasePart", true)
if ball then
for _, model in ipairs(others) do
local root = model:FindFirstChild("HumanoidRootPart")
if root and (ball.Position - root.Position).Magnitude < 5 then
local player = Players:GetPlayerFromCharacter(model) or Players:FindFirstChild(model.Name)
return model, player, ball
end
end
end
end
end
return nil
end
local HandlerCache = { at = -10, value = nil }
local function findHandler()
local now = clock()
if now - HandlerCache.at > 0.1 then
HandlerCache.at = now
HandlerCache.value = findHandlerRaw()
end
local value = HandlerCache.value
if value and not value.Parent then return nil end
return value
end
local Hoops = { list = {}, at = 0 }
local function scanHoops()
local list = {}
local folder = Workspace:FindFirstChild("Hoops")
if folder then
for _, model in ipairs(folder:GetChildren()) do
local goal = model:FindFirstChild("Goal", true)
if goal and goal:IsA("BasePart") then
table.insert(list, goal)
end
end
end
if #list == 0 then
for _, inst in ipairs(Workspace:GetDescendants()) do
if inst:IsA("BasePart") and inst.Name == "Goal" then
table.insert(list, inst)
if #list >= 8 then break end
end
end
end
Hoops.list = list
Hoops.at = clock()
end
local function hoopList()
if clock() - Hoops.at > 5 or #Hoops.list == 0 then
scanHoops()
end
return Hoops.list
end
local function nearestHoop(fromPos)
local best, bestDist = nil, math.huge
for _, part in ipairs(hoopList()) do
if part.Parent then
local dist = (part.Position - fromPos).Magnitude
if dist < bestDist then
bestDist = dist
best = part
end
end
end
return best, bestDist
end
local function hoopTarget(goal)
if not goal then return nil end
return goal.Position
end
local function scanWorld()
if clock() - Hoops.at > 5 or #Hoops.list == 0 then
scanHoops()
end
local char = getCharacter()
local held = char and (heldPhysics(char) or ballValueOf(char))
if held then
Ball.part = held
Ball.owner = LocalPlayer
Ball.held = true
Ball.at = clock()
return
end
Ball.held = false
Ball.owner = nil
local handlerChar, handlerPlayer, handlerBall = findHandler()
if handlerChar then
Ball.part = handlerBall
Ball.owner = handlerPlayer
Ball.at = clock()
return
end
local hrp = char and char:FindFirstChild("HumanoidRootPart")
local folder = Workspace:FindFirstChild("Basketballs")
local best, bestDist = nil, math.huge
if folder and hrp then
for _, ball in ipairs(folder:GetChildren()) do
if ball:IsA("BasePart") then
local dist = (ball.Position - hrp.Position).Magnitude
if dist < bestDist then
bestDist = dist
best = ball
end
end
end
end
Ball.part = best
Ball.at = clock()
end
task.spawn(function()
while Running do
task.wait(0.5)
pcall(scanWorld)
if remoteRoot() and not resolveRemote("shoot") then
pcall(scanRemotes)
end
end
end)
local Attack = { goal = nil, source = "unknown", locked = false }
local function setAttack(goal, source)
if not goal or Attack.locked then return end
Attack.goal = goal
Attack.source = source
end
local function shootHoop(fromPos)
local goal = Attack.goal
if goal and goal.Parent then
return goal, (goal.Position - fromPos).Magnitude
end
return nearestHoop(fromPos)
end
function Attack.status()
local goal = Attack.goal
if goal and goal.Parent then
local holder = goal.Parent
local name = (holder and holder ~= Workspace and holder.Name) or goal.Name
return "Attack hoop: " .. name .. "  (" .. Attack.source .. (Attack.locked and ", locked" or "") .. ")"
end
return "Attack hoop: not known yet. Take one normal shot, or stand at the hoop you attack and press Lock."
end
local Green = {
minTarget = 0.5,
maxTarget = 1.7,
lastIndex = nil,
shots = 0,
perfect = 0,
connected = false,
history = {},
streak = 0,
types = {},
lastType = nil,
liveType = nil,
lastReleaseAt = nil,
dirty = false,
file = "bloom_green_v2.json",
words = { "shot", "shoot", "jump", "layup", "lay", "dunk", "fade", "hook", "float",
"finger", "scoop", "pullup", "stepback", "turnaround", "spin", "pump" },
}
function Green.record(key)
local rec = Green.types[key]
if not rec then
local base = Green.types[string.match(key, "^(.-|[^|]*)|p") or ""]
or Green.types[string.match(key, "^(.-)|") or ""]
local prefix, num = string.match(key, "^(.-|[^|]*|p)(%-?%d+)$")
if prefix then
local bestRec, bestGap = nil, math.huge
for k, other in pairs(Green.types) do
local n = string.match(k, "^" .. prefix:gsub("%p", "%%%0") .. "(%-?%d+)$")
if n and other.perfect > 0 and math.abs(tonumber(n) - tonumber(num)) < bestGap then
bestRec, bestGap = other, math.abs(tonumber(n) - tonumber(num))
end
end
if bestRec then base = bestRec end
end
if base then
rec = { target = base.target, gain = 1, dir = 0, shots = 0, perfect = 0 }
Green.types[key] = rec
Green.dirty = true
return rec
end
local sum, n = 0, 0
for _, other in pairs(Green.types) do
if other.perfect > 0 then
sum += other.target
n += 1
end
end
rec = {
target = (n > 0) and clamp(sum / n, Green.minTarget, Green.maxTarget) or Config.autoGreen.target,
gain = 1, dir = 0, shots = 0, perfect = 0,
}
Green.types[key] = rec
Green.dirty = true
end
return rec
end
function Green.learnedCount()
local n = 0
for _ in pairs(Green.types) do n += 1 end
return n
end
function Green.save()
local ok = pcall(function()
local out = {}
for key, rec in pairs(Green.types) do
out[key] = { target = rec.target, shots = rec.shots, perfect = rec.perfect }
end
writefile(Green.file, HttpService:JSONEncode(out))
end)
if ok then Green.dirty = false end
end
function Green.load()
pcall(function()
if isfile(Green.file) then
local data = HttpService:JSONDecode(readfile(Green.file))
for key, saved in pairs(data) do
if type(key) == "string" and type(saved) == "table" and tonumber(saved.target) then
Green.types[key] = {
target = clamp(tonumber(saved.target), Green.minTarget, Green.maxTarget),
gain = 1, dir = 0,
shots = tonumber(saved.shots) or 0,
perfect = tonumber(saved.perfect) or 0,
}
end
end
end
end)
end
function Green.zone()
local hrp = getRoot()
local goal, dist = nil, nil
if hrp then goal, dist = shootHoop(hrp.Position) end
if not goal then return "any" end
if dist <= 10 then return "close" end
if dist < Config.autoPlay.shotDistance - 1.5 then return "mid" end
return "three"
end
function Green.keyed(t)
if not t then return nil end
return t .. "|" .. Green.zone()
end
function Green.shotType()
local char = getCharacter()
if not char then return nil end
local animator = char:FindFirstChildWhichIsA("Animator", true)
if animator then
local bestName, bestWeight = nil, -1
for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
local name = string.lower(track.Name)
local isShot = false
for _, word in ipairs(Green.words) do
if string.find(name, word, 1, true) then
isShot = true
break
end
end
if isShot and not track.Looped and track.WeightCurrent >= bestWeight then
bestName, bestWeight = track.Name, track.WeightCurrent
end
end
if bestName and bestName ~= "" then
return bestName
end
end
for key, value in pairs(char:GetAttributes()) do
local k = string.lower(key)
if type(value) == "string" and value ~= ""
and (string.find(k, "shot", 1, true) or string.find(k, "shoot", 1, true)) then
local v = string.lower(value)
if v ~= "shooting" and v ~= "none" and v ~= "false" then
return key .. ":" .. value
end
end
end
return nil
end
Green.load()
task.spawn(function()
while Running do
task.wait(15)
if Green.dirty then
Green.save()
end
end
end)
local function getMeter()
local char = getCharacter()
if not char then return nil end
local hrp = char:FindFirstChild("HumanoidRootPart")
local head = char:FindFirstChild("Head")
local want = string.lower((Config.autoGreen and Config.autoGreen.meterType or ""):gsub("%s%d+$", ""))
local active, verticalFallback, fallback = nil, nil, nil
for _, holder in ipairs({ hrp, head }) do
if holder then
for _, child in ipairs(holder:GetChildren()) do
local lname = string.lower(child.Name)
if lname:find("meter", 1, true) then
local hasNeedle = child:GetAttribute("Active") ~= nil or child:FindFirstChild("FillGradient", true)
if child:GetAttribute("Active") == true then active = active or child end
if lname == "verticalmeter" then verticalFallback = verticalFallback or child end
if hasNeedle and want ~= "" and lname:find(want, 1, true) then fallback = fallback or child end
end
end
end
end
if active then return active end
if fallback then return fallback end
if verticalFallback then return verticalFallback end
do
local pg = LocalPlayer:FindFirstChild("PlayerGui")
local c2 = Green.guiScan
if not c2 then c2 = { at = -10 } Green.guiScan = c2 end
if c2.obj and c2.obj.Parent then return c2.obj end
if pg and clock() - c2.at > 0.7 then
c2.at, c2.obj = clock(), nil
for _, d in ipairs(pg:GetDescendants()) do
if d:GetAttribute("Active") ~= nil and string.lower(d.Name):find("meter", 1, true) then
c2.obj = d
break
end
end
end
if c2.obj then return c2.obj end
end
local cache = Green.meterScan
if not cache then cache = { at = -10 } Green.meterScan = cache end
if cache.obj and cache.obj.Parent then return cache.obj end
if clock() - cache.at > 0.5 then
cache.at, cache.obj = clock(), nil
for _, d in ipairs(char:GetDescendants()) do
if (d:IsA("BillboardGui") or d:IsA("SurfaceGui") or d:IsA("Frame")) and string.lower(d.Name):find("meter", 1, true)
and d:GetAttribute("Active") ~= nil then
cache.obj = d
break
end
end
end
return cache.obj
end
local function meterActive()
local meter = getMeter()
if meter and meter:GetAttribute("Active") == true then return true, meter end
local char = getCharacter()
if char and char:GetAttribute("Action") == "Shooting" and char:GetAttribute("meterOffset") ~= nil then
return true, meter
end
if char then
for k, v in pairs(char:GetAttributes()) do
if v == true and string.lower(k):find("meter", 1, true) then return true, meter end
end
if char:GetAttribute("Action") == "Shooting" and Config.autoGreen.meterType ~= "Vertical" then
return true, meter
end
end
return false, meter
end
local function meterMag()
local char = getCharacter()
if not char then return nil end
local offset = char:GetAttribute("meterOffset")
if typeof(offset) == "Vector2" or typeof(offset) == "Vector3" then
return math.abs(offset.Y)
end
if typeof(offset) == "number" then
return math.abs(offset)
end
local m = getMeter()
local fg = m and m:FindFirstChild("FillGradient", true)
if fg then return math.abs(fg.Offset.Y) end
for k, v in pairs(char:GetAttributes()) do
local lk = string.lower(k)
if lk ~= "meteroffset" and (lk:find("meter", 1, true) or lk:find("needle", 1, true)) then
if typeof(v) == "Vector2" or typeof(v) == "Vector3" then return math.abs(v.Y) end
if typeof(v) == "number" then return math.abs(v) end
end
end
if m then
for _, d in ipairs(m:GetDescendants()) do
if d:IsA("UIGradient") then
local ln = string.lower(d.Name)
if ln:find("fill", 1, true) or ln:find("needle", 1, true) or ln:find("bar", 1, true) then
return math.abs(d.Offset.Y ~= 0 and d.Offset.Y or d.Offset.X)
end
end
end
end
return nil
end
local function greenWindow()
local meter = getMeter()
local green = meter and meter:FindFirstChild("Meter_Green")
local gradient = green and green:FindFirstChildOfClass("UIGradient")
if not gradient then return nil end
local start, finish = nil, nil
for _, key in ipairs(gradient.Transparency.Keypoints) do
if key.Value >= 0.99 then
if not start then start = key.Time end
finish = key.Time
end
end
return start, finish
end
local function applyGreenFeedback(index)
local timing = tonumber(index)
if not timing then return end
Green.lastIndex = timing
if Config.hud.showGrade and notify then
local g = math.floor(timing)
pcall(notify, g == 5 and "Perfect release" or (g < 5 and "Early release" or "Late release"),
string.format("grade %d  (%d / %d perfect)", g, Green.perfect or 0, Green.shots or 0))
end
table.insert(Green.history, math.floor(timing))
if #Green.history > 8 then table.remove(Green.history, 1) end
local rec = Green.record(Green.lastType or "default")
rec.shots += 1
if math.floor(timing) == 5 then rec.perfect += 1 end
do return end
Green.dirty = true
if not Config.autoGreen.adaptive then return end
if (Green.lastDev or 0) > 0.04 and math.floor(timing) ~= 5 then return end
local g = math.floor(timing)
local T = Green.lastUsed or rec.target
local W = clamp(Green.winVal or 0.34, 0.1, 0.6)
local stepSize = W / 9
local e = 5 - g
local pct
if Green.lastLog and clock() - (Green.lastLogAt or -10) < 2 then
pct = tonumber(string.match(Green.lastLog, "Percentage%s*%-%s*([%d%.]+)"))
end
Green.kappa = Green.kappa or 1
if rec.prevT and rec.prevG and math.abs(T - rec.prevT) > 0.008 and g ~= rec.prevG then
local later = T > rec.prevT
local gradeUp = g > rec.prevG
Green.evid = clamp((Green.evid or 0) + ((later == gradeUp) and 1 or -1), -6, 6)
end
rec.prevT, rec.prevG = T, g
if rec.prevE and rec.prevE ~= 0 and e ~= 0 then
if e * rec.prevE < 0 then
Green.kappa = clamp(Green.kappa * 0.7, 0.3, 3)
elseif math.abs(e) >= math.abs(rec.prevE) then
Green.kappa = clamp(Green.kappa * 1.25, 0.3, 3)
end
end
rec.prevE = e
if g == 5 then
rec.target = clamp(T, Green.minTarget, Green.maxTarget)
rec.locked, rec.miss = true, 0
Green.streak += 1
return
end
Green.streak = 0
local delta
if pct then
local err = (1 - clamp(pct, 0, 100) / 100) * (W / 2)
if pct <= 8 then err = (W / 2) * 1.3 end
delta = (e > 0 and 1 or -1) * err * 1.15 * Green.kappa
else
delta = e * stepSize * Green.kappa
if math.abs(e) == 1 then delta = delta * 0.6 end
end
if (Green.evid or 0) <= -3 then delta = -delta end
local nextT = clamp(T + delta, Green.minTarget, Green.maxTarget)
rec.target = nextT
local parent = string.match(Green.lastType or "", "^(.-)|")
if parent then
local base = Green.record(parent)
base.target = clamp(base.target + (nextT - T) * 0.6, Green.minTarget, Green.maxTarget)
end
end
task.spawn(function()
for _ = 1, 120 do
if not Running then return end
local feedback = resolveRemote("feedback")
if feedback then
local connection = feedback.OnClientEvent:Connect(function(character, _contest, timing)
if typeof(character) == "Instance" then
local char = getCharacter()
if char and character ~= char then return end
end
if not Green.lastReleaseAt or clock() - Green.lastReleaseAt > 4 then
local t = tonumber(timing)
if t then
Green.lastIndex = t
table.insert(Green.history, math.floor(t))
if #Green.history > 8 then table.remove(Green.history, 1) end
end
return
end
Green.lastReleaseAt = nil
Green.shots += 1
if Record then pcall(Record.onShot) end
Green.stat = Green.stat or { streak = 0, best = 0 }
if tonumber(timing) and math.floor(tonumber(timing)) == 5 then
Green.stat.streak += 1
Green.stat.best = math.max(Green.stat.best, Green.stat.streak)
else
Green.stat.streak = 0
end
if tonumber(timing) == 5 then
Green.perfect += 1
if Extra.onPerfect then pcall(Extra.onPerfect) end
if Record then Record.add("perfect") end
end
task.delay(0.15, function()
pcall(function()
local info = Green.relInfo or {}
Green.shotLog = Green.shotLog or {}
table.insert(Green.shotLog, string.format(
"%s | grade %s | target %.4f | rel mag %.4f | peak %.4f | vel %.3f | t %.3f | win %s | ping %dms | kappa %.2f | %s",
tostring(Green.lastType), tostring(timing), Green.lastUsed or 0, info.mag or 0, info.peak or 0,
info.vel or 0, info.elapsed or 0, tostring(Green.winVal), math.floor((Green.pingAvg or 0.05) * 1000 + 0.5),
Green.kappa or 1, tostring(Green.lastLog or "") .. " | " .. tostring(info.note or "fallback")))
while #Green.shotLog > 60 do table.remove(Green.shotLog, 1) end
writefile("bloom_shots.txt", table.concat(Green.shotLog, "\n"))
end)
applyGreenFeedback(timing)
end)
end)
track(connection)
Green.connected = true
break
end
task.wait(0.5)
end
end)
local Shot = { pressedAt = 0, active = false, sawShooting = false, session = nil }
task.spawn(function()
local function mine(char)
return typeof(char) == "Instance" and char == getCharacter()
end
for _ = 1, 120 do
if not Running then return end
local reg, upd = resolveRemote("meterRegister"), resolveRemote("greenWindow")
local out = resolveRemote("output")
if reg and upd then
track(reg.OnClientEvent:Connect(function(char, _kind, size)
if mine(char) and type(size) == "number" then Green.winVal = size end
end))
track(upd.OnClientEvent:Connect(function(char, size)
if mine(char) and type(size) == "number" then Green.winVal = size end
end))
if out then
track(out.OnClientEvent:Connect(function(kind, text)
if kind == "Log" and type(text) == "string" and string.find(text, "Shot Feedback", 1, true) then
Green.lastLog, Green.lastLogAt = text, clock()
end
end))
end
return
end
task.wait(0.5)
end
end)
local Stats = game:GetService("Stats")
local function pingSeconds()
local ok, value = pcall(function()
return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
end)
if ok and type(value) == "number" then
return value / 1000
end
return 0.05
end
local function faceGoalNow(goal)
if not goal then return end
local proxy, _, gyro = getProxy()
if not proxy or not gyro then return end
local flat = Vector3.new(goal.Position.X, proxy.Position.Y, goal.Position.Z)
if (flat - proxy.Position).Magnitude < 0.1 then return end
gyro.CFrame = CFrame.lookAt(proxy.Position, flat)
end
local function pressShoot()
local hrp = getRoot()
local goal = hrp and shootHoop(hrp.Position)
if goal then
setGoal(goal)
faceGoalNow(goal)
end
if Config.autoShoot.method == "Input" then
mouseDown()
elseif not fireRemote("shoot", { Shoot = true, Input = "E" }) then
mouseDown()
end
Shot.pressedAt = clock()
Shot.active = true
Shot.sawShooting = false
end
local function releaseShoot()
if Config.autoShoot.method == "Input" then
mouseUp()
else
fireRemote("shoot", { Shoot = false, Input = "E" })
fireRemote("shoot", { Shoot = false })
mouseUp()
pcall(function()
game:GetService("VirtualInputManager"):SendKeyEvent(false, Enum.KeyCode.E, false, game)
end)
end
Shot.active = false
end
function Green.release(session)
Green.lastType = session.shotType or "default"
Green.lastReleaseAt = clock()
Green.lastUsed, Green.window = session.target, nil
Green.relInfo = { elapsed = clock() - session.t0, mag = session.last, vel = session.vel or 0, peak = session.peak,
geo = session.geo, note = session.geo and string.format("geo c=%.4f bias=%.3f", session.geo, Green.cBias or 0) or nil }
Green.lastDev = math.abs(pingSeconds() - (Green.pingAvg or pingSeconds()))
releaseShoot()
session.released = true
session.relAt, session.retries = clock(), 0
end
function Green.pingSmooth()
local p = pingSeconds()
Green.pingAvg = Green.pingAvg and (Green.pingAvg * 0.85 + p * 0.15) or p
return Green.pingAvg
end
function Green.geoTarget()
local m = getMeter()
if not m then return nil end
local gf, fill = m:FindFirstChild("Meter_Green"), m:FindFirstChild("Meter_Fill")
local gg = gf and gf:FindFirstChildOfClass("UIGradient")
local fg = fill and fill:FindFirstChildOfClass("UIGradient")
if not gg or not fg then return nil end
local te, seen = nil, false
for _, kp in ipairs(gg.Transparency.Keypoints) do
if kp.Value < 0.5 then seen = true elseif seen and not te then te = kp.Time end
end
if not te then return nil end
local c = 1.4537 + 1.4 * (te - 0.342)
if c < 0.5 or c > 2.2 then return nil end
return c
end
function Green.ready()
if not Config.autoGreen.enabled then return false, "off" end
if not resolveRemote("shoot") then return false, "no shoot remote" end
if pingSeconds() > 0.45 then return false, "ping too high" end
return true
end
Green.perfects = { Vertical = -1.5, ["Funnel 1"] = -1.5, ["Funnel 2"] = -1.5, Bat = -1.5, Pill = -1.5, Hoop = -1.5, Rocket = -1.5, Roblox = -1.5 }
function Green.perfectValue()
return Green.perfects[Config.autoGreen.meterType] or Config.autoGreen.perfect
end
local function greenStep()
if not Config.autoGreen.enabled then
Shot.session = nil
Green.liveType = nil
return
end
local now = clock()
local active = meterActive()
local mag = meterMag()
local s = Shot.session
if not active then
if s and now - s.t0 > 0.08 then
Shot.session, Shot.active, Green.liveType = nil, false, nil
end
return
end
if not s then
s = { t0 = now, last = mag or 0, peak = mag or 0, ct = now, armed = false, retries = 0,
shotType = Green.keyed(Green.shotType()) }
Shot.session = s
end
if s.released then
if now - s.relAt > 0.12 and s.retries < 12 then
s.retries += 1
s.relAt = now
releaseShoot()
end
return
end
local elapsed = now - s.t0
if elapsed < 0.3 then
local t = Green.keyed(Green.shotType())
if t then s.shotType = t end
end
Green.liveType = s.shotType
if mag then
if s.cm == nil then
s.cm, s.ct = mag, now
elseif math.abs(mag - s.cm) > 1e-6 then
local gap = now - s.ct
if gap > 0.0005 then
local v = (mag - s.cm) / gap
s.vel = s.vel and (s.vel * 0.5 + v * 0.5) or v
end
s.cm, s.ct = mag, now
end
s.last = mag
if mag > s.peak then s.peak = mag end
if mag < 1.5 and mag > (Green.peak or 0) then Green.peak = mag end
end
do
local log = Green.shotLog
if not log or log.s ~= s then
log = { s = s, lines = { "meter " .. tostring(Config.autoGreen.meterType) } }
Green.shotLog = log
end
if #log.lines < 160 then
log.lines[#log.lines + 1] = string.format("%.3f  needle=%s", elapsed, mag and string.format("%.3f", mag) or "none")
end
end
local ping = Green.pingSmooth()
local limit = Config.autoGreen.holdMax / 1000
if Config.autoGreen.compensatePing then limit -= ping * 0.5 end
if Config.autoGreen.mode == "Timing" then limit = math.min(limit, Config.autoGreen.timing / 1000) end
if elapsed >= limit then
Green.release(s)
return
end
if not mag then return end
if Config.autoGreen.mode == "Timing" then return end
local netPing = ping
pcall(function() netPing = LocalPlayer:GetNetworkPing() end)
local target = (-Green.perfectValue()) - 0.15 - netPing - Config.autoGreen.leadMs / 1000
s.target, s.geo = target, nil
if mag < target then s.armed = true end
if s.armed and mag >= target and elapsed >= 0.03 then
if Green.shotLog then
table.insert(Green.shotLog.lines, string.format("RELEASE at %.3f needle=%.3f target=%.3f", elapsed, mag, target))
end
Green.release(s)
end
end
track(RunService.Heartbeat:Connect(function()
if not Running or not Config.autoGreen.enabled then return end
local active = meterActive()
if Shot.session or Shot.active or active then
local ok, err = pcall(greenStep)
if not ok and not Green.errShown then
Green.errShown = true
warn("[Bloom] auto green: " .. tostring(err))
end
end
local now = clock()
if active then
Green.wdStart = Green.wdStart or now
local since = now - Green.wdStart
local rel = Green.wdRel or 0
if since > Config.autoGreen.holdMax / 1000 + 0.12 and now - rel > 0.4 and (Green.wdCount or 0) < 3 then
local s2 = Shot.session
if not (s2 and s2.released and now - (s2.relAt or 0) < 0.4) then
Green.wdRel, Green.wdCount = now, (Green.wdCount or 0) + 1
pcall(releaseShoot)
end
end
else
Green.wdStart, Green.wdCount = nil, 0
end
end))
local Aim = { goal = nil, lastSet = 0 }
local function aimStep(dt)
if not Config.aimbot.enabled then return end
local proxy, _, gyro = getProxy()
if not proxy then return end
if Config.aimbot.onlyWithBall and not hasBall() then return end
local goal, dist = shootHoop(proxy.Position)
if not goal then return end
if dist > Config.aimbot.range then return end
if Aim.goal ~= goal or clock() - Aim.lastSet > 0.2 then
setGoal(goal)
Aim.goal = goal
Aim.lastSet = clock()
end
local target = hoopTarget(goal)
if not target then return end
local flat = Vector3.new(target.X, proxy.Position.Y, target.Z)
if (flat - proxy.Position).Magnitude < 0.1 then return end
local desired = CFrame.lookAt(proxy.Position, flat)
local alpha = clamp(dt / math.max(Config.aimbot.smoothness, 0.02), 0, 1)
if gyro then gyro.CFrame = gyro.CFrame:Lerp(desired, alpha) end
local cur = proxy.CFrame
proxy.CFrame = cur:Lerp(CFrame.new(cur.Position) * desired.Rotation, alpha)
end
track(RunService.RenderStepped:Connect(function(dt)
if Running and Config.aimbot.enabled then pcall(aimStep, dt) end
end))
local nearestOther
local Move = { originalMaxForce = nil, forced = false, stepAt = -10, rampStart = nil }
local function forceMove(direction, speed)
local proxy, mover, gyro = getProxy()
if not proxy then return end
if mover then
if not Move.originalMaxForce then Move.originalMaxForce = mover.MaxForce end
mover.MaxForce = Vector3.new(0, 0, 0)
mover.Velocity = Vector3.new(0, 0, 0)
end
local now = clock()
if not Move.forced then Move.rampStart = now end
Move.forced = true
local dt = (now - Move.stepAt < 0.1) and clamp(now - Move.stepAt, 0.004, 0.05) or 0.016
Move.stepAt = now
local ramp = clamp((now - (Move.rampStart or now)) / 0.18, 0.4, 1)
local cf = proxy.CFrame
local pos = cf.Position + direction * (clamp(speed, 0, 100) * ramp * dt)
proxy.CFrame = CFrame.new(pos) * (cf - cf.Position)
if gyro then gyro.CFrame = CFrame.lookAt(pos, pos + direction) end
end
local function stopGlide()
if not Move.forced then return end
local _, mover = getProxy()
if mover and Move.originalMaxForce then mover.MaxForce = Move.originalMaxForce end
Move.forced, Move.rampStart = false, nil
end
local Dribble = { dirty = false, baseSpeed = 0, lastSpam = 0, lastDir = Vector3.new(0, 0, 1), seq = nil, seqI = 1, seqUntil = 0, macroAt = -10 }
local ctl = {}
local inputDirection
inputDirection = function()
local camera = Workspace.CurrentCamera
if not camera then return nil end
local forward, right = 0, 0
if UserInputService:IsKeyDown(Enum.KeyCode.W) then forward += 1 end
if UserInputService:IsKeyDown(Enum.KeyCode.S) then forward -= 1 end
if UserInputService:IsKeyDown(Enum.KeyCode.D) then right += 1 end
if UserInputService:IsKeyDown(Enum.KeyCode.A) then right -= 1 end
if forward == 0 and right == 0 then
if ctl.c == nil then
ctl.c = false
pcall(function()
ctl.c = require(LocalPlayer.PlayerScripts:WaitForChild("PlayerModule", 2)):GetControls()
end)
end
local mv
if ctl.c then
local ok, v = pcall(function() return ctl.c:GetMoveVector() end)
if ok and v and Vector3.new(v.X, 0, v.Z).Magnitude > 0.05 then mv = Vector3.new(v.X, 0, v.Z) end
end
if mv then
local w = camera.CFrame:VectorToWorldSpace(mv)
w = Vector3.new(w.X, 0, w.Z)
if w.Magnitude > 0.01 then return w.Unit end
end
local hum = getHumanoid()
local md = hum and hum.MoveDirection
if md and md.Magnitude > 0.05 then return Vector3.new(md.X, 0, md.Z).Unit end
if UserInputService.TouchEnabled or #UserInputService:GetConnectedGamepads() > 0 then
local _, v = getProxy()
if v and not Move.forced then
local g = Vector3.new(v.Velocity.X, 0, v.Velocity.Z)
if g.Magnitude > 1 then return g.Unit end
end
end
return nil
end
local look = camera.CFrame.LookVector
local flat = Vector3.new(look.X, 0, look.Z)
if flat.Magnitude < 0.01 then return nil end
flat = flat.Unit
local rightVec = camera.CFrame.RightVector
local flatRight = Vector3.new(rightVec.X, 0, rightVec.Z)
if flatRight.Magnitude < 0.01 then return nil end
flatRight = flatRight.Unit
return (flat * forward + flatRight * right).Unit
end
local function dribblePreset(name)
if name == "Hesitation" then return { { side = 0, dur = 0.22 }, { side = 1, dur = 0.20 } }
elseif name == "Spin" then return { { side = -1, dur = 0.10 }, { side = 0, dur = 0.10 }, { side = 1, dur = 0.16 } }
elseif name == "In and out" then return { { side = 1, dur = 0.09 }, { side = -1, dur = 0.09 }, { side = 1, dur = 0.18 } }
end
return { { side = -1, dur = 0.13 }, { side = 1, dur = 0.19 } }
end
local function dribbleStep()
local proxy, velocity = getProxy()
local humanoid = getHumanoid()
if not proxy then
stopGlide()
return
end
if Config.dribble.fast and clock() - Dribble.lastSpam >= 1 / math.max(Config.dribble.rate, 1) then
Dribble.lastSpam = clock()
fireRemote("dribble", "C", false, Dribble.lastDir)
end
if Config.dribble.macro.enabled then
local now = clock()
if Dribble.seq and Dribble.seqI <= #Dribble.seq then
local _, od, oroot = nearestOther(true)
local hrp = getRoot()
if hrp and oroot then
local away = hrp.Position - oroot.Position
away = Vector3.new(away.X, 0, away.Z)
if away.Magnitude > 0.05 then
away = away.Unit
local perp = Vector3.new(-away.Z, 0, away.X)
local step = Dribble.seq[Dribble.seqI]
local dir = (perp * step.side + away * 0.6)
if dir.Magnitude > 0.05 then
dir = dir.Unit
Dribble.lastDir = dir
forceMove(dir, Config.dribble.speed * 1.1)
if now - Dribble.lastSpam >= 0.08 then
Dribble.lastSpam = now
fireRemote("dribble", "C", false, dir)
end
end
end
end
if now >= Dribble.seqUntil then
Dribble.seqI += 1
if Dribble.seq[Dribble.seqI] then
Dribble.seqUntil = now + Dribble.seq[Dribble.seqI].dur
else
Dribble.seq = nil
end
end
return
else
local _, od = nearestOther(true)
local pct = od and contestPercent(od) or 0
if pct >= Config.dribble.macro.trigger and now - Dribble.macroAt > Config.dribble.macro.cooldown then
Dribble.macroAt = now
Dribble.seq = dribblePreset(Config.dribble.macro.preset)
Dribble.seqI = 1
Dribble.seqUntil = now + Dribble.seq[1].dur
end
end
end
local direction = inputDirection()
if not direction then
if humanoid and humanoid.MoveDirection.Magnitude > 0.05 then
direction = humanoid.MoveDirection.Unit
elseif velocity and velocity.Velocity.Magnitude > 0.5 then
direction = Vector3.new(velocity.Velocity.X, 0, velocity.Velocity.Z).Unit
end
end
if not direction or direction.Magnitude < 0.05 then
stopGlide()
return
end
Dribble.lastDir = direction
if Config.dribble.glide then
forceMove(direction, Config.dribble.speed)
else
stopGlide()
end
end
function nearestOther(opponentsOnly)
local me = getCharacter()
local hrp = getRoot()
if not hrp then return nil end
local myTeam = me and me:GetAttribute("Team")
local seen, best, bestDist, bestRoot = {}, nil, math.huge, nil
local function consider(model)
if not model or seen[model] or model == me or model.Name == LocalPlayer.Name then return end
seen[model] = true
local root = model:FindFirstChild("HumanoidRootPart")
if not root then return end
if opponentsOnly then
local theirTeam = model:GetAttribute("Team")
if sameTeam(model, myTeam) then return end
end
local d = (root.Position - hrp.Position).Magnitude
if d < bestDist then best, bestDist, bestRoot = model, d, root end
end
local chars = Workspace:FindFirstChild("Characters")
if chars then
for _, m in ipairs(chars:GetChildren()) do
if m:IsA("Model") then consider(m) end
end
end
for _, plr in ipairs(Players:GetPlayers()) do
if plr ~= LocalPlayer then consider(plr.Character) end
end
return best, bestDist, bestRoot
end
local Guard = { side = 1, lastFlip = 0 }
local function attackedHoop(root, run)
if not run then
local v = root.AssemblyLinearVelocity
run = Vector3.new(v.X, 0, v.Z)
end
local look = root.CFrame.LookVector
local face = run.Magnitude > 3 and run.Unit or Vector3.new(look.X, 0, look.Z)
if face.Magnitude < 0.1 then return Guard.hoop or nearestHoop(root.Position) end
face = face.Unit
local best, bestScore, cur, curScore
for _, part in ipairs(hoopList()) do
if part.Parent then
local d = Vector3.new(part.Position.X - root.Position.X, 0, part.Position.Z - root.Position.Z)
if d.Magnitude > 0.5 then
local score = d.Unit:Dot(face) - d.Magnitude / 400
if not bestScore or score > bestScore then best, bestScore = part, score end
if part == Guard.hoop then cur, curScore = part, score end
end
end
end
if cur and best ~= cur and bestScore - curScore < 0.5 then best = cur end
Guard.hoop = best or Guard.hoop
return best or nearestHoop(root.Position)
end
local Steal = { last = 0, holdingG = false }
local function setHoldingG(value)
if Steal.holdingG == value then return end
Steal.holdingG = value
fireRemote("holdG", { HoldingG = value })
end
local function guardStep(tight)
if not Guard.loop then return Config.autoGuard.enabled and clock() - (Guard.ranAt or -10) < 0.1 end
local hrp = getRoot()
if not hrp then return false end
local handler = findHandler()
local theirRoot = handler and handler:FindFirstChild("HumanoidRootPart")
if not theirRoot then
local _, _, root = nearestOther(true)
if not root then _, _, root = nearestOther(false) end
theirRoot = root
end
if not theirRoot then return false end
local vel = theirRoot.AssemblyLinearVelocity
local run = Vector3.new(vel.X, 0, vel.Z)
do
local nowT, pos = clock(), theirRoot.Position
if Guard.tRoot == theirRoot and nowT - Guard.tAt > 0.03 and nowT - Guard.tAt < 0.5 then
local m = Vector3.new(pos.X - Guard.tPos.X, 0, pos.Z - Guard.tPos.Z) / (nowT - Guard.tAt)
Guard.vel = (Guard.vel or m):Lerp(m, 0.5)
Guard.tPos, Guard.tAt = pos, nowT
elseif Guard.tRoot ~= theirRoot or nowT - (Guard.tAt or -10) >= 0.5 then
Guard.tRoot, Guard.tPos, Guard.tAt, Guard.vel = theirRoot, pos, nowT, Vector3.zero
end
if Guard.vel and Guard.vel.Magnitude > run.Magnitude and Guard.vel.Magnitude < 60 then run = Guard.vel end
end
local look = theirRoot.CFrame.LookVector
local face = run.Magnitude > 6 and run.Unit or Vector3.new(look.X, 0, look.Z)
if face.Magnitude < 0.1 then face = Vector3.new(0, 0, 1) end
face = face.Unit
local theirPos = theirRoot.Position
local rim = attackedHoop(theirRoot, run)
if rim then
local d = Vector3.new(rim.Position.X - theirPos.X, 0, rim.Position.Z - theirPos.Z)
if d.Magnitude > 1 then face = d.Unit end
end
Guard.front = Guard.front and (Guard.front * 0.35 + face * 0.65) or face
if Guard.front.Magnitude < 0.2 then Guard.front = face end
local front = Guard.front.Unit
local gap = math.max(2, Config.contest.closeDist - 1.5)
local spot = theirPos + run * 0.3 + front * gap
local rel = Vector3.new(hrp.Position.X - theirPos.X, 0, hrp.Position.Z - theirPos.Z)
local behind = rel:Dot(front) < -0.5
if behind then
local side = Vector3.new(-front.Z, 0, front.X)
if rel:Dot(side) < 0 then side = -side end
spot = theirPos + run * 0.3 + side * 4 + front * 1.5
end
Guard.spot = Guard.spot and Guard.spot:Lerp(spot, 0.6) or spot
local flat = Vector3.new(Guard.spot.X - hrp.Position.X, 0, Guard.spot.Z - hrp.Position.Z)
if flat.Magnitude > 1.2 then
Guard.lastActive = clock()
if flat.Magnitude > 60 then
stopGlide()
else
local t = clock() - (Guard.walkStart or -10)
if clock() - (Guard.ranAt or -10) > 0.3 then Guard.walkStart = clock(); t = 0 end
local cap = Config.autoGuard.speed
local spd = math.min(clamp(run.Magnitude * 1.05 + flat.Magnitude * 2.5, 8, cap), 8 + t * 25)
Def.walk(flat.Unit, spd)
end
else
stopGlide()
end
local _, _, gyro = getProxy()
if gyro then
gyro.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(theirRoot.Position.X, hrp.Position.Y, theirRoot.Position.Z))
end
return true
end
local function stealStep()
local cfg = Config.autoSteal
local now = clock()
if Steal.pending and now >= Steal.pending then
Steal.pending = nil
local again = findHandler()
if again and again == Steal.target then
Steal.fails = math.min((Steal.fails or 0) + 1, 4)
else
Steal.fails = 0
end
end
if not cfg.enabled then return end
local handler = findHandler()
local hrp = getRoot()
if not handler or not hrp then return end
local theirRoot = handler:FindFirstChild("HumanoidRootPart")
if not theirRoot then return end
local pos = theirRoot.Position
if Steal.hRoot ~= theirRoot then
Steal.hRoot, Steal.hPos, Steal.hAt, Steal.vel, Steal.turnAt = theirRoot, pos, now, Vector3.zero, -10
elseif now - Steal.hAt >= 0.05 then
local v = Vector3.new(pos.X - Steal.hPos.X, 0, pos.Z - Steal.hPos.Z) / (now - Steal.hAt)
if Steal.vel.Magnitude > 6 and v.Magnitude > 6 then
local cosA = math.clamp(Steal.vel.Unit:Dot(v.Unit), -1, 1)
if math.deg(math.acos(cosA)) > 35 then Steal.turnAt = now end
end
Steal.vel, Steal.hPos, Steal.hAt = v, pos, now
end
local ball = theirRoot
local weld = theirRoot:FindFirstChild("Basketball")
if weld and weld:IsA("Motor6D") and weld.Part1 then ball = weld.Part1 end
local reach = Vector3.new(ball.Position.X - hrp.Position.X, 0, ball.Position.Z - hrp.Position.Z).Magnitude
if reach > cfg.range then return end
local wait = cfg.cooldown + (Steal.fails or 0) * 0.35
if now - Steal.last < wait then return end
if cfg.smart then
if handler:GetAttribute("Action") == "Shooting" then return end
local toMe = Vector3.new(hrp.Position.X - pos.X, 0, hrp.Position.Z - pos.Z)
local look = Vector3.new(theirRoot.CFrame.LookVector.X, 0, theirRoot.CFrame.LookVector.Z)
if toMe.Magnitude > 0.1 and look.Magnitude > 0.1 and look.Unit:Dot(toMe.Unit) < -0.3 then return end
local score = 0
if (Vector3.new(ball.Position.X - pos.X, 0, ball.Position.Z - pos.Z)).Magnitude >= 1.6 then score += 1 end
if now - (Steal.turnAt or -10) < 0.35 then score += 1 end
if (Steal.vel or Vector3.zero).Magnitude < 8 then score += 1 end
if reach <= cfg.range * 0.7 then score += 1 end
if score < 2 then return end
end
Steal.last = now
Steal.target = handler
Steal.pending = now + 0.5
Steal.count = (Steal.count or 0) + 1
fireRemote("steal")
end
local DefVis = { folder = nil, target = nil, reach = nil }
do
local function ring()
local part = Instance.new("Part")
part.Shape = Enum.PartType.Cylinder
part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
part.Material = Enum.Material.Neon
part.Color = Color3.fromRGB(255, 255, 255)
part.Transparency = 0.55
part.Name = "BloomFx"
part.Parent = DefVis.folder
return part
end
local function place(part, pos, radius)
part.Size = Vector3.new(0.12, radius * 2, radius * 2)
part.CFrame = CFrame.new(pos.X, pos.Y - 2.9, pos.Z) * CFrame.Angles(0, 0, math.pi / 2)
end
track(RunService.RenderStepped:Connect(function()
local want = Config.defVis.target or Config.defVis.reach
if not want then
if DefVis.folder then DefVis.folder:Destroy() DefVis.folder, DefVis.target, DefVis.reach = nil, nil, nil end
return
end
if not DefVis.folder then
DefVis.folder = Instance.new("Folder")
DefVis.folder.Name = "BloomFx"
DefVis.folder.Parent = Workspace.CurrentCamera or Workspace
end
local hrp = getRoot()
if Config.defVis.reach and hrp then
DefVis.reach = DefVis.reach or ring()
place(DefVis.reach, hrp.Position, Config.autoSteal.range)
elseif DefVis.reach then
DefVis.reach:Destroy() DefVis.reach = nil
end
local handler = Config.defVis.target and not hasBall() and findHandler() or nil
local theirRoot = handler and handler:FindFirstChild("HumanoidRootPart")
if theirRoot then
DefVis.target = DefVis.target or ring()
place(DefVis.target, theirRoot.Position, 4)
elseif DefVis.target then
DefVis.target:Destroy() DefVis.target = nil
end
end))
end
local function onGoalHalf(hrp, goal)
local list = hoopList()
if #list < 2 then return true end
local mid = Vector3.new(0, 0, 0)
for _, p in ipairs(list) do mid = mid + p.Position end
mid = mid / #list
local a = Vector3.new(goal.Position.X - mid.X, 0, goal.Position.Z - mid.Z)
local b = Vector3.new(hrp.Position.X - mid.X, 0, hrp.Position.Z - mid.Z)
return a:Dot(b) > 0
end
local Persist = { file = "bloom_settings.json", last = "", stop = false }
function Persist.encode()
local out = {}
for section, values in pairs(Config) do
if type(values) == "table" then
out[section] = {}
for key, value in pairs(values) do
local t = type(value)
if t == "number" or t == "string" or t == "boolean" then
out[section][key] = value
end
end
end
end
local ok, text = pcall(function() return HttpService:JSONEncode(out) end)
return ok and text or nil
end
function Persist.saveAs(file)
local text = Persist.encode()
if not text then return false end
return pcall(function() writefile(file, text) end)
end
function Persist.save(force)
if Persist.stop then return end
local text = Persist.encode()
if not text or (text == Persist.last and not force) then return end
if pcall(function() writefile(Persist.file, text) end) then
Persist.last = text
end
end
function Persist.load(file)
file = file or Persist.file
return pcall(function()
if not isfile(file) then error("no file") end
local data = HttpService:JSONDecode(readfile(file))
for section, values in pairs(data) do
local target = Config[section]
if type(target) == "table" and type(values) == "table" then
for key, value in pairs(values) do
if target[key] ~= nil and type(target[key]) == type(value) then
target[key] = value
end
end
end
end
end)
end
function Persist.cfgFile(name)
name = tostring(name or ""):gsub("[^%w_%-]", "")
if name == "" then name = "default" end
return "bloom_cfg_" .. name .. ".json"
end
Persist.load()
Config.farm.enabled = false
Config.autoGreen.meterType = "Vertical"
if not (Config.afk.enabled or Config.farm.enabled) then
Config.afk.blacktop, Config.afk.park = false, false
for _, group in ipairs({ "autoPlay", "autoShoot", "autoGuard", "autoSteal", "antiSteal", "chase",
"block", "rebound", "openSpot", "dribble", "aimbot" }) do
Config[group].enabled = false
end
Config.farm.enabled = false
Config.move.boost = false
Config.move.jumpShot = false
end
if Config.settings.autoLoad and Config.settings.autoName ~= "" then
local keepName = Config.settings.autoName
if Persist.load(Persist.cfgFile(keepName)) then
Config.settings.autoLoad, Config.settings.autoName = true, keepName
end
end
Record = {
keys = { "fgm", "fga", "tpm", "tpa", "blocks", "steals", "rebounds", "perfect", "wins", "losses" },
session = {}, life = {},
zones = { rim = { m = 0, a = 0 }, mid = { m = 0, a = 0 }, three = { m = 0, a = 0 } },
file = "bloom_stats.json", dirty = false, pending = nil, lastMake = 0,
}
for _, k in ipairs(Record.keys) do
Record.session[k] = 0
Record.life[k] = 0
end
function Record.add(key, n)
n = n or 1
Record.session[key] = (Record.session[key] or 0) + n
Record.life[key] = (Record.life[key] or 0) + n
Record.dirty = true
end
function Record.save()
local ok = pcall(function()
writefile(Record.file, HttpService:JSONEncode({ life = Record.life, zones = Record.zones }))
end)
if ok then Record.dirty = false end
end
function Record.load()
pcall(function()
if not isfile(Record.file) then return end
local data = HttpService:JSONDecode(readfile(Record.file))
if type(data.life) == "table" then
for _, k in ipairs(Record.keys) do
if type(data.life[k]) == "number" then Record.life[k] = data.life[k] end
end
end
if type(data.zones) == "table" then
for zone, z in pairs(Record.zones) do
local saved = data.zones[zone]
if type(saved) == "table" then
z.m = tonumber(saved.m) or 0
z.a = tonumber(saved.a) or 0
end
end
end
end)
end
Record.load()
function Record.zoneOf(dist)
local line = Config.autoPlay.shotDistance
if dist >= line - 1.5 then return "three" end
if dist <= 9 then return "rim" end
return "mid"
end
function Record.onShot()
local hrp = getRoot()
if not hrp then return end
local goal, dist = shootHoop(hrp.Position)
if not goal then return end
local zone = Record.zoneOf(dist)
Record.add("fga")
Record.zones[zone].a += 1
if zone == "three" then Record.add("tpa") end
Record.pending = { zone = zone, at = clock(), goal = goal, prev = {} }
end
function Record.checkMake()
local p = Record.pending
if not p then return end
local now = clock()
if now - p.at > 3.6 then
Record.pending = nil
return
end
local goal = p.goal
if not goal or not goal.Parent then
Record.pending = nil
return
end
local gp = goal.Position
local balls = {}
local folder = Workspace:FindFirstChild("Basketballs")
if folder then
for _, b in ipairs(folder:GetChildren()) do
if b:IsA("BasePart") then balls[#balls + 1] = b end
end
end
if Ball.part and Ball.part.Parent then balls[#balls + 1] = Ball.part end
for _, ball in ipairs(balls) do
local bp = ball.Position
local dx, dz = bp.X - gp.X, bp.Z - gp.Z
local rel = bp.Y - gp.Y
local prev = p.prev[ball]
p.prev[ball] = rel
if prev and prev > 0.2 and rel <= 0.2 and rel > -3 and math.sqrt(dx * dx + dz * dz) < 1.8 then
Record.pending = nil
Record.lastMake = now
Record.add("fgm")
Record.zones[p.zone].m += 1
if p.zone == "three" then Record.add("tpm") end
return
end
end
end
task.spawn(function()
while Running do
task.wait(5)
if Record.dirty then Record.save() end
end
end)
track(RunService.Heartbeat:Connect(function()
if Record.pending then pcall(Record.checkMake) end
end))
local function nearestDefender()
local chars = Workspace:FindFirstChild("Characters")
local me = getCharacter()
local hrp = getRoot()
if not chars or not hrp then return nil end
local myTeam = me and me:GetAttribute("Team")
local best, bestDist, bestRoot = nil, math.huge, nil
for _, model in ipairs(chars:GetChildren()) do
if model:IsA("Model") and model ~= me and model.Name ~= LocalPlayer.Name then
local theirTeam = model:GetAttribute("Team")
local opposing = not sameTeam(model, myTeam)
local root = model:FindFirstChild("HumanoidRootPart")
if opposing and root then
local d = (root.Position - hrp.Position).Magnitude
if d < bestDist then
best, bestDist, bestRoot = model, d, root
end
end
end
end
return best, bestDist, bestRoot
end
local function opposingRoots()
local list = {}
local chars = Workspace:FindFirstChild("Characters")
local me = getCharacter()
if not chars then return list end
local myTeam = me and me:GetAttribute("Team")
for _, model in ipairs(chars:GetChildren()) do
if model:IsA("Model") and model ~= me and model.Name ~= LocalPlayer.Name then
local theirTeam = model:GetAttribute("Team")
local opposing = not sameTeam(model, myTeam)
local root = model:FindFirstChild("HumanoidRootPart")
if opposing and root then list[#list + 1] = root end
end
end
return list
end
local function tapJump()
pcall(function()
local vim = game:GetService("VirtualInputManager")
vim:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
task.delay(0.06, function()
pcall(function() vim:SendKeyEvent(false, Enum.KeyCode.Space, false, game) end)
end)
end)
end
do
Def = { lastBlock = 0, lastJump = 0, rebAt = -10, rebTp = -10, heldAt = -10, tps = 0, skip = 0 }
local ATTACK_WORDS = { "shoot", "shot", "layup", "lay up", "floater", "hook", "finish", "dunk", "alley", "lob", "tip", "putback" }
local function attackAction(model)
local act = tostring(model:GetAttribute("Action") or ""):lower()
for _, w in ipairs(ATTACK_WORDS) do
if act:find(w, 1, true) then return true end
end
return false
end
local function findAirAttacker()
local hrp = getRoot()
if not hrp then return nil end
local best, bestD = nil, nil
for _, root in ipairs(opposingRoots()) do
local model = root.Parent
local d = (root.Position - hrp.Position).Magnitude
if model and d <= Config.block.range then
local goal, gd = nearestHoop(root.Position)
local rising = root.AssemblyLinearVelocity.Y > 6 and goal ~= nil and gd < 25
if (attackAction(model) or rising) and (not bestD or d < bestD) then best, bestD = model, d end
end
end
return best
end
function Def.blockStep()
local cfg = Config.block
local hrp = getRoot()
if not hrp or hasBall() then return false end
local handler = findHandler() or findAirAttacker()
if not handler then return false end
local me = getCharacter()
local t1 = me and me:GetAttribute("Team")
local t2 = handler:GetAttribute("Team")
if sameTeam(handler, t1) then return false end
local root = handler:FindFirstChild("HumanoidRootPart")
if not root then return false end
local dist = (root.Position - hrp.Position).Magnitude
if dist > cfg.range then return false end
local action = tostring(handler:GetAttribute("Action") or ""):lower()
local shooting = root.AssemblyLinearVelocity.Y > 6
for _, w in ipairs({ "shoot", "shot", "layup", "lay up", "floater", "hook", "finish", "tip", "putback" }) do
if action:find(w, 1, true) then shooting = true end
end
local dunking = action:find("dunk", 1, true) ~= nil or action:find("alley", 1, true) ~= nil
or (cfg.chaseDunks and root.AssemblyLinearVelocity.Y > 8)
local now0 = clock()
if shooting then
if Def.shootRoot ~= root or now0 - (Def.shootSeen or -10) > 0.3 then
Def.shootRoot, Def.shootAt = root, now0
end
Def.shootSeen = now0
end
if not (shooting or dunking) then
if cfg.follow then return guardStep(false) end
return false
end
local goal = attackedHoop(root)
local ahead = root.Position + root.AssemblyLinearVelocity * (dunking and 0.25 or 0.1)
local spot = ahead
if goal then
local toGoal = Vector3.new(goal.Position.X - ahead.X, 0, goal.Position.Z - ahead.Z)
if toGoal.Magnitude > 0.1 then spot = ahead + toGoal.Unit * 1.8 end
end
if (shooting and cfg.follow) or dunking then
local flat = Vector3.new(spot.X - hrp.Position.X, 0, spot.Z - hrp.Position.Z)
if flat.Magnitude > 1 then
Def.walk(flat.Unit, cfg.speed)
end
end
local now = clock()
local real = dunking or not cfg.ignoreFakes or now - (Def.shootAt or now) >= cfg.fakeWait
if real and dist <= cfg.jumpRange and now - Def.lastBlock > 0.6 then
Def.lastBlock = now
tapJump()
fireRemote("jump")
fireRemote("block")
end
return true
end
function Def.walk(direction, speed)
local proxy, _, gyro = getProxy()
if not proxy then return end
local _, mover = getProxy()
if mover then
if not Move.originalMaxForce then Move.originalMaxForce = mover.MaxForce end
mover.MaxForce = Vector3.new(0, 0, 0)
mover.Velocity = Vector3.new(0, 0, 0)
Move.forced = true
end
local now = clock()
local dt = (now - (Def.walkAt or -10) < 0.1) and clamp(now - Def.walkAt, 0.004, 0.05) or 0.016
Def.walkAt = now
local cf = proxy.CFrame
Def.acc = (Def.acc or 0) + clamp(speed, 0, 60) * dt
local pos = cf.Position
if Def.acc > 0 then
pos = pos + direction * Def.acc
Def.acc = 0
proxy.CFrame = CFrame.new(pos) * (cf - cf.Position)
end
if gyro then gyro.CFrame = CFrame.lookAt(pos, pos + direction) end
end
track(RunService.Heartbeat:Connect(function()
local function idle()
if Guard.moving then
Guard.moving = false
pcall(stopGlide)
end
end
if not Running or not Config.autoGuard.enabled then return idle() end
if not Match.allowed() or hasBall() then return idle() end
local handler = findHandler()
local hroot = handler and handler:FindFirstChild("HumanoidRootPart")
local me = getRoot()
if not hroot or not me then return idle() end
if (hroot.Position - me.Position).Magnitude > Config.autoGuard.range then return idle() end
local char = getCharacter()
if meterActive() or (char and char:GetAttribute("Action") == "Shooting") then return idle() end
Guard.loop = true
local ok, err = pcall(guardStep, false)
Guard.loop = false
Guard.ranAt = clock()
Guard.moving = true
local action = tostring(handler:GetAttribute("Action") or ""):lower()
local goingUp = hroot.AssemblyLinearVelocity.Y > 4
for _, w in ipairs({ "shoot", "shot", "layup", "lay up", "floater", "hook", "finish", "dunk" }) do
if action:find(w, 1, true) then goingUp = true end
end
local now = clock()
if goingUp and (hroot.Position - me.Position).Magnitude <= 13 and now - Def.lastBlock > 0.45 then
Def.lastBlock = now
tapJump()
fireRemote("jump")
fireRemote("block")
end
if not ok then warn("[Bloom] defense: " .. tostring(err)) end
end))
do
local ring
track(RunService.Heartbeat:Connect(function()
local hrp = getRoot()
if not Running or not Config.autoGuard.enabled or not hrp then
if ring then ring:Destroy() ring = nil end
return
end
if not ring or not ring.Parent then
ring = Instance.new("Part")
ring.Shape = Enum.PartType.Cylinder
ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch = true, false, false, false
ring.Transparency = 1
ring.Name = "BloomCircle"
local gui = Instance.new("SurfaceGui")
gui.Face = Enum.NormalId.Right
gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
gui.CanvasSize = Vector2.new(1024, 1024)
gui.LightInfluence = 0
gui.AlwaysOnTop = true
gui.Parent = ring
local f = Instance.new("Frame")
f.Size, f.BackgroundTransparency = UDim2.fromScale(1, 1), 1
f.Parent = gui
local c = Instance.new("UICorner")
c.CornerRadius = UDim.new(0.5, 0)
c.Parent = f
local st = Instance.new("UIStroke")
st.Color, st.Thickness, st.Transparency = Color3.fromRGB(255, 255, 255), 14, 0.15
st.Parent = f
ring.Parent = Workspace.CurrentCamera or Workspace
end
local d = Config.autoGuard.range * 2
ring.Size = Vector3.new(0.15, d, d)
ring.CFrame = CFrame.new(hrp.Position - Vector3.new(0, 2.9, 0)) * CFrame.Angles(0, 0, math.pi / 2)
end))
end
function Def.tp(cf)
local proxyPart, _, gyro = getProxy()
if proxyPart then
proxyPart.CFrame = cf
pcall(function() proxyPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end)
if gyro then gyro.CFrame = cf end
else
local hrp = getRoot()
if hrp then hrp.CFrame = cf end
end
end
function Def.outOfBounds(p, inset)
inset = inset or 0
local g1 = nearestHoop(p)
if not g1 then return false end
local g2, far = nil, math.huge
for _, part in ipairs(hoopList()) do
if part.Parent and part ~= g1 then
local d = (part.Position - g1.Position).Magnitude
if d > 40 and d < far then g2, far = part, d end
end
end
if not g2 then return (p - g1.Position).Magnitude > 60 end
local a = Vector3.new(g2.Position.X - g1.Position.X, 0, g2.Position.Z - g1.Position.Z)
local len = a.Magnitude
local u = a.Unit
local v = Vector3.new(p.X - g1.Position.X, 0, p.Z - g1.Position.Z)
local t = v:Dot(u)
local lat = math.abs(v.X * u.Z - v.Z * u.X)
return t < -7 + inset or t > len + 7 - inset or lat > 27 - inset
end
function Def.reboundCore()
local hrp = getRoot()
local now = clock()
local holder = hasBall()
local chars = Workspace:FindFirstChild("Characters")
local heldPart, heldPos = holder and Ball.part or nil, hrp and hrp.Position
for _, m in ipairs(chars and chars:GetChildren() or {}) do
if m:IsA("Model") then
local part = heldPhysics(m) or ballValueOf(m)
if part or m:GetAttribute("Basketball") then
holder = true
local r = m:FindFirstChild("HumanoidRootPart")
if part then heldPart = part end
if r then heldPos = r.Position end
end
end
end
if holder then
if Def.moving or Move.forced then
Def.moving = false
pcall(stopGlide)
end
Def.touched = false
Def.heldAt, Def.tps, Def.live, Def.land, Def.chaseAt = now, 0, nil, nil, nil
if heldPart then
Def.lastBall = heldPart:IsA("BasePart") and heldPart or heldPart:FindFirstChildWhichIsA("BasePart", true)
end
Def.lastPos = heldPos
return
end
if not hrp or now < Def.skip or now - Def.heldAt < 0.12 or now - Def.heldAt > 8 then return end
local mine = hrp.Position
local ball = Def.live
if ball and not ball.Parent then ball, Def.live = nil, nil end
if not ball then
local last = Def.lastBall
if last and last.Parent and last.AssemblyLinearVelocity.Magnitude > 2 then
ball = last
else
local folder = Workspace:FindFirstChild("Basketballs")
local balls = folder and folder:GetChildren() or {}
if #balls == 0 and Ball.part then balls = { Ball.part } end
local from = Def.lastPos or mine
local best = 45
for _, b in ipairs(balls) do
local part = b:IsA("BasePart") and b or b:FindFirstChildWhichIsA("BasePart", true)
if part and part.AssemblyLinearVelocity.Magnitude > 2 then
local d = (part.Position - from).Magnitude
if d < best then ball, best = part, d end
end
end
end
if not ball then return end
end
local bp, bv = ball.Position, ball.AssemblyLinearVelocity
local goal = nearestHoop(bp)
local out = goal and Vector3.new(bp.X - goal.Position.X, 0, bp.Z - goal.Position.Z) or Vector3.new(0, 0, 1)
local rim = out.Magnitude
local flat = Vector3.new(bv.X, 0, bv.Z)
local flying = goal ~= nil and rim > 8 and flat.Magnitude > 8 and flat.Unit:Dot(-out.Unit) > 0.6
if not Def.live then
if not goal or (rim > 18 and not flying) then return end
if rim < 2.5 and bv.Y < 0 and bp.Y > goal.Position.Y - 3 then
Def.skip = now + 4
return
end
Def.live = ball
end
if not Def.touched then
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Exclude
local ign = { ball }
if chars then ign[#ign + 1] = chars end
local prox = Workspace:FindFirstChild("ProxyCharacter")
if prox then ign[#ign + 1] = prox end
local balls = Workspace:FindFirstChild("Basketballs")
if balls then ign[#ign + 1] = balls end
rp.FilterDescendantsInstances = ign
local hit = Workspace:Raycast(bp, Vector3.new(0, -4, 0), rp)
if hit and bp.Y - hit.Position.Y < 1.8 then
Def.touched = true
Def.reactAt = now + 0.22 + math.random() * 0.2
Def.jit = Vector3.new((math.random() - 0.5) * 3, 0, (math.random() - 0.5) * 3)
if (Vector3.new(bp.X - mine.X, 0, bp.Z - mine.Z)).Magnitude > 34 then
Def.skip, Def.live, Def.touched = now + 3, nil, false
return
end
else
return
end
end
if Def.touched and now < (Def.reactAt or 0) then return end
Def.chaseAt = Def.chaseAt or now
if now - Def.chaseAt > 4.5 or Def.outOfBounds(bp, 1) or Def.outOfBounds(mine, -4) then
Def.skip, Def.live, Def.touched, Def.chaseAt = now + 3, nil, false, nil
return
end
local land
if Def.touched then
land = Vector3.new(bp.X + bv.X * 0.12, mine.Y, bp.Z + bv.Z * 0.12) + (Def.jit or Vector3.new())
elseif flying then
land = Vector3.new(goal.Position.X, mine.Y, goal.Position.Z) + out.Unit * 5
else
local t = 0
if bp.Y > mine.Y + 1 or bv.Y > 2 then
local g = Workspace.Gravity
t = 0.4
local disc = bv.Y * bv.Y + 2 * g * (bp.Y - (mine.Y + 2))
if disc >= 0 then
local root = (bv.Y + math.sqrt(disc)) / g
if root > 0 then t = root end
end
t = clamp(t, 0.05, 3)
end
land = Vector3.new(bp.X + bv.X * t, mine.Y, bp.Z + bv.Z * t)
end
Def.rebAt = now
if Def.land and (Def.land - land).Magnitude < 12 then
land = Def.land:Lerp(land, 0.5)
end
Def.land = land
if Def.outOfBounds(land, 1) then
Def.skip, Def.live, Def.touched, Def.chaseAt = now + 3, nil, false, nil
return
end
local gap = Vector3.new(land.X - mine.X, 0, land.Z - mine.Z)
if gap.Magnitude > 1.2 then
Def.moving = true
Def.walk(gap.Unit, clamp(gap.Magnitude * 3, 9, 21))
else
Def.moving = false
stopGlide()
end
local horiz = Vector3.new(bp.X - mine.X, 0, bp.Z - mine.Z).Magnitude
if horiz < 5 and bp.Y > mine.Y + 1 and bv.Y < 3 and not hasBall() and now - Def.lastJump > 0.9 then
Def.lastJump = now
tapJump()
end
end
function Def.reboundStep()
local ok, err = pcall(Def.reboundCore)
if not ok then warn("[Bloom] rebound: " .. tostring(err)) end
if Def.moving and clock() - Def.rebAt > 0.12 then
Def.moving = false
pcall(stopGlide)
end
end
Mv = {}
local buildWords = { "overall", "ovr", "speed", "stamina", "handle", "handling", "shoot", "three", "dunk", "block",
"steal", "strength", "vertical", "agility", "pass", "rebound", "defense", "finish", "accel", "jump" }
local buildSkip = { "walk", "run", "sprint", "max", "time", "cool", "mult", "level", "xp" }
local function buildMatch(name)
local lower = name:lower()
for _, bad in ipairs(buildSkip) do
if lower:find(bad, 1, true) then return false end
end
for _, word in ipairs(buildWords) do
if lower:find(word, 1, true) then return true end
end
return false
end
function Mv.build()
local function bump(inst)
for name, value in pairs(inst:GetAttributes()) do
if type(value) == "number" and value >= 1 and value < 99 and buildMatch(name) then
inst:SetAttribute(name, 99)
end
end
end
bump(LocalPlayer)
local char = getCharacter()
if char then bump(char) end
for _, child in ipairs(LocalPlayer:GetChildren()) do
if child.Name ~= "PlayerGui" and child.Name ~= "Backpack" and child.Name ~= "PlayerScripts" then
bump(child)
for _, d in ipairs(child:GetDescendants()) do
if (d:IsA("NumberValue") or d:IsA("IntValue")) and d.Value >= 1 and d.Value < 99
and buildMatch(d.Name) then
d.Value = 99
end
end
end
end
end
local function statHolders()
local list = { LocalPlayer }
local char = getCharacter()
if char then list[#list + 1] = char end
local proxy = Workspace:FindFirstChild("ProxyCharacter")
if proxy then list[#list + 1] = proxy end
for _, child in ipairs(LocalPlayer:GetChildren()) do
if child.Name ~= "PlayerGui" and child.Name ~= "Backpack" and child.Name ~= "PlayerScripts" then list[#list + 1] = child end
end
if char then for _, child in ipairs(char:GetChildren()) do
if not child:IsA("BasePart") and not child:IsA("Accessory") then list[#list + 1] = child end
end end
return list
end
local staminaSkip = { "max", "regen", "drain", "cost", "rate", "cool", "delay", "recover", "mult", "use", "gain" }
local function staminaName(name)
local l = name:lower()
if not (l:find("stamina", 1, true) or l:find("energy", 1, true) or l:find("endurance", 1, true)) then return false end
for _, bad in ipairs(staminaSkip) do if l:find(bad, 1, true) then return false end end
return true
end
Mv.stamMax = {}
function Mv.stamina()
for _, holder in ipairs(statHolders()) do
for name, value in pairs(holder:GetAttributes()) do
if type(value) == "number" and staminaName(name) then
local key = holder:GetFullName() .. "." .. name
local top = holder:GetAttribute("Max" .. name) or holder:GetAttribute(name .. "Max") or holder:GetAttribute("MaxStamina")
or holder:GetAttribute("MaxEnergy") or math.max(Mv.stamMax[key] or 0, value, 100)
Mv.stamMax[key] = top
if value < top then holder:SetAttribute(name, top) end
end
end
for _, d in ipairs(holder:GetChildren()) do
if (d:IsA("NumberValue") or d:IsA("IntValue")) and staminaName(d.Name) then
local top = holder:FindFirstChild("Max" .. d.Name) or holder:FindFirstChild("MaxStamina")
local cap = top and top.Value or math.max(Mv.stamMax[d] or 0, d.Value, 100)
Mv.stamMax[d] = cap
if d.Value < cap then d.Value = cap end
end
end
end
end
function Mv.noSlow()
local char = getCharacter()
if not char then return end
local floor = Config.move.floor
local ws = char:GetAttribute("WalkSpeed")
if type(ws) == "number" and ws < floor then
char:SetAttribute("WalkSpeed", floor)
end
local humanoid = getHumanoid()
if humanoid and humanoid.WalkSpeed < floor and humanoid.WalkSpeed > 0 then
humanoid.WalkSpeed = floor
end
end
function Mv.speedOf(pct)
pct = math.clamp(tonumber(pct) or 0, 0, 100)
local top = (Config.move.speedMode == "Blatant") and 100 or 28
return 20 + (top - 20) * pct / 100
end
do
local base, t0, sawMeter, armed = nil, 0, false, true
track(RunService.Heartbeat:Connect(function()
local proxy = getProxy()
if not Running or not Config.move.jumpShot or not proxy then
base, sawMeter, armed = nil, false, true
return
end
local char = getCharacter()
local meter = meterActive()
local acting = meter or (char ~= nil and char:GetAttribute("Action") == "Shooting")
if not acting then
base, sawMeter, armed = nil, false, true
return
end
if not armed then return end
if not base then base, t0 = proxy.Position.Y, clock() end
if meter then sawMeter = true end
local v = proxy.AssemblyLinearVelocity
if (sawMeter and not meter) or clock() - t0 > 1.5 then
armed, base, sawMeter = false, nil, false
proxy.AssemblyLinearVelocity = Vector3.new(v.X, -50, v.Z)
return
end
local cf = proxy.CFrame
proxy.CFrame = CFrame.new(cf.X, base + Config.move.jumpHeight, cf.Z) * (cf - cf.Position)
proxy.AssemblyLinearVelocity = Vector3.new(v.X, 0, v.Z)
end))
end
function Mv.boostStep()
local char = getCharacter()
local action = char and char:GetAttribute("Action") or ""
if action == "Shooting" or Shot.active then return false end
local dir = inputDirection()
if not dir then return false end
forceMove(dir, Mv.speedOf(Config.move.speedPct))
return true
end
function Mv.antiAnkle()
local char = getCharacter()
if char and char:GetAttribute("CanMove") == false then
char:SetAttribute("CanMove", true)
end
end
task.spawn(function()
while Running do
task.wait(0.1)
pcall(function()
if Config.move.noSlow then Mv.noSlow() end
if Config.move.stamina then Mv.stamina() end
if Config.move.antiAnkle then Mv.antiAnkle() end
end)
end
end)
task.spawn(function()
while Running do
task.wait(3)
if Config.move.build99 then pcall(Mv.build) end
end
end)
track(LocalPlayer.OnTeleport:Connect(function()
Persist.save(true)
end))
do
local seen = {}
local rules = {
{ "wins", { "victory", "you win", "you won", "winner" } },
{ "losses", { "defeat", "you lose", "you lost", "game over" } },
{ "blocks", { "block!", "blocked", "rejected" } },
}
local function check(label)
if not label:IsA("TextLabel") or not label.Visible then return end
local text = label.Text:lower()
if text == "" or #text > 40 then return end
for _, rule in ipairs(rules) do
for _, w in ipairs(rule[2]) do
if text:find(w, 1, true) then
local now = clock()
if now - (seen[rule[1]] or -10) > 4 then
seen[rule[1]] = now
Record.add(rule[1])
if rule[1] == "wins" or rule[1] == "losses" then Match.onEnd() end
end
return
end
end
end
end
local gui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
if gui then
track(gui.DescendantAdded:Connect(function(d)
if d:IsA("TextLabel") then
task.defer(check, d)
d:GetPropertyChangedSignal("Text"):Connect(function() if Running then check(d) end end)
end
end))
end
end
end
Match = { state = "Menu", since = clock(), lastLive = -100, endedAt = -100 }
function Match.allowed()
if Config.farm.enabled then return Match.state == "Match" end
return (not Config.match.only) or Match.state == "Match"
end
function Match.set(state)
if Match.state ~= state then
Match.state = state
Match.since = clock()
if state == "Match" then pcall(Farm.onStart) end
end
end
function Match.onEnd()
if Match.state == "Match" then
Match.endedAt = clock()
Match.set("Ended")
end
end
function Match.place()
local found = nil
local function look(text)
if type(text) ~= "string" then return end
local l = text:lower()
if l:find("private", 1, true) then found = found or "PRIVATE" end
if l:find("gym", 1, true) then found = found or "GYM" end
if l:find("park", 1, true) then found = found or "PARK" end
if l:find("rec", 1, true) and not l:find("record", 1, true) and not l:find("rect", 1, true) then found = found or "REC" end
end
local function attrs(inst)
if not inst then return end
for k, v in pairs(inst:GetAttributes()) do
look(k)
if type(v) == "string" then look(v) end
end
end
attrs(Workspace)
attrs(LocalPlayer)
attrs(getCharacter())
for _, child in ipairs(Workspace:GetChildren()) do
if not child:IsA("Terrain") and child.Name ~= "Characters" and child.Name ~= "Camera" then look(child.Name) end
end
return found
end
function Match.eval()
local now = clock()
local queued = now - -1000 < 600
local char, hrp = getCharacter(), getRoot()
if not char or not hrp then
if Match.state == "Match" then Match.onEnd()
elseif Match.state ~= "Ended" then Match.set(queued and "Loading" or "Menu") end
return
end
local live = false
local ball = Ball.part
if ball and ball.Parent and (ball.Position - hrp.Position).Magnitude < 170 then
local goal, gd = nearestHoop(hrp.Position)
local _, od = nearestOther(false)
local moving = Ball.owner ~= nil or hasBall() or ball.AssemblyLinearVelocity.Magnitude > 2
local near = 0
local chars = Workspace:FindFirstChild("Characters")
local total = chars and #chars:GetChildren() or 0
if chars then
for _, m in ipairs(chars:GetChildren()) do
local r = m:IsA("Model") and m ~= char and m:FindFirstChild("HumanoidRootPart")
if r and (r.Position - hrp.Position).Magnitude < 200 then near += 1 end
end
end
live = moving and goal ~= nil and gd < 110 and od ~= nil and od < 110
end
if live then Match.lastLive = now end
if Match.state == "Ended" then
if now - Match.endedAt > 8 then Match.set(live and "Match" or "Lobby") end
elseif live then
Match.set("Match")
elseif Match.state == "Match" then
if now - Match.lastLive > 6 then Match.set("Lobby") end
else
Match.set((now - -1000 < 120) and "Queue" or "Lobby")
end
end
task.spawn(function()
while Running do
task.wait(0.5)
pcall(Match.eval)
if clock() - (Match.placeAt or -100) > 8 then
Match.placeAt = clock()
local ok, place = pcall(Match.place)
Match.placeName = ok and place or nil
end
end
end)
task.spawn(function()
task.wait(4)
pcall(function()
local out = {}
for _, c in ipairs(Workspace:GetChildren()) do out[#out + 1] = c.ClassName .. " " .. c.Name end
for k, v in pairs(Workspace:GetAttributes()) do out[#out + 1] = "attr " .. k .. " = " .. tostring(v) end
for k, v in pairs(LocalPlayer:GetAttributes()) do out[#out + 1] = "player attr " .. k .. " = " .. tostring(v) end
writefile("bloom_place.txt", table.concat(out, "\n"))
end)
end)
local AutoShoot = { last = 0 }
do
local function valuePos(value)
if typeof(value) == "CFrame" then return value.Position end
if typeof(value) == "Vector3" then return value end
if typeof(value) == "Instance" and value:IsA("BasePart") then return value.Position end
return nil
end
local lastSeen = nil
task.spawn(function()
while Running do
task.wait(0.25)
pcall(function()
if Attack.locked then return end
local state = getState()
local pos = state and valuePos(state:GetAttribute("Goal"))
if not pos then return end
local mine = genv.__BloomGoal
if mine and (pos - mine).Magnitude < 1 then return end
if lastSeen and (pos - lastSeen).Magnitude < 1 then return end
lastSeen = pos
local hrp = getRoot()
if not hrp then return end
local hoop, hoopDist = nearestHoop(pos)
local nearest = nearestHoop(hrp.Position)
if hoop and hoopDist < 10 and nearest and hoop ~= nearest then
setAttack(hoop, "game goal")
end
end)
end
end)
local shotSeen = false
task.spawn(function()
while Running do
task.wait(0.1)
pcall(function()
local char = getCharacter()
local action = char and char:GetAttribute("Action") or ""
if action ~= "Shooting" then
shotSeen = false
return
end
if shotSeen then return end
shotSeen = true
if Shot.active or clock() - Shot.pressedAt < 6 then return end
local hrp = getRoot()
if not hrp then return end
local look = hrp.CFrame.LookVector
look = Vector3.new(look.X, 0, look.Z)
if look.Magnitude < 0.1 then return end
look = look.Unit
local best, bestDot = nil, 0.75
for _, part in ipairs(hoopList()) do
local to = Vector3.new(part.Position.X - hrp.Position.X, 0, part.Position.Z - hrp.Position.Z)
if to.Magnitude > 3 and to.Magnitude < 90 then
local d = to.Unit:Dot(look)
if d > bestDot then
best, bestDot = part, d
end
end
end
if best then
setAttack(best, "your shot")
end
end)
end
end)
end
task.spawn(function()
while Running do
task.wait(0.06)
pcall(function()
if not Match.allowed() then
setHoldingG(false)
return
end
local handler = findHandler()
local defense = not hasBall() and ((Config.autoGuard.enabled and handler ~= nil)
or (Config.autoSteal.enabled and handler ~= nil))
or (Config.chase.enabled and Config.chase.steal and handler ~= nil)
setHoldingG(defense)
pcall(stealStep)
end)
end
end)
Farm = { target = nil, home = nil, source = "none", status = "Off", side = "?", contestedSince = nil,
lastShot = -10, readyAt = -10, readied = false, readyText = nil, clicks = 0 }
local function farmPos(v)
if typeof(v) == "CFrame" then return v.Position end
if typeof(v) == "Vector3" then return v end
if typeof(v) == "Instance" and v:IsA("BasePart") then return v.Position end
return nil
end
function Farm.onStart()
Farm.target, Farm.home, Farm.source = nil, nil, "none"
Farm.contestedSince = nil
Farm.readied = false
local hrp = getRoot()
if hrp then Farm.home = nearestHoop(hrp.Position) end
end
function Farm.refreshTarget()
local hrp = getRoot()
if not hrp then return end
local state = getState()
local pos = state and farmPos(state:GetAttribute("Goal"))
if pos and not (genv.__BloomGoal and (pos - genv.__BloomGoal).Magnitude < 1) then
local hoop, d = nearestHoop(pos)
if hoop and d < 10 then
Farm.target, Farm.source = hoop, "game"
return
end
end
if Farm.source == "game" and Farm.target and Farm.target.Parent then return end
if Attack.goal and Attack.goal.Parent and Attack.source ~= "farm" then
Farm.target, Farm.source = Attack.goal, Attack.source
return
end
local list = hoopList()
if #list < 2 then return end
local home = Farm.home
if not (home and home.Parent) then home = nearestHoop(hrp.Position) Farm.home = home end
local far, farD = nil, -1
for _, part in ipairs(list) do
local d = (part.Position - home.Position).Magnitude
if part ~= home and d > farD then far, farD = part, d end
end
if far then Farm.target, Farm.source = far, "start side" end
end
local function flatDir(from, to)
local v = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
if v.Magnitude < 0.05 then return nil, 0 end
return v.Unit, v.Magnitude
end
function Farm.step()
if not Config.farm.enabled then return false end
local char, hrp = getCharacter(), getRoot()
if not char or not hrp then Farm.status = "Waiting for character" return false end
local now = clock()
local ti = char:GetAttribute("TeamIndex")
Farm.side = ti == nil and "?" or (ti == 1 and "Home" or "Away")
if Shot.active then
local since = now - Shot.pressedAt
local wait = math.max(Config.autoShoot.holdTime, 0.4) + (Config.autoGreen.enabled and 0.9 or 0)
if (not Shot.session and not meterActive() and since > wait) or since > 3 then releaseShoot() end
stopGlide()
Farm.status = "Shooting"
return true
end
if char:GetAttribute("Action") == "Shooting" or meterActive() then
stopGlide()
Farm.status = "Shooting"
return true
end
Farm.refreshTarget()
local speed = clamp(Config.farm.speed, 10, 60)
local myPos = hrp.Position
if not hasBall() then
Farm.contestedSince = nil
if findHandler() then
Farm.status = "They have the ball"
return false
end
local ball = Ball.part
if ball and ball.Parent and Ball.owner == nil then
local dir, dist = flatDir(myPos, ball.Position)
if dir and dist > 2 then
Def.walk(dir, speed)
Farm.status = "Getting the ball"
return true
end
end
Farm.status = "Looking for the ball"
return false
end
local goal = Farm.target
if not goal or not goal.Parent then Farm.status = "Finding their hoop" return false end
Attack.goal, Attack.source = goal, "farm"
local toHoop, dist = flatDir(myPos, goal.Position)
toHoop = toHoop or Vector3.new(0, 0, 1)
local opp, od, oroot = nearestOther(false)
local contest = (opp and od) and contestPercent(od) or 0
local away = nil
if oroot then away = flatDir(oroot.Position, myPos) end
local inRange = dist <= Config.farm.shootRange
if inRange then
if contest <= 0 then
Farm.contestedSince = nil
else
Farm.contestedSince = Farm.contestedSince or now
end
local force = Config.farm.forceAfter > 0 and Farm.contestedSince and now - Farm.contestedSince >= Config.farm.forceAfter
if (contest <= 0 or force) and now - Farm.lastShot > 1.4 then
Farm.lastShot = now
Farm.contestedSince = nil
stopGlide()
pressShoot()
Farm.status = (contest <= 0) and "Open - shooting" or "Forced shot"
return true
end
local dir = away or toHoop
if dist > Config.farm.shootRange - 3 then dir = (dir + toHoop).Unit end
Def.walk(dir, speed)
Farm.status = string.format("Getting open (%d%%)", contest)
return true
end
Farm.contestedSince = nil
local dir = toHoop
if away and od and od < 12 then dir = (toHoop + away * 0.9).Unit end
Def.walk(dir, speed)
Farm.status = "Running to hoop (" .. Farm.source .. ")"
return true
end
local function buttonText(b)
if b:IsA("TextButton") then return b.Text end
for _, d in ipairs(b:GetDescendants()) do
if d:IsA("TextLabel") and d.Text ~= "" then return d.Text end
end
return ""
end
local function reallyShown(o)
while o do
if o:IsA("GuiObject") and not o.Visible then return false end
if o:IsA("ScreenGui") and not o.Enabled then return false end
o = o.Parent
end
return true
end
function Farm.findReady()
local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
if not pg then return nil end
for _, d in ipairs(pg:GetDescendants()) do
if (d:IsA("TextButton") or d:IsA("ImageButton")) and not d:FindFirstAncestor("BloomUI") then
local t = (buttonText(d) .. " " .. d.Name):lower()
if t:find("ready", 1, true) and not t:find("unready", 1, true) and not t:find("not ready", 1, true)
and not t:find("already", 1, true) and not t:find("cancel", 1, true) then
if d.AbsoluteSize.X > 4 and reallyShown(d) then return d end
end
end
end
return nil
end
local function pressButton(b)
if getconnections then
for _, name in ipairs({ "MouseButton1Click", "Activated", "MouseButton1Down" }) do
local ok, list = pcall(getconnections, b[name])
if ok and type(list) == "table" and #list > 0 then
for _, c in ipairs(list) do pcall(function() c:Fire() end) end
return true
end
end
end
local pos, size = b.AbsolutePosition, b.AbsoluteSize
local x, y = pos.X + size.X / 2, pos.Y + size.Y / 2
local sg = b:FindFirstAncestorOfClass("ScreenGui")
if not (sg and sg.IgnoreGuiInset) then
local inset = game:GetService("GuiService"):GetGuiInset()
x, y = x + inset.X, y + inset.Y
end
local vim = game:GetService("VirtualInputManager")
vim:SendMouseButtonEvent(x, y, 0, true, game, 1)
task.wait(0.05)
vim:SendMouseButtonEvent(x, y, 0, false, game, 1)
return true
end
function Farm.readyStep()
local now = clock()
if now - Farm.readyAt < 6 then return end
local btn = Farm.findReady()
if not btn then return end
local text = buttonText(btn)
if Farm.readied and text ~= Farm.readyText then return end
Farm.readyAt, Farm.readied, Farm.readyText = now, true, text
Farm.clicks += 1
pcall(pressButton, btn)
Farm.status = "Clicked Ready"
end
task.spawn(function()
while Running do
task.wait(1.5)
if Config.farm.enabled and Config.farm.autoReady and Match.state ~= "Match" then
pcall(Farm.readyStep)
end
end
end)
track(LocalPlayer.Idled:Connect(function()
if not Config.farm.antiAfk then return end
pcall(function()
game:GetService("VirtualUser"):CaptureController()
game:GetService("VirtualUser"):ClickButton2(Vector2.new())
end)
end))
function Farm.set(on)
Config.farm.enabled = on
if on then
Config.autoGreen.enabled = true
if Config.farm.autoDefense then Config.autoGuard.enabled, Config.autoSteal.enabled = true, true end
if Config.farm.stamina then Config.move.stamina = true end
else
pcall(stopGlide)
Farm.status = "Off"
end
end
track(RunService.Stepped:Connect(function(_, dt)
if not Running then return end
if not Match.allowed() then
if Config.move.boost then
local ok, moved = pcall(Mv.boostStep)
if ok and moved then return end
end
if Move.forced then pcall(stopGlide) end
return
end
if not Config.aimbot.enabled and not Config.dribble.enabled and not Config.autoGuard.enabled and not Config.farm.enabled
and not Config.block.enabled and not Config.rebound.enabled and not Config.move.boost
and not Config.autoSteal.enabled then
if Move.forced then pcall(stopGlide) end
return
end
local ok, err = pcall(function()
aimStep(dt)
if Config.rebound.enabled then
Def.reboundStep()
if clock() - Def.rebAt < 0.15 then return end
end
if Config.farm.enabled and Farm.step() then
elseif (Config.block.enabled or Config.autoGuard.enabled) and Def.blockStep() then
elseif Config.autoGuard.enabled and not hasBall() and findHandler() and guardStep(false) then
elseif Config.dribble.enabled and hasBall() then
dribbleStep()
elseif Config.autoSteal.enabled and not hasBall() and findHandler() and guardStep(true) then
elseif Config.move.boost and Mv.boostStep() then
else
stopGlide()
end
end)
if not ok then
warn("[Bloom] movement: " .. tostring(err))
end
end))
local C = {
Window    = Color3.fromRGB(13, 13, 13),
Sidebar   = Color3.fromRGB(13, 13, 13),
Card      = Color3.fromRGB(20, 20, 20),
Line      = Color3.fromRGB(30, 30, 30),
Selected  = Color3.fromRGB(28, 28, 28),
Box       = Color3.fromRGB(30, 30, 30),
Text      = Color3.fromRGB(235, 235, 235),
Muted     = Color3.fromRGB(95, 95, 95),
SubText   = Color3.fromRGB(150, 150, 150),
ToggleOn  = Color3.fromRGB(85, 85, 85),
ToggleOff = Color3.fromRGB(40, 40, 40),
Knob      = Color3.fromRGB(255, 255, 255),
Accent    = Color3.fromRGB(150, 150, 150),
Purple    = Color3.fromRGB(150, 150, 150),
Violet    = Color3.fromRGB(150, 150, 150),
PurpleText = Color3.fromRGB(150, 150, 150),
}
local function new(class, props, parent)
local inst = Instance.new(class)
for k, v in pairs(props or {}) do inst[k] = v end
if parent then inst.Parent = parent end
return inst
end
local function corner(parent, r)
return new("UICorner", { CornerRadius = UDim.new(0, r) }, parent)
end
local function strokeOf(parent, color, thickness, transparency)
return new("UIStroke", {
Color = color, Thickness = thickness or 1, Transparency = transparency or 0,
ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
}, parent)
end
local function label(parent, text, size, color, font, pos, sz, xAlign)
return new("TextLabel", {
BackgroundTransparency = 1,
Text = text,
TextSize = size,
TextColor3 = color or C.Text,
Font = font or Enum.Font.Gotham,
Position = pos or UDim2.new(),
Size = sz or UDim2.new(1, 0, 0, size + 4),
TextXAlignment = xAlign or Enum.TextXAlignment.Left,
TextYAlignment = Enum.TextYAlignment.Top,
TextWrapped = true,
}, parent)
end
local function tweenTo(obj, props, t)
TweenService:Create(obj, TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad), props):Play()
end
local function flow(parent)
parent.BackgroundColor3 = C.Purple
end
local GuiParent
do
local function getGuiParent()
local ok, ui = pcall(function() return (gethui and gethui()) end)
if ok and ui then return ui end
ok, ui = pcall(function() return game:GetService("CoreGui") end)
if ok and ui then return ui end
return PlayerGui
end
GuiParent = getGuiParent()
end
for _, name in ipairs({ "BloomUI", "BloomContest" }) do
local o = GuiParent:FindFirstChild(name)
if o then o:Destroy() end
end
local IconFor = { ["Auto Green"] = "target", ["Open Shot"] = "eye", OP = "flame", Farm = "trophy", Dribble = "pulse",
Defense = "shield", Player = "user", Visuals = "eye", Boost = "bolt", Buttons = "box", Misc = "gear" }
local buildIcon
do
buildIcon = function(name, parent)
local holder = new("Frame", { Size = UDim2.fromOffset(18, 18), BackgroundTransparency = 1, ClipsDescendants = true }, parent)
local solids, strokes = {}, {}
local function line(x1, y1, x2, y2, th)
th = th or 1.6
local dx, dy = x2 - x1, y2 - y1
local len = math.sqrt(dx * dx + dy * dy)
local f = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2),
Size = UDim2.fromOffset(len + th * 0.6, th), Rotation = math.deg(math.atan2(dy, dx)), BorderSizePixel = 0 }, holder)
corner(f, 2)
table.insert(solids, f)
end
local function poly(points, closed)
for i = 1, #points - 1 do line(points[i][1], points[i][2], points[i + 1][1], points[i + 1][2]) end
if closed then line(points[#points][1], points[#points][2], points[1][1], points[1][2]) end
end
local function ring(x, y, size, th)
local f = new("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(size, size),
BackgroundTransparency = 1, BorderSizePixel = 0 }, holder)
corner(f, size)
table.insert(strokes, strokeOf(f, C.SubText, th or 1.6))
end
local function dot(x, y, size)
local f = new("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(size, size), BorderSizePixel = 0 }, holder)
corner(f, size)
table.insert(solids, f)
end
local function box(x, y, w, h, r, th)
local f = new("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
BackgroundTransparency = 1, BorderSizePixel = 0 }, holder)
corner(f, r)
table.insert(strokes, strokeOf(f, C.SubText, th or 1.6))
end
local icons = {
target = function() ring(2, 2, 14, 1.6) ring(5.5, 5.5, 7, 1.6) dot(7.5, 7.5, 3) end,
eye = function() box(1.5, 4.5, 15, 9, 5, 1.6) dot(6.5, 6.5, 5) end,
flame = function()
poly({ { 9, 1.5 }, { 13.5, 8 }, { 14.5, 12 }, { 12, 16 }, { 9, 17 }, { 6, 16 }, { 3.5, 12 }, { 4.5, 8.5 }, { 7, 10.5 }, { 7.5, 5 } }, true)
end,
trophy = function()
box(4.5, 2.5, 9, 8, 3, 1.6) line(9, 11, 9, 14.5) line(5.5, 15.5, 12.5, 15.5) ring(0.8, 3.5, 4, 1.4) ring(13.2, 3.5, 4, 1.4)
end,
pulse = function() poly({ { 0.5, 9 }, { 5, 9 }, { 7.5, 2.5 }, { 11, 15 }, { 13, 9 }, { 17.5, 9 } }) end,
shield = function() poly({ { 9, 1.5 }, { 15.5, 3.5 }, { 15, 10 }, { 9, 16.5 }, { 3, 10 }, { 2.5, 3.5 } }, true) end,
user = function() ring(5.5, 1.5, 7, 1.6) ring(2.5, 11, 13, 1.6) end,
bolt = function() poly({ { 10.5, 1.5 }, { 4, 10 }, { 9, 10 }, { 7.5, 16.5 }, { 14, 7.5 }, { 9, 7.5 } }, true) end,
box = function() box(2, 2, 14, 14, 4, 1.6) dot(7, 7, 4) end,
gear = function()
ring(4, 4, 10, 1.6) dot(7.5, 7.5, 3)
for i = 0, 7 do
local a = i * math.pi / 4
line(9 + math.cos(a) * 6.8, 9 + math.sin(a) * 6.8, 9 + math.cos(a) * 8.6, 9 + math.sin(a) * 8.6, 2.2)
end
end,
}
;(icons[name] or icons.target)()
local function setColor(color)
for _, f in ipairs(solids) do f.BackgroundColor3 = color end
for _, st in ipairs(strokes) do st.Color = color end
end
setColor(C.SubText)
return holder, setColor
end
end
local Gui = new("ScreenGui", {
Name = "BloomUI",
ResetOnSpawn = false,
ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
IgnoreGuiInset = true,
DisplayOrder = 9999,
}, GuiParent)
local WIN_W, WIN_H, SIDE_W = 840, 610, 240
local FIT = 1
do
local cam = Workspace.CurrentCamera
local view = cam and cam.ViewportSize or Vector2.new(1280, 720)
FIT = math.min(1, (view.Y - 16) / WIN_H, (view.X - 16) / WIN_W)
end
local Window = new("Frame", {
Name = "Window",
BackgroundColor3 = C.Window,
BorderSizePixel = 0,
Size = UDim2.fromOffset(WIN_W, WIN_H),
AnchorPoint = Vector2.new(0.5, 0.5),
Position = UDim2.new(0.5, 0, 0.5, 0),
ClipsDescendants = true,
}, Gui)
corner(Window, 22)
local WinScale = new("UIScale", { Scale = (Config.ui.scale or 1) * FIT }, Window)
strokeOf(Window, C.Line, 1)
local Sidebar = new("Frame", {
Name = "Sidebar",
BackgroundColor3 = C.Sidebar,
BorderSizePixel = 0,
Size = UDim2.new(0, SIDE_W, 1, 0),
}, Window)
corner(Sidebar, 22)
local SideBG = Sidebar
new("Frame", {
BackgroundColor3 = C.Line, BorderSizePixel = 0,
Position = UDim2.new(0, SIDE_W, 0, 0), Size = UDim2.new(0, 1, 1, 0),
}, Window)
local closeDot, minDot
do
local dotHolder = new("Frame", {
BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 10), Size = UDim2.fromOffset(60, 14),
}, Sidebar)
local function dot(x, color, name)
local b = new("TextButton", {
Name = name, Text = "", AutoButtonColor = false,
BackgroundColor3 = color, BorderSizePixel = 0,
Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(12, 12),
}, dotHolder)
corner(b, 12)
return b
end
closeDot = dot(0, Color3.fromRGB(237, 85, 80), "Close")
minDot = dot(18, Color3.fromRGB(240, 185, 55), "Minimize")
dot(36, Color3.fromRGB(45, 45, 45), "Max")
end
local Pill = new("TextButton", {
Name = "Pill", Text = "Prada", Font = Enum.Font.GothamBold, TextSize = 13,
TextColor3 = C.Text, BackgroundColor3 = C.Card, BorderSizePixel = 0, AutoButtonColor = false,
AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10),
Size = UDim2.fromOffset(96, 28), Visible = false,
}, Gui)
corner(Pill, 16)
strokeOf(Pill, C.Line, 1)
label(Sidebar, "Prada Hub", 17, C.Text, Enum.Font.GothamBold,
UDim2.fromOffset(24, 56), UDim2.fromOffset(190, 22))
new("Frame", { BackgroundColor3 = C.Line, BorderSizePixel = 0,
Position = UDim2.fromOffset(0, 98), Size = UDim2.new(1, 0, 0, 1) }, Sidebar)
local TabScroll = new("ScrollingFrame", {
Name = "Tabs",
BackgroundTransparency = 1, BorderSizePixel = 0,
Position = UDim2.fromOffset(0, 108), Size = UDim2.new(1, 0, 1, -190),
ScrollBarThickness = 2, ScrollBarImageColor3 = C.Line,
CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, Sidebar)
new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, TabScroll)
new("UIPadding", { PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 20), PaddingTop = UDim.new(0, 4) }, TabScroll)
new("Frame", { BackgroundColor3 = C.Line, BorderSizePixel = 0,
Position = UDim2.new(0, 0, 1, -76), Size = UDim2.new(1, 0, 0, 1) }, Sidebar)
local Profile = { aboutLabel = nil }
do
local avatar = new("ImageLabel", {
BackgroundColor3 = Color3.fromRGB(35, 35, 35), BorderSizePixel = 0,
Position = UDim2.new(0, 24, 1, -58), Size = UDim2.fromOffset(40, 40),
}, Sidebar)
corner(avatar, 20)
local avatarImage = ""
local nameLabel = label(Sidebar, LocalPlayer.DisplayName, 12, C.Text, Enum.Font.GothamBold,
UDim2.new(0, 74, 1, -54), UDim2.fromOffset(150, 16))
local userLabel = label(Sidebar, "@" .. LocalPlayer.Name, 11, C.Muted, Enum.Font.Gotham,
UDim2.new(0, 74, 1, -37), UDim2.fromOffset(150, 14))
function Profile.apply(hide)
if hide then
avatar.Image = ""
nameLabel.Text = "Hidden"
userLabel.Text = "@hidden"
else
avatar.Image = avatarImage
nameLabel.Text = LocalPlayer.DisplayName
userLabel.Text = "@" .. LocalPlayer.Name
end
if Profile.aboutLabel then
Profile.aboutLabel.Text = "Prada Hub\n" .. (hide and "Name hidden" or ("Logged in as " .. LocalPlayer.Name))
end
end
task.spawn(function()
local ok, img = pcall(function()
return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
end)
if ok then
avatarImage = img
if not Config.misc.hideName then avatar.Image = img end
end
end)
Profile.apply(Config.misc.hideName)
end
local Content = new("Frame", {
Name = "Content", BackgroundTransparency = 1,
Position = UDim2.fromOffset(SIDE_W + 1, 0), Size = UDim2.new(1, -(SIDE_W + 1), 1, 0),
}, Window)
local PageTitle = label(Content, "Auto Green", 13, C.SubText, Enum.Font.Gotham,
UDim2.fromOffset(24, 18), UDim2.fromOffset(300, 16))
new("Frame", { BackgroundColor3 = C.Line, BorderSizePixel = 0,
Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, 0, 0, 1) }, Content)
local notify
do
local ToastHolder = new("Frame", {
AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -18, 1, -18),
Size = UDim2.fromOffset(250, 300), BackgroundTransparency = 1,
}, Gui)
new("UIListLayout", {
SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom,
Padding = UDim.new(0, 6),
}, ToastHolder)
local toastOrder = 0
notify = function(title, text)
toastOrder += 1
local f = new("Frame", {
Size = UDim2.new(1, 0, 0, 48), BackgroundColor3 = C.Card, BorderSizePixel = 0,
LayoutOrder = toastOrder,
}, ToastHolder)
corner(f, 14)
strokeOf(f, C.Line, 1)
label(f, title, 12, C.Text, Enum.Font.GothamBold, UDim2.fromOffset(14, 8), UDim2.new(1, -28, 0, 16))
label(f, text or "", 11, C.SubText, Enum.Font.Gotham, UDim2.fromOffset(14, 25), UDim2.new(1, -28, 0, 14))
task.delay(3, function() f:Destroy() end)
end
end
local menuKey = Config.ui.keybind
local binding = nil
local minimized = false
local function setWindowVisible(visible)
Window.Visible = visible
Pill.Visible = (not visible) and minimized
end
minDot.MouseButton1Click:Connect(function()
minimized = true
setWindowVisible(false)
end)
Pill.MouseButton1Click:Connect(function()
minimized = false
setWindowVisible(true)
end)
do
local function headerButton(text, xOffset, hoverColor)
local b = new("TextButton", {
Text = text, Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = C.SubText,
AutoButtonColor = false, BackgroundColor3 = C.Selected, BorderSizePixel = 0,
Size = UDim2.fromOffset(32, 28), Position = UDim2.new(1, xOffset, 0, 12), ZIndex = 5,
}, Content)
corner(b, 12)
b.MouseEnter:Connect(function()
tweenTo(b, { BackgroundColor3 = hoverColor })
b.TextColor3 = C.Text
end)
b.MouseLeave:Connect(function()
tweenTo(b, { BackgroundColor3 = C.Selected })
b.TextColor3 = C.SubText
end)
return b
end
local minButton = headerButton("-", -80, Color3.fromRGB(70, 60, 30))
local closeButton = headerButton("X", -44, Color3.fromRGB(110, 40, 40))
minButton.MouseButton1Click:Connect(function()
minimized = true
setWindowVisible(false)
end)
closeButton.MouseButton1Click:Connect(function()
local inst = genv.BloomInstance
if inst then inst.unload() else Gui:Destroy() end
end)
end
do
local function makeDraggable(handle, target)
local dragging, dragStart, startPos
handle.InputBegan:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
dragging, dragStart, startPos = true, input.Position, target.Position
end
end)
track(UIS.InputChanged:Connect(function(input)
if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
or input.UserInputType == Enum.UserInputType.Touch) then
local d = input.Position - dragStart
target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
startPos.Y.Scale, startPos.Y.Offset + d.Y)
end
end))
track(UIS.InputEnded:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
dragging = false
end
end))
end
makeDraggable(Sidebar, Window)
makeDraggable(Content, Window)
end
track(UIS.InputBegan:Connect(function(input, processed)
if binding then
if input.UserInputType == Enum.UserInputType.Keyboard then
binding(input.KeyCode)
end
return
end
if processed then return end
if input.KeyCode == menuKey then
minimized = false
setWindowVisible(not Window.Visible)
end
end))
local Tabs, TabButtons, TabIcons = {}, {}, {}
local widgetSync = {}
local function refreshWidgets()
for _, fn in ipairs(widgetSync) do
pcall(fn)
end
end
local function selectTab(name)
PageTitle.Text = name
for n, tab in pairs(Tabs) do
tab.page.Visible = (n == name)
end
for n, btn in pairs(TabButtons) do
tweenTo(btn, { BackgroundTransparency = (n == name) and 0 or 1 })
btn.Label.TextColor3 = (n == name) and C.Text or C.SubText
TabIcons[n]((n == name) and C.Text or C.SubText)
end
if Tabs[name] and Tabs[name].onShow then pcall(Tabs[name].onShow) end
end
local tabOrder = 0
local addTab, separator
do
local function buildColumns(page)
local function col(xs, xo)
local c = new("ScrollingFrame", {
BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2,
ScrollBarImageColor3 = C.Line, AutomaticCanvasSize = Enum.AutomaticSize.Y,
CanvasSize = UDim2.new(),
Size = UDim2.new(0.5, -18, 1, -12), Position = UDim2.new(xs, xo, 0, 12),
}, page)
new("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }, c)
new("UIPadding", { PaddingBottom = UDim.new(0, 12) }, c)
return c
end
return col(0, 12), col(0.5, 6)
end
addTab = function(name, icon)
tabOrder += 1
local btn = new("TextButton", {
Name = name, Text = "", AutoButtonColor = false,
BackgroundColor3 = C.Selected, BackgroundTransparency = 1, BorderSizePixel = 0,
Size = UDim2.new(1, 0, 0, 40), LayoutOrder = tabOrder,
}, TabScroll)
corner(btn, 12)
local iconHolder, setIconColor = buildIcon(icon or IconFor[name] or "target", btn)
iconHolder.Name = "Icon"
iconHolder.Position = UDim2.fromOffset(14, 11)
TabIcons[name] = setIconColor
new("TextLabel", {
Name = "Label", BackgroundTransparency = 1, Text = name, TextSize = 14,
TextColor3 = C.SubText, Font = Enum.Font.GothamMedium,
TextXAlignment = Enum.TextXAlignment.Left,
Position = UDim2.fromOffset(44, 0), Size = UDim2.new(1, -44, 1, 0),
}, btn)
TabButtons[name] = btn
btn.MouseButton1Click:Connect(function() selectTab(name) end)
btn.MouseEnter:Connect(function()
if Tabs[name] and not Tabs[name].page.Visible then
btn.Label.TextColor3 = C.Text
setIconColor(C.Text)
end
end)
btn.MouseLeave:Connect(function()
if Tabs[name] and not Tabs[name].page.Visible then
btn.Label.TextColor3 = C.SubText
setIconColor(C.SubText)
end
end)
local page = new("Frame", {
Name = name, BackgroundTransparency = 1, Visible = false,
Position = UDim2.fromOffset(0, 53), Size = UDim2.new(1, 0, 1, -53),
}, Content)
local left, right = buildColumns(page)
local tab = { name = name, page = page, left = left, right = right, order = 0 }
Tabs[name] = tab
return tab
end
separator = function()
tabOrder += 1
local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 17), LayoutOrder = tabOrder }, TabScroll)
new("Frame", { BackgroundColor3 = C.Line, BorderSizePixel = 0,
Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 1) }, holder)
end
end
local Card
do
local function defaultFormat(v)
if v == math.floor(v) then
return tostring(v)
end
return (string.format("%.3f", v):gsub("0+$", ""))
end
local function rowLabel(parent, text, rightWidth)
return new("TextLabel", {
BackgroundTransparency = 1, Text = text, TextSize = 13, TextColor3 = C.Text,
Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left,
TextTruncate = Enum.TextTruncate.AtEnd,
Size = UDim2.new(1, -rightWidth, 1, 0),
}, parent)
end
Card = function(tab, title, side)
local col = (side == "right") and tab.right or tab.left
tab.order += 1
local card = new("Frame", {
Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
BackgroundColor3 = C.Card, BorderSizePixel = 0, LayoutOrder = tab.order,
}, col)
corner(card, 16)
new("UIPadding", { PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 14),
PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }, card)
new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, card)
local n = 0
local function nxt() n += 1; return n end
if title then
new("TextLabel", {
BackgroundTransparency = 1, Text = title, TextSize = 15, TextColor3 = C.Text,
Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left,
Size = UDim2.new(1, 0, 0, 20), LayoutOrder = nxt(),
}, card)
end
local c = {}
function c:Note(text)
local l = new("TextLabel", {
BackgroundTransparency = 1, Text = text, TextSize = 11, TextColor3 = C.Muted,
Font = Enum.Font.Gotham, TextWrapped = true,
TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = nxt(),
}, card)
return l
end
function c:Toggle(text, tbl, key, after)
local state = tbl[key] and true or false
local row = new("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, LayoutOrder = nxt() }, card)
rowLabel(row, text, 60)
local sw = new("TextButton", {
Text = "", AutoButtonColor = false, BackgroundColor3 = C.ToggleOff, BorderSizePixel = 0,
Size = UDim2.fromOffset(50, 24), Position = UDim2.new(1, -50, 0.5, -12),
}, row)
corner(sw, 12)
local knob = new("Frame", {
BackgroundColor3 = C.Knob, BorderSizePixel = 0,
Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(4, 3),
}, sw)
corner(knob, 9)
local function render()
tweenTo(knob, { Position = state and UDim2.fromOffset(28, 3) or UDim2.fromOffset(4, 3) })
tweenTo(sw, { BackgroundColor3 = state and C.ToggleOn or C.ToggleOff })
end
render()
sw.MouseButton1Click:Connect(function()
state = not state
tbl[key] = state
render()
if after then task.spawn(after, state) end
refreshWidgets()
end)
table.insert(widgetSync, function()
local v = tbl[key] and true or false
if v ~= state then
state = v
render()
end
end)
end
function c:Slider(text, min, max, tbl, key, step, fmt, after)
step = step or 1
fmt = fmt or defaultFormat
local value = clamp(tbl[key], min, max)
local row = new("Frame", { Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1, LayoutOrder = nxt() }, card)
new("TextLabel", {
BackgroundTransparency = 1, Text = text, TextSize = 13, TextColor3 = C.Text,
Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left,
TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, -80, 0, 22),
}, row)
local box = new("Frame", {
Size = UDim2.fromOffset(66, 22), Position = UDim2.new(1, -66, 0, 0),
BackgroundColor3 = C.Box, BorderSizePixel = 0,
}, row)
corner(box, 10)
local valueText = new("TextLabel", {
BackgroundTransparency = 1, Text = fmt(value), TextSize = 12, TextColor3 = C.Text,
Font = Enum.Font.GothamBold, Size = UDim2.fromScale(1, 1),
}, box)
local bar = new("Frame", {
Size = UDim2.new(1, -12, 0, 6), Position = UDim2.new(0, 6, 0, 34),
BackgroundColor3 = C.ToggleOff, BorderSizePixel = 0,
}, row)
corner(bar, 3)
local fill = new("Frame", {
Size = UDim2.fromScale((value - min) / (max - min), 1),
BackgroundColor3 = C.Accent, BorderSizePixel = 0,
}, bar)
corner(fill, 3)
local knob = new("Frame", {
Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0.5, 0.5),
Position = UDim2.new(1, 0, 0.5, 0), BackgroundColor3 = C.Knob, BorderSizePixel = 0,
}, fill)
corner(knob, 7)
local hit = new("TextButton", {
Text = "", BackgroundTransparency = 1,
Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 0, 26),
}, row)
local function setValue(v, write)
v = clamp(math.floor(v / step + 0.5) * step, min, max)
v = tonumber(string.format("%.4f", v))
value = v
valueText.Text = fmt(v)
fill.Size = UDim2.fromScale((v - min) / (max - min), 1)
if write then
tbl[key] = v
if after then after(v) end
end
end
local sliding = false
local function fromInput(input)
local rel = clamp((input.Position.X - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
setValue(min + (max - min) * rel, true)
end
hit.InputBegan:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
sliding = true
fromInput(input)
end
end)
track(UIS.InputChanged:Connect(function(input)
if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement
or input.UserInputType == Enum.UserInputType.Touch) then
fromInput(input)
end
end))
track(UIS.InputEnded:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
sliding = false
end
end))
table.insert(widgetSync, function()
if not sliding and tbl[key] ~= value then setValue(tbl[key], false) end
end)
end
function c:Dropdown(text, options, tbl, key, after)
local row = new("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = nxt() }, card)
rowLabel(row, text, 130)
local btn = new("TextButton", {
Text = tostring(tbl[key]), Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = C.Text,
TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
AutoButtonColor = false, Size = UDim2.fromOffset(122, 28),
Position = UDim2.new(1, -122, 0.5, -14), BackgroundColor3 = C.Box, BorderSizePixel = 0,
}, row)
corner(btn, 12)
new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 20) }, btn)
new("TextLabel", {
BackgroundTransparency = 1, Text = "v", Font = Enum.Font.GothamBold, TextSize = 11,
TextColor3 = C.SubText, Size = UDim2.fromOffset(18, 28), Position = UDim2.new(1, -4, 0, 0),
}, btn)
btn.MouseButton1Click:Connect(function()
local winPos = Window.AbsolutePosition
local rx = btn.AbsolutePosition.X - winPos.X
local ry = btn.AbsolutePosition.Y - winPos.Y
local w = btn.AbsoluteSize.X
local h = math.min(#options * 26 + 8, 230)
local y = ry + 32
if y + h > WIN_H - 6 then y = ry - h - 4 end
local overlay = new("TextButton", {
Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 49,
}, Window)
local menu = new("ScrollingFrame", {
Position = UDim2.fromOffset(rx, y), Size = UDim2.fromOffset(w, h),
BackgroundColor3 = C.Selected, BorderSizePixel = 0, ScrollBarThickness = 2,
ScrollBarImageColor3 = C.Accent, AutomaticCanvasSize = Enum.AutomaticSize.Y,
CanvasSize = UDim2.new(), ZIndex = 50,
}, Window)
corner(menu, 14)
strokeOf(menu, C.Line, 1)
new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, menu)
new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4),
PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }, menu)
local function close()
overlay:Destroy()
menu:Destroy()
end
overlay.MouseButton1Click:Connect(close)
overlay.MouseButton2Click:Connect(close)
for _, option in ipairs(options) do
local item = new("TextButton", {
Text = option, Font = Enum.Font.GothamMedium, TextSize = 12,
TextColor3 = (option == tbl[key]) and C.Text or C.SubText,
BackgroundColor3 = C.Box, BorderSizePixel = 0, AutoButtonColor = false,
Size = UDim2.new(1, 0, 0, 24), ZIndex = 51,
}, menu)
corner(item, 9)
item.MouseEnter:Connect(function() item.BackgroundColor3 = C.ToggleOff end)
item.MouseLeave:Connect(function() item.BackgroundColor3 = C.Box end)
item.MouseButton1Click:Connect(function()
tbl[key] = option
btn.Text = tostring(option)
close()
if after then task.spawn(after, option) end
end)
end
end)
table.insert(widgetSync, function()
local v = tostring(tbl[key])
if btn.Text ~= v then btn.Text = v end
end)
end
function c:Input(text, tbl, key, after)
local row = new("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = nxt() }, card)
rowLabel(row, text, 130)
local box = new("TextBox", {
Text = tostring(tbl[key] or ""), PlaceholderText = "type here", Font = Enum.Font.GothamBold,
TextSize = 12, TextColor3 = C.Text, PlaceholderColor3 = C.Muted, ClearTextOnFocus = false,
TextXAlignment = Enum.TextXAlignment.Left,
Size = UDim2.fromOffset(122, 28), Position = UDim2.new(1, -122, 0.5, -14),
BackgroundColor3 = C.Box, BorderSizePixel = 0,
}, row)
corner(box, 10)
new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 6) }, box)
box.FocusLost:Connect(function()
tbl[key] = (box.Text ~= "") and box.Text or tbl[key]
if after then task.spawn(after, tbl[key]) end
end)
end
function c:Button(text, callback)
local b = new("TextButton", {
Text = text, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = C.Text,
AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 32),
BackgroundColor3 = C.Selected, BorderSizePixel = 0, LayoutOrder = nxt(),
}, card)
corner(b, 12)
strokeOf(b, C.Line, 1)
b.MouseEnter:Connect(function() tweenTo(b, { BackgroundColor3 = C.Box }) end)
b.MouseLeave:Connect(function() tweenTo(b, { BackgroundColor3 = C.Selected }) end)
b.MouseButton1Click:Connect(function()
if callback then task.spawn(callback) end
end)
return b
end
function c:Keybind(text, getKey, setKey)
local row = new("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = nxt() }, card)
rowLabel(row, text, 90)
local btn = new("TextButton", {
Text = getKey().Name, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = C.Text,
AutoButtonColor = false, Size = UDim2.fromOffset(82, 28),
Position = UDim2.new(1, -82, 0.5, -14), BackgroundColor3 = C.Box, BorderSizePixel = 0,
}, row)
corner(btn, 12)
btn.MouseButton1Click:Connect(function()
btn.Text = "..."
binding = function(key)
binding = nil
if key == Enum.KeyCode.Escape then key = Enum.KeyCode.RightShift end
setKey(key)
btn.Text = key.Name
end
end)
end
return c
end
end
local T = {}
do
T.Shooting = addTab("Auto Green")
T.ShotX = T.Shooting
T.OpenShot = addTab("Open Shot")
T.Movement = addTab("OP")
separator()
T.Dribbling = addTab("Dribble")
T.Defense = addTab("Defense")
separator()
T.Player = addTab("Player")
T.Visuals = addTab("Visuals")
T.Boost = addTab("Boost")
T.Buttons = addTab("Buttons")
T.Mascot = addTab("Mascot")
T.Settings = addTab("Misc")
do
local AssetService = game:GetService("AssetService")
local Look = { original = nil, active = false, name = nil, desc = nil, char = nil }
local function lookWear(desc, label, silent)
local char, hum = getCharacter(), getHumanoid()
if not hum then
if not silent then notify("Mascot", "no character yet") end
return false
end
if not Look.original or Look.char ~= char then
local ok, orig = pcall(function() return hum:GetAppliedDescription() end)
if ok and orig then Look.original = orig end
end
local ok = pcall(function() hum:ApplyDescription(desc) end)
if not ok then
if not silent then notify("Mascot", "could not apply that look") end
return false
end
Look.active, Look.name, Look.desc, Look.char = true, label, desc, char
if not silent then notify("Mascot", "wearing " .. tostring(label) .. " (only you see this)") end
return true
end
local function lookRestore()
local hum = getHumanoid()
if hum and Look.original then pcall(function() hum:ApplyDescription(Look.original) end) end
Look.active, Look.name, Look.desc = false, nil, nil
notify("Mascot", "restored")
end
local function bundleApply(bundleId, label)
local ok, details = pcall(function() return AssetService:GetBundleDetailsAsync(bundleId) end)
if not ok or type(details) ~= "table" then notify("Mascot", "could not read that bundle") return end
local outfitId = nil
for _, item in pairs(details.Items or {}) do
if item.UserOutfit then outfitId = item.UserOutfit break end
end
if not outfitId then notify("Mascot", "that bundle has no outfit to copy") return end
local okD, desc = pcall(function() return Players:GetHumanoidDescriptionFromOutfitId(outfitId) end)
if not okD or not desc then notify("Mascot", "could not load that outfit") return end
lookWear(desc, label)
end
task.spawn(function()
while Running do
task.wait(1.5)
if Look.active and Look.desc and getCharacter() and getCharacter() ~= Look.char then
local desc, label = Look.desc, Look.name
Look.original = nil
pcall(lookWear, desc, label, true)
end
end
end)
local mascotCard = Card(T.Mascot, "Mascot", "left")
mascotCard:Button("Haymaker Dog", function() task.spawn(bundleApply, 238242939018769, "Haymaker Dog") end)
mascotCard:Button("Triple T OFFICIAL", function() task.spawn(bundleApply, 170431393424031, "Triple T OFFICIAL") end)
mascotCard:Button("Back to my avatar", function() lookRestore() end)
mascotCard:Note("Your screen only. Uses the game's own rig and animations, same as your real character, so it should move normally instead of looking off.")
end
T.SA, T.SB, T.SC, T.SD = T.Settings, T.Settings, T.Settings, T.Settings
end
local fmtInt, fmt1, fmt2, fmt3, fmtSec, fmtMs, fmtPct
do
fmtInt = function(v) return string.format("%d", v) end
fmt1 = function(v) return string.format("%.1f", v) end
fmt2 = function(v) return string.format("%.2f", v) end
fmt3 = function(v) return string.format("%.3f", v) end
fmtSec = function(v) return string.format("%.2fs", v) end
fmtMs = function(v) return string.format("%dms", v) end
fmtPct = function(v) return string.format("%d%%", v) end
end
local Lighting = game:GetService("Lighting")
local VirtualUser = game:GetService("VirtualUser")
local TextChatService = game:GetService("TextChatService")
do
local lastContest = 0
track(RunService.RenderStepped:Connect(function()
if not Running then return end
local now = clock()
if now - lastContest < 0.05 then return end
lastContest = now
local model, dist = nearestOther(false)
Contest.percent = model and contestPercent(dist) or 0
Contest.dist = model and dist or nil
end))
end
local HudGui
do
for _, name in ipairs({ "BloomContest" }) do
local old = GuiParent:FindFirstChild(name)
if old then old:Destroy() end
end
HudGui = Instance.new("ScreenGui")
HudGui.Name = "BloomContest"
HudGui.ResetOnSpawn = false
HudGui.IgnoreGuiInset = true
HudGui.DisplayOrder = 1000
HudGui.Parent = GuiParent
local function hudLabel(y, size)
local l = Instance.new("TextLabel")
l.BackgroundTransparency = 1
l.AnchorPoint = Vector2.new(0.5, 0)
l.Position = UDim2.new(0.5, 0, 0, y)
l.Size = UDim2.fromOffset(320, size + 6)
l.Font = Enum.Font.GothamSemibold
l.TextSize = size
l.TextStrokeTransparency = 0.35
l.TextColor3 = Color3.fromRGB(70, 255, 120)
l.Text = ""
l.Parent = HudGui
return l
end
local contestLabel = hudLabel(6, 26)
local statLabel = hudLabel(36, 16)
local readyLabel = hudLabel(56, 14)
readyLabel.Size = UDim2.fromOffset(460, 20)
local frames, acc, fps = 0, 0, 60
local lastHud = 0
track(RunService.RenderStepped:Connect(function(dt)
if not Running then return end
frames += 1
acc += dt
if acc >= 0.5 then
fps = math.floor(frames / acc + 0.5)
frames, acc = 0, 0
end
local now = clock()
if now - lastHud < 0.1 then return end
lastHud = now
local show = Config.contest.enabled
contestLabel.Visible = show
if show then
local p = Contest.percent
contestLabel.Text = string.format("CONTEST %d%%", p)
local color
if p <= 0 then color = Color3.fromRGB(70, 255, 120)
elseif p < 60 then color = Color3.fromRGB(255, 220, 80)
else color = Color3.fromRGB(255, 80, 80) end
contestLabel.TextColor3 = color
end
local okGreen, why = false, nil
if Config.autoGreen.enabled then okGreen, why = Green.ready() end
readyLabel.Visible = Config.autoGreen.enabled
readyLabel.Text = okGreen and "AUTO GREEN: READY" or ("AUTO GREEN: NOT READY" .. (why and (" - " .. why) or ""))
readyLabel.TextColor3 = okGreen and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(255, 90, 90)
readyLabel.Position = UDim2.new(0.5, 0, 0, (show and 30 or 0) + (Config.hud.showStats and 24 or 0) + 8)
local stats = Config.hud.showStats
statLabel.Visible = stats
statLabel.Position = UDim2.new(0.5, 0, 0, show and 36 or 6)
if stats then
statLabel.Text = string.format("PING %dms   FPS %d   %s%s", math.floor(pingSeconds() * 1000 + 0.5), fps, (Match.state == "Lobby" and Match.placeName or Match.state):upper(),
(clock() - (Guard.lastActive or -10) < 0.4) and "   DEFENDING" or
(Config.autoGuard.enabled and ("   D:" .. (findHandler() and findHandler().Name or "none")) or ""))
end
end))
end
do
local old = GuiParent:FindFirstChild("BloomOverlay")
if old then old:Destroy() end
local Overlay = Instance.new("ScreenGui")
Overlay.Name = "BloomOverlay"
Overlay.ResetOnSpawn = false
Overlay.IgnoreGuiInset = true
Overlay.DisplayOrder = 900
Overlay.Parent = GuiParent
Extra.overlay = Overlay
local WHITE = Color3.new(1, 1, 1)
local function bar(parent, w, h, rot, pos)
local f = Instance.new("Frame")
f.BackgroundColor3, f.BorderSizePixel = WHITE, 0
f.AnchorPoint, f.Position, f.Size, f.Rotation = Vector2.new(0.5, 0.5), pos or UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(w, h), rot
f.Parent = parent
return f
end
function Extra.onPerfect()
if Config.fb.sound then
local snd = Instance.new("Sound")
snd.SoundId, snd.Volume = "rbxasset://sounds/electronicpingshort.wav", 0.8
snd.Parent = Overlay
snd:Play()
task.delay(1.5, function() snd:Destroy() end)
end
if Config.fb.flash then
local f = Instance.new("Frame")
f.BackgroundColor3, f.BackgroundTransparency, f.BorderSizePixel = WHITE, 0.88, 0
f.Size = UDim2.fromScale(1, 1)
f.Parent = Overlay
TweenService:Create(f, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
task.delay(0.4, function() f:Destroy() end)
end
if Config.fb.hit then
local holder = Instance.new("Frame")
holder.BackgroundTransparency = 1
holder.AnchorPoint, holder.Position, holder.Size = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(40, 40)
holder.Parent = Overlay
for _, r in ipairs({ 45, -45 }) do bar(holder, 26, 3, r) end
task.spawn(function()
for i = 1, 10 do
task.wait(0.03)
holder.Size = UDim2.fromOffset(40 + i * 2, 40 + i * 2)
end
holder:Destroy()
end)
end
end
local mark = Instance.new("TextLabel")
mark.BackgroundColor3, mark.BackgroundTransparency, mark.BorderSizePixel = Color3.fromRGB(10, 10, 10), 0.15, 0
mark.Position, mark.AutomaticSize, mark.Size = UDim2.fromOffset(12, 12), Enum.AutomaticSize.X, UDim2.fromOffset(0, 26)
mark.Font, mark.TextSize, mark.TextColor3, mark.Visible = Enum.Font.GothamSemibold, 13, WHITE, false
mark.Parent = Overlay
do
local c = Instance.new("UICorner")
c.CornerRadius = UDim.new(0, 8)
c.Parent = mark
local pad = Instance.new("UIPadding")
pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)
pad.Parent = mark
end
local listLabel = Instance.new("TextLabel")
listLabel.BackgroundTransparency = 1
listLabel.AnchorPoint, listLabel.Position, listLabel.Size = Vector2.new(1, 0), UDim2.new(1, -14, 0, 12), UDim2.fromOffset(200, 200)
listLabel.Font, listLabel.TextSize, listLabel.TextColor3 = Enum.Font.GothamBold, 13, WHITE
listLabel.TextXAlignment, listLabel.TextYAlignment, listLabel.TextStrokeTransparency = Enum.TextXAlignment.Right, Enum.TextYAlignment.Top, 0.5
listLabel.Visible = false
listLabel.Parent = Overlay
local features = {
{ "Auto Green", Config.autoGreen, "enabled" }, { "Auto Defense", Config.autoGuard, "enabled" },
{ "Auto Rebound", Config.rebound, "enabled" },
{ "Auto Block", Config.block, "enabled" }, { "Face the hoop", Config.aimbot, "enabled" },
{ "Shot arc", Config.arc, "enabled" },
}
local frames, acc, fps = 0, 0, 60
local lastText = 0
track(RunService.RenderStepped:Connect(function(dt)
if not Running then return end
frames += 1
acc += dt
if acc >= 0.5 then fps, frames, acc = math.floor(frames / acc + 0.5), 0, 0 end
local now = clock()
if now - lastText < 0.5 then return end
lastText = now
mark.Visible = Config.overlay.watermark
if mark.Visible then
mark.Text = string.format("Prada Hub   |   %d fps   |   %d ms   |   %s", fps, math.floor(pingSeconds() * 1000 + 0.5),
(Match.state == "Lobby" and Match.placeName or Match.state or ""):upper())
end
listLabel.Visible = Config.overlay.list
if listLabel.Visible then
local lines = {}
for _, f in ipairs(features) do
if f[2][f[3]] then lines[#lines + 1] = f[1] end
end
listLabel.Text = table.concat(lines, "\n")
end
end))
local arcDots = {}
for i = 1, 26 do
local d = Instance.new("Part")
d.Name, d.Shape, d.Size, d.Material = "BloomFx", Enum.PartType.Ball, Vector3.new(0.28, 0.28, 0.28), Enum.Material.Neon
d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch, d.CastShadow, d.Transparency = true, false, false, false, false, 1
d.Parent = Workspace
arcDots[i] = d
end
local arcOn = false
track(RunService.RenderStepped:Connect(function()
if not Running then return end
local hrp = getRoot()
local showArc = false
if Config.arc.enabled and hrp and hasBall() then
local goal, dist = shootHoop(hrp.Position)
if goal and dist and dist < 70 then
showArc = true
local p0 = hrp.Position + Vector3.new(0, 2.5, 0)
local p2 = goal.Position
local p1 = (p0 + p2) / 2 + Vector3.new(0, dist * 0.45 + 4, 0)
for i, d in ipairs(arcDots) do
local u = (i - 1) / (#arcDots - 1)
d.Position = (1 - u) ^ 2 * p0 + 2 * (1 - u) * u * p1 + u ^ 2 * p2
d.Transparency = 0.15 + (i % 2) * 0.25
d.Color = WHITE
end
end
end
if not showArc and arcOn then
for _, d in ipairs(arcDots) do d.Transparency = 1 end
end
arcOn = showArc
end))
local keyLookup = {}
for _, item in ipairs(Enum.KeyCode:GetEnumItems()) do keyLookup[string.lower(item.Name)] = item.Name end
local alias = { cross = "ButtonA", circle = "ButtonB", square = "ButtonX", triangle = "ButtonY", l1 = "ButtonL1",
r1 = "ButtonR1", l2 = "ButtonL2", r2 = "ButtonR2", l3 = "ButtonL3", r3 = "ButtonR3", share = "ButtonSelect",
options = "ButtonStart", up = "DPadUp", down = "DPadDown", left = "DPadLeft", right = "DPadRight" }
function Extra.keyName(text)
local k = string.lower(text or "")
return keyLookup[k] or alias[k]
end
function Extra.listen(cb)
local conn
conn = UserInputService.InputBegan:Connect(function(input)
local t = input.UserInputType
if (t == Enum.UserInputType.Keyboard or t.Name:sub(1, 7) == "Gamepad") and input.KeyCode ~= Enum.KeyCode.Unknown then
conn:Disconnect()
cb(input.KeyCode.Name)
end
end)
task.delay(8, function() if conn.Connected then conn:Disconnect() end end)
end
local binds = {
{ "green", "Auto Green", Config.autoGreen }, { "guard", "Auto Defense", Config.autoGuard },
{ "rebound", "Auto Rebound", Config.rebound }, { "aim", "Face the hoop", Config.aimbot },
{ "block", "Auto Block", Config.block },
}
track(UserInputService.InputBegan:Connect(function(input, processed)
if processed or not Running or input.UserInputType ~= Enum.UserInputType.Keyboard then return end
for _, b in ipairs(binds) do
local key = Config.keys[b[1]]
if key ~= "" and input.KeyCode.Name == key then
b[3].enabled = not b[3].enabled
if not b[3].enabled and b[1] == "guard" then pcall(stopGlide) end
refreshWidgets()
pcall(notify, b[2], b[3].enabled and "on" or "off")
end
end
end))
Extra.binds = binds
local function slotFile() return "bloom_" .. string.lower(Config.slots.slot):gsub("%s+", "_") .. ".json" end
function Extra.saveSlot()
local ok = Persist.saveAs(slotFile())
pcall(notify, Config.slots.slot, ok and "saved" or "could not save")
end
function Extra.loadSlot()
local ok = Persist.load(slotFile())
if ok then
refreshWidgets()
end
pcall(notify, Config.slots.slot, ok and "loaded" or "empty slot")
end
function Extra.cleanup()
for _, d in ipairs(arcDots) do pcall(function() d:Destroy() end) end
pcall(function() Overlay:Destroy() end)
end
end
do
track(RunService.RenderStepped:Connect(function()
if not Running then return end
if not Config.autoGreen.rainbow then return end
local meter = getMeter()
if not meter then return end
do
local t = os.clock() * 0.35
local keys = {}
for i = 0, 6 do
keys[#keys + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV((t + i / 6) % 1, 0.85, 1))
end
local seq = ColorSequence.new(keys)
for _, d in ipairs(meter:GetDescendants()) do
if d:IsA("UIGradient") then d.Color = seq end
end
end
end))
do
local bb = Instance.new("BillboardGui")
bb.Name, bb.AlwaysOnTop, bb.Size, bb.StudsOffset, bb.Enabled = "BloomOpen", true, UDim2.fromOffset(130, 34), Vector3.new(0, 4.3, 0), false
bb.Parent = Extra.overlay
local pill = Instance.new("Frame")
pill.BackgroundColor3, pill.BackgroundTransparency, pill.BorderSizePixel = Color3.fromRGB(10, 10, 10), 0.1, 0
pill.Size = UDim2.fromScale(1, 1)
pill.Parent = bb
local pc = Instance.new("UICorner")
pc.CornerRadius = UDim.new(1, 0)
pc.Parent = pill
local ps = Instance.new("UIStroke")
ps.Color, ps.Thickness, ps.Transparency = Color3.new(1, 1, 1), 1.5, 0.35
ps.Parent = pill
local bar = Instance.new("Frame")
bar.BackgroundColor3, bar.BorderSizePixel = Color3.fromRGB(34, 34, 34), 0
bar.AnchorPoint, bar.Position, bar.Size = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.new(1, -10, 1, -10)
bar.Parent = pill
local tc = Instance.new("UICorner")
tc.CornerRadius = UDim.new(1, 0)
tc.Parent = bar
local fill = Instance.new("Frame")
fill.BorderSizePixel, fill.Size = 0, UDim2.fromScale(1, 1)
fill.Parent = bar
local fc = Instance.new("UICorner")
fc.CornerRadius = UDim.new(1, 0)
fc.Parent = fill
local txt = Instance.new("TextLabel")
txt.BackgroundTransparency, txt.Size, txt.Font, txt.TextSize = 1, UDim2.fromScale(1, 1), Enum.Font.GothamBlack, 13
txt.TextColor3, txt.TextStrokeTransparency, txt.ZIndex = Color3.new(1, 1, 1), 0.3, 3
txt.Parent = bar
local shown = 0
local GREEN, YELLOW, RED = Color3.fromRGB(70, 255, 120), Color3.fromRGB(255, 220, 80), Color3.fromRGB(255, 80, 80)
track(RunService.RenderStepped:Connect(function(dt)
if not Running then return end
local hrp = getRoot()
bb.Enabled = Config.openMeter.enabled and hrp ~= nil
if not bb.Enabled then return end
bb.Adornee = hrp
bb.Size = UDim2.fromOffset(130 * Config.openMeter.scale, 34 * Config.openMeter.scale)
local open = 1 - math.clamp((Contest.percent or 0) / 100, 0, 1)
shown += (open - shown) * math.min(dt * 10, 1)
fill.Size = UDim2.fromScale(math.max(shown, 0.04), 1)
local col = shown > 0.5 and YELLOW:Lerp(GREEN, (shown - 0.5) * 2) or RED:Lerp(YELLOW, shown * 2)
fill.BackgroundColor3 = col
txt.Text = open >= 0.99 and "OPEN" or string.format("%d%% OPEN", math.floor(open * 100 + 0.5))
end))
end
do
local bb = Instance.new("BillboardGui")
bb.Name, bb.AlwaysOnTop, bb.Size, bb.StudsOffset, bb.Enabled = "BloomTag", true, UDim2.fromOffset(260, 30), Vector3.new(0, 5.8, 0), false
bb.Parent = Extra.overlay
local t = Instance.new("TextLabel")
t.BackgroundTransparency, t.Size, t.Font, t.TextSize = 1, UDim2.fromScale(1, 1), Enum.Font.GothamBlack, 20
t.TextColor3, t.TextStrokeTransparency, t.TextStrokeColor3 = Color3.new(1, 1, 1), 0.2, Color3.new(0, 0, 0)
t.Parent = bb
track(RunService.RenderStepped:Connect(function()
if not Running then return end
local hrp = getRoot()
bb.Enabled = Config.tag.enabled and hrp ~= nil
if bb.Enabled then
bb.Adornee = hrp
t.Text = "\u{266A} " .. Config.tag.text
end
end))
end
end
do
local Overlay = Extra.overlay
local M = { index = 0 }
Extra.music = M
local sound = Instance.new("Sound")
sound.Name = "BloomMusic"
sound.Parent = Overlay
local win = Instance.new("Frame")
win.BackgroundColor3, win.BorderSizePixel, win.Visible = Color3.fromRGB(8, 8, 8), 0, false
win.AnchorPoint, win.Position, win.Size = Vector2.new(0, 1), UDim2.new(0, 20, 1, -20), UDim2.fromOffset(340, 216)
win.Active = true
win.Parent = Overlay
do
local c = Instance.new("UICorner")
c.CornerRadius = UDim.new(0, 14)
c.Parent = win
local st = Instance.new("UIStroke")
st.Color, st.Thickness, st.Transparency = Color3.new(1, 1, 1), 1, 0.7
st.Parent = win
end
local video = Instance.new("VideoFrame")
video.BackgroundColor3, video.BorderSizePixel = Color3.new(0, 0, 0), 0
video.Position, video.Size = UDim2.fromOffset(8, 30), UDim2.new(1, -16, 1, -62)
video.Parent = win
local vc = Instance.new("UICorner")
vc.CornerRadius = UDim.new(0, 8)
vc.Parent = video
local title = Instance.new("TextLabel")
title.BackgroundTransparency, title.Position, title.Size = 1, UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 20)
title.Font, title.TextSize, title.TextColor3, title.TextXAlignment = Enum.Font.GothamBold, 13, Color3.new(1, 1, 1), Enum.TextXAlignment.Left
title.Text = "music"
title.Parent = win
local timeLabel = Instance.new("TextLabel")
timeLabel.BackgroundTransparency, timeLabel.AnchorPoint = 1, Vector2.new(0, 1)
timeLabel.Position, timeLabel.Size = UDim2.new(0, 12, 1, -6), UDim2.new(1, -24, 0, 20)
timeLabel.Font, timeLabel.TextSize, timeLabel.TextColor3, timeLabel.TextXAlignment = Enum.Font.GothamSemibold, 12, Color3.fromRGB(170, 170, 170), Enum.TextXAlignment.Left
timeLabel.Text = "0:00 / 0:00"
timeLabel.Parent = win
do
local drag, from, startPos
win.InputBegan:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
drag, from, startPos = true, input.Position, win.Position
end
end)
track(UserInputService.InputChanged:Connect(function(input)
if drag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
local d = input.Position - from
win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
end
end))
track(UserInputService.InputEnded:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then drag = false end
end))
end
local playing, isVideo = false, false
local function fmtTime(t) return string.format("%d:%02d", math.floor(t / 60), math.floor(t % 60)) end
local function fetch(url)
local req = envFn("request") or envFn("http_request")
if req then
local ok, res = pcall(req, { Url = url, Method = "GET" })
if ok and res and res.Body and #res.Body > 0 then return res.Body end
end
local ok, body = pcall(function() return game:HttpGet(url) end)
return ok and body or nil
end
function M.stop()
playing = false
pcall(function() sound:Stop() end)
pcall(function() video:Pause() end)
win.Visible = false
end
function M.play(src)
src = (src or ""):gsub("^%s+", ""):gsub("%s+$", "")
if src == "" then return notify("Music", "type an audio id or a direct file link first") end
M.stop()
local asset, video0
if src:match("^%d+$") then
asset = "rbxassetid://" .. src
elseif src:match("^https?://") then
if src:find("youtube.com", 1, true) or src:find("youtu.be", 1, true) then
return notify("Music", "YouTube links can't be played, use a direct file link or an audio id")
end
local ext = (src:match("%.(%w+)[%?#]?[^/%.]*$") or "mp3"):lower()
if not ({ mp3 = 1, ogg = 1, wav = 1, mp4 = 1, webm = 1 })[ext] then ext = "mp3" end
video0 = (ext == "mp4" or ext == "webm")
local sum = 0
for i = 1, #src do sum = (sum * 31 + src:byte(i)) % 1000000007 end
local file = "bloom_music_" .. sum .. "." .. ext
local have = false
pcall(function() have = isfile(file) end)
if not have then
notify("Music", "downloading...")
local body = fetch(src)
if not body then return notify("Music", "could not download that link") end
local ok = pcall(function() writefile(file, body) end)
if not ok then return notify("Music", "your executor can't save files") end
end
local ok, a = pcall(function() return getcustomasset(file) end)
if not ok then return notify("Music", "your executor can't load custom files") end
asset = a
else
return notify("Music", "that isn't an audio id or a link")
end
isVideo, playing = video0 or false, true
title.Text = src:sub(1, 60)
if isVideo then
video.Video, video.Volume, video.Looped = asset, Config.music.volume, false
win.Visible = Config.music.video
video:Play()
else
sound.SoundId, sound.Volume, sound.Looped = asset, Config.music.volume, false
sound:Play()
win.Visible = false
end
end
M.names = {}
local function lines()
local t = {}
for l in (Config.music.list or ""):gmatch("[^\n]+") do
local src, name = l:match("^([^|]*)|(.*)$")
t[#t + 1] = { src = src or l, name = name or src or l }
end
for i = #M.names, 1, -1 do M.names[i] = nil end
for i, e in ipairs(t) do M.names[i] = e.name end
return t
end
local function save(t)
local o = {}
for i, e in ipairs(t) do o[i] = e.src .. "|" .. e.name end
Config.music.list = table.concat(o, "\n")
lines()
end
local function playEntry(e)
Config.music.sel, Config.music.source = e.name, e.src
title.Text = e.name:sub(1, 60)
refreshWidgets()
M.play(e.src)
title.Text = e.name:sub(1, 60)
end
local function nameFor(src)
if src:match("^%d+$") then
local ok, info = pcall(function() return game:GetService("MarketplaceService"):GetProductInfo(tonumber(src)) end)
if ok and info and info.Name and info.Name ~= "" then return info.Name end
end
return src:sub(1, 28)
end
function M.add()
local src = (Config.music.source or ""):gsub("^%s+", ""):gsub("%s+$", "")
if src == "" then return notify("Music", "type an audio id first") end
local name = (Config.music.name or ""):gsub("|", "")
if name == "" then name = nameFor(src) end
name = name:gsub("|", "")
local t = lines()
local base, n = name, 1
local function taken(x) for _, e in ipairs(t) do if e.name == x then return true end end end
while taken(name) do n = n + 1; name = base .. " (" .. n .. ")" end
t[#t + 1] = { src = src, name = name }
save(t)
Config.music.sel, Config.music.name = name, ""
refreshWidgets()
notify("Music", "saved: " .. name)
end
local function curIndex(t)
for i, e in ipairs(t) do if e.name == Config.music.sel then return i end end
return 0
end
function M.step(dir, auto)
local t = lines()
if #t == 0 then return notify("Music", "the playlist is empty") end
local i = curIndex(t)
local mode = Config.music.loop
if mode == "Shuffle" and #t > 1 then
local j = i
while j == i do j = math.random(1, #t) end
i = j
else
i = ((i - 1 + dir) % #t) + 1
end
M.index = i
playEntry(t[i])
end
function M.playSelected()
local t = lines()
local i = curIndex(t)
if i == 0 then return notify("Music", "pick a saved song first") end
playEntry(t[i])
end
function M.remove()
local t = lines()
local i = curIndex(t)
if i == 0 then return notify("Music", "pick a saved song first") end
table.remove(t, i)
save(t)
Config.music.sel = t[1] and t[1].name or ""
refreshWidgets()
notify("Music", "removed")
end
function M.clear()
Config.music.list, Config.music.sel, M.index = "", "", 0
lines()
refreshWidgets()
notify("Music", "playlist cleared")
end
function M.ended()
if not playing then return end
local mode = Config.music.loop
if mode == "Loop track" then
if isVideo then video.TimePosition = 0; video:Play() else sound.TimePosition = 0; sound:Play() end
elseif mode == "Off" then
local t = lines()
local i = curIndex(t)
if i > 0 and i < #t then M.step(1, true) else M.stop() end
else
M.step(1, true)
end
end
function M.toggle()
if isVideo then
if video.Playing then video:Pause() else video:Play() end
elseif sound.IsPlaying then sound:Pause() else sound:Resume() end
end
function M.volume()
sound.Volume, video.Volume = Config.music.volume, Config.music.volume
end
function M.showVideo()
win.Visible = playing and isVideo and Config.music.video
end
sound.Ended:Connect(function() if not isVideo then M.ended() end end)
video.Ended:Connect(function() if isVideo then M.ended() end end)
lines()
task.spawn(function()
while Running do
task.wait(0.3)
if playing then
local pos, len
if isVideo then pos, len = video.TimePosition, video.TimeLength else pos, len = sound.TimePosition, sound.TimeLength end
timeLabel.Text = fmtTime(pos) .. " / " .. fmtTime(len)
end
end
end)
local oldCleanup = Extra.cleanup
function Extra.cleanup()
pcall(M.stop)
if oldCleanup then oldCleanup() end
end
end
local Perf = { saved = {}, graphicsOn = false, flatOn = false, cpuOn = false }
do
local function remember(inst, prop)
local entry = Perf.saved[inst]
if not entry then
entry = {}
Perf.saved[inst] = entry
end
if entry[prop] == nil then
local ok, value = pcall(function() return inst[prop] end)
if ok then entry[prop] = value end
end
end
local function set(inst, prop, value)
remember(inst, prop)
pcall(function() inst[prop] = value end)
end
local function restore(props)
for inst, entry in pairs(Perf.saved) do
for prop, value in pairs(entry) do
if props[prop] then
pcall(function() inst[prop] = value end)
entry[prop] = nil
end
end
end
end
local fxClasses = { "ParticleEmitter", "Trail", "Beam", "Fire", "Smoke", "Sparkles" }
local function isFx(d)
for _, c in ipairs(fxClasses) do
if d:IsA(c) then return true end
end
return false
end
function Perf.graphics(on)
Perf.graphicsOn = on
if on then
set(Lighting, "GlobalShadows", false)
for _, e in ipairs(Lighting:GetChildren()) do
if e:IsA("PostEffect") and e.Name ~= "BloomColor" then set(e, "Enabled", false) end
if e:IsA("Atmosphere") then set(e, "Density", 0) end
end
pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
set(Lighting, "EnvironmentDiffuseScale", 0)
set(Lighting, "EnvironmentSpecularScale", 0)
set(Lighting, "ShadowSoftness", 0)
set(Lighting, "FogEnd", 1e6)
for _, e in ipairs(Lighting:GetChildren()) do
if e:IsA("Sky") then set(e, "StarCount", 0) end
end
local chars = Workspace:FindFirstChild("Characters")
local function strip(d)
if d.Name == "BloomFx" then return end
if isFx(d) then
set(d, "Enabled", false)
elseif d:IsA("Decal") or d:IsA("Texture") then
if not (chars and d:IsDescendantOf(chars)) then set(d, "Transparency", 1) end
elseif d:IsA("MeshPart") then
set(d, "RenderFidelity", Enum.RenderFidelity.Performance)
elseif d:IsA("SurfaceAppearance") then
pcall(function() d:Destroy() end)
end
end
local n = 0
for _, d in ipairs(Workspace:GetDescendants()) do
n += 1
if n % 1500 == 0 then task.wait() end
strip(d)
end
if Perf.watch then Perf.watch:Disconnect() end
Perf.watch = Workspace.DescendantAdded:Connect(function(d) pcall(strip, d) end)
else
if Perf.watch then Perf.watch:Disconnect() Perf.watch = nil end
restore({ GlobalShadows = true, Enabled = true, Density = true, Transparency = true, RenderFidelity = true,
EnvironmentDiffuseScale = true, EnvironmentSpecularScale = true, ShadowSoftness = true,
FogEnd = true, StarCount = true })
end
end
function Perf.flatten(on)
Perf.flatOn = on
if on then
local chars = Workspace:FindFirstChild("Characters")
local n = 0
for _, d in ipairs(Workspace:GetDescendants()) do
n += 1
if n % 1500 == 0 then task.wait() end
if d:IsA("BasePart") and not d:IsA("Terrain") and not (chars and d:IsDescendantOf(chars)) then
set(d, "Material", Enum.Material.SmoothPlastic)
set(d, "Reflectance", 0)
set(d, "CastShadow", false)
end
end
else
restore({ Material = true, Reflectance = true, CastShadow = true })
end
end
function Perf.lowCpu(on)
Perf.cpuOn = on
local terrain = Workspace:FindFirstChildOfClass("Terrain")
if on then
if terrain then
set(terrain, "Decoration", false)
set(terrain, "WaterWaveSize", 0)
set(terrain, "WaterReflectance", 0)
end
pcall(function() settings().Rendering.EagerBulkExecution = false end)
else
restore({ Decoration = true, WaterWaveSize = true, WaterReflectance = true })
end
end
local function lite(d)
if d:IsA("Accessory") then
for _, h in ipairs(d:GetDescendants()) do
if h:IsA("BasePart") then set(h, "Transparency", 1) end
end
elseif d:IsA("BasePart") then
set(d, "CastShadow", false)
if d:IsA("MeshPart") then set(d, "RenderFidelity", Enum.RenderFidelity.Performance) end
elseif d:IsA("Decal") and d.Name == "face" then
set(d, "Transparency", 1)
elseif d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") then
pcall(function() d:Destroy() end)
end
end
function Perf.mobile(on)
Perf.mobileOn = on
if Perf.mobileWatch then Perf.mobileWatch:Disconnect() Perf.mobileWatch = nil end
if on then
pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
pcall(function() settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level04 end)
set(Lighting, "GlobalShadows", false)
local mine = Workspace:FindFirstChild("Characters")
mine = mine and mine:FindFirstChild(LocalPlayer.Name)
local function apply(model)
if model == mine or model.Name == LocalPlayer.Name then return end
for _, d in ipairs(model:GetDescendants()) do lite(d) end
end
local chars = Workspace:FindFirstChild("Characters")
if chars then
for _, m in ipairs(chars:GetChildren()) do apply(m) end
Perf.mobileWatch = chars.ChildAdded:Connect(function(m)
task.wait(0.5)
pcall(apply, m)
end)
end
else
restore({ GlobalShadows = true, Transparency = true, CastShadow = true, RenderFidelity = true })
end
end
function Perf.ping(on)
Perf.pingOn = on
if on then
pcall(function() settings().Network.IncomingReplicationLag = 0 end)
pcall(function() game:GetService("NetworkClient"):SetOutgoingKBPSLimit(math.huge) end)
pcall(function() settings().Network.PhysicsSend = Enum.PhysicsSendRate and Enum.PhysicsSendRate.Rate60 or settings().Network.PhysicsSend end)
end
end
function Perf.restoreAll()
for inst, entry in pairs(Perf.saved) do
for prop, value in pairs(entry) do
pcall(function() inst[prop] = value end)
end
end
table.clear(Perf.saved)
end
end
do
local lastFps = nil
task.spawn(function()
while Running do
task.wait(1)
local want = nil
if Config.autoGreen.highFps and Config.autoGreen.enabled then
want = 240
elseif Config.perf.fpsCap then
want = Config.perf.fpsValue
elseif Config.perf.lowGraphics then
want = 999
end
if want ~= lastFps then
local fn = envFn("setfpscap")
if fn then
pcall(fn, want or 0)
end
lastFps = want
end
end
end)
end
local Fx = {}
function Fx.resetCharacter()
for _, char in ipairs({ LocalPlayer.Character, getCharacter() }) do
if char then
local hum = char:FindFirstChildWhichIsA("Humanoid", true)
if hum then pcall(function() hum.Health = 0 end) end
pcall(function() char:BreakJoints() end)
end
end
end
do
local shooting = Card(T.Shooting, "Timing", "left")
shooting:Toggle("Auto Green", Config.autoGreen, "enabled", function(v)
if v then
Config.autoGreen.mode = "Meter"
Config.autoGreen.adaptive = true
Config.autoGreen.target = 1.43
Config.autoGreen.compensatePing = true
Config.autoGreen.highFps = true
end
end)
shooting:Toggle("Rainbow meter", Config.autoGreen, "rainbow")
shooting:Note("Hold E to shoot; the release is timed for you.")
Config.openSpot.enabled = false
Config.autoShoot.enabled = false
do
local fb = Card(T.Visuals, "Feedback", "left")
fb:Toggle("Perfect sound", Config.fb, "sound")
fb:Toggle("Perfect flash", Config.fb, "flash")
fb:Toggle("Hit marker", Config.fb, "hit")
fb:Toggle("Shot arc", Config.arc, "enabled")
end
local extras = Card(T.OpenShot, "Open Shot", "left")
extras:Toggle("Face the hoop", Config.aimbot, "enabled")
extras:Toggle("Show release grade", Config.hud, "showGrade")
extras:Toggle("Open meter", Config.openMeter, "enabled")
extras:Slider("Open meter size", 0.6, 1.6, Config.openMeter, "scale", 0.1, function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end)
local stats = Card(T.ShotX, "Live", "right")
local statText = stats:Note("")
statText.TextSize = 13
statText.TextColor3 = C.Text
stats:Button("Copy last shot log", function()
local log = Green.shotLog
local text = log and table.concat(log.lines, "\n") or "no shot yet"
local fn = envFn("setclipboard") or envFn("toclipboard")
if fn then pcall(fn, text) end
notify("Shot log", fn and "copied" or "no clipboard")
end)
stats:Button("Copy meter info", function()
local lines = {}
local function add(t) lines[#lines + 1] = t end
local char = getCharacter()
add("Chosen meter: " .. tostring(Config.autoGreen.meterType))
if char then
for k, v in pairs(char:GetAttributes()) do
if string.lower(k):find("meter", 1, true) or k == "Action" or k == "Stamina" then add("char." .. k .. " = " .. tostring(v)) end
end
end
local function dump(root, label)
if not root then return end
for _, d in ipairs(root:GetDescendants()) do
if string.lower(d.Name):find("meter", 1, true) or d:GetAttribute("Active") ~= nil then
add(label .. d:GetFullName() .. "  [" .. d.ClassName .. "]")
for k, v in pairs(d:GetAttributes()) do add("    @" .. k .. " = " .. tostring(v)) end
if d:IsA("UIGradient") or d:IsA("ImageLabel") or d:IsA("Frame") then
add("    size " .. tostring(d.AbsoluteSize) .. (d:IsA("UIGradient") and (" offset " .. tostring(d.Offset)) or ""))
end
end
end
end
dump(char, "char: ")
dump(LocalPlayer:FindFirstChild("PlayerGui"), "gui: ")
local m = getMeter()
add("found by script: " .. (m and m:GetFullName() or "nothing"))
local text = table.concat(lines, "\n")
local fn = envFn("setclipboard") or envFn("toclipboard")
if fn then pcall(fn, text) end
print(text)
notify("Meter", fn and "info copied" or "printed to console")
end)
stats:Button("Reset stats", function()
Green.shots, Green.perfect = 0, 0
Green.stat = { streak = 0, best = 0 }
Green.history = {}
end)
task.spawn(function()
while Running do
local st = Green.stat or { streak = 0, best = 0 }
local n, p = Green.shots or 0, Green.perfect or 0
local last = Green.history[#Green.history]
local lastText = "-"
if last then lastText = (last == 5 and "Perfect") or (last < 5 and "Early") or "Late" end
local char = getCharacter()
local stam = char and tonumber(char:GetAttribute("Stamina"))
statText.Text = string.format("Grade: %s\nPing: %d ms\nReal stamina: %s\nPerfect rate: %d%% (%d of %d)\nStreak %d   Best %d",
lastText, math.floor(pingSeconds() * 1000 + 0.5), stam and (stam >= 95 and "full" or tostring(math.floor(stam))) or "?",
n > 0 and math.floor(p / n * 100 + 0.5) or 0, p, n, st.streak, st.best)
task.wait(0.4)
end
end)
local defenseCard = Card(T.Defense, "Defense", "left")
defenseCard:Toggle("Auto Defense", Config.autoGuard, "enabled", function(v)
Config.chase.enabled = false
if not v then pcall(stopGlide) end
end)
defenseCard:Slider("Defense speed", 12, 32, Config.autoGuard, "speed", 1, function(v) return string.format("%d", v) end)
defenseCard:Slider("Defense circle", 10, 80, Config.autoGuard, "range", 1, function(v)
return string.format("%d", v)
end)
defenseCard:Toggle("Auto Rebound", Config.rebound, "enabled")
defenseCard:Toggle("Auto Smart Steal", Config.autoSteal, "enabled", function(v)
if v then Config.autoGuard.enabled, Config.autoSteal.smart, Config.chase.enabled = true, true, false end
refreshWidgets()
end)
defenseCard:Toggle("Smart steal", Config.autoSteal, "smart")
defenseCard:Slider("Steal reach", 4, 12, Config.autoSteal, "range", 0.5, fmt1)
do
local more = Card(T.Defense, "Extras", "right")
more:Toggle("Auto Block", Config.block, "enabled", function(v)
end)
more:Toggle("Ignore pump fakes", Config.block, "ignoreFakes")
local dv = Card(T.Visuals, "Defense", "right")
dv:Toggle("Ring on ball handler", Config.defVis, "target")
dv:Toggle("Reach ring", Config.defVis, "reach")
more:Slider("Fake delay", 0.1, 0.5, Config.block, "fakeWait", 0.05, fmt2)
more:Slider("Block range", 5, 20, Config.block, "jumpRange", 1, function(v) return string.format("%d", v) end)
end
local function syncDribble()
Config.dribble.enabled = Config.dribble.glide or Config.dribble.fast or Config.dribble.macro.enabled
if not Config.dribble.glide then pcall(stopGlide) end
end
syncDribble()
local dribCard = Card(T.Dribbling, "Dribble glide", "left")
dribCard:Toggle("Dribble glide", Config.dribble, "glide", syncDribble)
dribCard:Slider("Glide speed", 16, 60, Config.dribble, "speed", 1, function(v) return string.format("%d", v) end)
local typed = { v = "" }
dribCard:Input("Set glide speed (16-60)", typed, "v", function(text)
local n = tonumber(text)
if n then Config.dribble.speed = math.clamp(n, 16, 60) end
refreshWidgets()
end)
local fastCard = Card(T.Dribbling, "Speed dribble", "right")
fastCard:Toggle("Speed dribble", Config.dribble, "fast", syncDribble)
fastCard:Slider("Dribbles per second", 2, 20, Config.dribble, "rate", 1, function(v) return string.format("%d", v) end)
local macroCard = Card(T.Dribbling, "Dribble macro", "left")
macroCard:Toggle("Use a move when contested", Config.dribble.macro, "enabled", syncDribble)
macroCard:Dropdown("Move set", { "Crossover", "Hesitation", "Spin", "In and out" }, Config.dribble.macro, "preset")
macroCard:Slider("Trigger at contest %", 10, 100, Config.dribble.macro, "trigger", 5, function(v) return string.format("%d%%", v) end)
macroCard:Slider("Cooldown (s)", 0.4, 3, Config.dribble.macro, "cooldown", 0.1, function(v) return string.format("%.1f", v) end)
macroCard:Note("While you have the ball and the defender is this close, it runs the move once, then waits the cooldown before trying again.")
do
local Overlay = Extra.overlay
local feats = {
{ "green", "Auto Green", Config.autoGreen, "enabled" },
{ "guard", "Auto Defense", Config.autoGuard, "enabled", function(v) if not v then pcall(stopGlide) end end },
{ "rebound", "Auto Rebound", Config.rebound, "enabled" },
{ "block", "Auto Block", Config.block, "enabled" },
{ "aim", "Face the hoop", Config.aimbot, "enabled" },
{ "arc", "Shot arc", Config.arc, "enabled" },
{ "glide", "Dribble glide", Config.dribble, "glide", syncDribble },
{ "fast", "Speed dribble", Config.dribble, "fast", syncDribble },
{ "speed", "Speed", Config.move, "boost", function(v) if not v then pcall(stopGlide) end end },
}
local btns = {}
local function sizeOf() return Config.pins.size end
local function count()
local n = 0
for _, f in ipairs(feats) do if Config.pins[f[1]] then n += 1 end end
return n
end
local function place(i)
local h = sizeOf() + 8
return UDim2.new(1, -(sizeOf() * 2.4 + 8), 0.5, (i - 1) * h - (count() * h) / 2)
end
local function make(i, f)
local b = Instance.new("TextButton")
b.Name, b.AutoButtonColor, b.Text = "Pin_" .. f[1], false, f[2]
b.Font, b.TextSize, b.BorderSizePixel = Enum.Font.GothamBold, 13, 0
b.Size, b.Position = UDim2.fromOffset(sizeOf() * 2.4, sizeOf()), place(i)
local c = Instance.new("UICorner")
c.CornerRadius = UDim.new(0, 12)
c.Parent = b
b.Parent = Overlay
local drag, moved, startPos, startMouse, active
b.InputBegan:Connect(function(input)
local t = input.UserInputType
if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
drag, moved, startPos, startMouse, active = true, false, b.Position, input.Position, input
end
end)
track(UserInputService.InputChanged:Connect(function(input)
if not drag then return end
local t = input.UserInputType
if t == Enum.UserInputType.MouseMovement or (t == Enum.UserInputType.Touch and input == active) then
local d = input.Position - startMouse
if d.Magnitude > 8 then moved = true end
if moved then
b:SetAttribute("moved", true)
b.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
end
end
end))
track(UserInputService.InputEnded:Connect(function(input)
if not drag then return end
local t = input.UserInputType
if t == Enum.UserInputType.MouseButton1 or (t == Enum.UserInputType.Touch and input == active) then
drag = false
if not moved then
f[3][f[4]] = not f[3][f[4]]
if f[5] then pcall(f[5], f[3][f[4]]) end
refreshWidgets()
end
end
end))
return b
end
local function sync()
local n = 0
for i, f in ipairs(feats) do
if Config.pins[f[1]] then
n += 1
if not btns[f[1]] then btns[f[1]] = make(n, f) end
elseif btns[f[1]] then
btns[f[1]]:Destroy()
btns[f[1]] = nil
end
end
local k = 0
for _, f in ipairs(feats) do
local b = btns[f[1]]
if b then
k += 1
b.Size = UDim2.fromOffset(sizeOf() * 2.4, sizeOf())
if not b:GetAttribute("moved") then b.Position = place(k) end
end
end
end
local pins = Card(T.Buttons, "Screen buttons", "left")
for _, f in ipairs(feats) do pins:Toggle(f[2], Config.pins, f[1], sync) end
pins:Slider("Button size", 34, 70, Config.pins, "size", 1, function(v) return string.format("%d", v) end, sync)
pins:Button("Show all", function()
for _, f in ipairs(feats) do Config.pins[f[1]] = true end
refreshWidgets()
sync()
end)
pins:Button("Hide all", function()
for _, f in ipairs(feats) do Config.pins[f[1]] = false end
refreshWidgets()
sync()
end)
pins:Button("Reset positions", function()
local n = 0
for _, f in ipairs(feats) do
if btns[f[1]] then n += 1 btns[f[1]]:SetAttribute("moved", nil) btns[f[1]].Position = place(n) end
end
end)
task.spawn(function()
while Running do
for _, f in ipairs(feats) do
local b = btns[f[1]]
if b then
local on = f[3][f[4]]
b.BackgroundColor3 = on and Color3.fromRGB(245, 245, 245) or Color3.fromRGB(14, 14, 14)
b.TextColor3 = on and Color3.fromRGB(10, 10, 10) or Color3.fromRGB(245, 245, 245)
b.BackgroundTransparency = on and 0.05 or 0.25
end
end
task.wait(0.15)
end
end)
pcall(sync)
end
local movementCard = Card(T.Movement, "Movement", "left")
movementCard:Toggle("Infinite stamina", Config.move, "stamina")
movementCard:Toggle("99+ build", Config.move, "build99", function(v)
if v then task.spawn(function() pcall(Mv.build) end) end
end)
movementCard:Toggle("Jump shot", Config.move, "jumpShot")
movementCard:Slider("Jump height", 1, 12, Config.move, "jumpHeight", 0.5, fmt1)
movementCard:Toggle("Speed", Config.move, "boost")
movementCard:Dropdown("Mode", { "Normal", "Blatant" }, Config.move, "speedMode")
movementCard:Slider("Speed", 0, 100, Config.move, "speedPct", 1, function(v)
return string.format("%d", Mv.speedOf(v))
end)
end
do
do
local ACCENT = {
Default = Color3.fromRGB(150, 150, 150), White = Color3.fromRGB(245, 245, 245), Pink = Color3.fromRGB(255, 82, 162), Violet = Color3.fromRGB(167, 139, 250),
Cyan = Color3.fromRGB(80, 220, 255), Gold = Color3.fromRGB(255, 200, 60), Green = Color3.fromRGB(80, 235, 130),
Red = Color3.fromRGB(255, 90, 90),
}
local BACK = {
Black = { Color3.fromRGB(13, 13, 13), Color3.fromRGB(30, 30, 30), Color3.fromRGB(28, 28, 28), Color3.fromRGB(30, 30, 30) },
Midnight = { Color3.fromRGB(8, 10, 24), Color3.fromRGB(24, 28, 52), Color3.fromRGB(28, 32, 60), Color3.fromRGB(42, 48, 84) },
Plum = { Color3.fromRGB(20, 8, 18), Color3.fromRGB(46, 24, 42), Color3.fromRGB(52, 28, 46), Color3.fromRGB(78, 42, 70) },
Forest = { Color3.fromRGB(8, 18, 12), Color3.fromRGB(24, 44, 32), Color3.fromRGB(28, 50, 36), Color3.fromRGB(42, 76, 54) },
}
local function recolor(pairsList)
local function swap(d)
for _, pr in ipairs(pairsList) do
local old, new = pr[1], pr[2]
if pcall(function() return d.BackgroundColor3 end) and d.BackgroundColor3 == old then d.BackgroundColor3 = new end
if pcall(function() return d.TextColor3 end) and d.TextColor3 == old then d.TextColor3 = new end
if d:IsA("UIStroke") and d.Color == old then d.Color = new end
if d:IsA("ScrollingFrame") and d.ScrollBarImageColor3 == old then d.ScrollBarImageColor3 = new end
end
end
swap(Window)
for _, d in ipairs(Window:GetDescendants()) do swap(d) end
end
local function applyTheme(first)
local a = ACCENT[Config.theme.accent] or ACCENT.Default
local toggleOn = (Config.theme.accent == "Default") and Color3.fromRGB(85, 85, 85) or a
local b = BACK[Config.theme.background] or BACK.Black
local list = {}
if C.Accent ~= a then list[#list + 1] = { C.Accent, a } end
if C.ToggleOn ~= toggleOn and C.ToggleOn ~= C.Accent then list[#list + 1] = { C.ToggleOn, toggleOn } end
if C.Window ~= b[1] then
list[#list + 1] = { C.Window, b[1] }
list[#list + 1] = { C.Box, b[2] }
list[#list + 1] = { C.Selected, b[3] }
list[#list + 1] = { C.Line, b[4] }
end
if #list > 0 then recolor(list) end
C.Accent, C.Purple, C.Violet, C.PurpleText, C.ToggleOn = a, a, a, a, toggleOn
C.Window, C.Sidebar, C.Box, C.Selected, C.Line = b[1], b[1], b[2], b[3], b[4]
refreshWidgets()
end
local th = Card(T.SA, "Colors", "right")
th:Dropdown("Accent", { "Default", "White", "Pink", "Violet", "Cyan", "Gold", "Green", "Red" }, Config.theme, "accent", function() applyTheme() end)
th:Dropdown("Background", { "Black", "Midnight", "Plum", "Forest" }, Config.theme, "background", function() applyTheme() end)
task.defer(applyTheme)
end
local hud = Card(T.SB, "On-screen HUD", "left")
hud:Toggle("Contest % at top of screen", Config.contest, "enabled")
hud:Toggle("Ping + FPS at top of screen", Config.hud, "showStats")
hud:Slider("Contest close (studs = 100%)", 2, 10, Config.contest, "closeDist", 0.5, fmt1)
hud:Slider("Contest far (studs = 0%)", 8, 30, Config.contest, "farDist", 1, fmtInt)
local boost = Card(T.Boost, "FPS Boosters", "left")
boost:Toggle("Low graphics (no shadows, effects, particles)", Config.perf, "lowGraphics", function(v)
task.spawn(Perf.graphics, v)
end)
boost:Toggle("Flatten textures (smooth plastic)", Config.perf, "flatten", function(v)
task.spawn(Perf.flatten, v)
end)
boost:Toggle("Low CPU (no grass, calm water)", Config.perf, "lowCpu", function(v)
task.spawn(Perf.lowCpu, v)
end)
boost:Toggle("Custom FPS limit", Config.perf, "fpsCap")
boost:Slider("FPS limit", 30, 240, Config.perf, "fpsValue", 10, fmtInt)
boost:Toggle("Mobile boost (cheap rendering for other players)", Config.perf, "mobile", function(v)
task.spawn(Perf.mobile, v)
end)
boost:Toggle("Network trim", Config.perf, "pingTrim", function(v)
task.spawn(Perf.ping, v)
end)
boost:Button("Max boost (all of the above)", function()
Config.perf.mobile, Config.perf.pingTrim = true, true
task.spawn(Perf.mobile, true)
task.spawn(Perf.ping, true)
Config.perf.lowGraphics, Config.perf.flatten, Config.perf.lowCpu = true, true, true
refreshWidgets()
task.spawn(Perf.graphics, true)
task.spawn(Perf.flatten, true)
task.spawn(Perf.lowCpu, true)
notify("FPS", "boosters on")
end)
local look = Card(T.SA, "Interface", "left")
look:Slider("Menu opacity", 0, 0.9, Config.ui, "alpha", 0.05, function(v)
return string.format("%d%%", math.floor((1 - v) * 100 + 0.5))
end, function(v)
Window.BackgroundTransparency = v
SideBG.BackgroundTransparency = v
end)
Window.BackgroundTransparency = Config.ui.alpha or 0
SideBG.BackgroundTransparency = Config.ui.alpha or 0
look:Slider("Menu size", 0.5, 1.4, Config.ui, "scale", 0.05, function(v)
return string.format("%d%%", math.floor(v * 100 + 0.5))
end, function(v)
WinScale.Scale = v * FIT
end)
local screen = Card(T.SA, "Screen", "right")
local function applyColor()
local fx = Lighting:FindFirstChild("BloomColor")
if not fx then
fx = Instance.new("ColorCorrectionEffect")
fx.Name = "BloomColor"
fx.Parent = Lighting
end
fx.Enabled = true
fx.Brightness = Config.visual.brightness
fx.Saturation = Config.visual.saturation
end
local function pct(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end
screen:Slider("Brightness", -0.5, 0.5, Config.visual, "brightness", 0.05, pct, applyColor)
screen:Slider("Saturation", -1, 1, Config.visual, "saturation", 0.05, pct, applyColor)
if Config.visual.brightness ~= 0 or Config.visual.saturation ~= 0 then pcall(applyColor) end
do
local ov = Card(T.SB, "Overlay", "right")
ov:Toggle("Watermark", Config.overlay, "watermark")
ov:Toggle("Active features", Config.overlay, "list")
ov:Toggle("Head tag", Config.tag, "enabled")
ov:Input("Tag text", Config.tag, "text")
local keys = Card(T.SC, "Keybinds", "left")
for _, b in ipairs(Extra.binds) do
keys:Input(b[2], Config.keys, b[1], function(text)
local name = Extra.keyName(text)
Config.keys[b[1]] = name or ""
notify(b[2], name and ("key " .. name) or "no such key")
end)
end
local slots = Card(T.SC, "Config slots", "right")
slots:Dropdown("Slot", { "Slot 1", "Slot 2", "Slot 3" }, Config.slots, "slot")
slots:Button("Save to slot", function() Extra.saveSlot() end)
slots:Button("Load slot", function() Extra.loadSlot() end)
end
local profile = Card(T.Player, "Profile", "left")
local profText = profile:Note("")
profText.TextSize = 13
profText.TextColor3 = C.Text
task.spawn(function()
while Running do
pcall(function()
local char = getCharacter()
local function a(k, d) local v = char and char:GetAttribute(k) return v ~= nil and v or d end
local inch = tonumber(a("Height", 0)) or 0
local shown = Config.misc.hideName and "Hidden" or LocalPlayer.DisplayName
profText.Text = string.format("%s\n%s   %s\nHeight %d'%d\"   Weight %s lb\nOverall %s   Stamina %s\nTakeover %s",
shown, tostring(a("Position", "-")), tostring(a("BuildName", "-")), math.floor(inch / 12), inch % 12,
tostring(a("Weight", "-")), tostring(a("Overall", "-")), tostring(math.floor(tonumber(a("Stamina", 0)) or 0)),
tostring(a("TakeoverType", "-")))
end)
task.wait(0.5)
end
end)
local charCard = Card(T.Player, "Actions", "right")
local function forceUnstuck()
pcall(stopGlide)
Move.forced = false
pcall(function() Def.moving = false end)
local proxy, velocity, gyro = getProxy()
if velocity then
velocity.Velocity = Vector3.new(0, 0, 0)
if Move.originalMaxForce then velocity.MaxForce = Move.originalMaxForce end
end
pcall(function()
local state = getState()
if state and state:GetAttribute("CanMove") == false then state:SetAttribute("CanMove", true) end
end)
pcall(function()
local hum = getHumanoid()
if hum then
hum.PlatformStand, hum.Sit = false, false
hum:ChangeState(Enum.HumanoidStateType.GettingUp)
end
end)
pcall(function()
local char = getCharacter()
for _, d in ipairs(char and char:GetDescendants() or {}) do
if d:IsA("BasePart") and d.Anchored then d.Anchored = false end
end
end)
pcall(function()
if proxy and proxy:IsA("BasePart") then
proxy.Anchored = false
proxy.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
proxy.CFrame = proxy.CFrame + Vector3.new(0, 2, 0)
else
local hrp = getRoot()
if hrp then hrp.CFrame = hrp.CFrame + Vector3.new(0, 2, 0) end
end
end)
notify("Unstuck", "done")
end
local NameHide = { saved = {} }
function NameHide.apply()
local on = Config.misc.hideName
local char = getCharacter()
if not char then return end
local hum = char:FindFirstChildWhichIsA("Humanoid", true)
if hum then
if on and NameHide.saved.dist == nil then NameHide.saved.dist = hum.DisplayDistanceType end
if on then hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
elseif NameHide.saved.dist ~= nil then hum.DisplayDistanceType = NameHide.saved.dist NameHide.saved.dist = nil end
end
for _, d in ipairs(char:GetDescendants()) do
if d:IsA("BillboardGui") and d.Name ~= "VerticalMeter" and not d:FindFirstChild("FillGradient", true) then
local hasName = false
for _, l in ipairs(d:GetDescendants()) do
if l:IsA("TextLabel") and (l.Text == LocalPlayer.Name or l.Text == LocalPlayer.DisplayName or l.Text == "@" .. LocalPlayer.Name) then hasName = true end
end
if hasName or string.find(string.lower(d.Name), "name", 1, true) then
if on and NameHide.saved[d] == nil then NameHide.saved[d] = d.Enabled end
if on then d.Enabled = false elseif NameHide.saved[d] ~= nil then d.Enabled = NameHide.saved[d] NameHide.saved[d] = nil end
end
end
end
end
local quick = Card(T.SD, "Quick", "left")
quick:Button("Disable all features", function()
for _, group in ipairs({ "autoShoot", "autoGuard", "autoSteal", "antiSteal", "chase", "block", "rebound",
"openSpot", "dribble", "aimbot" }) do
if Config[group] then Config[group].enabled = false end
end
Config.move.boost = false
refreshWidgets()
notify("Prada Hub", "features disabled")
end)
local usersCard = Card(T.SD, "Prada users", "left")
usersCard:Toggle("Show Prada Hub users above their head", Config.users, "show")
usersCard:Toggle("Let other Prada Hub users see me", Config.users, "share")
usersCard:Note("Sends one hidden marker in chat (at most every 90 s). Whoever runs the hub and receives it gets a tag on their screen. If the game filters or blocks the message, nobody shows up.")
local nameCard = Card(T.SD, "Name", "right")
nameCard:Toggle("Hide my name", Config.misc, "hideName", function(v) Profile.apply(v) NameHide.apply() end)
local Invis = { shown = {}, was = false }
local function invisApply(on)
local char = getCharacter()
if not char then return end
for _, d in ipairs(char:GetDescendants()) do
if d:IsA("BasePart") then
local lname = string.lower(d.Name)
if not string.find(lname, "ball", 1, true) and d.Name ~= "HumanoidRootPart" then
pcall(function() d.LocalTransparencyModifier = on and 1 or 0 end)
end
elseif d:IsA("Decal") or d:IsA("Texture") then
if on then
if Invis.shown[d] == nil then Invis.shown[d] = d.Transparency end
pcall(function() d.Transparency = 1 end)
elseif Invis.shown[d] ~= nil then
pcall(function() d.Transparency = Invis.shown[d] end)
Invis.shown[d] = nil
end
elseif d:IsA("Highlight") or d:IsA("ParticleEmitter") or d:IsA("Trail") then
if on then
if Invis.shown[d] == nil then Invis.shown[d] = d.Enabled end
pcall(function() d.Enabled = false end)
elseif Invis.shown[d] ~= nil then
pcall(function() d.Enabled = Invis.shown[d] end)
Invis.shown[d] = nil
end
end
end
end
nameCard:Toggle("Invisible (your screen)", Config.settings, "invisible", function(v)
if not v then invisApply(false) end
end)
track(RunService.RenderStepped:Connect(function()
if Config.settings.invisible then
Invis.was = true
invisApply(true)
elseif Invis.was then
Invis.was = false
invisApply(false)
end
end))
task.spawn(function()
while Running do
if Config.misc.hideName then pcall(NameHide.apply) end
task.wait(1)
end
end)
charCard:Button("Force unstuck", forceUnstuck)
charCard:Button("Reset character", function() Fx.resetCharacter() end)
local cfg = Card(T.SA, "Config", "left")
cfg:Input("Config name", Config.settings, "name")
local function cfgFile() return Persist.cfgFile(Config.settings.name) end
cfg:Button("Save config", function()
if Persist.saveAs(cfgFile()) then notify("Config", "saved " .. cfgFile()) else notify("Config", "could not save") end
end)
cfg:Button("Load config", function()
local keepOn, keepName = Config.settings.autoLoad, Config.settings.autoName
local ok = Persist.load(cfgFile())
Config.settings.autoLoad, Config.settings.autoName = keepOn, keepName
if ok then
refreshWidgets()
if Config.perf.lowGraphics then task.spawn(Perf.graphics, true) end
if Config.perf.flatten then task.spawn(Perf.flatten, true) end
if Config.perf.lowCpu then task.spawn(Perf.lowCpu, true) end
if Config.perf.mobile then task.spawn(Perf.mobile, true) end
if Config.perf.pingTrim then task.spawn(Perf.ping, true) end
notify("Config", "loaded " .. cfgFile())
else
notify("Config", "no saved config with that name")
end
end)
cfg:Toggle("Auto load this config", Config.settings, "autoLoad", function(v)
if not v then return end
local have = false
pcall(function() have = isfile(cfgFile()) end)
if have then
Config.settings.autoName = Config.settings.name
Persist.save(true)
notify("Auto load", "will load " .. Config.settings.name)
else
Config.settings.autoLoad = false
refreshWidgets()
notify("Auto load", "save a config first")
end
end)
if Config.perf.lowGraphics then task.spawn(Perf.graphics, true) end
if Config.perf.flatten then task.spawn(Perf.flatten, true) end
if Config.perf.lowCpu then task.spawn(Perf.lowCpu, true) end
if Config.perf.mobile then task.spawn(Perf.mobile, true) end
if Config.perf.pingTrim then task.spawn(Perf.ping, true) end
end
do
local SIG = "\u{200B}\u{2063}\u{200C}\u{2063}\u{200B}"
local users = {}
local folder = new("Folder", { Name = "PradaTags" }, GuiParent)
local function mark(name)
if name and name ~= LocalPlayer.Name then users[name] = true end
end
local function hook(plr)
if plr == LocalPlayer then return end
track(plr.Chatted:Connect(function(msg)
if type(msg) == "string" and msg:find(SIG, 1, true) then mark(plr.Name) end
end))
end
for _, plr in ipairs(Players:GetPlayers()) do hook(plr) end
pcall(function()
local tcs = game:GetService("TextChatService")
track(tcs.MessageReceived:Connect(function(m)
local src = m.TextSource
if src and type(m.Text) == "string" and m.Text:find(SIG, 1, true) then
local plr = Players:GetPlayerByUserId(src.UserId)
if plr then mark(plr.Name) end
end
end))
end)
local lastSend = -1000
local function announce()
if not Running or not Config.users.share or clock() - lastSend < 90 then return end
lastSend = clock()
pcall(function()
local tcs = game:GetService("TextChatService")
local channels = tcs:FindFirstChild("TextChannels")
local general = channels and channels:FindFirstChild("RBXGeneral")
if general then
general:SendAsync(SIG)
return
end
local ev = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
local say = ev and ev:FindFirstChild("SayMessageRequest")
if say then say:FireServer(SIG, "All") end
end)
end
track(Players.PlayerAdded:Connect(function(plr)
hook(plr)
task.delay(8, announce)
end))
task.delay(6, announce)
local function tagFor(name, head)
local tag = folder:FindFirstChild(name)
if tag and tag.Adornee == head then return end
if tag then tag:Destroy() end
tag = new("BillboardGui", { Name = name, Adornee = head, AlwaysOnTop = true, Size = UDim2.fromOffset(110, 22),
StudsOffset = Vector3.new(0, 2.7, 0), LightInfluence = 0, MaxDistance = 250 }, folder)
new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "Prada Hub",
Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Color3.fromRGB(255, 255, 255),
TextStrokeTransparency = 0.35 }, tag)
end
task.spawn(function()
while Running do
task.wait(1)
pcall(function()
if not Config.users.show then
folder:ClearAllChildren()
return
end
for name in pairs(users) do
local plr = Players:FindFirstChild(name)
local chars = Workspace:FindFirstChild("Characters")
local char = (chars and chars:FindFirstChild(name)) or (plr and plr.Character)
local head = char and char:FindFirstChild("Head")
if not plr then
users[name] = nil
local old = folder:FindFirstChild(name)
if old then old:Destroy() end
elseif head then
tagFor(name, head)
end
end
end)
end
end)
end
closeDot.MouseButton1Click:Connect(function()
local inst = genv.BloomInstance
if inst then inst.unload() else Gui:Destroy() end
end)
task.spawn(function()
while Running do
task.wait(0.5)
if Window.Visible then
refreshWidgets()
end
end
end)
do
local status = Card(T.Player, "Status", "left")
local statusText = status:Note("")
statusText.TextSize = 13
statusText.TextColor3 = C.Text
task.spawn(function()
while Running do
pcall(function()
local st = Match and Match.state or "Lobby"
local where = ((st == "Lobby" and Match.placeName) or st):upper()
local ok, why = Green.ready()
local meterObj = getMeter()
statusText.Text = string.format("Where  %s\nPing  %d ms\nMeter  %s\nAuto Green  %s", where,
math.floor(pingSeconds() * 1000 + 0.5), meterObj and meterObj.Name or "none yet",
ok and "READY" or ("NOT READY - " .. tostring(why)))
end)
task.wait(0.5)
end
end)
end
selectTab("Auto Green")
notify("Prada Hub loaded", menuKey.Name .. " to toggle the menu")
local unloaded = false
genv.BloomInstance = {
unload = function()
if unloaded then return end
unloaded = true
Config.afk.enabled = false
Config.farm.enabled = false
pcall(Persist.save, true)
pcall(function() GuiParent.PradaTags:Destroy() end)
Persist.stop = true
pcall(Record.save)
pcall(Perf.restoreAll)
pcall(function() if DefVis.folder then DefVis.folder:Destroy() end end)
pcall(Extra.cleanup)
pcall(function() Lighting.BloomColor:Destroy() end)
pcall(function() HudGui:Destroy() end)
pcall(function() if Off.line.folder then Off.line.folder:Destroy() end end)
pcall(Green.save)
for _, sectionTable in pairs(Config) do
if type(sectionTable) == "table" then
for key, value in pairs(sectionTable) do
if type(value) == "boolean" then
sectionTable[key] = false
end
end
end
end
pcall(stopGlide)
pcall(function() setHoldingG(false) end)
pcall(releaseShoot)
Running = false
for _, connection in ipairs(Connections) do
pcall(function() connection:Disconnect() end)
end
table.clear(Connections)
pcall(function() Gui:Destroy() end)
genv.BloomInstance = nil
end,
config = Config,
}
