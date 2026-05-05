-- Tech World — hidden-hatch heartbeat must still drive "Click to open" UI; widen GUI scan (CoreGui).
return {
	id = "w2_tech",
	priority = 40,
	detect = function(env)
		local pf = env.getPlaceFileModule()
		if not pf then
			return false
		end
		if pf.IsWorld2 == true then
			return true
		end
		local wn = pf.WorldNumber or pf.worldNumber or pf.World or pf.world
		return type(wn) == "number" and wn == 2
	end,
	allowEggPromptDuringHiddenHatchHeartbeat = true,
	augmentEggOpeningScanRoots = function(roots)
		local ok, cg = pcall(game.GetService, game, "CoreGui")
		if ok and cg then
			table.insert(roots, cg)
		end
	end,
	adjustEggOpeningBurstCount = function(n)
		local base = tonumber(n) or 0
		return math.max(base, 4)
	end,
}
