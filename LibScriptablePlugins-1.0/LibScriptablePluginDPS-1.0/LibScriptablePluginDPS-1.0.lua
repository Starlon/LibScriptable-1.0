local MAJOR = "LibScriptablePluginDPS-1.0"
local MINOR = 24
local PluginDPS = LibStub:NewLibrary(MAJOR, MINOR)
if not PluginDPS then return end
local LibTimer = LibStub("LibScriptableUtilsTimer-1.0", true)
assert(LibTimer, MAJOR .. " requires LibScriptableUtilsTimer-1.0")

local _G = _G
local frame = CreateFrame("Frame")
local data = {}
local update
local MAXRECORDS = 10

local ScriptEnv = {}

if not PluginDPS.__index then
	PluginDPS.__index = PluginDPS
end

-- Populate an environment with this plugin's fields
-- @usage :New(environment)
-- @parma environment This will be the environment when setfenv is called.
-- @return A new plugin object, aka the environment, and the plugin object as second return
function PluginDPS:New(environment)

	for k, v in pairs(ScriptEnv) do
		environment[k] = v
	end

	self.timer = self.timer or LibTimer:New(MAJOR, 300, true, update)

	return environment
end

local function onEvent(self, event, ...)
	if PluginDPS[event] then
		PluginDPS[event](PluginDPS, ...)
	end
end

frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:Show()

local GetTime = _G.GetTime
local UnitGUID = _G.UnitGUID

-- Return the unit's DPS score.
-- @usage UnitDPS(unit)
-- @param unit The said unit, i.e mouseover, raid1
-- @return The unit's DPS
function PluginDPS.UnitDPS(unit)
	if not PluginDPS.active then return end
	local id = UnitGUID(unit)
	if not data[id] then return end
	local dps = data[id].damage / (GetTime() - data[id].startTime)
	return string.format("%.1f", dps), dps
end
ScriptEnv.UnitDPS = PluginDPS.UnitDPS

-- Clear all DPS data for a unit
-- @usage ResetDPS(unit)
-- @param unit The said unit, i.e. mouseover, raid1
function PluginDPS.ResetDPS(unit)
	local id = UnitGUID(unit)
	if not data[id] then return end
	data[id] = nil
end
ScriptEnv.ResetDPS = PluginDPS.ResetDPS

-- Wipe all DPS data
function PluginDPS.WipeDPS()
	wipe(data)
end
ScriptEnv.WipeDPS = PluginDPS.WipeDPS

-- Start DPS data collection
-- @usage StartDPS()
function PluginDPS.StartDPS()
	PluginDPS.timer:Start()
	frame:SetScript("OnEvent", onEvent)
	PluginDPS.active = true
end
ScriptEnv.StartDPS = PluginDPS.StartDPS

-- Stop DPS data collection
-- @usage StopDPS()
function PluginDPS.StopDPS()
	PluginDPS.timer:Stop()
	frame:SetScript("OnEvent", nil)
	PluginDPS.active = false
end
ScriptEnv.StopDPS = PluginDPS.StopDPS

function PluginDPS.GetData()
	return data
end
ScriptEnv.GetData = PluginDPS.GetData

function PluginDPS.DPSActive()
	return PluginDPS.active
end
ScriptEnv.DPSActive = PluginDPS.DPSActive
local events = {
	SWING_DAMAGE = 1,
	RANGE_DAMAGE = 4,
	SPELL_DAMAGE = 4,
	SPELL_PERIODIC_DAMAGE = 4,
	DAMAGE_SHIELD = 4,
	DAMAGE_SPLIT = 4,
}
function PluginDPS:COMBAT_LOG_EVENT_UNFILTERED(timestamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, ...)

	if not events[eventType] or not sourceGUID then return end

	local index = events[eventType]
	local damage = select(index, ...)
	local overkill = select(index+1, ...)
	local resisted = select(index+3, ...)
	local blocked = select(index+4, ...)
	local absorbed = select(index+5, ...)

	if not data[sourceGUID] then
		data[sourceGUID] = {}
		data[sourceGUID].startTime = GetTime()
	end

	data[sourceGUID].damage = (data[sourceGUID].damage or 0) + (damage or 0)
	data[sourceGUID].lastUpdate = GetTime()
end

function update()
	for k, v in pairs(data) do
		local diff = GetTime() - (v.lastUpdate or 0)
		if v.lastUpdate and  diff > 5 then
			v.lastUpdate = GetTime()
			v.startTime = v.startTime + diff
		end
	end
end

