-- This file is Copyright (c) 2007-2010, Ace3 Development Team
-- All rights reserved.
local name, addon = ...
local MAJOR = "LibScriptableUtilsTimer-1.0" 
local MINOR = 24
assert(LibStub, MAJOR.." requires LibStub") 
local LibTimer = LibStub:NewLibrary(MAJOR, MINOR)
if not LibTimer then return end
local LibError = LibStub("LibScriptableUtilsError-1.0")
assert(LibError, MAJOR .. " requires LibScriptableUtilsError-1.0")

local pool = setmetatable({}, {__mode = "k"})

local cache = {}
local storage = {}
local update
local OnFinish
local tconcat = table.concat

local MINDURATION = 50

LibTimer.frame = CreateFrame("Frame")

if not LibTimer.__index then
	LibTimer.__index = LibTimer
end

-- Recycle functions from ShefkiTimer-1.0
-- Full timer recycling unlike AceTimer.  We recycle everything because we don't
-- want to making any more AnimationGroup and Animation objects than necessary.
local timerCache = {}
local function new()
	local timer = table.remove(timerCache)
	if not timer then
		local ag = LibTimer.frame:CreateAnimationGroup()
		timer = ag:CreateAnimation("Animation")
	end
	return timer
end

local function del(timer)
	if not timer then return end
	timerCache[timer] = true
end

--[[
   xpcall safecall implementation from AceTimer-3.0
]]
local xpcall = xpcall

local function errorhandler(err)
	return geterrorhandler()(err)
end

local function CreateDispatcher(argCount)
	local code = [[
	local xpcall, eh = ...  -- our arguments are received as unnamed values in "..." since we don't have a proper function declaration
	local method, ARGS
	local function call() return method(ARGS) end

	local function dispatch(func, ...)
		method = func
		if not method then return end
		ARGS = ...
		return xpcall(call, eh)
	end

	return dispatch
	]]

	local ARGS = {}
	for i = 1, argCount do ARGS[i] = "arg"..i end
	code = code:gsub("ARGS", tconcat(ARGS, ", "))
	return assert(loadstring(code, "safecall Dispatcher["..argCount.."]"))(xpcall, errorhandler)
end

local Dispatchers = setmetatable({}, {
	__index=function(self, argCount)
		local dispatcher = CreateDispatcher(argCount)
		rawset(self, argCount, dispatcher)
		return dispatcher
	end
})
Dispatchers[0] = function(func)
	return xpcall(func, errorhandler)
end

local function safecall(func, ...)
	return Dispatchers[select('#', ...)](func, ...)
end


--- Create a new LibTimer object
-- @usage LibScriptableTimer:New(name, duration, repeating, callback, data, errorLevel, durationLimit)
-- @param name A name for this timer object
-- @param duration The timer's duration in milliseconds.
-- @param repeating Whether to repeat the timer or not
-- @param callback Function to call when the timer has expired
-- @param data Data to pass to the callback
-- @param errorLevel Error verbosity level
-- @return A new LibScriptableTimer object
function LibTimer:New(name, duration, repeating, callback, data, errorLevel)
	assert(type(name) == "string", "Timer objects require a name.")

	duration = type(duration) == "number" and duration or 0
	
	if duration > 0 and duration < MINDURATION then 
		duration = MINDURATION
	end

	local obj = next(pool)

	if obj then
		pool[obj] = nil
	else
		obj = {}
	end

	setmetatable(obj, self)
	
	obj.error = LibError:New(MAJOR .. ": " .. name, errorLevel)
	
	obj.name = name
	obj.duration = duration / 1000
	
	obj.repeating = repeating
	obj.callback = callback or function() obj.error:Print("No callback", 2) end
	obj.data = data
	obj.errorLevel = errorLevel
	
	local timer = new()
	obj.timer = timer
	
	timer.obj = obj
			
	return obj	
	
end


--- Delete a LibTimer object
-- @usage object:Del()
-- @return Nothing
function LibTimer:Del()
	local timer = self
	pool[timer] = true
	timer:Stop()
	timer.error:Del()
	del(timer.timer)
end

--- Start a timer.
-- @usage object:Start([duration], [data])
-- @param duration The duration in milliseconds. This is optional. The timer's initialized duration will be replaced by this value.
-- @param data Replace the timer's data that will be sent through the callback with this value.
-- @param func Replace the timer's callback function
function LibTimer:Start(duration, data, func)
	if type(duration) == "number" then
		self.duration = duration / 1000
	end
		
	if self.duration == 0 then return end
	
	self.startTime = GetTime()
		
	self.data = data or self.data
	if type(func) == "function" then self.callback = func end
	
	local timer = self.timer
	local delay = self.duration
	local repeating = self.repeating
	local ag = timer:GetParent()
	
	timer:SetScript("OnFinished",OnFinished)
	timer:SetScript("OnUpdate",nil)
	timer:SetDuration(delay)
	if repeating then
		ag:SetLooping("REPEAT")
	else
		ag:SetLooping("NONE")
	end
	
	ag:Play()

end

-- Set the timer's refresh rate. This also stops the timer.
-- @usage :Set(100)
-- @param duration The duration in milliseconds. If no duration is passed, then refresh rate is set to zero.
-- @return NOthing
function LibTimer:Set(duration)
	self.duration = (duration or 0) / 1000
	self:Stop()
end

-- Does LibScriptable need this? Mind's fuzzy atm. lol Leaving here in case it dawns on me.
-- state variables to prevent timers canceled during callbacks from being returned
-- from the pool until OnFinished finishes.
local in_OnFinished
local canceled_in_OnFinished

--- Stop a timer
-- @usage object:Stop()
-- @return True if the timer was stopped
function LibTimer:Stop()
	self.timer:GetParent():Stop()
end

--- Return the timer's remaining duration
-- @usage object:TimeLapsed()
-- @return The remaining duration
function LibTimer:TimeLapsed()
	if type(self.startTime) ~= "number" then return 0 end
	return GetTime() - self.startTime
end

--- Deprecated
function LibTimer:TimeRemaining()
end

function OnFinished(self, elapsed)
	if self.safecall then 
		safecall(self.obj.callback, self.obj.data)
	else
		self.obj.callback(self.obj.data)
	end
	self.obj.error:Print(("Lapsed - %f"):format(self.obj:TimeLapsed()), 3)
end
