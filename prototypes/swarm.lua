z0ttel = function(role, home_x, home_y)
	-- API STUFF
	count = function(a) local n = 0 for _, v in pairs(a) do n = n + 1 end return n end
	math.randomseed(get_timestep())

	-- Environment_variables
	local xmin, xmax, ymin, ymax = get_world_size()

	-- Hello world
	print("Hello world! I am a " .. role .. ", home at " .. home_x .. "/" .. home_y)
	
	-- Fortpflanzung
	function receiver() --print("receiver running")
		on_incoming_data = function(data) --print("receiving z0ttel")
			z0ttel = loadstring(data);
			on_incoming_data = function(data) --print("receiving role")
				local role = data
				on_incoming_data = function(data) --print("receiving home x")
					local home_x = data
					on_incoming_data = function(data) --print("receiving home y")
						local home_y = data
						z0ttel(role, home_x, home_y)
					end
				end
			end
		end
	end
	
	function infect(role)
		send_data(receiver)
		send_data(z0ttel)
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

	action.run = function()
		if action.queue[1] == nil then return end
		--if action.queue[1].quantity == nil then
		--	print(role .. ": action: " .. action.queue[1].action)
		--else
		--	print(role .. ": action: " .. action.queue[1].action .. "(" .. action.queue[1].quantity .. ")")
		--end
		if action.queue[1].action == "make" then
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




	roles = {}
	roles.home = function()
		--action.upgrade(nil, 24)
		action.make(SHIP, 3)
		action.transfer(DRIVE, 1, function()
			infect("probe")
		end)
		action.undock()

		function makeship()
			action.make(SHIP, 3)
			action.transfer(DRIVE, 1, function()
				infect("probe")
			end)
			action.undock(function()
				makeship()
			end)
		end

		makeship()
	end

	roles.probe = function()
		function attraction(dist, entity)
			if get_type(entity) == PLANET and get_player(entity) == 0 then
				return 1
			else
				return 0 - ((5000 - dist) / 20000)
			end
		end

		function swarm_move()
			local curr_x, curr_y = get_position(self)
			
			-- attraction vector
			local att_x = 0
			local att_y = 0
			
			-- iterate through entities in range
			for _, v in pairs(get_entities(5000, SHIP + PLANET + BASE + ASTEROID)) do
				
				-- If we're close to a free planet - try to colonize
				if get_type(v) == PLANET and get_player(v) == 0 and get_distance(v) <= 100 then
						if colonize(v) then
							print("new colony!")
						else
							print("Could not colonize!")
						end
				end

				local v_x, v_y = get_position(v)
				local rel_x = v_x - curr_x
				local rel_y = v_y - curr_y
				local distance = get_distance(v)
				local att_x_v, att_y_v
				-- sqrt(300 * 300 * 2) is the default attraction vector length
				-- -> attraction 1 results in a attraction vector of that length
				if math.abs(distance) > 1 then
					att_x_v = (rel_x / distance) * 3000 * attraction(distance, v)
					att_y_v = (rel_y / distance) * 3000 * attraction(distance, v)
				else
					att_x_v = math.random(6000) - 3000
					att_y_v = math.random(6000) - 3000
				end
				
				-- add attraction vector of entity to general attraction vector
				att_x = att_x + att_x_v
				att_y = att_y + att_y_v
			end
			
			moveto(curr_x + att_x, curr_y + att_y)
		end

		on_timer_expired = function()
			set_timer(20)
			swarm_move()
		end
		on_autopilot_arrived = swarm_move
		on_being_undocked = on_timer_expired

		on_colonize_complete = function() -- {
			on_timer_expired = function() end
			rebuild_slots()

			makeship = function()
				action.make(SHIP, 3, function()
					infect("probe")
				end)
				action.transfer(DRIVE, 1)
				action.undock(function()
					makeship()
				end)
			end

			makeship()

			action.run()
		end -- }
	end
	
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

z0ttel('home', home_x, home_y)

-- .quit
