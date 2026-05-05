-- Void / World 3 stub — extend when PlaceFile / mechanics differ.
return {
	id = "w3_void",
	priority = 30,
	detect = function(env)
		local pf = env.getPlaceFileModule()
		if not pf then
			return false
		end
		if pf.IsWorld3 == true then
			return true
		end
		local wn = pf.WorldNumber or pf.worldNumber or pf.World or pf.world
		return type(wn) == "number" and wn == 3
	end,
}
