z0ttel = function(role, home_x, home_y)
	math.randomseed(get_timestep())
	if role == "home" then home_x, home_y = get_position(self) end
	
	local xmin, xmax, ymin, ymax = get_world_size()
		
	print("Hello world! I am a " .. role .. ", home at " .. home_x .. "/" .. home_y)
	
	-- Fortpflanzung
	receiver = function() --print("receiver running")
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
	
	infect = function(role)
		send_data(receiver)
		send_data(z0ttel)
		send_data(role)
		send_data(home_x) send_data(home_y)
	end
	
	function random_search(divergence, limit)
		state = "searching"
		
		local curr_x, curr_y = get_position(self)
		local x = 0
		local y = 0
		
		if limit == true then
			x = math.max(xmin + 4000, math.min(xmax - 4000, home_x + math.random(divergence) - (divergence / 2)))
			y = math.max(ymin + 4000, math.min(ymax - 4000, home_y + math.random(divergence) - (divergence / 2)))
		else
			x = math.max(xmin + 4000, math.min(xmax - 4000, curr_x + math.random(divergence) - (divergence / 2)))
			y = math.max(ymin + 4000, math.min(ymax - 4000, curr_y + math.random(divergence) - (divergence / 2)))
		end
		set_autopilot_to(x,y)
	end

	
	roles = {}
	
	-- HOME
	roles.home = function()
		local nextchildrole = "seed"
		local ores = {}
		local drives = {}
		local weapons = {}
		local to_child_transfer = {}
		local child_next_slot = 1
		
		on_incoming_data = function() end

		on_build_complete = function(newship)
			infect(nextchildrole)
			local drive = drives[1]
			table.remove(drives, 1)
			table.insert(to_child_transfer, 1, drive)
			local drive = drives[1]
			table.remove(drives, 1)
			table.insert(to_child_transfer, 1, drive)
			local drive = drives[1]
			table.remove(drives, 1)
			table.insert(to_child_transfer, 1, drive)
			on_transfer_complete()
		end
		
		on_mining_complete = function()
			-- Initialize slot tracking
			drives = {} weapons = {} ores = {}
			local s = get_slots()
			for i = 1, #s do
				if s[i] == DRIVE then
					table.insert(drives, 1, i)
				elseif s[i] == WEAPON then
					table.insert(weapons, 1, i)
				elseif s[i] == ORE then
					table.insert(ores, 1, i)
				end
			end
			if #ores > 2 then
				if #drives < 3 then
					local newdrive = manufacture(ores[1], DRIVE)
					if newdrive then
						table.insert(drives, 1, newdrive)
						table.remove(ores, 1)
					else
						print("error while manufacturing drive")
					end
				elseif #weapons < 2 then
					local newweapon = manufacture(ores[1], WEAPON)
					if newweapon then
						table.insert(weapons, 1, newweapon)
						table.remove(ores, 1)
					else
						print("error while manufacturing weapon")
					end
				else
					if(build_ship(ores[1], ores[2], ores[3])) then
						table.remove(ores, 3) table.remove(ores, 2) table.remove(ores, 1)
					else
						print("error while building ship")
					end
				end
			else
				local newore = mine()
				if newore then
					table.insert(ores, 1, newore)
				else
					print("error while mining ore")
				end
			end
		end
		
		on_manufacture_complete = function()
			on_mining_complete()
		end
		on_undocking_complete = function()
			on_mining_complete()
		end
		on_transfer_complete = function()
			if #to_child_transfer > 0 then
				local to_transfer = to_child_transfer[1]
				if transfer_slot(to_transfer, child_next_slot) then
					child_next_slot = child_next_slot + 1
					table.remove(to_child_transfer, 1)
				else
					print("error: could not transfer something.")
				end
			else
				child_next_slot = 1
				undock()
				on_mining_complete()
			end
		end
		
		-- Initialize slot tracking
		local s = get_slots()
		for i = 1, #s do
			if s[i] == DRIVE then
				table.insert(drives, 1, i)
			elseif s[i] == WEAPON then
				table.insert(weapons, 1, i)
			elseif s[i] == ORE then
				table.insert(ores, 1, i)
			end
		end
		
		-- Start working
		on_mining_complete()
	end
	
	roles.seed = function()
		local state = "searching"
		local planet_to_check = nil
		
		local angle = math.random(math.pi * 10) / 5;
		local radius = math.random(4000) + 1000
		local anglegrowth = (math.random(math.pi * 100) - (50 * math.pi)) / 1000;
		local radiusgrowth = 300
		
		on_autopilot_arrived = function()
			if state == "searching" then
				local target = find_closest(2000, PLANET)
				local nextbase = find_closest(2000, BASE)
				if nextbase ~= nil and target ~= nil and get_position(target) == get_position(nextbase) then
					target = nil
				end
				
				if target == nil then
					angle = (angle + anglegrowth) % (2 * math.pi)
			
					radius = radius + radiusgrowth
					
					if radiusgrowth > 0 and radius > (xmax - xmin) and radius > (ymax - ymin) then
						radiusgrowth = 0 - radiusgrowth
					elseif radiusgrowth < 0 and radius < 5000 then
						radiusgrowth = 0 - radiusgrowth
					end
					
					if radius < 3000 then radius = 3000 end
					
					
					x = home_x + math.sin(angle) * radius
					y = home_y + math.cos(angle) * radius
					
					if x > (xmax - 4000) then
						home_x = home_x - 10000
						on_autopilot_arrived()
						return
					end
					
					if x < (xmin + 4000) then
						home_x = home_x + 10000
						on_autopilot_arrived()
						return
					end
					
					if y > (ymax - 4000) then
						home_y = home_y - 10000
						on_autopilot_arrived()
						return
					end
					
					if y < (ymin + 4000) then
						home_y = home_y + 10000
						on_autopilot_arrived()
						return
					end
					
					
					set_autopilot_to(x,y)
				else
					set_autopilot_to(get_position(target))
					planet_to_check = target
					state = "checkplanet"
				end
			elseif state == "checkplanet" then
				if colonize(planet_to_check) == nil then
					state = "searching"
					on_autopilot_arrived()
					return
				end
			end
		end
		on_being_undocked = on_autopilot_arrived
		
		local grow = function()
			local full = true
			local s = get_slots()
			for i = 1, #s do
				if s[i] == DRIVE or s[i] == WEAPON then
					manufacture(i, ORE)
					return
				elseif s[i] ~= ORE then
					mine()
					return
				end
			end
			
			if #s < 24 then
				upgrade_base()
			else
				local all_slots = {}
				for i = 1, #s do
					all_slots[i] = i
				end
				if build_ship(all_slots) then
				
				else
					print("error while building ship")
				end
			end
		end
		
		on_colonize_complete = grow
		on_upgrade_complete = grow
		on_manufacture_complete = grow
		on_mining_complete = grow
		on_build_complete = function()
			infect("guard")
			local ore = mine()
			local has = 0
			on_mining_complete = function()
				manufacture(ore, DRIVE)
				on_manufacture_complete = function()
					transfer_slot(ore, has + 1)
					on_transfer_complete = function()
						has = has + 1
						if has == 24 then
						undock()
						on_mining_complete = grow
						on_manufacture_complete = grow
						else
							ore = mine()
						end
					end
				end
			end

		end
	end
	
	roles.guard = function()
		local enemy = nil
	
		local angle = math.random(math.pi * 10) / 10;
		local radius = math.random(10000) + 4000

		
		on_autopilot_arrived = function()
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
				
				local others = get_entities(4000, SHIP)
				local o = 0
				for i = 1, #others do
					if get_player(others[i]) == get_player() then
						o = o + 1
					else
						o = o - 1
					end
				end
				--print("neighbours: " .. #others)
				
				if o > 4 then
					radius = radius + 200
				elseif o < 2 then
					radius = radius - 200
				end
				
				if radius < 3000 then radius = 3000 end
				
				x = math.max(xmin + 4000, math.min(xmax - 4000, home_x + math.sin(angle) * radius))
				y = math.max(ymin + 4000, math.min(ymax - 4000, home_y + math.cos(angle) * radius))
				set_autopilot_to(x,y)
			else
				set_autopilot_to(get_position(enemy))
			end
				--random_search(30000, true)
		end
		on_being_undocked = on_autopilot_arrived
	end
	
	roles.miner = function()
		
	end
	
	roles[role]()
	
	on_homebase_killed = function()
		if role ~= "home" then
			killself()
		end
	end
end

z0ttel('home')

-- .quit
