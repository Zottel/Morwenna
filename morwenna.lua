morwenna = function(role, home_x, home_y)
-- -------------------------------------------------------------------------- --
-- API STUFF
-- -------------------------------------------------------------------------- --
	count = function(a) local n = 0 for _, v in pairs(a) do n = n + 1 end return n end
	math.randomseed(get_timestep())

	-- Environment_variables
	local xmin, xmax, ymin, ymax = get_world_size()

	-- Hello world
	print("Hello world! I am a " .. role .. ", home at " .. home_x .. "/" .. home_y)
	
	-- Fortpflanzung
	function receiver() --print("receiver running")
		on_incoming_data = function(data) --print("receiving morwenna")
			morwenna = loadstring(data);
			on_incoming_data = function(data) --print("receiving role")
				local role = data
				on_incoming_data = function(data) --print("receiving home x")
					local home_x = data
					on_incoming_data = function(data) --print("receiving home y")
						local home_y = data
						morwenna(role, home_x, home_y)
					end
				end
			end
		end
	end
	
	function infect(role)
		send_data(receiver)
		send_data(morwenna)
		send_data(role)
		send_data(home_x) send_data(home_y)
	end
	
	-- slot tracking
	slots = {}
	slots_empty = {}
	slots_ore = {}
	slots_drive = {}
	slots_weapon = {}

	function dump_busy()
		local flag = is_busy()
		if flag == DOCKING then
			print("busy doing: DOCKING")
		elseif flag == UNDOCKING then
			print("busy doing: UNDOCKING")
		elseif flag == TRANSFER then
			print("busy doing: TRANSFER")
		elseif flag == BUILD then
			print("busy doing: BUILD")
		elseif flag == TIMER then
			print("busy doing: TIMER")
		elseif flag == MINING then
			print("busy doing: MINING")
		elseif flag == MANUFACTURE then
			print("busy doing: MANUFACTURE")
		elseif flag == COLONIZE then
			print("busy doing: COLONIZE")
		elseif flag == UPGRADE then
			print("busy doing: UPGRADE")
		else
			print("not busy")
		end
	end

	function dump_slots()
		print("empty: " .. count(slots_empty) .. ", ore: " .. count(slots_ore) .. ", drives: " .. count(slots_drive) .. ", weapons: " .. count(slots_weapon))
	end
	function rebuild_slots()
		slots = get_slots()
		slots_empty = {}
		slots_ore = {}
		slots_drive = {}
		slots_weapon = {}
		for i = 1, #slots do
			if slots[i] == ORE then
				slots_ore[i] = i
			elseif slots[i] == DRIVE then
				slots_drive[i] = i
			elseif slots[i] == WEAPON then
				slots_weapon[i] = i
			elseif slots[i] == EMPTY then
				slots_empty[i] = i
			end
		end
	end

	rebuild_slots()

-- -------------------------------------------------------------------------- --
--    ACTION QUEUE                                                            --
-- -------------------------------------------------------------------------- --
--
	local action = {}
	action.queue = {}

	action.make = function(type, quantity, callback, insert)
		local newaction = {action = "make", quantity = quantity, type = type, callback = callback}
		if insert then table.insert(action.queue, 1, newaction) else table.insert(action.queue, newaction) end
	end

	action.transfer = function(type, quantity, callback, direction, insert)
		local newaction = {action = "transfer", quantity = quantity, type = type, direction = direction, callback = callback}
		if insert then table.insert(action.queue, 1, newaction) else table.insert(action.queue, newaction) end
	end

	action.upgrade = function(callback, quantity, insert)
		local newaction = {action = "upgrade", type = type, quantity = quantity, callback = callback}
		if not quantity then newaction.quantity = 0 end
		if insert then table.insert(action.queue, 1, newaction) else table.insert(action.queue, newaction) end
	end

	action.undock = function(callback, insert)
		local newaction = {action = "undock", callback = callback}
		if insert then table.insert(action.queue, 1, newaction) else table.insert(action.queue, newaction) end
	end

	action.fire = function(callback, target, insert)
		local newaction = {action = "fire", target = target, callback = callback}
		if insert then table.insert(action.queue, 1, newaction) else table.insert(action.queue, newaction) end
	end

	action.run = function()
		if action.queue[1] == nil then return end
		--if action.queue[1].quantity == nil then
		--	print(role .. ": action: " .. action.queue[1].action)
		--else
		--	print(role .. ": action: " .. action.queue[1].action .. "(" .. action.queue[1].quantity .. ")")
		--end
		if action.queue[1].action == "fire" then
			--TODO
		elseif action.queue[1].action == "make" then
			if action.queue[1].type == ORE then
				if count(slots_empty) > 0 then
					local ore_slot = mine()
					if not ore_slot then
						return
					end
					on_mining_complete = function()
						slots_empty[ore_slot] = nil
						slots_ore[ore_slot] = ore_slot
						if action.queue[1].quantity > 1 then
							action.queue[1].quantity = action.queue[1].quantity - 1
						else
							local callback = action.queue[1].callback
							table.remove(action.queue, 1)
							if callback then
								callback()
							end
						end
						action.run()
						return
					end
				else
					if count(slots_drive) > 0 then
						local convert_slot = table.maxn(slots_drive)
						manufacture(convert_slot, ORE)
						on_manufacture_complete = function()
							slots_drive[convert_slot] = nil
							slots_ore[convert_slot] = convert_slot
							if action.queue[1].quantity > 1 then
								action.queue[1].quantity = action.queue[1].quantity - 1
							else
								local callback = action.queue[1].callback
								table.remove(action.queue, 1)
								if callback then
									callback()
								end
							end
							action.run()
							return
						end
					elseif count(slots_weapon) > 0 then
						local convert_slot = table.maxn(slots_weapon)
						manufacture(convert_slot, ORE)
						on_manufacture_complete = function()
							slots_weapon[convert_slot] = nil
							slots_ore[convert_slot] = convert_slot
							if action.queue[1].quantity > 1 then
								action.queue[1].quantity = action.queue[1].quantity - 1
							else
								local callback = action.queue[1].callback
								table.remove(action.queue, 1)
								if callback then
									callback()
								end
							end
							action.run()
							return
						end
					else
						print("error: No more place for ore! Wanted to mine for: " .. action.queue[1].quantity)
						dump_slots()
					end
				end
			elseif action.queue[1].type == DRIVE then
				if count(slots_ore) < action.queue[1].quantity then
					action.make(ORE, action.queue[1].quantity - count(slots_ore), nil, true)
					action.run()
				else
					local manufacturing_slot = nil
					on_manufacture_complete = function()
						slots_ore[manufacturing_slot] = nil
						slots_drive[manufacturing_slot] = manufacturing_slot
						if action.queue[1].quantity > 1 then
							action.queue[1].quantity = action.queue[1].quantity - 1
						else
							local callback = action.queue[1].callback
							table.remove(action.queue, 1)
							if callback then
								callback()
							end
						end
						action.run()
						return
					end
					manufacturing_slot = table.maxn(slots_ore)
					if not manufacture(manufacturing_slot, DRIVE) then
						print("error: manufacture()")
					end
				end
			elseif action.queue[1].type == WEAPON then
				if count(slots_ore) < action.queue[1].quantity then
					action.make(ORE, action.queue[1].quantity - count(slots_ore), nil, true)
					action.run()
				else
					local manufacturing_slot = nil
					on_manufacture_complete = function()
						slots_ore[manufacturing_slot] = nil
						slots_weapon[manufacturing_slot] = manufacturing_slot
						if action.queue[1].quantity > 1 then
							action.queue[1].quantity = action.queue[1].quantity - 1
						else
							local callback = action.queue[1].callback
							table.remove(action.queue, 1)
							if callback then
								callback()
							end
						end
						action.run()
						return
					end
					manufacturing_slot = table.maxn(slots_ore)
					if not manufacture(manufacturing_slot, WEAPON) then
						print("error: manufacture()")
					end
				end
			elseif action.queue[1].type == SHIP then
				if count(slots_ore) < action.queue[1].quantity then
					action.make(ORE, action.queue[1].quantity - count(slots_ore), nil, true)
					action.run()
				else
					if get_docking_partner() then
						print("error: already docked - cannot build a new ship")
					else
						local build_slots = {}
						local n = action.queue[1].quantity
						for _, v in pairs(slots_ore) do
							if n > 0 then
								table.insert(build_slots, v)
								n = n - 1
							end
						end
						if build_ship(build_slots) == nil then
							print("error: could not build_ship")
							table.remove(action.queue, 1)
							action.run()
							return
						else
							on_build_complete = function(newship)
								for _, v in pairs(build_slots) do
									slots_ore[v] = nil
									slots_empty[v] = v
								end
								local callback = action.queue[1].callback
								table.remove(action.queue, 1)
								if callback then
									callback(newship)
								end
								action.run()
								return
							end
						end
					end
				end
			end
		elseif action.queue[1].action == "transfer" then
			-- From the partner to us
			if action.queue[1].direction then
				-- TODO - sometime in the future
			else
				local partner = get_docking_partner()
				if not partner then print("NO DOCKING PARTNER!") return end
				-- Search free remote slot
				local remote_slots = get_slots(partner)

				local remote_slot = nil
				local local_slot = nil

				for i = 1, #remote_slots do
					if remote_slots[i] == EMPTY then
						remote_slot = i
					end
				end
				
				if remote_slot == nil then
					print("error: no empty remote slot!")
					return
				end
				
				if action.queue[1].type == ORE then
					if count(slots_ore) < action.queue[1].quantity then
						action.make(ORE, action.queue[1].quantity - count(slots_ore), nil, true)
						action.run()
						return
					else
						local_slot = table.maxn(slots_ore)
					end
				elseif action.queue[1].type == DRIVE then
					if count(slots_drive) < action.queue[1].quantity then
						action.make(DRIVE, action.queue[1].quantity - count(slots_drive), nil, true)
						action.run()
						return
					else
						local_slot = table.maxn(slots_drive)
					end
				elseif action.queue[1].type == WEAPON then
					if count(slots_weapon) < action.queue[1].quantity then
						action.make(WEAPON, action.queue[1].quantity - count(slots_weapon), nil, true)
						action.run()
						return
					else
						local_slot = table.maxn(slots_weapon)
					end
				end
				transfer_slot(local_slot, remote_slot)
				on_transfer_complete = function()
					rebuild_slots()
					
					if action.queue[1].quantity > 1 then
						action.queue[1].quantity = action.queue[1].quantity - 1
					else
						local callback = action.queue[1].callback
						table.remove(action.queue, 1)
						if callback then
							callback()
						end
					end
					
					action.run()
				end
			end
		elseif action.queue[1].action == "undock" then
			if undock() then
				on_undocking_complete = function()
					local callback = action.queue[1].callback

					table.remove(action.queue, 1)

					if callback then
						callback()
					end

					action.run()
					return
				end
			else
				print("could not undock!")
				dump_busy()
				table.remove(action.queue, 1)
				action.run()
				return
			end
		elseif action.queue[1].action == "upgrade" then
			if #slots >= action.queue[1].quantity then
				local callback = action.queue[1].callback

				table.remove(action.queue, 1)

				if callback then
					callback()
				end

				action.run()
				return
			end
				
			if #slots == count(slots_ore) then
				on_upgrade_complete = function()
					rebuild_slots()
					action.run()
				end

				if not upgrade_base() then
					print("error: upgrade_base()")
					-- Continue with next enqueued action
					table.remove(action.queue, 1)
					action.run()
					return
				end
			else
				action.make(ORE, #slots - count(slots_ore), nil, true)
				action.run()
			end
		end
	end


-- -------------------------------------------------------------------------- --
-- SHIP PERSONALITIES/ROLES
-- -------------------------------------------------------------------------- --

	roles = {}
	roles.home = function()
		--action.upgrade(nil, 24)
		for i = 1, 5 do
			action.make(SHIP, 3)
			action.transfer(DRIVE, 1, function()
				infect("probe")
			end)
			action.undock()
		end

		action.upgrade(nil, 12)

		function makeship()
			for i = 1, 3 do
				action.make(SHIP, 12)
				action.transfer(DRIVE, 3)
				action.transfer(WEAPON, 9, function()
					infect("attack")
				end)
				action.undock()
			end
			for i = 1, 2 do
				action.make(SHIP, 12)
				action.transfer(DRIVE, 3)
				action.transfer(WEAPON, 9, function()
					infect("guard")
				end)
				action.undock()
			end

			action.make(SHIP, 3)
			action.transfer(DRIVE, 3, function()
				infect("probe")
			end)
			action.undock(function()
				makeship()
			end)
		end

		makeship()
	end

	roles.probe = function()
		next_planet = nil
		random_search_count = 0
		state = "searching"

		function random_search()
			local x = math.max(xmin + 5000, math.min(xmax - 5000, xmin + math.random(xmax - xmin)))
			local y = math.max(ymin + 5000, math.min(ymax - 5000, ymin + math.random(ymax - ymin)))
			set_autopilot_to(x,y)
		end

		search_planets = function() -- {
			if state == "exploding" then
				if is_flying() then
					return
				else
					state = "searching"
				end
			end

			tmpnextplanet = next_planet

			if tmpnextplanet ~= nil and get_player(tmpnextplanet) ~= 0 then
				tmpnextplanet = nil
			end

			neighbour_ships = get_entities(2000, SHIP)
			if #neighbour_ships > 3 then
				state = "exploding"
				next_planet = nil
				random_search()
				return
			end

			if tmpnextplanet ~= nil and get_distance(tmpnextplanet) < 100 then
				if colonize(tmpnextplanet) then
					next_planet = nil
					on_timer_expired = function() end
					return
				else
					tmpnextplanet = nil
				end
			end
			
			local max_dist = 0
			if tmpnextplanet == nil then
				max_dist = 1000000
			else
				max_dist = get_distance(tmpnextplanet)
			end
			for _, v in pairs(get_entities(1000000, PLANET))do
				if get_player(v) == 0 and get_distance(v) < max_dist then
					tmpnextplanet = v
					max_dist = get_distance(v)
				end
			end
			
			if tmpnextplanet ~= next_planet then
				next_planet = tmpnextplanet
				if tmpnextplanet then
					x, y = get_position(next_planet)
					set_autopilot_to(get_position(next_planet))
				else
					autopilot_stop()
				end
				return
			elseif is_flying() then
				return
			else
				if random_search_count > 10 then
					moveto(-100, -100)
					return
				end

				random_search_count = random_search_count + 1

				random_search()
			end
			
		end -- }

		on_autopilot_arrived = search_planets
		on_being_undocked = search_planets

		on_timer_expired = function()
			set_timer(10)
			search_planets()
		end
		set_timer(10)

		on_colonize_complete = function() -- {
			rebuild_slots()

			for i = 1, 6 do
				action.make(SHIP, 3)
				action.transfer(DRIVE, 1, function()
					infect("probe")
				end)
				action.undock()
			end

			action.upgrade(nil, 6)

			action.make(SHIP, 6, function()
				infect("attacker")
			end)
			action.transfer(DRIVE, 2)
			action.transfer(WEAPON, 4)
			action.undock()

			action.upgrade(nil, 24)

			makeship = function()
				action.make(SHIP, 12, function()
					infect("attacker")
				end)
				action.transfer(DRIVE, 6)
				action.transfer(WEAPON, 6)
				action.undock()

				action.make(SHIP, 12)
				action.transfer(DRIVE, 3)
				action.transfer(WEAPON, 9, function()
					infect("guard")
				end)
				action.undock()
				
				action.make(SHIP, 24)
				action.transfer(DRIVE, 12)
				action.transfer(WEAPON, 12, function()
					infect("attacker")
				end)
				action.undock()
				
				action.make(SHIP, 24, function()
					infect("attacker")
				end)
				action.transfer(DRIVE, 12)
				action.transfer(WEAPON, 12)
				action.undock(function()
					makeship()
				end)
			end

			makeship()

			action.run()
		end -- }
	end
		
	roles.guard = function()
		local enemy = nil
	
		local angle = math.random(math.pi * 10) / 10;
		local radius = math.random(10000) + 4000

		
		on_autopilot_arrived = function() -- {
			min_enemy_distance = 100000
			ships = get_entities(100000, SHIP);
			enemy = nil
			for i = 1, #ships do
				if get_player(ships[i]) ~= get_player() then
					if get_distance(ships[i]) < min_enemy_distance then
						min_enemy_distance = get_distance(ships[i])
						enemy = ships[i]
						state = "foundenemy"
					end
				end
			end

			if enemy == nil then
				angle = (angle + math.pi/10) % (2 * math.pi)
				
				local others = get_entities(2000, SHIP + BASE)
				local o = 0
				for i = 1, #others do
					if get_player(others[i]) == get_player() then
						o = o + 1
					else
						o = o - 1
					end
				end
				--print("neighbours: " .. #others)
				
				if o > 3 then
					radius = radius + 200
				elseif o < 2 then
					radius = radius - 200
				end
				
				if radius < 2000 then radius = 2000 end
				
				x = math.max(xmin + 4000, math.min(xmax - 4000, home_x + math.sin(angle) * radius))
				y = math.max(ymin + 4000, math.min(ymax - 4000, home_y + math.cos(angle) * radius))
				set_autopilot_to(x,y)
			else
				set_autopilot_to(get_position(enemy))
				fire(enemy)
			end
				--random_search(30000, true)
		end -- }
		on_being_undocked = on_autopilot_arrived

		on_entity_in_range = function(other)
			if (get_type(other) == SHIP or get_type(other) == BASE)
			   and get_player(other) ~= get_player()
			then
				if enemy == nil
				   or get_distance(enemy) == nil
					 or get_type(enemy) == PLANET
				   or get_distance(enemy) > get_distance(other)
					 or enemy == other
				then
					enemy = other
					local ex, ey = get_position(enemy)
					local mx, my = get_position(self)
					set_autopilot_to((ex + mx) / 2, (ey + my) / 2)
					--autopilot_stop()
					fire(enemy)
				end
			end
		end
		on_weapons_ready = function()
			if not fire(enemy) then
				if get_distance(enemy) ~= nil then
					local ex, ey = get_position(enemy)
					local mx, my = get_position(self)
					set_autopilot_to((ex + mx) / 2, (ey + my) / 2)
				else
					on_autopilot_arrived()
				end
			end
		end
	end

	roles.attacker = function()
		state = "searching"
		local enemy = nil
	
		on_autopilot_arrived = function()
			if state == "searching" then
				enemy = nil
				min_enemy_distance = 100000
				ships = get_entities(100000, SHIP + BASE);
				for i = 1, #ships do
					if get_player(ships[i]) ~= get_player() then
						if get_distance(ships[i]) < min_enemy_distance then
							min_enemy_distance = get_distance(ships[i])
							enemy = ships[i]
							state = "approaching"
						end
					end
				end
				if enemy ~= nil then
					set_autopilot_to(get_position(enemy))
					return
				end
				min_enemy_distance = 1000000
				planets = get_entities(1000000, PLANET);
				for i = 1, #planets do
					if get_player(planets[i]) ~= 0 and get_player(planets[i]) ~= get_player() then
						if get_distance(planets[i]) < min_enemy_distance then
							min_enemy_distance = get_distance(planets[i])
							enemy = planets[i]
							state = "approaching"
						end
					end
				end
				if enemy ~= nil then
					set_autopilot_to(get_position(enemy))
					return
				end
			elseif state == "approaching" then
				if get_distance(enemy) == nil or get_type(enemy) == planet then
					state = "searching"
					on_autopilot_arrived()
				elseif get_distance(enemy) > 400 then
					local ex, ey = get_position(enemy)
					local mx, my = get_position(self)
					set_autopilot_to((ex + mx) / 2, (ey + my) / 2)
				else
					fire(enemy)
				end
			end
		end
		on_being_undocked = on_autopilot_arrived

		on_entity_approaching = function(other)
			if (get_type(other) == SHIP or get_type(other) == BASE)
			   and get_player(other) ~= get_player()
			then
				if enemy == nil
				   or get_distance(enemy) == nil
					 or get_type(enemy) == PLANET
				   or get_distance(enemy) > get_distance(other)
				then
					enemy = other
					set_autopilot_to(get_position(enemy))
				end
			end
		end

		on_entity_in_range = function(other)
			if (get_type(other) == SHIP or get_type(other) == BASE)
			   and get_player(other) ~= get_player()
			then
				if enemy == nil
				   or get_distance(enemy) == nil
					 or get_type(enemy) == PLANET
				   or get_distance(enemy) > get_distance(other)
					 or enemy == other
				then
					enemy = other
					local ex, ey = get_position(enemy)
					local mx, my = get_position(self)
					set_autopilot_to((ex + mx) / 2, (ey + my) / 2)
					--autopilot_stop()
					fire(enemy)
				end
			end
		end
		on_weapons_ready = function()
			if not fire(enemy) then
				if get_distance(enemy) ~= nil then
					local ex, ey = get_position(enemy)
					local mx, my = get_position(self)
					set_autopilot_to((ex + mx) / 2, (ey + my) / 2)
				else
					on_autopilot_arrived()
				end
			end
		end
	end

	roles.crusher = function()
		state = "searching"

		local enemy = nil
	
		on_autopilot_arrived = function()
			if state == "searching" then
				enemy = nil
				min_enemy_distance = 100000
				bases = get_entities(100000, BASE);
				for i = 1, #bases do
					if get_player(bases[i]) ~= get_player() then
						if get_distance(bases[i]) < min_enemy_distance then
							min_enemy_distance = get_distance(bases[i])
							enemy = bases[i]
							state = "approaching"
						end
					end
				end

				if enemy ~= nil then
					local ex, ey = get_position(enemy)
					local mx, my = get_position(self)
					set_autopilot_to((ex + mx) / 2, (ey + my) / 2)
					return
				end

				min_enemy_distance = 1000000
				planets = get_entities(1000000, PLANET);
				for i = 1, #planets do
					if get_player(planets[i]) ~= 0 and get_player(planets[i]) ~= get_player() then
						if get_distance(planets[i]) < min_enemy_distance then
							min_enemy_distance = get_distance(planets[i])
							enemy = planets[i]
							state = "approaching"
						end
					end
				end
				if enemy ~= nil then
					set_autopilot_to(get_position(enemy))
					return
				end
			elseif state == "approaching" then
				if get_distance(enemy) == nil or get_type(enemy) == planet then
					state = "searching"
					on_autopilot_arrived()
				elseif get_distance(enemy) > 400 then
					local ex, ey = get_position(enemy)
					local mx, my = get_position(self)
					set_autopilot_to((ex + mx) / 2, (ey + my) / 2)
				else
					fire(enemy)
				end
			end
		end
		on_being_undocked = on_autopilot_arrived

		on_entity_approaching = function(other)
			if get_player(other) ~= get_player() then
				if get_type(other) == BASE
				   and get_distance(enemy) > get_distance(other)
				then
					enemy = other
					local ex, ey = get_position(enemy)
					local mx, my = get_position(self)
					set_autopilot_to((ex + mx) / 2, (ey + my) / 2)
				end
			end
		end

		on_entity_in_range = function(other)
			if not fire(enemy) then
				if get_player(other) ~= get_player() then
					fire(other)
				end
			end
			if get_type(other) == BASE and get_player(other) ~= get_player()
			then
				if enemy == nil
				   or get_distance(enemy) == nil
					 or get_type(enemy) == PLANET
				   or get_distance(enemy) > get_distance(other)
					 or enemy == other
				then
					enemy = other
					local ex, ey = get_position(enemy)
					local mx, my = get_position(self)
					set_autopilot_to((ex + mx) / 2, (ey + my) / 2)
					--autopilot_stop()
					fire(enemy)
				end
			end
		end
		on_weapons_ready = function()
			if not fire(enemy) then
				if get_distance(enemy) ~= nil then
					local ex, ey = get_position(enemy)
					local mx, my = get_position(self)
					set_autopilot_to((ex + mx) / 2, (ey + my) / 2)
				else
					on_autopilot_arrived()
				end
			end
		end
	end

-- -------------------------------------------------------------------------- --
-- INITIALIZATION
-- -------------------------------------------------------------------------- --

	if get_type(self) == BASE and get_docking_partner() ~= nil then
		print("Getting rid of dead weight.")
		infect("probe")
		action.transfer(DRIVE, 1)
		action.undock(function()
			roles[role]()
		end)
		action.run()
	else
		roles[role]()

		action.run()
	end

end

home_x, home_y = get_position(self)

morwenna('home', home_x, home_y)

-- .quit
