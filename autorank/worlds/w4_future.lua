-- Future worlds (W4+) stub — extend when needed.
return {
	id = "w4_future",
	priority = 50,
	detect = function(env)
		local pf = env.getPlaceFileModule()
		if not pf then
			return false
		end
		if pf.IsWorld4 == true then
			return true
		end
		local wn = pf.WorldNumber or pf.worldNumber or pf.World or pf.world
		return type(wn) == "number" and wn >= 4
	end,
}
