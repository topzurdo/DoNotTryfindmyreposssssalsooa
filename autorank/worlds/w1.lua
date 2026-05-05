-- Main / World 1 — baseline after PlaceFile is available.
return {
	id = "w1",
	priority = 1,
	detect = function(env)
		local pf = env.getPlaceFileModule()
		if not pf then
			return false
		end
		return true
	end,
}
