--[[
  AutoRank bootstrap — loads full runtime from autorank/core.lua.
  Local: place autorank/core.lua next to this file (readfile).
  Remote: HttpGet getgenv().AutoRankCoreUrl or GitHub raw fallback below.
]]

local CORE_FALLBACK_URL =
	"https://raw.githubusercontent.com/topzurdo/DoNotTryfindmyreposssssalsooa/refs/heads/main/autorank/core.lua"

local g0 = (getgenv and getgenv()) or _G
local coreUrl = rawget(g0, "AutoRankCoreUrl")
if type(coreUrl) ~= "string" or coreUrl == "" then
	coreUrl = CORE_FALLBACK_URL
end

local src = nil
if readfile and isfile then
	for _, path in ipairs({ "autorank/core.lua", "./autorank/core.lua" }) do
		if isfile(path) then
			local ok, chunk = pcall(readfile, path)
			if ok and type(chunk) == "string" and #chunk > 0 then
				src = chunk
				break
			end
		end
	end
end
if not src then
	local ok, body = pcall(function()
		return game:HttpGet(coreUrl, true)
	end)
	if ok and type(body) == "string" and #body > 0 then
		src = body
	end
end

if not src then
	error("[AutoRank] Cannot load autorank/core.lua (readfile path or HttpGet).")
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
