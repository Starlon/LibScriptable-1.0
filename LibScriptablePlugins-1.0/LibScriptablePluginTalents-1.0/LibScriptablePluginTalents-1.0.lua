local MAJOR = "LibScriptablePluginTalents-1.0"
local MINOR = 24
local PluginTalents = LibStub:NewLibrary(MAJOR, MINOR)
if not PluginTalents then return end
--local GroupTalents = LibStub("LibGroupTalents-1.0", true)
--assert(GroupTalents, MAJOR .. " requires LibGroupTalents-1.0")
local TalentQuery = LibStub("LibTalentQuery-1.0", true)
assert(TalentQuery, MAJOR .. " requires LibTalentQuery-1.0")
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
			spec[guid].ilvl = floor(total / count)
		end
		
		frame:SetScript("OnUpdate", nil)
	end
end

function PluginTalents:TalentQuery_Ready(e, name, realm, unitid)

	local specid = GetInspectSpecialization(unitid)
	local role1 = GetSpecializationRoleByID(specid)
	local _, name = GetSpecializationInfoByID(specid)
	local guid = UnitGUID(unitid)

	if not spec[guid] then
		spec[guid] = new()
		spec[guid].guid = guid
	end

	if UnitIsUnit("player", unitid) then
		local specgroup = GetActiveSpecGroup(false)
		local id, name, description, texture, background = GetSpecializationInfo(specgroup, false);

		spec[guid] = new(name, texture, background)
	else
		local id, name, description, texture, background, role, class = GetSpecializationInfoByID(specid)
	
		spec[guid] = new(name, texture, background, role)
	end
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

function PluginTalents.SendQuery(unit)
	local guid = UnitGUID(unit)
	if not UnitIsPlayer(unit) or not (CheckInteractDistance(unit, 1)) then return end

	if UnitIsUnit(unit, "player") then
		PluginTalents:TalentQuery_Ready(_, UnitName(unit), nil, "player")
	else
		TalentQuery:Query(unit)
	end
end

function PluginTalents.UnitILevel(unit, returnNil)
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

	local cur = spec[guid]
	if not cur then return end
	local name = cur[1]
	local texture = cur[2]
	local background = cur[3]
	
	if not name then return L["Scanning"] .. periods end

	return ('|T%s:12|t %s'):format(texture or "", name or "")
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
	return UnitGroupRolesAssigned(unit);
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

--GroupTalents.RegisterCallback(PluginTalents, "LibGroupTalents_Update", "OnUpdate")
TalentQuery.RegisterCallback(PluginTalents, "TalentQuery_Ready")
TalentQuery.RegisterCallback(PluginTalents, "LibGroupTalents_RoleChange", "OnRoleChange")
throttleTimer = LibTimer:New(MAJOR .. " throttle timer", THROTTLE_TIME, true, PluginTalents.SendQuery)

