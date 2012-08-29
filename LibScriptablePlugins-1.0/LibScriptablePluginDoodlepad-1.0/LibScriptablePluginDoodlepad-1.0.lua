-- Huge appreciation goes out to ckknight for 99% of the following.
local MAJOR = "LibScriptablePluginDoodlepad-1.0"
local MINOR = 24

local PluginDoodlepad = LibStub:NewLibrary(MAJOR, MINOR)
if not PluginDoodlepad then return end
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

PluginColor:New(PluginColor)

local _G = _G
local ScriptEnv = {}

if not PluginDoodlepad.__index then
	PluginDoodlepad.__index = PluginDoodlepad
end

-- Populate an environment with this plugin's fields
-- @usage :New(environment) 
-- @parma environment This will be the environment when setfenv is called.
-- @return A new plugin object, aka the environment, and the plugin object as second return value
function PluginDoodlepad:New(environment)
	
	environment = environment or {}

	for k, v in pairs(ScriptEnv) do
		environment[k] = v
	end

	
	return environment
end


local dw, dh = 1000, 1000
--- Borrowed from Doodlepad, with permission from Humbedooh. All rights reserved.
-- Draw a line on a surface. Provide frame, a line texture, coordinates, width/height, and color.
local function Doodle_DrawLine(drawLayer, T, sx, sy, ex, ey, width, height, color)
	sx = sx * (width/dw);
	sy = -sy * (height/dh);
	ex = ex * (width/dw);
	ey = -ey * (height/dh);
	T:SetTexCoord(0,1,0,1);
	local C = drawLayer;
    local w = penWidth;
    local dx,dy = ex - sx, ey - sy;
    local cx,cy = (sx + ex) / 2, (sy + ey) / 2;
    if (dx < 0) then
        dx,dy = -dx,-dy;
    end
    local Z = (256/255) / 2;
    local l = sqrt((dx * dx) + (dy * dy));
    local s,c = -dy / l, dx / l;
    local sc = s * c;
    local Bwid, Bhgt, BLx, BLy, TLx, TLy, TRx, TRy, BRx, BRy;
    if (dy >= 0) then
        Bwid = ((l * c) - (width * s)) * Z;
        Bhgt = ((width * c) - (l * s)) * Z;
        BLx, BLy, BRy = (width / l) * sc, s * s, (l / width) * sc;
        BRx, TLx, TLy, TRx = 1 - BLy, BLy, 1 - BRy, 1 - BLx;
        TRy = BRx;
    else
        Bwid = ((l * c) + (width * s)) * Z;
        Bhgt = ((width * c) + (l * s)) * Z;
        BLx, BLy, BRx = s * s, -(l / width) * sc, 1 + (width / l) * sc;
        BRy, TLx, TLy, TRy = BLx, 1 - BRx, 1 - BLx, 1 - BLy;
        TRx = TLy;
    end
    T:SetDrawLayer("BORDER", 0)
	T:ClearAllPoints();
	if not (Bwid-1<Bwid) or not (Bhgt-1<Bhgt) then return; end -- discard bad data (IND or INF)
    local r, g, b, a = PluginColor.Color2RGBA(color, true)
    T:SetVertexColor(r, g, b, a);
    T:SetTexCoord(TLx, TLy, BLx, BLy, TRx, TRy, BRx, BRy);
    T:SetPoint("TOPLEFT",   C, "TOPLEFT", cx - Bwid, cy + Bhgt);
    T:SetSize(Bwid*2,Bhgt*2);
    T:Show()
end
ScriptEnv.DrawLine = Doodle_DrawLine

