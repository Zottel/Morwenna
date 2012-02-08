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
	
	-- Reproduction
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
		all_slots = get_slots()
		slots = {[EMPTY] = {},
		         [ORE] = {},
						 [DRIVE] = {},
						 [WEAPON] = {}}
		for i = 1, #all_slots do
			if all_slots[i] == ORE then
				slots[ORE][i] = i
			elseif all_slots[i] == DRIVE then
				slots[DRIVE][i] = i
			elseif all_slots[i] == WEAPON then
				slots[WEAPON][i] = i
			elseif all_slots[i] == EMPTY then
				slots[EMPTY][i] = i
			end
		end
	end

	rebuild_slots()

-- -------------------------------------------------------------------------- --
--    ACTION QUEUE                                                            --
-- -------------------------------------------------------------------------- --

	local action = {}

	-- Callback to be handled once some action is finished
	action.onFinished = nil

	-- Create two queues - combat actions are supposed to have a higher priority.
	action.queue = {}
	action.combatqueue = {}

	action.insert = function(item)
		if item.type == "fire" then
			table.insert(action.combatqueue, 1, item)
		else
			table.insert(action.queue, 1, item)
		end
	end

	action.append = function(item)
		if item.type == "fire" then
			table.insert(action.combatqueue, item)
		else
			table.insert(action.queue, item)
		end
	end

	-- Remove first element from queues and return it.
	-- This is where the priorization combatqueue>queue happens
	action.pop = function()
		if action.combatqueue[1] == nil then
			if action.queue[1] == nil then
				return nil
			else
				local item = action.queue[1]
				table.remove(action.queue, 1)
				return item
			end
		else
			local item = action.combatqueue[1]
			table.remove(action.combatqueue, 1)
			return item
		end
	end

	action.make = function(type, quantity, callback)
		action.append{action = "make", type = type, quantity = quantity, callback = callback}
	end

	action.transfer = function(type, quantity, callback)
		action.append{action = "transfer", quantity = quantity, type = type, callback = callback}
	end

	action.upgrade = function(callback, quantity)
		action.append{action = "upgrade", type = type, quantity = quantity, callback = callback}
	end

	action.undock = function(callback)
		action.append{action = "undock", callback = callback}
	end

	action.fire = function(callback, target, repeat_mode)
		action.append{action = "fire", target = target, callback = callback, repeat_mode = repeat_mode}
	end

	-- Main action queue dispatcher
	action.run = function()

		-- When the ship/base is busy there is nothing to do now
		if is_busy() then
			print("action.run() was called while busy!")
			dump_busy()
			return
		end

		-- If an onFinished handler was registered, remove and call it
		if action.onFinished then
			local onFinished = action.onFinished
			action.onFinished = nil
			onFinished()
		end
		
		local item = action.pop()

		if item then
			if action.handlers[item.action] then
				action.handlers[item.action](item)
			else
				print("unknown action: '" .. item.action .."'")
				action.run()
				return
			end
		end
	end

	-- ACTION HANDLERS
	action.handlers = {}

	-- fire(item):
	-- Makes one shot at the specified target.
	--
	-- item members:
	--   target:   target entity
	--   repeat_mode:   ("after"|"before"|nil)
	--   callback
	action.handlers.fire = function(item)
		if not fire(item.target) then
			-- Target must be out of sight or destroyed - move to next task
			action.run()
			return
		else
			action.onFinished = item.callback
			
			if item["repeat_mode"] == "after" then
				action.append(item)
			elseif item["repeat_mode"] == "before" then
				action.insert(item)
			end
		end
	end

	-- make(item):
	-- TODO
	-- item members:
	--   quantity
	--   type:         (ORE|DRIVE|WEAPON|SHIP)
	--   callback
	--   required_for: item
	action.handlers.make = function(item)
		-- Are there enough slots to fill with what we're making?
		if item.quantity > count(all_slots) then
			-- Nope - gotta upgrade teh base
			-- requeue item
			action.insert(item)
			-- and insert the required ore production before
			action.insert({action = "upgrade",
										 quantity = item.quantity,
										 required_for = item})
			action.run()
			return
		end

		-- Look for specific make handler and call it
		if action.handlers.make_stage2[item.type] then
			action.handlers.make_stage2[item.type](item)
		else
			print("no handler for making" .. item.type)
			action.run()
		end
	end

	action.handlers.make_stage2 = {}

	action.handlers.make_stage2[SHIP] = function(item)
		-- is there enough ore?
		if count(slots[ORE]) >= item.quantity then
			-- yup - build an array containing the ore slots we use.
			local build_slots = {}
			local n = item.quantity

			for _, v in pairs(slots[ORE]) do
				if n > 0 then
					table.insert(build_slots, v)
					n = n - 1
				end
			end

			if build_ship(build_slots) == nil then
				print("error: could not build_ship")
				action.run()
				return
			else
				-- keep lists of slots updated
				for _, v in pairs(build_slots) do
					slots[ORE][v] = nil
					slots[EMPTY][v] = v
				end
				action.onFinished = item.callback
			end
			
		else
			-- not enough ore - gotta re-insert our task…
			action.insert(item)
			-- …and insert the required ore production before
			action.insert({action = "make",
			               type=ORE,
			               quantity = item.quantity,
			               required_for = item})
			action.run()
		end
	end

	action.handlers.make_stage2[ORE] = function(item)
		-- Are there empty slots left?
		if count(slots[EMPTY]) > 0 then
			-- Produce one ore
			local ore_slot = mine()
			if not ore_slot then
				print("could not mine!")
				action.run()
				return
			end

			-- Maintain slot lists
			slots[EMPTY][ore_slot] = nil
			slots[ORE][ore_slot] = ore_slot
		else
			local takefrompossible = {}

			if item.required_for and item.required_for.type == DRIVE then
				table.insert(takefrompossible, slots[DRIVE])
			elseif item.required_for and item.required_for.type == WEAPON then
				table.insert(takefrompossible, slots[WEAPON])
			else
				table.insert(takefrompossible, slots[WEAPON])
				table.insert(takefrompossible, slots[DRIVE])
			end

			local takefrom = nil
			local takefromslot = nil

			for _, from in pairs(takefrompossible) do
				if count(from) >= 1 then
					takefrom = from
					takefromslot = table.maxn(from)
				end
			end

			if takefromslot and manufacture(takefromslot, ORE) then
				takefrom[takefromslot] = nil
				slots[ORE][takefromslot] = takefromslot
			else
				print("could not manufacture ore! (ore: " .. count(slots[ORE]) .. ", drives: " .. count(slots[DRIVE]) .. ", weapons: " .. count(slots[WEAPON]) .. ")")
				if item.required_for and item.required_for.type == DRIVE then
					print("required for drive")
				elseif item.required_for and item.required_for.type == WEAPON then
					print("required for weapon")
				end
				action.run()
				return
			end
		end
		
		-- Repeat until the required quantity is produced
		if item.quantity < count(slots[ORE]) then
			action.insert(item)
		else
			action.onFinished = item.callback
		end
	end

	action.handlers.make_stage2[DRIVE] = function(item)
		if count(slots[ORE]) >= item.quantity then
			local convert_slot = table.maxn(slots[ORE])
			if manufacture(convert_slot, DRIVE) ~= nil then
				slots[ORE][convert_slot] = nil
				slots[DRIVE][convert_slot] = convert_slot
				if item.quantity >= count(slots[DRIVE]) then
					action.onFinished = item.callback
				else
					action.insert(item)
				end
			else
				print("could not manufacture drive")
				action.run()
				return
			end
		else
			-- requeue item
			action.insert(item)
			-- and insert the required ore production before
			action.insert({action = "make",
			               type=ORE,
			               quantity = item.quantity,
			               required_for = item})
			action.run()
		end
	end

	action.handlers.make_stage2[WEAPON] = function(item)
		if count(slots[ORE]) >= item.quantity then
			local convert_slot = table.maxn(slots[ORE])
			if manufacture(convert_slot, WEAPON) ~= nil then
				slots[ORE][convert_slot] = nil
				slots[WEAPON][convert_slot] = convert_slot
				if item.quantity >= count(slots[WEAPON]) then
					action.onFinished = item.callback
				else
					action.insert(item)
				end
			else
				print("could not manufacture weapon") 
				action.run()
				return
			end
		else
			-- requeue item
			action.insert(item)
			-- and insert the required ore production before
			action.insert({action = "make",
			               type=ORE,
			               quantity = item.quantity,
			               required_for = item})
			action.run()
		end
	end
	
	-- transfer(item):
	-- Transfers slot content from current ship/base to docking partner
	-- item members:
	--   quantity
	--   type:   (ORE|DRIVE|WEAPON)
	--   callback
	action.handlers.transfer = function(item)
		local partner = get_docking_partner()
		if not partner then
			print("NO DOCKING PARTNER!")
			action.run()
			return
		end
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
			action.run()
			return
		end

		if not slots[item.type] then
			print("Wrong slot type")
			action.run()
			return
		end

		if count(slots[item.type]) > 0 then
			local_slot = table.maxn(slots[item.type])

			if not transfer_slot(local_slot, remote_slot) then
				print("could not transfer slot!")
				action.run()
				return
			end

			slots[item.type][local_slot] = nil
			slots[EMPTY][local_slot] = local_slot

			item.quantity = item.quantity - 1
			
			if item.quantity <= 0 then
				action.onFinished = item.callback
			else
				action.insert(item)
			end

		else
			action.insert(item)
			action.insert({action = "make",
			               type=item.type,
			               quantity = 1})
			action.run()
		end
	end

	-- upgrade(item):
	-- Upgrades base to slot size specified by quantity
	-- item members:
	--   quantity
	--   callback
	action.handlers.upgrade = function(item)
		if #all_slots < item.quantity then
			if count(slots[ORE]) == #all_slots then
				if upgrade_base() then
					dump_slots()
					rebuild_slots()
					if #all_slots <= item.quantity then
						action.onFinished = item.callback
					else
						action.insert(item)
					end
				else
					print("could not upgrade!")
					action.run()
					return
				end
			else
				action.insert(item)
				action.insert({action = "make",
				               type = ORE,
				               quantity = #all_slots})
				action.run()
			end
		else
			-- Nothing to do here
			action.run()
		end
	end
	
	-- Undocks from docking partner
	--
	-- item members:
	--   callback
	action.handlers.undock = function(item)
		if undock() then
			action.onFinished = item.callback
		else
			print("could not undock!")
			action.run()
			return
		end
	end
	
	-- Register action.run for all relevant event handlers
	-- TODO: Look for missing handlers
	on_weapons_ready = action.run
	on_undocking_complete = action.run
	on_transfer_complete = action.run
	on_build_complete = action.run
	on_mining_complete = action.run
	on_manufacture_complete = action.run
	on_colonize_complete = action.run
	on_upgrade_complete = action.run

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
					on_timer_expired = action.run
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

			if not is_busy() then
				action.run()
			end
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

	-- Get rid of docked ship built by previous AI version
	if get_type(self) == BASE and get_docking_partner() ~= nil then
		-- TODO: wait for base to stop being busy with previous actions
		--       register handlers
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
