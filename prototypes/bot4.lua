ticks = 100

set_timer(ticks)

on_timer_expired = function()
	print("*******************************************************")
	scanned = get_entities(100000, PLANET + BASE + SHIP + ASTEROID)

	for n, v in pairs(scanned) do
		if get_distance(v) < 5000 then
			print(entity_to_string(v))
		end
	end

	set_timer(ticks)
end

-- .quit
--.quit

