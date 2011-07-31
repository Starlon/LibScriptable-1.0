local MAJOR = "LibScriptableLocale-esMX-1.0"
local MINOR = 20
assert(LibStub, MAJOR.." requires LibStub")

local L = LibStub:NewLibrary(MAJOR, MINOR)
if not L then return end

L.L = setmetatable({}, {__index = function(k, v)
	if type(v) ~= "string" then return k end
	return v
end})

local L = L.L

