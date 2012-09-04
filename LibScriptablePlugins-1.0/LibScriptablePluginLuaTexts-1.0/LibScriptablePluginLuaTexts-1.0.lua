-- Huge appreciation goes out to ckknight for 99% of the following.
local MAJOR = "LibScriptablePluginLuaTexts-1.0"
local MINOR = 24

local PluginLuaTexts = LibStub:NewLibrary(MAJOR, MINOR)
if not PluginLuaTexts then return end
local PluginUtils = LibStub("LibScriptablePluginUtils-1.0", true)
assert(PluginUtils, MAJOR .. " requires LibScriptablePluginUtils-1.0")
local PluginUnitTooltipScan = LibStub("LibScriptablePluginUnitTooltipScan-1.0", true)
assert(PluginUnitTooltipScan, MAJOR .. " requires LibScriptablePluginUnitTooltipScan-1.0")
local LibHook = LibStub("LibScriptableUtilsHook-1.0", true)
assert(LibHook, MAJOR .. " requires LibScriptableUtilsHook-1.0")
local LibTimer = LibStub("LibScriptableUtilsTimer-1.0", true)
assert(LibTimer, MAJOR .. " requires LibScriptableUtilsTimer-1.0")
local PluginColor = LibStub("LibScriptablePluginColor-1.0")
assert(PluginColor, MAJOR .. " requires LibScriptablePluginColor-1.0")
local Locale = LibStub("LibScriptableLocale-1.0", true)
assert(Locale, MAJOR .. " requires LibScriptableLocale-1.0")
local L = Locale.L

local _G = _G
local ScriptEnv = {}

ScriptEnv.Colorize = PluginColor.Colorize

local timerframe = CreateFrame("Frame")
PluginLuaTexts.timerframe = timerframe
timerframe:Hide()

local player_guid

if not PluginLuaTexts.__index then
	PluginLuaTexts.__index = PluginLuaTexts
end

local spellcastEvents = {['UNIT_SPELLCAST_START']=true,['UNIT_SPELLCAST_CHANNEL_START']=true,['UNIT_SPELLCAST_STOP']=true,['UNIT_SPELLCAST_FAILED']=true,['UNIT_SPELLCAST_INTERRUPTED']=true,['UNIT_SPELLCAST_SUCCEEDED']=true,['UNIT_SPELLCAST_DELAYED']=true,['UNIT_SPELLCAST_CHANNEL_UPDATE']=true,['UNIT_SPELLCAST_CHANNEL_STOP']=true}

-- Populate an environment with this plugin's fields
-- @usage :New(environment) 
-- @parma environment This will be the environment when setfenv is called.
-- @return A new plugin object, aka the environment, and the plugin object as second return value
function PluginLuaTexts:New(environment, config)
	for k, v in pairs(ScriptEnv) do
		environment[k] = v
	end

	local obj = setmetatable({}, {__index=PluginLuaTexts})


	-- UNIT_SPELLCAST_SENT has to always be registered so we can capture
	-- additional data not always available.
	obj.frame = CreateFrame("Frame")
	obj.frame:SetScript("OnEvent", function(frame, event, ...)
		if PluginLuaTexts[event] then
			PluginLuaTexts[event](frame.obj, event, ...)
		else
			PluginLuaTexts:OnEvent(event, ...)
		end
	end)
	obj.frame:RegisterEvent("UNIT_SPELLCAST_SENT")
	obj.frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
	obj.frame:RegisterEvent("PLAYER_FLAGS_CHANGED")
	for k, _ in pairs(spellcastEvents) do
		obj.frame:RegisterEvent(k)
	end
	obj.frame.environment = environment
	obj.frame.obj = obj
	obj.frame:Show()

	-- Hooks to trap OnEnter/OnLeave for the frames.
	--self:AddFrameScriptHook("OnEnter")
	--self:AddFrameScriptHook("OnLeave")

	-- Cache the player's guid for later use
	player_guid = UnitGUID("player")
	environment.player_guid = player_guid

	--LibHook:CreateHook(_G, "SetCVar", PluginLuaTexts, true)
	--self:SecureHook("SetCVar")
	PluginLuaTexts:SetCVar()
	local events = {
		-- Harcoded events basically the ones that aren't just unit=true ones
		['UNIT_PET_EXPERIENCE'] = {pet=true},
		['PLAYER_XP_UPDATE'] = {player=true},
		['UNIT_COMBO_POINTS'] = {all=true},
		['UPDATE_FACTION'] = {all=true},
		['UNIT_LEVEL'] = {all=true},

		-- They pass the unit but they don't provide the pairing (e.g.
		-- the target changes) so we'll miss updates if we don't update
		-- every text on every one of these events.  /sigh
		['UNIT_THREAT_LIST_UPDATE'] = {all=true},
		['UNIT_THREAT_SITUATION_UPDATE'] = {all=true},
	}

	timerframe:Show()
	config = config or {}
	obj.size = config.size or 1
	obj.attach_to = config.attach_to or "root"
	obj.location = config.location or "edget_top_left"
	obj.position = config.position or 1
	obj.exists = config.exists or false
	obj.code = config.code or ""
	obj.events = events
	obj.enabled = config.enabled or true
	obj.config = config
	--fix_unit_healthmax(obj)
	environment.LuaTexts = obj
	
	return environment, obj
end

--[[
local mouseover_check_cache = {}
local spell_cast_cache = {}
local power_cache = {}
local cast_data = {}
local to_update = {}
local afk_cache = {}
local dnd_cache = {}
local offline_cache = {}
local dead_cache = {}
local offline_times = {}
local afk_times = {}
local dnd = {}
local dead_times = {}
]]

local texts = {}
local no_update = {}
local event_cache = {}
local func_cache = {}
local power_cache = {}
PluginLuaTexts.power_cache = power_cache
local mouseover_check_cache = {}
PluginLuaTexts.mouseover_check_cache = mouseover_check_cache
local spell_cast_cache = {}
PluginLuaTexts.spell_cast_cache = spell_cast_cache
local cast_data = {}
PluginLuaTexts.cast_data = cast_data
local to_update = {}
PluginLuaTexts.to_update = to_update
local afk_cache = {}
PluginLuaTexts.afk_cache = afk_cache
local dnd_cache = {}
PluginLuaTexts.dnd_cache = dnd_cache
local offline_cache = {}
PluginLuaTexts.offline_cache = offline_cache
local dead_cache = {}
PluginLuaTexts.dead_cache = dead_cache
local offline_times = {}
PluginLuaTexts.offline_times = offline_times
local afk_times = {}
PluginLuaTexts.afk_times = afk_times
local dnd = {}
PluginLuaTexts.dnd = dnd
local dead_times = {}
PluginLuaTexts.dead_times = dead_times
local predicted_power = true


--[[
do
	-- Build the event defaults
	local events = {
		-- Harcoded events basically the ones that aren't just unit=true ones
		['UNIT_PET_EXPERIENCE'] = {pet=true},
		['PLAYER_XP_UPDATE'] = {player=true},
		['UNIT_COMBO_POINTS'] = {all=true},
		['UPDATE_FACTION'] = {all=true},
		['UNIT_LEVEL'] = {all=true},

		-- They pass the unit but they don't provide the pairing (e.g.
		-- the target changes) so we'll miss updates if we don't update
		-- every text on every one of these events.  /sigh
		['UNIT_THREAT_LIST_UPDATE'] = {all=true},
		['UNIT_THREAT_SITUATION_UPDATE'] = {all=true},
	}

	-- Iterate the provided codes to fill in all the rest
	for base, codes in pairs(PROVIDED_CODES) do
		for name, entry in pairs(codes) do
			for event in pairs(entry.events) do
				if not events[event] then
					events[event] = {unit=true}
				end
			end
		end
	end

	PitBull4_LuaTexts:SetDefaults({
		elements = {
			['**'] = {
				size = 1,
				attach_to = "root",
				location = "edge_top_left",
				position = 1,
				exists = false,
				code = "",
				events = {},
				enabled = true,
			}
		},
		first = true
	},
	{
		-- Global defaults
		events = events,
	})
end
]]

-- Fix a typo in the original default event names. 
-- s/UNIT_HEALTHMAX/UNIT_MAXHEALTH/
local function fix_unit_healthmax(self)	
	for _,profile in pairs(self.config) do
		if profile.global then
			local events = profile.global.events
			if events then
				local old_event = events.UNIT_HEALTHMAX
				if not events.UNIT_MAXHEALTH and old_event then
					events.UNIT_MAXHEALTH = old_event
					events.UNIT_HEALTHMAX = nil
				end
			end
		end
		local layouts = profile.layouts
		if layouts then
			for _,layout in pairs(layouts) do	
				local elements = layout.elements
				if elements then
					for _,text in pairs(elements)	do
						local events = text.events
						if events then
							local old_event = events.UNIT_HEALTHMAX
							if not events.UNIT_MAXHEALTH and old_event then
								events.UNIT_MAXHEALTH = old_event
								events.UNIT_HEALTHMAX = nil
							end
						end
					end
				end
			end
		end
	end
end

do
	local target_same_mt = { __index=function(self, key)
		if type(key) ~= "string" then
			return false
		end
		
		if key:sub(-6) == "target" then
			local value = self[key:sub(1, -7)]
			self[key] = value
			return value
		end
		
		self[key] = false
		return false
	end }
	
	local target_same_with_target_mt = { __index=function(self, key)
		if type(key) ~= "string" then
			return false
		end
		
		if key:sub(-6) == "target" then
			local value = self[key:sub(1, -7)]
			value = value and value .. "target"
			self[key] = value
			return value
		end
		
		self[key] = false
		return false
	end }
	
	local better_unit_ids = {
		player = "player",
		pet = "pet",
		vehicle = "pet",
		playerpet = "pet",
		mouseover = "mouseover",
		focus = "focus",
		target = "target",
		playertarget = "target",
		npc = "npc",
	}
	for i = 1, MAX_PARTY_MEMBERS do
		better_unit_ids["party" .. i] = "party" .. i
		better_unit_ids["partypet" .. i] = "partypet" .. i
		better_unit_ids["party" .. i .. "pet"] = "partypet" .. i
	end
	for i = 1, MAX_RAID_MEMBERS do
		better_unit_ids["raid" .. i] = "raid" .. i
		better_unit_ids["raidpet" .. i] = "raidpet" .. i
		better_unit_ids["raid" .. i .. "pet"] = "raidpet" .. i
	end
	for i = 1, MAX_ARENA_TEAM_MEMBERS do
		better_unit_ids["arena" .. i] = "arena" .. i
		better_unit_ids["arenapet" .. i] = "arenapet" .. i
		better_unit_ids["arena" .. i .. "pet"] = "arenapet" .. i
	end
	for i = 1, MAX_BOSS_FRAMES do
		better_unit_ids["boss" .. i] = "boss" .. i
	end
	setmetatable(better_unit_ids, target_same_with_target_mt)
	
	--- Return the best UnitID for the UnitID provided
	-- @param unit the known UnitID
	-- @usage PluginLuaTexts.GetBestUnitID("playerpet") == "pet"
	-- @return the best UnitID. If the ID is invalid, it will return false
	function PluginLuaTexts.GetBestUnitID(unit)
		return better_unit_ids[unit]
	end
	
	local valid_singleton_unit_ids = {
		player = true,
		pet = true,
		mouseover = true,
		focus = true,
		target = true,
	}
	setmetatable(valid_singleton_unit_ids, target_same_mt)
	
	--- Return whether the UnitID provided is a singleton
	-- @param unit the UnitID to check
	-- @usage PluginLuaTexts.IsSingletonUnitID("player") == true
	-- @usage PluginLuaTexts.IsSingletonUnitID("party1") == false
	-- @return whether it is a singleton
	function PluginLuaTexts.IsSingletonUnitID(unit)
		return valid_singleton_unit_ids[unit]
	end
	
	local valid_classifications = {
		player = true,
		pet = true,
		mouseover = true,
		focus = true,
		target = true,
		party = true,
		partypet = true,
		raid = true,
		raidpet = true,
	}
	setmetatable(valid_classifications, target_same_mt)
	
	--- Return whether the classification is valid
	-- @param classification the classification to check
	-- @usage PluginLuaTexts.IsValidClassification("player") == true
	-- @usage PluginLuaTexts.IsValidClassification("party") == true
	-- @usage PluginLuaTexts.IsValidClassification("partytarget") == true
	-- @usage PluginLuaTexts.IsValidClassification("partypettarget") == true
	-- @usage PluginLuaTexts.IsValidClassification("party1") == false
	-- @return whether it is a a valid classification
	function PluginLuaTexts.IsValidClassification(unit)
		return valid_classifications[unit]
	end
	
	local non_wacky_unit_ids = {
		player = true,
		pet = true,
		mouseover = true,
		focus = true,
		target = true,
		party = true,
		partypet = true,
		raid = true,
		raidpet = true,
	}
	
	--- Return whether the classification provided is considered "wacky"
	-- @param classification the classification in question
	-- @usage assert(not PluginLuaTexts.IsWackyUnitGroup("player"))
	-- @usage assert(PluginLuaTexts.IsWackyUnitGroup("targettarget"))
	-- @usage assert(PluginLuaTexts.IsWackyUnitGroup("partytarget"))
	-- @return whether it is wacky
	function PluginLuaTexts.IsWackyUnitGroup(classification)
		return not non_wacky_unit_ids[classification]
	end
end


-- Pre 3.2.0 compatability support
local wow_320 = select(4, GetBuildInfo()) >= 30200
local GetQuestDifficultyColor
if not wow_320 then
	GetQuestDifficultyColor = _G.GetDifficultyColor
else
	GetQuestDifficultyColor = _G.GetQuestDifficultyColor
end

-- The following functions exist to provide a method to help people moving
-- from LibDogTag.  They implement the functionality that exists in some of
-- the tags in LibDogTag.  Tags that are identical to Blizzard API calls are
-- not included and you should use the API call.  Some of them do not implement
-- all of the features of the relevent tag in LibDogTag.  People interested in
-- contributing new functions should open a ticket on the PitBull4 project as
-- a patch to the LuaTexts module.  In general tags that are simplistic work
-- on other tags should be generalized (e.g. Percent instead of PercentHP and PercentMP)
-- or should simply not exist.  A major design goal is to avoid inefficient code.
-- Functions which encourage inefficient code design will not be accepted.

-- A number of these functions are borrowed or adapted from the code implmenting
-- similar tags in DogTag.  Permission to do so granted by ckknight.

local UnitToLocale = {player = L["Player"], target = L["Target"], pet = L["%s's pet"]:format(L["Player"]), focus = L["Focus"], mouseover = L["Mouse-over"]}
setmetatable(UnitToLocale, {__index=function(self, unit)
	if unit:find("pet$") then
		local nonPet = unit:sub(1, -4)
		self[unit] = L["%s's pet"]:format(self[nonPet])
		return self[unit]
	elseif not unit:find("target$") then
		if unit:find("^party%d$") then
			local num = unit:match("^party(%d)$")
			self[unit] = L["Party member #%d"]:format(num)
			return self[unit]
		elseif unit:find("^raid%d%d?$") then
			local num = unit:match("^raid(%d%d?)$")
			self[unit] = L["Raid member #%d"]:format(num)
			return self[unit]
		elseif unit:find("^partypet%d$") then
			local num = unit:match("^partypet(%d)$")
			self[unit] = UnitToLocale["party" .. num .. "pet"]
			return self[unit]
		elseif unit:find("^raidpet%d%d?$") then
			local num = unit:match("^raidpet(%d%d?)$")
			self[unit] = UnitToLocale["raid" .. num .. "pet"]
			return self[unit]
		end
		self[unit] = unit
		return unit
	end
	local nonTarget = unit:sub(1, -7)
	self[unit] = L["%s's target"]:format(self[nonTarget])
	return self[unit]
end})

local function VehicleName(unit)
	local name = UnitName(unit:gsub("vehicle", "pet")) or UnitName(unit) or L["Vehicle"]
	local owner_unit = unit:gsub("vehicle", "")
	if owner_unit == "" then
		owner_unit = "player"
	end
	local owner = UnitName(owner_unit)
	if owner then
		return L["%s's %s"]:format(owner, name)
	else
		return name
	end
end
ScriptEnv.VehicleName = VehicleName

local PowerTypes = {[0] = L["Mana"], [1] = L["Rage"], [2] = L["Focus"], [3] = L["Energy"], [4] = L["Happiness"], [5] = L["Runes"], [6] = L["Runic Power"], [7] = L["Soul Shards"], [8] = L["Eclipse"], [9] = L["Holy Power"]}


local function PowerName(unit)
	return strjoin("", PowerTypes[UnitPowerType(unit)],":")
end
ScriptEnv.PowerName = PowerName

local function PowerType(unit)
	return select(2, UnitPowerType(unit))
end
ScriptEnv.PowerType = PowerType

local function Name(unit, titled)
	if unit ~= "player" and not UnitExists(unit) then
		return UnitToLocale[unit]
	else
		if unit:match("%d*pet%d*$") then
			local vehicle = unit:gsub("pet", "vehicle")
			if UnitIsUnit(unit, vehicle) then
				return VehicleName(vehicle)
			end
		elseif unit:match("%d*vehicle%d*$") then
			return VehicleName(unit)
		end
	end
	if titled then
		return UnitPVPName(unit)
	else
		return UnitName(unit)
	end
end
ScriptEnv.Name = Name

local function Guild(unit, tooltip)
	if tooltip then
		return select(3, PluginUnitTooltipScan.GetUnitTooltipScan(unit))
	else
		return select(1, GetGuildInfo(unit))
	end
end
ScriptEnv.Guild = Guild

local function Rank(unit)
	return select(2, GetGuildInfo(unit))
end
ScriptEnv.Rank = Rank

local function RankIndex(unit)
	return select(3, GetGuildInfo(unit))
end
ScriptEnv.RankIndex = RankIndex

local function Realm(unit)
	local txt = select(2, UnitName(unit))
	if txt == "" then return end
	return txt
end
ScriptEnv.Realm = Realm

local function Faction(unit)
	return UnitFactionGroup(unit)
end
ScriptEnv.Faction = Faction

local function HasAura(unit, aura)
    local i = 1
    while true do
        local buff = UnitBuff(unit, i)
        if not buff then return end
        if buff == aura then return true end
        i = i + 1
    end
end
ScriptEnv.HasAura = HasAura


local L_DAY_ONELETTER_ABBR    = DAY_ONELETTER_ABBR:gsub("%s*%%d%s*", "")
local L_HOUR_ONELETTER_ABBR   = HOUR_ONELETTER_ABBR:gsub("%s*%%d%s*", "")
local L_MINUTE_ONELETTER_ABBR = MINUTE_ONELETTER_ABBR:gsub("%s*%%d%s*", "")
local L_SECOND_ONELETTER_ABBR = SECOND_ONELETTER_ABBR:gsub("%s*%%d%s*", "")
local L_DAYS_ABBR = DAYS_ABBR:gsub("%s*%%d%s*","")
local L_HOURS_ABBR = HOURS_ABBR:gsub("%s*%%d%s*","")
local L_MINUTES_ABBR = MINUTES_ABBR:gsub("%s*%%d%s*","")
local L_SECONDS_ABBR = SECONDS_ABBR:gsub("%s*%%d%s*","")

local t = {}
local function FormatDuration(number, format)
	local negative = ""
	if number < 0 then
		number = -number
		negative = "-"
	end

	if not format then
		format = 'c'
	else
		format = format:sub(1, 1):lower()
	end

	if format == "e" then
		if number == 1/0 then
			return negative .. "***"
		end

		t[#t+1] = negative

		number = math.floor(number + 0.5)

		local first = true

		if number >= 60*60*24 then
			local days = math.floor(number / (60*60*24))
			number = number % (60*60*24)
			t[#t+1] = ("%.0f"):format(days)
			t[#t+1] = " "
			t[#t+1] = _L_DAYS_ABBR
			first = false
		end

		if number >= 60*60 then
			local hours = math.floor(number / (60*60))
			number = number % (60*60)
			if not first then
				t[#t+1] = " "
			else
				first = false
			end
			t[#t+1] = hours
			t[#t+1] = " "
			t[#t+1] = L_HOURS_ABBR
		end

		if number >= 60 then
			local minutes = math.floor(number / 60)
			number = number % 60
			if not first then
				t[#t+1] = " "
			else
				first = false
			end
			t[#t+1] = minutes
			t[#t+1] = " "
			t[#t+1] = L_MINUTES_ABBR
		end

		if number >= 1 or first then
			local seconds = number
			if not first then
				t[#t+1] = " "
			else
				first = false
			end
			t[#t+1] = seconds
			t[#t+1] = " "
			t[#t+1] = L_SECONDS_ABBR
		end
		local s = table.concat(t)
		wipe(t)
		return s
	elseif format == "f" then
		if number == 1/0 then
			return negative .. "***"
		elseif number >= 60*60*24 then
			return ("%s%.0f%s %02d%s %02d%s %02d%s"):format(negative, math.floor(number/86400), L_DAY_ONELETTER_ABBR, number/3600 % 24, L_HOUR_ONELETTER_ABBR, number/60 % 60, L_MINUTE_ONELETTER_ABBR, number % 60, L_SECOND_ONELETTER_ABBR)
		elseif number >= 60*60 then
			return ("%s%d%s %02d%s %02d%s"):format(negative, number/3600, L_HOUR_ONELETTER_ABBR, number/60 % 60, L_MINUTE_ONELETTER_ABBR, number % 60, L_SECOND_ONELETTER_ABBR)
		elseif number >= 60 then
			return ("%s%d%s %02d%s"):format(negative, number/60, L_MINUTE_ONELETTER_ABBR, number % 60, L_SECOND_ONELETTER_ABBR)
		else
			return ("%s%d%s"):format(negative, number, L_SECOND_ONELETTER_ABBR)
		end
	elseif format == "s" then
		if number == 1/0 then
			return negative .. "***"
		elseif number >= 2*60*60*24 then
			return ("%s%.1f %s"):format(negative, number/86400, L_DAYS_ABBR)
		elseif number >= 2*60*60 then
			return ("%s%.1f %s"):format(negative, number/3600, L_HOURS_ABBR)
		elseif number >= 2*60 then
			return ("%s%.1f %s"):format(negative, number/60, L_MINUTES_ABBR)
		elseif number >= 3 then
			return ("%s%.0f %s"):format(negative, number, L_SECONDS_ABBR)
		else
			return ("%s%.1f %s"):format(negative, number, L_SECONDS_ABBR)
		end
	else
		if number == 1/0 then
			return ("%s**%d **:**:**"):format(negative, L_DAY_ONELETTER_ABBR)
		elseif number >= 60*60*24 then
			return ("%s%.0f%s %d:%02d:%02d"):format(negative, math.floor(number/86400), L_DAY_ONELETTER_ABBR, number/3600 % 24, number/60 % 60, number % 60)
		elseif number >= 60*60 then
			return ("%s%d:%02d:%02d"):format(negative, number/3600, number/60 % 60, number % 60)
		else
			return ("%s%d:%02d"):format(negative, number/60 % 60, number % 60)
		end
	end
end
ScriptEnv.FormatDuration = FormatDuration

-- Depends upon the local t = {} above FormatDuration
local function SeparateDigits(number, thousands, decimal)
	if not thousands then
		thousands = ','
	end
	if not decimal then
		decimal = '.'
	end
	local int = math.floor(number)
	local rest = number % 1
	if int == 0 then
		t[#t+1] = 0
	else
		local digits = math.log10(int)
		local segments = math.floor(digits / 3)
		t[#t+1] = math.floor(int / 1000^segments)
		for i = segments-1, 0, -1 do
			t[#t+1] = thousands
			t[#t+1] = ("%03d"):format(math.floor(int / 1000^i) % 1000)
		end
	end
	if rest ~= 0 then
		t[#t+1] = decimal
		rest = math.floor(rest * 10^6)
		while rest % 10 == 0 do
			rest = rest / 10
		end
		t[#t+1] = rest
	end
	local s = table.concat(t)
	wipe(t)
	return s
end
ScriptEnv.SeparateDigits = SeparateDigits

local function Angle(value)
	if value and value ~= '' then
		return '<' .. value .. '>'
	else
		return ''
	end
end
ScriptEnv.Angle = Angle

local function Paren(value)
	if value and value ~= '' then
		return '(' .. value .. ')'
	else
		return ''
	end
end
ScriptEnv.Paren = Paren

local function IsAFK(unit)
	return not not afk_times[UnitGUID(unit)]
end
ScriptEnv.IsAFK = IsAFK

local function AFKDuration(unit)
	local afk = afk_times[UnitGUID(unit)]
	if afk then
		--UpdateIn(0.25)
		return GetTime() - afk
	end
end
ScriptEnv.AFKDuration = AFKDuration

local function AFK(unit)
	local afk = AFKDuration(unit)
	if afk then
		return _G.AFK..' ('..FormatDuration(afk)..')'
	end
end
ScriptEnv.AFK = AFK

local function IsDND(unit)
	return not not dnd_times[UnitGUID(unit)]
end
ScriptEnv.IsDND = IsDND

local function DND(unit)
	if dnd[UnitGUID(unit)] then
		return _G.DND
	end
end
ScriptEnv.DND = DND

local classification_lookup = {
	rare = L["Rare"],
	rareelite = L["Rare-Elite"],
	elite = L["Elite"],
	worldboss = L["Boss"]
}

classification_lookup = setmetatable(classification_lookup, {__index = function(self, i)
	if rawget(self, key) then return rawget(self, key) or "" end
end})

local function Classification(unit)
	return classification_lookup[PluginUtils.BetterUnitClassification(unit)]
end
ScriptEnv.Classification = Classification

local ShortClassification_abbrev = {
	[L["Rare"]] = L["Rare_short"],
	[L["Rare-Elite"]] = L["Rare-Elite_short"],
	[L["Elite"]] = L["Elite_short"],
	[L["Boss"]] = L["Boss_short"]
}

local function ShortClassification(arg)
	local short = ShortClassification_abbrev[arg]
	if not short and PluginLuaTexts.GetBestUnitID(arg) then
		-- If it's empty then maybe arg is a unit
		short = ShortClassification_abbrev[Classification(arg)]
	end
	return short
end
ScriptEnv.ShortClassification = ShortClassification

local function Class(unit)
	if UnitIsPlayer(unit) then
		return UnitClass(unit) or UNKNOWN
	else
		return UnitClassBase(unit) or select(13, PluginUnitTooltipScan.GetUnitTooltipScan(unit)) or UNKNOWN
	end
end
ScriptEnv.Class = Class

local function Location(unit)
	return select(5, PluginUnitTooltipScan.GetUnitTooltipScan(unit))
end
ScriptEnv.Location = Location

local ShortClass_abbrev = {
	[L["Priest"]] = L["Priest_short"],
	[L["Mage"]] = L["Mage_short"],
	[L["Shaman"]] = L["Shaman_short"],
	[L["Paladin"]] = L["Paladin_short"],
	[L["Warlock"]] = L["Warlock_short"],
	[L["Druid"]] = L["Druid_short"],
	[L["Rogue"]] = L["Rogue_short"],
	[L["Hunter"]] = L["Hunter_short"],
	[L["Warrior"]] = L["Warrior_short"],
	[L["Death Knight"]] = L["Death Knight_short"],
	[L["Priest_female"]] = L["Priest_short"],
	[L["Mage_female"]] = L["Mage_short"],
	[L["Shaman_female"]] = L["Shaman_short"],
	[L["Paladin_female"]] = L["Paladin_short"],
	[L["Warlock_female"]] = L["Warlock_short"],
	[L["Druid_female"]] = L["Druid_short"],
	[L["Rogue_female"]] = L["Rogue_short"],
	[L["Hunter_female"]] = L["Hunter_short"],
	[L["Warrior_female"]] = L["Warrior_short"],
	[L["Death Knight_female"]] = L["Death Knight_short"],
}

local function ShortClass(arg)
	local short = ShortClass_abbrev[arg]
	if not short and PluginLuaTexts.GetBestUnitID(arg) then
		-- If it's empty then maybe arg is a unit
		short = ShortClass_abbrev[Class(arg)]
	end
	return short
end
ScriptEnv.ShortClass = ShortClass

local function Level(unit)
	local level = UnitLevel(unit)
	if level <= 0 then
		level = '??'
	end
	return level
end
ScriptEnv.Level = Level

local function Creature(unit)
	return UnitCreatureFamily(unit) or UnitCreatureType(unit) or UNKNOWN
end
ScriptEnv.Creature = Creature

local function SmartRace(unit)
	if UnitIsPlayer(unit) then
		local race = UnitRace(unit)
		return race or UNKNOWN
	else
		return Creature(unit)
	end
end
ScriptEnv.SmartRace = SmartRace
ScriptEnv.Race = SmartRace

local ShortRace_abbrev = {
	[L["Blood Elf"]] = L["Blood Elf_short"],
	[L["Draenei"]] = L["Draenei_short"],
	[L["Dwarf"]] = L["Dwarf_short"],
	[L["Gnome"]] = L["Gnome_short"],
	[L["Human"]] = L["Human_short"],
	[L["Night Elf"]] = L["Night Elf_short"],
	[L["Orc"]] = L["Orc_short"],
	[L["Tauren"]] = L["Tauren_short"],
	[L["Troll"]] = L["Troll_short"],
	[L["Undead"]] = L["Undead_short"],
	[L["Blood Elf_female"]] = L["Blood Elf_short"],
	[L["Draenei_female"]] = L["Draenei_short"],
	[L["Dwarf_female"]] = L["Dwarf_short"],
	[L["Gnome_female"]] = L["Gnome_short"],
	[L["Human_female"]] = L["Human_short"],
	[L["Night Elf_female"]] = L["Night Elf_short"],
	[L["Orc_female"]] = L["Orc_short"],
	[L["Tauren_female"]] = L["Tauren_short"],
	[L["Troll_female"]] = L["Troll_short"],
	[L["Undead_female"]] = L["Undead_short"],
}

local function ShortRace(arg)
	local short = ShortRace_abbrev[arg]
	if not short and PluginLuaTexts.GetBestUnitID(arg) then
		-- If it's empty then maybe arg is a unit
		short = ShortRace_abbrev[UnitRace(arg)]
	end
	return short
end
ScriptEnv.ShortRace = ShortRace

local function IsPet(unit)
	return not UnitIsPlayer(unit) and (UnitPlayerControlled(unit) or UnitPlayerOrPetInRaid(unit))
end
ScriptEnv.IsPet = IsPet

local function OfflineDuration(unit)
	local offline = offline_times[UnitGUID(unit)]
	if offline then
		--UpdateIn(0.25)
		return GetTime() - offline
	end
end
ScriptEnv.OfflineDuration = OfflineDuration

local function Offline(unit)
 	local offline = OfflineDuration(unit)
	if offline then
		return L["Offline"]..' ('..FormatDuration(offline)..')'
	end
end
ScriptEnv.Offline = Offline

local function IsOffline(unit)
	return not not offline_times[UnitGUID(unit)]
end
ScriptEnv.IsOffline = IsOffline

local function DeadDuration(unit)
	local dead_time = dead_times[UnitGUID(unit)]
	if dead_time then
		--UpdateIn(0.25)
		return GetTime() - dead_time
	end
end
ScriptEnv.DeadDuration = DeadDuration

local function Dead(unit)
	local dead_time = DeadDuration(unit)
	local dead_type = (UnitIsGhost(unit) and L["Ghost"]) or (UnitIsDead(unit) and L["Dead"])
	if dead_time and dead_type then
		return dead_type..' ('..FormatDuration(dead_time)..')'
	elseif dead_type then
		return dead_type
	end
end
ScriptEnv.Dead = Dead

local MOONKIN_FORM = GetSpellInfo(24858)
local AQUATIC_FORM = GetSpellInfo(1066)
local FLIGHT_FORM = GetSpellInfo(33943)
local SWIFT_FLIGHT_FORM = GetSpellInfo(40120)
local TRAVEL_FORM = GetSpellInfo(783)
local TREE_OF_LIFE, SHAPESHIFT = GetSpellInfo(33891)

local function DruidForm(unit)
	local _, class = UnitClass(unit)
	if class ~= "DRUID" then
		return nil
	end
	local power = UnitPowerType(unit)
	if power == 1 then
		return L["Bear"]
	elseif power == 3 then
		return L["Cat"]
	elseif UnitAura(unit,MOONKIN_FORM,SHAPESHIFT) then
		return L["Moonkin"]
	elseif UnitAura(unit,TREE_OF_LIFE,SHAPESHIFT) then
		return L["Tree"]
	elseif UnitAura(unit,TRAVEL_FORM,SHAPESHIFT) then
		return L["Travel"]
	elseif UnitAura(unit,AQUATIC_FORM,SHAPESHIFT) then
		return L["Aquatic"]
	elseif UnitAura(unit,SWIFT_FLIGHT_FORM,SHAPESHIFT) or UnitAura(unit,SWIFT_FLIGHT_FORM,SHAPESHFIT) then
		return L["Flight"]
	end
end
ScriptEnv.DruidForm = DruidForm

local DIVINE_INTERVENTION = GetSpellInfo(19752)
local function Status(unit)
	return Offline(unit) or UnitAura(unit,DIVINE_INTERVENTION) or (UnitIsFeignDeath(unit) and L["Feigned Death"]) or Dead(unit)
end
ScriptEnv.Status = Status

local function HP(unit)
	local hp = UnitHealth(unit)
	if hp == 1 and UnitIsGhost(unit) then
		return 0
	end
	return hp
end
ScriptEnv.HP = HP
ScriptEnv.Health = HP

-- Just use the Blizzard API no change needed
-- only reason this is here is for symmetry,
-- it feels weird to have HP (which we need
-- to avoid the hp = 1 while dead crap), but
-- not have MaxHP
local MaxHP = UnitHealthMax
ScriptEnv.MaxHP = MaxHP
ScriptEnv.MaxHealth = MaxHP

local function Power(unit, power_type)
	local power = UnitPower(unit, power_type)

	-- Detect mana texts for player and pet units, cache the power
	-- and mark the font_strings for faster updating.  Allows
	-- smoothing updating of PowerBars.
	local guid = UnitGUID(unit)
	if power_type == nil or UnitPowerType(unit) == power_type then
		if guid == ScriptEnv.player_guid then
			ScriptEnv.player_power = power
		elseif guid == UnitGUID("pet") then
			ScriptEnv.pet_power = power
		end
	end

	return power
end
ScriptEnv.Power = Power

-- more symmetry
local MaxPower = UnitPowerMax
ScriptEnv.MaxPower = MaxPower

local function Round(number, digits)
	if not digits then
		digits = 0
	end
	local mantissa = 10^digits
	local norm = number*mantissa + 0.5
	local norm_floor = math.floor(norm)
	if norm == norm_floor and (norm_floor % 2) == 1 then
		return (norm_floor-1) / mantissa
	else
		return norm_floor / mantissa
	end
end
ScriptEnv.Round = Round

local function Short(value,format)
	if type(value) == "number" then
		local fmt
		if value >= 10000000 or value <= -10000000 then
			fmt = "%.1fm"
			value = value / 1000000
		elseif value >= 1000000 or value <= -1000000 then
			fmt = "%.2fm"
			value = value / 1000000
		elseif value >= 100000 or value <= -100000 then
			fmt = "%.0fk"
			value = value / 1000
		elseif value >= 10000 or value <= -10000 then
			fmt = "%.1fk"
			value = value / 1000
		else
			fmt = "%d"
			value = math.floor(value+0.5)
		end
		if format then
			return fmt:format(value)
		else
			return fmt, value
		end
	else
		local fmt_a, fmt_b
		local a,b = value:match("^(%d+)/(%d+)$")
		if a then
			a, b = tonumber(a), tonumber(b)
			if a >= 10000000 or a <= -10000000 then
				fmt_a = "%.1fm"
				a = a / 1000000
			elseif a >= 1000000 or a <= -1000000 then
				fmt_a = "%.2fm"
				a = a / 1000000
			elseif a >= 100000 or a <= -100000 then
				fmt_a = "%.0fk"
				a = a / 1000
			elseif a >= 10000 or a <= -10000 then
				fmt_a = "%.1fk"
				a = a / 1000
			end
			if b >= 10000000 or b <= -10000000 then
				fmt_b = "%.1fm"
				b = b / 1000000
			elseif b >= 1000000 or b <= -1000000 then
				fmt_b = "%.2fm"
				b = b / 1000000
			elseif b >= 100000 or b <= -100000 then
				fmt_b = "%.0fk"
				b = b / 1000
			elseif b >= 10000 or b <= -10000 then
				fmt_b = "%.1fk"
				b = b / 1000
			end
			if format then
				return (fmt_a.."/"..fmt_b):format(a,b)
			else
				return fmt_a.."/"..fmt_b,a,b
			end
		else
			return value
		end
	end
end
ScriptEnv.Short = Short

local function VeryShort(value,format)
	if type(value) == "number" then
		local fmt
		if value >= 1000000 or value <= -1000000 then
			fmt = "%.0fm"
			value = value / 1000000
		elseif value >= 1000 or value <= -1000 then
			fmt = "%.0fk"
			value = value / 1000
		else
			fmt = "%.0f"
		end
		if format then
			return fmt:format(value)
		else
			return fmt, value
		end
	else
		local a,b = value:match("^(%d+)/(%d+)")
		if a then
			local fmt_a, fmt_b
			a, b = tonumber(a), tonumber(b)
			if b >= 1000000 or b <= -1000000 then
				fmt_b = "%.0fm"
				b = b / 1000000
			elseif b >= 1000 or b <= -1000 then
				fmt_b = "%.0fk"
				b = b / 1000
			end
			if a >= 1000000 or a <= -1000000 then
				fmt_a = "%.0fm"
				a = a / 1000000
			elseif a >= 1000 or a <= -1000 then
				fmt_a = "%.0fk"
				a = a / 1000
			end
			if format then
				return (fmt_a.."/"..fmt_b):format(a,b)
			else
				return fmt_a.."/"..fmt_b,a,b
			end
		else
			return value
		end
	end
end
ScriptEnv.VeryShort = VeryShort

local function Combos(unit, target)
	if unit and target then
		return GetComboPoints(unit, target)
	else
		return GetComboPoints(UnitHasVehicleUI("player") and "vehicle" or "player", "target")
	end
end
ScriptEnv.Combos = Combos

local function ComboSymbols(symbol, unit, target)
	if not symbol then
		symbol = '@'
	end
	return string.rep(symbol,Combos(unit,target))
end
ScriptEnv.ComboSymbols = ComboSymbols

local function Percent(x, y)
	if y ~= 0 then
		return Round(x / y * 100,1)
	else
		return 0
	end
end
ScriptEnv.Percent = Percent

local function XP(unit)
	if unit == "player" then
		return UnitXP(unit)
	elseif unit == "pet" or unit == "playerpet" then
		return GetPetExperience()
	else
		return 0
	end
end
ScriptEnv.XP = XP

local function MaxXP(unit)
	if unit == "player" then
		return UnitXPMax(unit)
	elseif unit == "pet" or unit == "playerpet" then
		local _, max = GetPetExperience()
		return max
	else
		return 0
	end
end
ScriptEnv.MaxXP = MaxXP

local function RestXP(unit)
	if unit == "player" then
		return GetXPExhaustion() or 0
	else
		return 0
	end
end
ScriptEnv.RestXP = RestXP

local function ThreatPair(unit)
	if UnitIsFriend("player", unit) then
		if UnitExists("target") then
			return unit, "target"
		else
			return
		end
	else
		return "player", unit
	end
end
ScriptEnv.ThreatPair = ThreatPair

local function CastData(unit)
	return cast_data[UnitGUID(unit)]
end
ScriptEnv.CastData = CastData

local function Alpha(number)
	if number > 1 then
		number = 1
	elseif number < 0 then
		number = 0
	end
	PluginLuaTexts.alpha = number
end
ScriptEnv.Alpha = Alpha

local function Outline()
	PluginLuaTexts.outline = "OUTLINE"
end
ScriptEnv.Outline = Outline

local function ThickOutline()
	PluginLuaTexts.outline = "OUTLINE, THICKOUTLINE"
end
ScriptEnv.ThickOutline = ThickOutline

local function abbreviate(text)
	local b = text:byte(1)
	if b <= 127 then
		return text:sub(1, 1)
	elseif b <= 223 then
		return text:sub(1, 2)
	elseif b <= 239 then
		return text:sub(1, 3)
	else
		return text:sub(1, 4)
	end
end
local function Abbreviate(value)
    if value:find(" ") then
      return value:gsub(" *([^ ]+) *", abbreviate)
    else
      return value
    end
end
ScriptEnv.Abbreviate = Abbreviate

local function PVPDuration(unit)
	if unit and not UnitIsUnit(unit,"player") then return end
  if IsPVPTimerRunning() then
		--UpdateIn(0.25)
		return GetPVPTimer()/1000
	end
end
ScriptEnv.PVPDuration = PVPDuration

local count = 0
local function PVPRank(unit)
--[[
	local pvp = PluginTalents.UnitPVPStats(unit);
	if not CheckInteractDistance(unit, 1) and not pvp then return L["Out of Range"] end
	local txt;
	if pvp then
	  local fctn = ScriptEnv.Faction(unit)
	  if fctn == L["Alliance"] then
		fctn = L["Horde"]
	  elseif fctn == L["Horde"] then
		fctn = L["Alliance"]
	  end
	  local rankIcon = ScriptEnv.Texture(pvp.texture, 12)
	  local factIcon = ScriptEnv.Texture("Interface\\PvPRankBadges\\PvPRank"..fctn..".blp", 12)
	  txt = format("%s %s %d HKs", rankIcon, pvp.text or factIcon..L["No Rank (-1)"], pvp.lifetimeHK)
	else
      local elips = ""
      for i = 0, count % 3 do
		elips = elips .. "."
	  end
	  count = count + 1
	  txt = L["Fetching"] .. elips
	end
	return txt
]]
end
ScriptEnv.PVPRank = PVPRank

local function ArenaTeam(unit, num)
--[[
	local pvp = PluginTalents.UnitPVPStats(unit);
	if not pvp then return "" end
	local team = pvp.teams[num]
	if not team then return "" end
	local text = ""
	if team and type(team.teamSize) == "number" and team.teamSize > 0 then
		local points = ScriptEnv.CalculateArenaPoints(team.teamRating, team.teamSize)
		local perc = team.teamRating / 3000
		local emblem = ScriptEnv.Texture("Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-"..team.emblem, 12)
		local embcol = PluginColor.RGBA2Color(team.emblemR, team.emblemG, team.emblemB)
		local bkgcol = PluginColor.RGBA2Color(team.backR, team.backG, team.backB)
		local brightest = PluginColor.ColorBrightest(embcol, bkgcol)
		local r, g, b = PluginColor.Color2RGBA(brightest)
		local tag = PluginColor.Colorize(format("%dv%d", num, num), r, g, b)
		local wins, played = team.teamWins, team.teamPlayed
		local losses = played - wins
		local winlost = ""
		if wins >= losses then
			winlost = PluginColor.Colorize(format("%d/%d", wins, losses), 0, 1, 1)
		else
			winlost = PluginColor.Colorize(format("%d/%d", wins, losses), 1, 0, 0)
		end    
		text = format("%s %s %s %s (%.1f pts) %s", tag, emblem, team.teamName or "Name?", PluginColor.Colorize(team.teamRating, perc, 0.5, 1), points, winlost)
	end
	return text
]]
end
ScriptEnv.ArenaTeam = ArenaTeam

-- http://www.arenajunkies.com/showthread.php?t=222736
-- (-6e-13*1500)^5+(7e-9*1500)^4-(4e-5*1500)^3+(0.0863*1500)^2-98.66*1500+43743

-- Calculate Arena Points -- Updated Formula for 2.2 -- Now always uses 1500 rating if rating is less than that
-- Specifically borrowed from Examiner
function CalculateArenaPoints(teamRating,teamSize)
	local multiplier = (teamSize == 5 and 1) or (teamSize == 3 and 0.88) or (teamSize == 2 and 0.76)
	if (teamRating <= 1500) then
		return multiplier * (0.22 * 1500 + 14);
	else
		return multiplier * (1511.26 / (1 + 1639.28 * 2.71828 ^ (-0.00412 * teamRating)));
	end
end
ScriptEnv.CalculateArenaPoints = CalculateArenaPoints

local function Texture(texture, size)
	if type(texture) ~= "string" then return '|T:12|t' end
	size = size or 12
	return format("|T%s:%d|t", texture, size)
end
ScriptEnv.Texture = Texture

local function TextureWithCoords(texture, size, size2, xoffset, yoffset, dimx, dimy, coordx1, coordx2, coordy1, coordy2)
	--|TTexturePath:size1:size2:xoffset:yoffset:dimx:dimy:coordx1:coordx2:coordy1:coordy2|t
	local fmt = "|T%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s|t"	
	local text = format(fmt, texture, tostring(size), tostring(size2), tostring(xoffset), tostring(yoffset), tostring(dimx), tostring(dimy), tostring(coordx1), tostring(coordx2), tostring(coordy1), tostring(coordy2))
	return text
end
ScriptEnv.TextureWithCoords = TextureWithCoords

-----------------End of ScriptEnv---------------------

-- These events should never have the event unregistered unless
-- the module is disabled.  In general they are needed for support
-- for things that cannot be cleaned on an as needed basis and
-- require very little actual processing time.
local protected_events = {
	['UNIT_SPELLCAST_SENT'] = true,
	['PARTY_MEMBERS_CHANGED'] = true,
}

function PluginLuaTexts:SetCVar()
	predicted_power = GetCVarBool("predictedPower")
end

function PluginLuaTexts:RegisterEvent(event)
	frame:RegisterEvent(event)
end


local next_spell, next_rank, next_target
function PluginLuaTexts.UNIT_SPELLCAST_SENT(event, unit, spell, rank, target)
	if unit ~= "player" then return end

	next_spell = spell
	next_rank = rank and tonumber(rank:match("%d+"))
	next_target = target ~= "" and target or nil
end

local pool = setmetatable({}, {__mode='k'})
local function new()
	local t = next(pool)
	if t then
		pool[t] = nil
	else
		t = {}
	end
	return t
end

local function del(t)
	wipe(t)
	pool[t] = true
	return nil
end

local function copy(t)
	local n = {}
	for k,v in pairs(t) do
		n[k] = v
	end
	return n
end

local function update_cast_data(event, unit, event_spell, event_rank, event_cast_id)
	local guid = UnitGUID(unit)
	if not guid then return end
	local data = cast_data[guid]
	if not data then
		data = new()
		cast_data[guid] = data
	end

	local spell, rank, name, icon, start_time, end_time, is_trade_skill, cast_id, interrupt = UnitCastingInfo(unit)
	local channeling = false
	if not spell then
		spell, rank, name, icon, start_time, end_time, uninterruptble = UnitChannelInfo(unit)
		channeling = true
	end
	if spell then
		data.spell = spell
		rank = rank and tonumber(rank:match("%d+"))
		data.rank = rank
		local old_start = data.start_time
		start_time = start_time * 0.001
		data.start_time = start_time
		data.end_time = end_time * 0.001
		if event == "UNIT_SPELLCAST_DELAYED" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
			data.delay = (data.delay or 0) + (start_time - (old_start or start_time))
		else
			data.delay = 0
		end
		if guid == player_guid and spell == next_spell and rank == next_rank then
			data.target = next_target
		end
		data.casting = not channeling
		data.channeling = channeling
		data.fade_out = false
		data.interruptible = not uninterruptible
		if event ~= "UNIT_SPELLCAST_INTERRUPTED" then
			-- We can't update the cache of the cast_id on UNIT_SPELLCAST_INTERRUPTED  because
			-- for whatever reason it ends up giving us 0 inside this event.
			data.cast_id = cast_id
		end
		data.stop_time = nil
		data.stop_message = nil
		return
	end
	if not data.spell then
		cast_data[guid] = del(data)
		return
	end

	if data.cast_id == event_cast_id then
		-- The event was for the cast we're current casting
		if event == "UNIT_SELLCAST_FAILED" then
			data.stop_message = _G.FAILED
		elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
			data.stop_message = _G.INTERRUPTED
		elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
			-- Sometimes the interrupt event happens just before the
			-- success event so clear the stop_message if we get succeded.
			data.stop_message = nil
		end
	end

	data.casting = false
	data.channeling = false
	data.fade_out = true
	if not data.stop_time then
		data.stop_time = GetTime()
	end
end

local tmp = {}
local function fix_cast_data()
	local frame
	local current_time = GetTime()
	for guid, data in pairs(cast_data) do
		tmp[guid] = data
	end
	for guid, data in pairs(tmp) do
		if data.casting then
			if current_time > data.end_time and player_guid ~= guid then
				data.casting = false
				data.fade_out = true
				data.stop_time = current_time
			end
		elseif data.channeling then
			if current_time > data.end_time then
				data.channeling = false
				data.fade_out = true
				data.stop_time = current_time
			end
		elseif data.fade_out then
			local alpha = 0
			local stop_time = data.stop_time
			if stop_time then
				alpha = stop_time - current_time + 1
			end

			if alpha <0 then
				cast_data[guid] = del(data)
			end
		else
			cast_data[guid] = del(data)
		end
	end
	wipe(tmp)
end

local group_members = {}
local first = true
local function update_timers()
	if first then
		first = false
		PluginLuaTexts:PARTY_MEMBERS_CHANGED()
	end
	for unit, guid in pairs(group_members) do
		if not UnitIsConnected(unit) then
			if not offline_times[guid] then
				offline_times[guid] = GetTime()
			end
			afk_times[guid] = nil
			if dnd[guid] then
				dnd[guid] = nil
			end
		else
			offline_times[guid] = nil
			if UnitIsAFK(unit) then
				if not afk_times[guid] then
					afk_times[guid] = GetTime()
				end
			else
				afk_times[guid] = nil
				local dnd_change = false
				if UnitIsDND(unit) then
					if not dnd[guid] then
						dnd[guid] = true
						dnd_change = true
					end
				else
					if dnd[guid] then
						dnd[guid] = nil
						dnd_change = true
					end
				end
			end
		end
		if UnitIsDeadOrGhost(unit) then
			if not dead_times[guid] then
				dead_times[guid] = GetTime()
			end
		else
			dead_times[guid] = nil
		end
	end
end

function PluginLuaTexts:PARTY_MEMBERS_CHANGED(event)
  local prefix, min, max = "raid", 1, GetNumGroupMembers()
	if max == 0 then
		prefix, min, max = "party", 1, GetNumGroupMembers()
	end
	if max == 0 then
		-- not in a raid or a party
		wipe(group_members)
		group_members["player"] = player_guid
		return
	end

	wipe(group_members)
	for i = min, max do
		local unit
		if i == 0 then
			unit = 'player'
		else
			unit = prefix .. i
		end
		local guid = UnitGUID(unit)
		group_members[unit] = guid

		if guid then
			tmp[guid] = true
		end
	end

	-- Cleanup any timers that reference people no longer in the party
	for guid in pairs(offline_times) do
		if not tmp[guid] then
			offline_times[guid] = nil
		end
	end
	for guid in pairs(dead_times) do
		if not tmp[guid] then
			dead_times[guid] = nil
		end
	end
	for guid in pairs(afk_times) do
		if not tmp[guid] then
			afk_times[guid] = nil
		end
	end
	wipe(tmp)
end

function PluginLuaTexts:OnEvent(event, unit, ...)
	--[[local event_entry = event_cache[event]
	if not event_entry then return end
	local event_config = self.events[event]
	local all, by_unit, player, pet, guid

	if event_config then
		all, by_unit = event_config.all, event_config.unit
		player, pet = event_config.player, event_config.pet
	else
		-- Sucks but if for some reason the event entry is missing update all
		all = true
	end

	if unit then
		guid = UnitGUID(unit)
	end
	]]

	if event == "PLAYER_FLAGS_CHANGED" then
		update_timers()
	elseif string.sub(event,1,15) == "UNIT_SPELLCAST_" then
		-- spell casting events need to go through
		update_cast_data(event, unit, ...)
	end
end

local lastUpdate = 0
local updateTimer = LibTimer:New(MAJOR .. " updateTimer", 500, true, function()
	fix_cast_data()
	
	if GetTime() - lastUpdate > 1 then
		update_timers()
		lastUpdate = GetTime()
	end
end)
updateTimer:Start()

for k, v in pairs(ScriptEnv) do
	PluginLuaTexts[k] = v
end
