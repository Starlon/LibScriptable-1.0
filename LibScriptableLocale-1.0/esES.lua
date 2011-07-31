if GetLocale() ~= "esES" then return end
local MAJOR = "LibScriptableLocale-esES-1.0"
local MINOR = 21
assert(LibStub, MAJOR.." requires LibStub")

local L = LibStub:NewLibrary(MAJOR, MINOR)
if not L then return end

L.L = {}
local L = L.L
local mt = {__index=function(table, key)
	local val = rawget(table, key)
	if type(val) ~= "string" then val = key end
	return val
end, __newindex=function(table, key, val)
	if type(val) ~= "string" then val = key end
	rawset(table, key, val)
end}
setmetatable(L, mt)

