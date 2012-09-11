-- Most of this file is largely borrowed from Pitbull_Luatexts, thanks to ckknight
local MAJOR = "LibScriptablePluginColor-1.0"
local MINOR = 24

local ScriptEnv = {}

local PluginColor = LibStub:NewLibrary(MAJOR, MINOR)
if not PluginColor then return end

-- Populate an environment with this plugin's fields
-- @usage :New(environment) 
-- @parma environment This will be the environment when setfenv is called.
-- @return A new plugin object, aka the environment
function PluginColor:New(environment)
	for k, v in pairs(ScriptEnv) do
		environment[k] = v
	end
	
	environment.gradient = self:RedThroughBlue()
	
	return environment
end

local LibEvaluator = LibStub("LibScriptableUtilsEvaluator-1.0")
local pool = setmetatable({}, {__mode = "k"})

local function new()
	local obj = next(pool)
	
	if obj then
		pool[obj] = nil
	else
		obj = {}
	end
	
	return obj
end

local function del(tbl)
	pool[tbl] = true
end

-- Convert a 32bit or 16bit color value to its individual RGB values
-- @usage Color2RGBA(color, thirtyTwoBit)
-- @param color The color value, i.e. 0xffffff
-- @param thirtyTwoBit True if color is in 32 bit format
-- @return Returns 4 values: red, green, blue, and alpha
local function Color2RGBA(color, thirtyTwoBit)
	
	local r, g, b, a = 0, 0, 0, 0
		
	if (color == nil) then
		return r, g, b, a;
	end

	local l = color
		
	if thirtyTwoBit then
		--/* RGBA */
		a = bit.band(bit.rshift(l, 24), 0xff) / 255
		r = bit.band(bit.rshift(l, 16), 0xff) / 255
		g = bit.band(bit.rshift(l, 8), 0xff) / 255
		b = bit.band(bit.rshift(l, 0), 0xff) / 255
	else
		--/* RGB */
		r = bit.band(bit.rshift(l, 16), 0xff) / 255
		g = bit.band(bit.rshift(l, 8), 0xff) / 255
		b = bit.band(bit.rshift(l, 0), 0xff) / 255
		a = 0xff / 255
	end
	return r, g, b, a
end
ScriptEnv.Color2RGBA = Color2RGBA

-- Convert RGBA values into its 32bit or 16bit value
-- @usage RGBA2Color(red, green, blue, [alpha])
-- @param red The color's red value
-- @param green The color's green value
-- @param blue The color's blue value
-- @param alpha The color's alpha value. This parameter is optional.
-- @return A color value, i.e. 0xffffff
local function RGBA2Color(red, green, blue, alpha)
	red = bit.band((red or 1) * 255, 0xff)
	green = bit.band((green or 1) * 255, 0xff)
	blue = bit.band((blue or 1) * 255, 0xff)
	alpha = alpha and bit.band(alpha * 255, 0xff)
	if alpha then
		local r = bit.lshift(red, 16)
		local g = bit.lshift(green, 8)
		local b = blue
		local a = bit.lshift(alpha, 24)
		return bit.bor(r, bit.bor(g, bit.bor(b, a)))	
	else
		local r = bit.lshift(red, 16)
		local g = bit.lshift(green, 8)
		local b = blue
		local a = 0xff000000
		return bit.bor(r, bit.bor(g, bit.bor(b, a)))
	end
end
ScriptEnv.RGBA2Color = RGBA2Color

--- Determine and return the brightest of 2 32bit colors. The alpha channel is ignored.
-- @usage ColorBrighest(color1, color2)
-- @param col1 The first color to compare.
-- @param col2 The second color to compare.
-- @return The brighest of the two colors is returned.
local function ColorBrightest(col1, col2)
	local r1, g1, b1 = Color2RGBA(col1)
	local r2, g2, b2 = Color2RGBA(col2)
	local v1 = select(3, ScriptEnv.RGB2HSV(r1, g1, b1))
	local v2 = select(3, ScriptEnv.RGB2HSV(r2, g2, b2))
	if v1 > v2 then
		return col1
	else
		return col2
	end
end
ScriptEnv.ColorBrightest = ColorBrightest

--- Convert an RGB color into its greyscale value
-- @usage RGB2Gray(red, green, blue)
-- @param red The color's red value
-- @param green The color's green value
-- @param blue The color's blue value
-- @return A value in the range of 0-255 representing the color's grayscale format
local function RGB2Gray(red, green, blue)
	return (77 * red * 255 + 150 * green * 255 + 28 * blue * 255) / 255;
end
ScriptEnv.RGB2Gray = RGB2Gray

--- Convert an RGB color into its black-white value
-- @usage RGB2Black(red, green, blue)
-- @param red The color's red value
-- @param green The color's green value
-- @param blue The color's blue value
-- @return A boolean representing the color's black format
local function RGB2Black(red, green, blue)
	return RGB2Gray(red, green, blue) < 127
end
ScriptEnv.RGB2Black = RGB2Black

--- Return RGB values from HSV colorspace values.
-- @usage HSV2RGB(h, s, v)
-- @param h Hue value, ranging from 0 to 360
-- @param s Satration value, ranging from 0 to 1
-- @param v Value value, ranging from 0 to 1
-- @return Red, green, and blue values from the HSV values provided.
function HSV2RGB (h, s, v)
	local i
	local f, w, q, t
	local r, g, b = 0, 0, 0

	if (s == 0.0) then
		s = 0.000001;
	end

	if (h == 360.0) then
		h = 0.0;
	end

	h = h / 60.0;
	i = floor(h);
	f = h - i;
	w = v * (1.0 - s);
	q = v * (1.0 - (s * f));
	t = v * (1.0 - (s * (1.0 - f)));

	if i == 0 then
		r = v; g = t; b = w;
	elseif i == 1 then
		r = q; g = v; b = w;
	elseif i == 2 then
		r = w; g = v; b = t;
	elseif i == 3 then
		r = w; g = q; b = v;
	elseif i == 4 then
		r = t; g = w; b = v;
	elseif i == 5 then
		r = v; g = w; b = q
	end

	return r, g, b
end
ScriptEnv.HSV2RGB = HSV2RGB

--- Creates HSV colorspace values from RGB values
-- @usage RGB2HSV(r, g, b)
-- @param r Red value
-- @param g Green value
-- @param b Blue value
-- @return Hue, Saturation, and Value values from RGB values
function RGB2HSV(r, g, b)
        local max, min, delta
	local h, s, v

	max = r;
	if (g > max) then
		max = g;
	end

	if (b > max) then
		max = b;
	end

	min = r;
	if (g < min) then
		min = g;
	end

	if (b < min) then
		min = b;
	end

	v = max;

	if (max ~= 0.0) then
		s = (max - min) / max;
	else
		s = 0.0;
	end

	if (s == 0.0) then
		h = 0.0;
	else
		delta = max - min;

		if (r == max) then
			h = (g - b) / delta;
		elseif (g == max) then
			h = 2.0 + (b - r) / delta;
		elseif (b == max) then
			h = 4.0 + (r - g) / delta;
		end

		h = h * 60.0;

		if (h < 0.0) then
			h = h + 360;
		end
	end

	return h, s, v
end
ScriptEnv.RGB2HSV = RGB2HSV

--- Convert an RGB expression into a suitable color for a background behind the RGB value. This is part of LuaTexts.
-- @usage BgColor(r, g, b)
-- @param r The color's red value
-- @param g The color's green value
-- @param b The color's blue value
-- @return Red, green, and blue representing the new background color
local function BgColor(r, g, b)
	return (r + 0.2)/3, (g + 0.2)/3, (b + 0.2)/3
end
ScriptEnv.BgColor = BgColor

--- Retrieve the game's default threat status color
-- @usage ThreatStatusColor(status)
-- @param status The indicated threat status
-- @return Red, green, and blue -- note that the values are multiplied by 255 for an 8 bit format
local function ThreatStatusColor(status)
	local r, g, b = GetThreatStatusColor(status)
	return r, g, b
end
ScriptEnv.ThreatStatusColor = ThreatStatusColor

--- This comes from oUF. Trivial, but I like to give credit where credit is due. 
-- @usage Gradient(perc)
-- @param perc A value between 0 and 1 -- The position within the gradient
-- @return Red, green, and blue
local function Gradient(perc)
    if type(perc) ~= "number" then 
	perc = 0
    end

    if perc > 1 then
	perc = 1	
    elseif perc < 0 then
	perc = 0
    end

    if perc <= 0.5 then
        return 1, perc*2, 0
    else
        return 2 - perc*2, 1, 0
    end
end
ScriptEnv.Gradient = Gradient

--- Retrieve a table representing the colors along a gradient red through blue
-- @usage RedThroughBlue()
-- @return A table of RGB values
function PluginColor:RedThroughBlue()
	local colors = {}

	-- Start with solid red:
	local r = 255;
	local g = 0;
	local b = 0;
	
	-- From red to yellow:
	local i = 0
	while i <= 255 do
		g = i
		tinsert(colors, {r / 255, g / 255, b / 255})
		i = i + 1
	end

	-- From yellow to green:
	i = 255
	while i >= 0 do
		r = i
		tinsert(colors, {r / 255, g / 255, b / 255})
		i = i - 1
	end
	
	-- From green to blue:
	i = 0
	while i <= 255 do
		b = i
		tinsert(colors, {r / 255, g / 255, b / 255})
		g = g - 1
		i = i + 1
	end

	local subColors = {}
	
	for i = #colors, 1, -1 do
		if mod(i, 8) == 0 then
			tinsert(subColors, colors[i])
		end
	end
	
	for i = #subColors + 1, 100 do
		tinsert(subColors, colors[1])
	end

	return subColors
end
ScriptEnv.RedThroughBlue = RedThroughBlue

--- Retrieve a string suitable to insert a texture within a fonstring
-- @usage Colorize(str, r, g, b)
-- @param str The string to color
-- @param r The color's red value
-- @param g The color's green value
-- @param b The color's blue value
-- @return A colorized string suitable to insert in a fonstring
local floor = math.floor
local function Colorize(str, r, g, b)
	if type(str) ~= "string" and type(str) ~= "number" then return "" end
	if type(r) ~= "number" then r = 1 end
	if type(g) ~= "number" then g = 1 end
	if type(b) ~= "number" then b = 1 end
	if lolz then
		print(str, r, g, b)
	end
	return ("|cff%02x%02x%02x%s|r"):format(floor(r * 255), floor(g * 255), floor(b * 255), tostring(str))
end
ScriptEnv.Colorize = Colorize

--- Wraps UnitSelectionColor
-- @usage AggroColor(unit)
-- @param The unit in question
-- @return Red, green, and blue
local function AggroColor(unit)
	local r, g, b = UnitSelectionColor(unit)
	return r, g, b
end
ScriptEnv.AggroColor = AggroColor

--- Wraps GetThreatStatus Color
-- @usage ThreatStatusColor(status)
-- @param status
-- @return Red, green, and blue
local function ThreatStatusColor(status)
	local r, g, b = GetThreatStatusColor(status)
	return r, g, b
end
ScriptEnv.ThreatStatusColor = ThreatStatusColor

--- Return a suitable color along a gradient indicating health percentage
-- @usage HPColor(cur, max)
-- @param cur The percent of health
-- @param max The maximum percent of health
-- @return Red, green, and blue
local function HPColor(cur, max)
	local perc = cur / (max <= 0 and .00001 or max)
	local r1, g1, b1
	local r2, g2, b2
	if perc <= 0.5 then
		perc = perc * 2
		r1, g1, b1 = 1, 0, 0 
		r2, g2, b2 = 1, 1, 0
	else
		perc = perc * 2 - 1
		r1, g1, b1 = 1, 1, 0
		r2, g2, b2 = 0, 1, 0
	end
	local r, g, b = r1 + (r2 - r1)*perc, g1 + (g2 - g1)*perc, b1 + (b2 - b1)*perc
	if r < 0 then
		r = 0
	elseif r > 1 then
		r = 1
	end
	if g < 0 then
		g = 0
	elseif g > 1 then
		g = 1
	end
	if b < 0 then
		b = 0
	elseif b > 1 then
		b = 1
	end
	
	return r, g, b
end
ScriptEnv.HPColor = HPColor

local PowerBarColor = _G.PowerBarColor

local PowerTypes = {Warrior = "RAGE", Rogue = "ENERGY", Pet = "HAPPINESS", Deathknight = "RUNIC_POWER", Hunter = "FOCUS"}

setmetatable(PowerTypes, {__index = function(self, key)
	if rawget(self, key) then return rawget(self, key) end
	return "MANA"
end})

local function PowerColor(power_type, unit)
	if unit and not power_type then 
		local class = UnitClass(unit)
		power_type = PowerTypes[class]
	end
	local color = PowerBarColor[power_type]
	local r,g,b
	if color then
		r, g, b = color.r,color.g,color.b
	else
		r, g, b = 0.7, 0.7, 0.7
	end
	return r, g, b
end
ScriptEnv.PowerColor = PowerColor

--- Accessor for FACTION_BAR_COLORS, which is suitable for color reputation values
-- @usage ReputationColor(reaction)
-- @param reaction Indicated reaction
-- @return red, green, and blue
local function ReputationColor(reaction)
  local color = FACTION_BAR_COLORS[reaction]
	if color then
		return color.r, color.g, color.b
	end
end
ScriptEnv.ReputationColor = ReputationColor

local FACTION_BAR_COLORS = _G.FACTION_BAR_COLORS
local HOSTILE_REACTION = 2
local NEUTRAL_REACTION = 4
local FRIENDLY_REACTION = 5

--- Retrieve a color representing a unit's hostility toward's you
-- @usage HostileColor(unit)
-- @param unit The unit in question
-- @return red, green, and blue
local function HostileColor(unit)
	local r, g, b
	if not unit then
		r, g, b = 0.8, 0.8, 0.8 --UNKNOWN
	else
		if UnitIsPlayer(unit) or UnitPlayerControlled(unit) then
			if UnitCanAttack(unit, "player") then
				-- they can attack me
				if UnitCanAttack("player", unit) then
					-- and I can attack them
					local t = FACTION_BAR_COLORS[HOSTILE_REACTION]
					r, g, b = t.r, t.g, t.b
				else
					-- but I can't attack them
--					r, g, b = unpack(FACTION_BAR_COLORS.civilian)
					r, g, b = 0.8, 0.8, 0.8
				end
			elseif UnitCanAttack("player", unit) then
				-- they can't attack me, but I can attack them
				local t = (FACTION_BAR_COLORS[NEUTRAL_REACTION])
				r, g, b = t.r, t.g, t.b
			elseif UnitIsPVP(unit) then
				-- on my team
				local t = FACTION_BAR_COLORS[FRIENDLY_REACTION]
				r, g, b = t.r, t.g, t.b
			else
				-- either enemy or friend, no violance
				-- r, g, b = unpack(PitBull4.ReactionColors.civilian)
				r, g, b = 0.8, 0.8, 0.8
			end
		elseif (UnitIsTapped(unit) and not UnitIsTappedByPlayer(unit)) or UnitIsDead(unit) then
			r, g, b = 0.5, 0.5, 0.5 -- TODO: We really need this to be globally configurable.
		else
			local reaction = UnitReaction(unit, "player")
			if reaction then
				local t
				if reaction >= 5 then
					t = FACTION_BAR_COLORS[FRIENDLY_REACTION]
				elseif reaction == 4 then
					t = FACTION_BAR_COLORS[NEUTRAL_REACTION]
				else
					t = FACTION_BAR_COLORS[HOSTILE_REACTION]
				end
				r, g, b = t.r, t.g, t.b
			else
				r, g, b = 0.8, 0.8, 0.8 --UNKNOWN
			end
		end
	end
	return r, g, b
end
ScriptEnv.HostileColor = HostileColor

local RAID_CLASS_COLORS = _G.RAID_CLASS_COLORS

--- Retrieve a color suitable to color a unit's class value
-- @usage ClassColor(unit)
-- @param unit The unit in question
-- @return red, green, and blue
local function ClassColor(unit)
	local r, g, b = 0.8, 0.8, 0.8 --UNKNOWN
	local _, class = UnitClass(unit)
	local t = RAID_CLASS_COLORS[class]
	
	if t then
		r, g, b = t.r, t.g, t.b
	end
	
	return r, g, b
end
ScriptEnv.ClassColor = ClassColor

--- Retrieve a color suitable to color a unit's difficulty level
-- @usage DifficultyColor(unit)
-- @param unit The unit in question
-- @return red, green, and blue
local function DifficultyColor(unit)
	local level
	level = UnitLevel(unit)
	if level <= 0 then
		level = 99
	end
	local color = GetQuestDifficultyColor(level)
	return color.r, color.g, color.b
end
ScriptEnv.DifficultyColor = DifficultyColor

for k, v in pairs(ScriptEnv) do
	PluginColor[k] = v
end
