do return end
local MAJOR = "LibScriptableLCDDriverQTip-1.0"
local MINOR = 24
assert(LibStub, MAJOR.." requires LibStub") 
local LibDriverQTip = LibStub:NewLibrary(MAJOR, MINOR)
if not LibDriverQTip then return end
local LibError = LibStub("LibScriptableUtilsError-1.0", true)
assert(LibError, MAJOR .. " requires LibScriptableUtilsError-1.0")
local LibCore = LibStub("LibScriptableLCDCore-1.0", true)
assert(LibCore, MAJOR .. " requires LibScriptableLCDCore-1.0")
local LCDText = LibStub("LibScriptableLCDText-1.0", true)
assert(LCDText, MAJOR .. " requires LibScriptableLCDText-1.0")
local PluginResources = LibStub("LibScriptablePluginResourceTools-1.0", true)
assert(PluginResources, MAJOR .. " requires LibScriptablePluginResourceTools-1.0")
PluginResources = PluginResources:New(PluginResources)

local PluginString = LibStub("LibScriptablePluginString-1.0", true)
assert(PluginString, MAJOR .. " requires LibScriptablePluginString-1.0")
PluginString = PluginString:New(PluginString)
local LibQTip = LibStub('LibQTip-1.0', true)
assert(LibQTip, MAJOR .. " requires LibQTip-1.0")

local pool = setmetatable({}, {__mode = "k"})

local options
local frame = CreateFrame("Frame")
local objects = {}

local DEFAULT_LIMIT = 50

if not LibDriverQTip.__index then
	LibDriverQTip.__index = LibDriverQTip
end

-- @name LibScriptableDriverQTip:New
-- @usage LibScriptableDriverQTip:New(visitor, rows, cols, yres, xres, layers)
-- @param visitor App
-- @param environment Execution environment
-- @param name A name for this LCD
-- @param config The configuration
-- @param errorLevel Error verbosity
-- @return A new LibScriptableDriverQTip object

function LibDriverQTip:New(visitor, environment, name, config, errorLevel)
	
	assert(type(name) == "string", MAJOR .. ": Invalid name")
	assert(type(config[name]) == "table", MAJOR .. ": " .. name .. ": Invalid config")
	assert(type(config[name].addon) == "string", format("%s : %s: Missing %s.addon", MAJOR, name, name))

	PluginResources.Update()
	local mem1, mempercent1, memdiff1, totalmem1, totalmemdiff1 = PluginResources.GetMemUsage(config[name].addon)
	local cpu1, cpupercent1, cpudiff1, totalcpu1, totalcpudiff1 = PluginResources.GetCPUUsage(config[name].addon)
	
	local obj = next(pool)

	if obj then
		pool[obj] = nil
	else
		obj = {}
		obj.buffer = {}
	end

	setmetatable(obj, self)
	
	obj.environment = environment
	obj.name = name
	obj.core = LibCore:New(obj, obj.environment, name, config, "text", errorLevel)
	obj.error = LibError:New(MAJOR, errorLevel)
	--local rows, cols = config[name].rows, config[name].cols
	obj.rows, obj.cols, obj.yres, obj.xres, obj.layers = config[name].rows or 4, config[name].cols or 20, config[name].yres or 8, config[name].xres or 6, config[name].layers or 3
	obj.lcd = LCDText:New(obj.core, obj.rows, obj.cols, obj.yres, obj.xres, obj.layers, errorLevel, obj.Blit, obj, config[name].update)
	obj.core.lcd = obj.lcd -- You must provide a LibCore object with an LCD object.
	obj.tooltip = LibQTip:Acquire("LibScriptableDriverQTip" .. name, obj.cols)
	obj.tooltip:SmartAnchorTo(UIParent)
	obj.row = config[name].row
	obj.col = config[name].col
	
	obj.points = {}
	
	for i, point in ipairs(config[name].points or {}) do
		obj.points[i] = point
	end
	
	-- New font looking like GameTooltipText but red with height 15
	local font = CreateFont("LibDriverQTip-normal-"..name)
	local fontbold = CreateFont("LibDriverQTip-bold-"..name)
	
	self.font = {}
	self.font.normal = font
	self.font.bold = fontbold
	
	if config[name].font then
		font:SetFont(config[name].font.normal, config[name].font.size or 12, config[name].font.style)
		fontbold:SetFont(config[name].font.bold or config[name].font.normal, config[name].font.size or 12, config[name].font.style)
		self.font.size = config[name].font.size
		self.font.style = config[name].font.style		
	else
		font:SetFont(GameTooltipText:GetFont())
		fontbold:SetFont(GameTooltipText:GetFont())
		self.font.size = 12
	end
	
	font:SetTextColor(1,1,1)
	fontbold:SetTextColor(1,1,1)
	
	obj.tooltip:SetFont(font)
	
	obj.parent = config[name].parent or "UIParent"
	
	obj.tooltip:SetParent(obj.parent)
	
	self.background = config.background
	
	local tbl = {}
	for i = 1, obj.cols do
		tinsert(tbl, ' ')
	end
	for i = 0, obj.rows - 1 do
		obj.tooltip:AddLine(unpack(tbl))
	end
	
	for row = 1, obj.core.lcd.LROWS do
		for col = 1, obj.core.lcd.LCOLS do
			obj.tooltip:SetCell(row, col, " ", nil, "CENTER", 1, nil, 0, 0, obj.font.size, obj.font.size)
		end
	end	
	
	obj:Move("CENTER", obj.col, obj.row)	
	obj.core:CFGSetup()
	obj.core:BuildLayouts()

	PluginResources.Update()
	local mem2, mempercent2, memdiff2, totalmem2, totalmemdiff2 = PluginResources.GetMemUsage(config[name].addon)
	local cpu2, cpupercent2, cpudiff2, totalcpU2, totalcpudiff2 = PluginResources.GetCPUUsage(config[name].addon)
	
	obj.error:Print(format("%s load stats: Memory at start: %s, Memory at finish: %s, Difference: %s", name, PluginString.memshort(mem1), PluginString.memshort(mem2), PluginString.memshort(memdiff2)), 1)
	obj.error:Print(format("%s load stats: CPU at start: %s, CPU at finish: %s, Difference: %s", name, PluginString.timeshort(cpu1), PluginString.timeshort(cpu2), PluginString.timeshort(cpudiff2)), 1)
	
	tinsert(objects, obj)
	
	return obj
end

-- Delete an object
-- @name LibScriptableDriverQTip:Del
-- @usage LibScriptableDriverQTip:Del([lcd]) or object:Del()
-- @param lcd An optional lcd object
-- @return Nothing
function LibDriverQTip:Del(lcd)
	if not lcd then
		lcd = self
	end
	pool[lcd] = true
	lcd.tooltip:Hide()
	LibQTip:Release(lcd.tooltip)
	lcd.core:Del()
	lcd.error:Del()
end

-- Show the tooltip
-- @name LibScriptableDriverQTip:Show
-- @usage LibScriptableDriverQTip:Show()
-- @return Nothing
function LibDriverQTip:Show()
	self.core:Start()
	for i, point in ipairs(self.points) do
		self:Move(unpack(point))
	end
	self.tooltip:Show()
end

-- Hide the tooltip
-- @name :Hide
-- @usage :Hide()
-- @return NOthing
function LibDriverQTip:Hide()
	self.core:Stop()
	self.tooltip:Hide()
end

--[[
local function OnTooltipSetUnit(...)
	
	for i, obj in ipairs(objects) do
		
		if obj.parent == "GameTooltip" then
		LCD4WoW:Print("----------bleh", obj.name)
			obj:Move(unpack(obj.point))
		end
	end
end

GameTooltip:HookScript("OnTooltipSetUnit", OnTooltipSetUnit)
]]

-- Move the tooltip
-- @name LibScriptableDriverQTip:Move
-- @usage LibScriptableDriverQTip(anchor, x, y)
-- @param anchor Frame anchor, i.e: CENTER.
-- @param x X position
-- @param y Y position
-- @return Nothing
function LibDriverQTip:Move(arg1, arg2, arg3, arg4, arg5)
	self.tooltip:ClearAllPoints()
	self.tooltip:SetPoint(arg1, arg2, arg3, arg4, arg5)
end

function LibDriverQTip:Blit(obj, r, c, buffer, len)
	assert(type(buffer) == "table", type(buffer))
	for i = c, c + len - 1 do
		if type(buffer[i - c]) == "number" then
			local chr = obj.lcd.specialChars[buffer[i - c]]
			for y = 0 , obj.lcd.YRES - 1 do
				local mask = bit.lshift(1, obj.lcd.XRES)
				for x = 0, obj.lcd.XRES - 1 do
					mask = bit.rshift(mask, 1)
					if bit.band(chr[y + 1], mask) == 0 then
						obj.tooltip:SetCell(r + y + 1, i + x + 1, " ")
					else
						obj.tooltip:SetCell(r + y + 1, i + x + 1, "#")
					end
				end
			end
		else
			obj.tooltip:SetCell(r + 1, i + 1, (buffer[i - c] or ' '):sub(1, 1))
		end
	end
end

function LibDriverQTip:RebuildOpts(visitor, db)
	return LibCore:RebuildOpts(visitor, db)
end

function LibDriverQTip:KeyEvent(modifier, up)
	--self.core:KeyEvent(modifier, up)
end
