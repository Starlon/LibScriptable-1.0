local MAJOR = "LibScriptablePluginTalents-1.0"
local MINOR = 24
local PluginTalents = LibStub:NewLibrary(MAJOR, MINOR)
if not PluginTalents then return end
--local GroupTalents = LibStub("LibGroupTalents-1.0", true)
--assert(GroupTalents, MAJOR .. " requires LibGroupTalents-1.0")
local LibTimer = LibStub("LibScriptableUtilsTimer-1.0", true)
assert(LibTimer, MAJOR .. " requires LibScriptableUtilsTimer-1.0")
local Locale = LibStub("LibScriptableLocale-1.0", true)
assert(Locale, MAJOR .. " requires LibScriptableLocale-1.0")
local L = Locale.L

local _G = _G
local GameTooltip = _G.GameTooltip
local UnitIsUnit = _G.UnitIsUnit
local GetNumTalentTabs = _G.GetNumTalentTabs
local GetTalentTabInfo = _G.GetTalentTabInfo
local UnitExists = _G.UnitExists
local UnitIsPlayer = _G.UnitIsPlayer
local UnitName = _G.UnitName
local EXPIRE_TIME = 5000
local spec = setmetatable({}, {__mode="v"})
local frame = CreateFrame("Frame")
local featsFrame = CreateFrame("Frame")
local honorFrame = CreateFrame("Frame")
local count = 0
local query = {}
local spec_cache = {}
local spec_role = {}
local PVP_cache = setmetatable({}, {__mode="v"})
local FEATS_cache = {}
local inspectUnit
local THROTTLE_TIME = 500
local throttleTimer 
local ScriptEnv = {}
local lastInspect = 0

if not PluginTalents.__index then
	PluginTalents.__index = PluginTalents
end

local pool = setmetatable({}, {__mode = "k"})
local function new(...)
	local obj = next(pool)
	if obj then
		pool[obj] = nil
	else
		obj = {}
	end
	for i = 1, select("#", ...) do
		obj[i] = select(i, ...)
	end
	return obj
end

local function del(obj)
	wipe(obj)
	pool[obj] = true
end

--- Populate an environment with this plugin's fields
-- @usage :New(environment) 
-- @param environment This will be the environment when setfenv is called.
-- @return A new plugin object, aka the environment
function PluginTalents:New(environment)

    for k, v in pairs(ScriptEnv) do
		environment[k] = v
	end	
	return environment
end

local indexOf = function(t, val, talengGroup)
	for i=1, #t do
		if t[i][2] == val then
			return i
		end
	end
end

local iconsz = 19 
local riconsz = iconsz
local role_tex_file = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES.blp"
local role_t = "\124T"..role_tex_file..":%d:%d:"
local role_tex = {
   DAMAGER = role_t.."0:0:64:64:20:39:22:41\124t",
   HEALER  = role_t.."0:0:64:64:20:39:1:20\124t",
   TANK    = role_t.."0:0:64:64:0:19:22:41\124t",
   LEADER  = role_t.."0:0:64:64:0:19:1:20\124t",
   NONE    = ""
}
function getRoleTex(role,size)
  local str = role_tex[role]
  if not str or #str == 0 then return "" end
  if not size then size = 0 end
  role_tex[size] = role_tex[size] or {}
  str = role_tex[size][role]
  if not str then
     str = string.format(role_tex[role], size, size)
     role_tex[size][role] = str
  end
  return str
end
function getRoleTexCoord(role)
  local str = role_tex[role]
  if not str or #str == 0 then return nil end
  local a,b,c,d = string.match(str, ":(%d+):(%d+):(%d+):(%d+)%\124t")
  return a/64,b/64,c/64,d/64
end

-- From LibInspectLess
local function GetInspectItemLinks(unit)
	local done = true
	for i=1, 19 do
		if GetInventoryItemTexture(unit, i) and not GetInventoryItemLink(unit, i) then
			--GetTexture always return stuff but GetLink is not.
			done = false
		end
	end
	return done
end

-- this is unthrottled, but it doesn't matter since it's such a short interval before the client finishes downloading everything
local function ItemOnUpdate(elapsed)
	local done = GetInspectItemLinks(inspectUnit)
	local count = 0
	if done then
		local guid = UnitGUID(inspectUnit)
		local total = 0
		for i = 1, 18 do
			local ItemLink = GetInventoryItemLink(inspectUnit, i);
			if ItemLink and i ~= 4 then
				local _, _, _, ilvl = GetItemInfo(ItemLink);
				total = total + ilvl
				count = count + 1
			end
		end
		
		if guid and spec[guid] and count > 0 then
			spec[guid].ilvl = floor(total / count + 0.5)
		end
		
		frame:SetScript("OnUpdate", nil)
	end
end


local function sortfunc(a, b)
	return a>b
end

--[[
function PluginTalents:OnUpdate(event, guid, unitid, newSpec, talent1, talent2, talent3)
	local class = UnitClass(unitid)
	if not talentTrees[class] then return end
	local guid = UnitGUID(unitid)
	local isnotplayer = not UnitIsUnit("player", unitid)
	local talentGroup = GetActiveTalentGroup(isnotplayer)
	
	if not spec[guid] then
		spec[guid] = new()
		spec[guid].guid = guid
	end

	if not spec[guid][talentGroup] then
		spec[guid][talentGroup] = new()
	end

	for tab = 1, 3 do
		spec[guid][talentGroup][tab] = new(nil, nil, nil, "None", nil)
	end
	
	local specNames 
	if GroupTalents:GetTreeNames(class) then
		specNames = new(GroupTalents:GetTreeNames(class))
	else
		specNames = new(unpack(talentTrees[class]))
	end

	local highPoints = new()
	local pointsspent = new(talent1, talent2, talent3)
	
	for i, point in ipairs(pointsspent) do
		local _, treename, _, iconTexture = GetTalentTabInfo(i, isnotplayer, false, talentGroup)
	
		highPoints[i] = point
		spec[guid][talentGroup][i] = {treename, point, iconTexture}
	end
	
	table.sort(highPoints, sortfunc)
	
	local i = indexOf(spec[guid][talentGroup], highPoints[1])
	spec[guid].tab = i
	spec[guid].talentGroup = talentGroup

	del(specNames)
	del(highPoints)
	del(pointsspent)
	
	inspectUnit = unitid
	
	frame:SetScript("OnUpdate", ItemOnUpdate)
end
--]]

function PluginTalents:TalentQuery_Ready(e, name, realm, unitid)
	local class = UnitClass(unitid)
	local specNames = new()
	local guid = UnitGUID(unitid)
	local isnotplayer = not UnitIsUnit("player", unitid)
	local talentGroup = GetActiveTalentGroup(isnotplayer)

	if not spec[guid] then
		spec[guid] = new()
		spec[guid].guid = guid
	end

	if not spec[guid][talentGroup] then
		spec[guid][talentGroup] = new()
	end

	for tab = 1, 3 do
		spec[guid][talentGroup][tab] = new(nil, nil, nil, "None", nil)
	end
	
	local specNames = new()
	local highPoints = new()
	for tab = 1, GetNumTalentTabs(isnotplayer) do
		local _, treename, _, iconTexture, pointsSpent = GetTalentTabInfo(tab, isnotplayer, false, talentGroup)
		highPoints[tab] = pointsSpent
		spec[guid][talentGroup][tab] = new(treename, pointsSpent, iconTexture)
		specNames[tab] = treename
	end
	
	table.sort(highPoints, sortfunc)
	
	local i = indexOf(spec[guid][talentGroup], highPoints[1])
	spec[guid].tab = i
	spec[guid].talentGroup = talentGroup
	
	del(specNames)
	del(highPoints)

	inspectUnit = unitid
	
	frame:SetScript("OnUpdate", ItemOnUpdate)	
	
	-- We do PVP stuff
	if not UnitIsUnit(unitid, "player") and not PVP_cache[guid] then
		if (HasInspectHonorData()) then
			honorFrame:UnregisterEvent("INSPECT_HONOR_UPDATE");
		end
		honorFrame:RegisterEvent("INSPECT_HONOR_UPDATE");
		RequestInspectHonorData();
	end
	
end

function PluginTalents:OnRoleChange(event, guid, unit, newrole, oldrole)
	spec[guid] = nil
	spec_cache[guid] = nil
	spec_role[guid].newrole = newrole
	spec_role[guid].oldrole = oldrole
end

--[[
local function okToInspect(unit)
	local guid = UnitGUID(unit)
	return 
end
]]

function PluginTalents.SendQuery(unit)
	local guid = UnitGUID(unit)
	if not UnitIsPlayer(unit) or not (CheckInteractDistance(unit, 1)) then return end

	frame:RegisterEvent("INSPECT_READY")
	NotifyInspect(unit)
	lastInspect = GetTime()
end

function PluginTalents.UnitILevel(unit, returnNil)
	do return 0 end
	if type(unit) ~= "string" then return end
	local guid = UnitGUID(unit)
	if not UnitIsPlayer(unit) or not UnitExists(unit) then return end
	
	local periods = ""
	for i = 0, count % 3 do
		periods = periods .. "."
	end
	count = count + 1

	if not (spec[guid] and spec[guid].ilvl) and returnNil then return nil end
	
	if not CheckInteractDistance(unit, 1) and not spec[guid] then return L["Out of Range"] end

	if not spec[guid] or not spec[guid].ilvl then return L["Scanning"] .. periods end

	return format("%d", spec[guid].ilvl)
end
ScriptEnv.UnitILevel = PluginTalents.UnitILevel

function PluginTalents.SpecText(unit, returnNil)
	if type(unit) ~= "string" then return end
	do return end
	if not UnitIsPlayer(unit) or not UnitExists(unit) then return end
	local guid = UnitGUID(unit)
	local guid = UnitGUID(unit)
			
	local periods = ""
	for i = 0, count % 3 do
		periods = periods .. "."
	end
	count = count + 1
	
	if not CheckInteractDistance(unit, 1) and not spec[guid] then return L["Out of Range"] end

	if not spec[guid] then return L["Scanning"] .. periods end

	if not spec[guid] and returnNil then return nil end

	local cur = spec[guid][spec[guid].talentGroup]
	local one = cur[1][2]
	local two = cur[2][2]
	local three = cur[3][2]
	local name = cur[spec[guid].tab][1]
	local texture = cur[spec[guid].tab][3]
	
	if not name or not texture or not one or not two or not three then return end
	
	return ('|T%s:12|t %s (%d/%d/%d)'):format(texture or "", name, one, two, three)
end
ScriptEnv.SpecText = PluginTalents.SpecText

function PluginTalents.GetSpec(unit)
	if type(unit) ~= "string" or not UnitExists(unit) then return end
	local guid = UnitGUID(unit)

	return unpack(spec[guid])
end
ScriptEnv.GetSpec = PluginTalents.GetSpec

function PluginTalents.GetSpecData()
	return spec
end
ScriptEnv.GetSPecData = PluginTalents.GetSpecData

function PluginTalents.ClearSpec(unit)
	if type(unit) ~= "string" or not UnitExists(unit) then return end
	local guid = UnitGUID(unit)
	spec[guid] = nil
end
ScriptEnv.ClearSpec = PluginTalents.ClearSpec

function PluginTalents.GetRole(unit)
	local guid = UnitGUID(unit)
	if spec[guid] then
		return roleTypes[spec[guid].role], roleTypes[spec[guid].oldrole or -1]
	end
end
ScriptEnv.GetRole = PluginTalents.GetRole

local function onTooltipSetUnit()
	
	local _, unit = GameTooltip:GetUnit()

	if not unit or not CheckInteractDistance(unit, 1) then return end
	
	if unit then
		--GroupTalents:RefreshTalentsByUnit(unit)
	end
	
	if not UnitIsPlayer(unit) then return end
	
	local guid = UnitGUID(unit)
	
	local sendQuery = false
	if spec_cache[guid] then
		spec[guid] = spec_cache[guid]
		spec_cache[guid] = nil
	else
		sendQuery = true
	end

	if not PVP_cache[guid] then
		sendQuery = true
	end

	if sendQuery then
		throttleTimer:Start(nil, unit)
	end

	frame:SetScript("OnUpdate", nil)
end
GameTooltip:HookScript("OnTooltipSetUnit", onTooltipSetUnit)

local function onHide()
	for i, v in ipairs(spec) do
		if v[5] == "mouseover" then
			del(v)
			spec_cache[v.guid] = v
			spec[k] = nil
		end
	end
	frame:SetScript("OnUpdate", nil)
end
GameTooltip:HookScript("OnHide", onHide)


--- ACHIEVEMENTS --

-- Achievement Inspection Ready
function featsFrame:INSPECT_ACHIEVEMENT_READY(event,guid)
	self:UnregisterEvent("INSPECT_ACHIEVEMENT_READY");
	FEATS_cache[guid] = GetComparisonAchievementPoints();
	ClearAchievementComparisonUnit();
	featsFrame.requestedAchievementData = false
end

-- Requests Achievement Data
function RequestAchievementData(unit)
	if featsFrame.requestedAchievementData then return end
	featsFrame:RegisterEvent("INSPECT_ACHIEVEMENT_READY");
	featsFrame:SetScript("OnEvent", featsFrame.INSPECT_ACHIEVEMENT_READY);
	SetAchievementComparisonUnit(unit);
	featsFrame.requestedAchievementData = true
end

PluginTalents.UnitFeats = function(unit)
    if not UnitIsPlayer(unit) then return end
	if type(unit) ~= "string" or not UnitExists(unit) then 
			return -1;
	end
	local guid = UnitGUID(unit);
	if not FEATS_cache[guid] then
		RequestAchievementData(unit)
		return -1
	end
	return FEATS_cache[guid]
end
ScriptEnv.UnitFeats = PluginTalents.UnitFeats

--- HONOR ---
-- Much of this was borrowed from Examiner

-- Load Arena Teams Normal
function LoadArenaTeamsNormal(unit, player)
    local isSelf = UnitIsUnit(unit, "player")
	player.teams = {}
	for i = 1, MAX_ARENA_TEAMS do
		local at = {}
		if (isSelf) then
			at.teamName, at.teamSize, at.teamRating, at.teamPlayed, at.teamWins, at.seasonTeamPlayed, at.seasonTeamWins, at.playerPlayed, at.seasonPlayerPlayed, at.teamRank, at.playerRating, at.backR, at.backG, at.backB, at.emblem, at.emblemR, at.emblemG, at.emblemB, at.border, at.borderR, at.borderG, at.borderB = GetArenaTeam(i);
			at.teamPlayed, at.teamWins, at.playerPlayed = at.seasonTeamPlayed, at.seasonTeamWins, at.seasonPlayerPlayed;
		else
			at.teamName, at.teamSize, at.teamRating, at.teamPlayed, at.teamWins, at.playerPlayed, at.playerRating, at.backR, at.backG, at.backB, at.emblem, at.emblemR, at.emblemG, at.emblemB, at.border, at.borderR, at.borderG, at.borderB = GetInspectArenaTeamData(i);
		end
		if type(at.teamSize) == "number" and at.teamSize ~= 0 then
			player.teams[at.teamSize] = at
		end
	end
end

-- Load Honor Normal
function LoadHonorNormal(unit, hd)
    local isSelf = UnitIsUnit(unit, "player")
	-- Query -- Az: Even if inspecting ourself, use inspect data as GetPVPYesterdayStats() is bugged as of (4.0.1 - 4.0.3a)
	if not isSelf and HasInspectHonorData() then
		hd.todayHK, hd.todayHonor, hd.yesterdayHK, hd.yesterdayHonor, hd.lifetimeHK, hd.lifetimeRank = GetInspectHonorData();
	elseif not isSelf then
		return false
	else
		hd.todayHK, hd.todayHonor = GetPVPSessionStats();
		hd.yesterdayHK, hd.yesterdayHonor = GetPVPYesterdayStats();
		hd.lifetimeHK, hd.lifetimeRank = GetPVPLifetimeStats();
	end
	-- Update
	if (hd.lifetimeRank ~= 0) then
		hd.texture = "Interface\\PvPRankBadges\\PvPRank"..format("%.2d",hd.lifetimeRank - 4)..".blp";
		--self.rankIcon.texture:SetTexCoord(0,1,0,1);
		hd.text = format("%s (%d)",GetPVPRankInfo(hd.lifetimeRank, unit),(hd.lifetimeRank - 4));
	end
end

function quit(self)
	self:UnregisterEvent("INSPECT_HONOR_UPDATE")
end

local cache = {}
-- INSPECT_HONOR_UPDATE
function honorFrame:INSPECT_HONOR_UPDATE(event)
	if not HasInspectHonorData() or not inspectUnit then return end
	local unit = inspectUnit
	if not unit then 
		return self:UnregisterEvent("INSPECT_HONOR_UPDATE")
	end
	local guid = UnitGUID(unit)
	if not guid then
		return self:UnregisterEvent("INSPECT_HONOR_UPDATE")
	end
	local toon = {}
	LoadHonorNormal(unit, toon)
	LoadArenaTeamsNormal(unit, toon)
	PVP_cache[guid] = toon
	self:UnregisterEvent("INSPECT_HONOR_UPDATE")
end

PluginTalents.UnitPVPStats = function(unit)
	if not UnitExists(unit) or not UnitIsPlayer(unit) then return end
	
	local guid = UnitGUID(unit)
	
	if not guid then return end
		
	if UnitIsUnit(unit, "player") and not PVP_cache[guid] then
		local toon = {}
		LoadHonorNormal(unit, toon)
		LoadArenaTeamsNormal(unit, toon)
		PVP_cache[guid] = toon
	end
	
	return PVP_cache[guid]
end
ScriptEnv.UnitPVPStats = PluginTalents.UnitPVPStats
honorFrame:SetScript("OnEvent", honorFrame.INSPECT_HONOR_UPDATE)

function WipeInspect()
	wipe(spec_cache)
	wipe(spec)
	wipe(spec_role)
	wipe(PVP_cache)
	wipe(FEATS_cache)
end
ScriptEnv.WipeInspect = WipeInspect

throttleTimer = LibTimer:New(MAJOR .. " throttle timer", THROTTLE_TIME, true, PluginTalents.SendQuery)

