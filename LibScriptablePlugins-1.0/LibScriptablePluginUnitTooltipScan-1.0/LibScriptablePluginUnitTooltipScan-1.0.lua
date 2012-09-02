
local MAJOR = "LibScriptablePluginUnitTooltipScan-1.0" 
local MINOR = 24
assert(LibStub, MAJOR.." requires LibStub") 
local LibUnitTooltipScan = LibStub:NewLibrary(MAJOR, MINOR)
if not LibUnitTooltipScan then return end
local self = LibUnitTooltipScan
local L = LibStub("LibScriptableLocale-1.0", true).L

if not LibUnitTooltipScan.__index then 
	LibUnitTooltipScan.__index = LibUnitTooltipScan
end

local pool = setmetatable({}, {__mode = "k"})

local objects = {}
local objectsDict = {}
local update
local frame = CreateFrame("Frame")
local tooltip = CreateFrame("GameTooltip", "LibScriptableUnitTooltipScan", UIParent, "GameTooltipTemplate")
local initialized

local factionList = {}

if not LibUnitTooltipScan.__index then
	LibUnitTooltipScan.__index = LibUnitTooltipScan
end

LibUnitTooltipScan.leftLines = {}
LibUnitTooltipScan.rightLines = {}

function initialize()
	if initialized then return end
	for i = 1, 20 do
		tooltip:AddDoubleLine(" ", " ")
		LibUnitTooltipScan.leftLines[i] = _G["LibScriptableUnitTooltipScanTextLeft" .. i]
		LibUnitTooltipScan.rightLines[i] = _G["LibScriptableUnitTooltipScanTextRight" .. i]
	end
	initialized = true
end

local function onEvent(frame, event)
	if event == "UPDATE_FACTION" then
		for i = 1, GetNumFactions() do
			local name = GetFactionInfo(i)
			factionList[name] = true
		end
	end
end

local init

--- Populate an environment with this plugin's fields
-- @usage :New(environment) 
-- @param environment This will be the environment when setfenv is called.
-- @return A new plugin object, aka the environment
function LibUnitTooltipScan:New(environment)

	if not init then
		frame:SetScript("OnEvent", onEvent)
		frame:RegisterEvent("UPDATE_FACTION")
		initialize()
		init = true
	end

	environment.GetUnitTooltipScan = self.GetUnitTooltipScan
	environment.GetUnitTooltipStats = self.GetUnitTooltipScan -- for compatibility, but use the above
	
	return environment
end



--- Return the default unit tooltip's information
-- @usage LibUnitTooltipScan:GetUnitTooltipScan(unit)
-- @param unit The unitid to retrieve information about
-- @return Name, guild, and location, pettype, and a table `lines = {left={}, right={}}`.
--
local getLocation, getGuild, getName, getPetType, getLines
do
	local lines = {left={}, right={}}
	function LibUnitTooltipScan.GetUnitTooltipScan(unit)
		tooltip:Hide()
		tooltip:ClearLines()
		tooltip:SetOwner(UIParent, "ANCHOR_NONE")
		tooltip:SetUnit(unit)
		tooltip:Show()
		local name, nameI = getName()
		local guild, guildI = getGuild()
		local location, locationI = getLocation(unit)
		local type, typeI = getPetType()
		return name, nameI, guild, guildI, location, locationI, type, typeI, getLines(lines)
	end
end

function getLines(lines)
	for i = 1, tooltip:NumLines() do
		lines.left[i] = lines.left[i] and self.leftLines[i]:GetText()
		lines.right[i] = lines.left[i] and left.rightLines[i]:GetText()
	end
	return lines
end

local LEVEL_start = "^" .. (type(LEVEL) == "string" and LEVEL or "Level")
function getLocation(scanunit)
    local left_2 = self.leftLines[2]:GetText()
    local left_3 = self.leftLines[3]:GetText()
    if not left_2 or not left_3 then
        return nil
    end
    local hasGuild = not left_2:find(LEVEL_start)
    local factionText = not hasGuild and left_3 or self.leftLines[4]:GetText()
    if factionText == PVP then
        factionText = nil
    end

    local hasFaction = factionText and not UnitPlayerControlled(scanunit) and not UnitIsPlayer(scanunit) and (UnitFactionGroup(scanunit) or factionList[factionText])
	if UnitInParty(scanunit) or UnitInRaid(scanunit) then
		if hasGuild and hasFaction then
			return self.leftLines[5]:GetText(), 5
		elseif (hasGuild or hasFaction) then
			local text = self.leftLines[4]:GetText()
			if text == PVP then return nil end
			return self.leftLines[4]:GetText(), 4
		elseif not left_3:find(LEVEL_start) and left_3 ~= PVP then
			return left_3, 3
		end
	end
	return nil
end

function getGuild()
    local left_2 = self.leftLines[2]:GetText()
	if not left_2 then return nil end
    if left_2:find(LEVEL_start) then return nil end
    return "<" .. left_2 .. ">", 2
end

function getName()
	return self.leftLines[1]:GetText(), 1
end


function getPetType()
	for i = 1, tooltip:NumLines() do
		local str = self.leftLines[i]:GetText()
		local tst =  str:match(L[".*Pet.*Level.* (.*)"])

		if tst then
			return tst, i
		end
	end
	return nil
end
