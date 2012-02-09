z0ttel = function(whatami, generation)
	if generation == nil then generation = 0 end
	
	local state = "init"
	print("I AM ALIVE: " .. generation)
	
	-- Fortpflanzung
	seed = function()
		print("seed running")
		on_incoming_data = function(data)
			print("receiving z0ttel")
			z0ttel = loadstring(data);
			on_incoming_data = function(data)
				print("receiving generation")
				z0ttel('slave', data + 1)
			end
		end
	end
	infect = function()
		print("infecting")
		send_data(seed)
		send_data(z0ttel)
		send_data(generation)
	end
	
	function random_search()
		state = "searching"
		
		divergence = 15000
		
		local xmin, xmax, ymin, ymax = get_world_size()
		local curr_x, curr_y = get_position(self)
		
		local x = math.max(xmin + 1000, math.min(xmax - 1000, curr_x + math.random(divergence) - (divergence / 2)))
		local y = math.max(ymin + 1000, math.min(ymax - 1000, curr_y + math.random(divergence) - (divergence / 2)))
		set_autopilot_to(x,y)
	end
	
	on_incoming_data = function(data)
		infect()
	end
	
	-- Called when your autopilot arrives at it's destination.
	-- entity argument: self
	on_autopilot_arrived = function(self)
		if generation > 2 then random_search() return end
		if state == "searching" then
			local target=find_closest(2000, PLANET)
			if target == nil
			then
				print("No planet -.-")
				random_search()
			else
				print("found planet")
				set_autopilot_to(get_position(target))
				planet_to_check = target
				state = "checkplanet"
			end
		elseif state == "checkplanet" then
			print("arrived at planet")
			if colonize(planet_to_check) == nil then
				print("colonize: noes!")
				random_search()
			else
				print("colonize: hai!")
			end
		end
	end


	-- Called when a ship or base enters your scanner radius
	-- entity argument: the other entity
	on_entity_approaching = function(other)
		if type(self) == SHIP and get_player(other) ~= get_player() then
			set_autopilot_to(get_position(other))
			state = "going for enemy"
		end
	end


	-- Called when a ship or base enters your weapons range
	-- entity argument: the other entity.
	on_entity_in_range = function(other)
		if get_player(other) ~= get_player() then
			print("enemy in range!")
			enemy = other
			fire(other)
			autopilot_stop()
			state = "combat"
		end
	end


	-- Called when someone shoots at you.
	-- entity argument: the shooter
	on_shot_at = function(shooter)
		print("being shot at!")
		fire(shooter)
		enemy = shooter
	end


	-- After firing weapons, this callback is invoked as soon as your weapons are ready to fire again
	-- entity_argument: false
	on_weapons_ready = function()
		if get_distance(enemy) ~= nil and get_distance(enemy) < 500 then
			print("enemy still in range!")
			fire(enemy)
		else
			print("lost enemy!")
			random_search()
		end
	end


	-- Called when you are docked by another entity
	-- entity argument: the new docking partner
	on_being_docked = function(partner) end


	-- Called when a docking operation you initiated has completed
	-- entity argument: the new docking partner
	on_docking_complete = function(partner) end


	-- Called when your docking partner initiated undocking.
	-- entity argument: your former dockung partner
	on_being_undocked = function(partner)
		print("being undocked")
		if state == "init" then
			random_search()
		end
	end
	
	on_undocking_complete = function(other)
		if state == "builddrives" then
			state = "buildship"
			mine()
		end
	end


	-- Called when a slot-transfer between you and your docking partner completes.
	-- entity argument: self
	on_transfer_complete = function(self)
		local s = get_slots()
		for i = 1, #s do
			if s[i] == DRIVE  or s[i] == WEAPON then
				transfer_slot(i, i)
				return
			end
		end
		print("transfer complete")
		undock()
	end


	-- Called when a ship has been successfully built, and is now attached to you.
	-- entity argument: The new ship
	on_build_complete = function(newship)
		print("build complete")
		infect()
		state = "builddrives"
		mine()
	end


	-- Called when a timer, previously set by set_timer(), expires.
	-- entity argument: self
	on_timer_expired = function(self) end


	-- By now you should really be able to infer the meaning from the name.
	-- entity argument: self
	on_mining_complete = function(self)
		if state == "init" then
			local all_ore = true;
			local s = get_slots()
			for i = 1, #s do
				if s[i] ~= ORE then
					all_ore = false
				end
			end
			if all_ore then
				print("Haz all teh ore!")
				upgrade_base()
			else
				mine()
			end
		elseif state == "buildship" then
			local all_ore = true;
			local s = get_slots()
			for i = 1, #s do
				if s[i] ~= ORE then
					all_ore = false
				end
			end
			if all_ore then
				print("Haz all teh ore!")
				local slots = {}
				for i = 1, #s do
					slots[i] = i
				end
				build_ship(slots)
			else
				mine()
			end
		elseif state == "builddrives" then
			local all_ore = true;
			local s = get_slots()
			for i = 1, #s do
				if s[i] ~= ORE then
					all_ore = false
				end
			end
			if all_ore then
				print("Haz all teh ore!")
				manufacture(1, WEAPON) -- one weapon - rest will be drives
			else
				mine()
			end
		end
	end

	-- Once a manufacture action completes, this is called.
	-- entity argument: self
	on_manufacture_complete = function(self)
		if state == "init" then
			local s = get_slots()
			for i = 1, #s do
				if s[i] == DRIVE or s[i] == WEAPON then
					manufacture(i, ORE)
					return
				end
			end
			print("convert drives back to ore finished")
			local slots = {}
			for i = 1, #s do
				slots[i] = i
			end
			build_ship(slots)
		elseif state == "builddrives" then
			local s = get_slots()
			for i = 1, #s do
				if s[i] ~= DRIVE and s[i] ~= WEAPON then
					if i < 6 then
						manufacture(i, DRIVE)
					else
						manufacture(i, WEAPON)
					end
					return
				end
			end
			print("manufacture complete")
			transfer_slot(1, 1)
		end
	end

	-- called once the colonize process is complete. Congratulation, you are now a base.
	-- entity argument: self
	on_colonize_complete = function(self)
		print("I am a colony now!")
		state = "init"
		manufacture(1, ORE)
	end

	-- called upon completion of upgrade_base()
	-- entity argument: self
	on_upgrade_complete = function(self)
		print("Haz teh upgrade!")
		state = "buildship"
		mine()
	end


	-- This callback is invoked in your homebase after it has been killed by an enemy. When you recieve this callback, you are already in your new base, with a fresh lua state from scratch.
	-- entity argument: self
	on_homebase_killed = function(self)
		print("*********************************************************")
		print("NOES!")
		print("*********************************************************")
	end
	
	-- start doing something:
	if whatami == "master" then state = "buildship" mine() end

end

z0ttel('master')

-- .quit
