--[[
  AutoRank bootstrap — только HttpGet (никакого readfile).
  URL: getgenv().AutoRankCoreUrl или fallback raw ниже.
]]

local CORE_FALLBACK_URL =
	"https://raw.githubusercontent.com/topzurdo/DoNotTryfindmyreposssssalsooa/refs/heads/main/autorank/core.lua"

local g0 = (getgenv and getgenv()) or _G
local coreUrl = rawget(g0, "AutoRankCoreUrl")
if type(coreUrl) ~= "string" or coreUrl == "" then
	coreUrl = CORE_FALLBACK_URL
end

local ok, src = pcall(function()
	return game:HttpGet(coreUrl, true)
end)
if not ok or type(src) ~= "string" or #src == 0 then
	error("[AutoRank] HttpGet core failed: " .. tostring(coreUrl))
end
if not loadstring then
	error("[AutoRank] loadstring not available.")
end

local chunk, err = loadstring(src, "@autorank/core")
if not chunk then
	error("[AutoRank] core compile error: " .. tostring(err))
end

local okRun, runErr = pcall(chunk)
if not okRun then
	error("[AutoRank] core runtime error: " .. tostring(runErr))
end
