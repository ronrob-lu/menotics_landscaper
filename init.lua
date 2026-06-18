-- menotics_landscaper/init.lua
-- Author: ronrob-lu
-- License: MIT

local S = minetest.get_translator and minetest.get_translator("menotics_landscaper") or function(s) return s end

-- Node Fallbacks mapping (checks which node exists first)
local function find_existing_node(nodenames)
    for _, name in ipairs(nodenames) do
        if minetest.registered_nodes[name] then
            return name
        end
    end
    return nil
end

local fallback_top_nodes = {"default:dirt_with_grass", "mcl_core:dirt_with_grass", "mapgen_dirt_with_grass"}
local fallback_filler_nodes = {"default:dirt", "mcl_core:dirt", "mapgen_dirt"}
local fallback_stone_nodes = {"default:stone", "mcl_core:stone", "mapgen_stone"}
local fallback_trunk_nodes = {"default:tree", "mcl_core:tree", "mapgen_tree"}
local fallback_leaves_nodes = {"default:leaves", "mcl_core:leaves", "mapgen_leaves"}

local default_node_top = find_existing_node(fallback_top_nodes) or "mapgen_dirt_with_grass"
local default_node_filler = find_existing_node(fallback_filler_nodes) or "mapgen_dirt"
local default_node_stone = find_existing_node(fallback_stone_nodes) or "mapgen_stone"
local default_trunk = find_existing_node(fallback_trunk_nodes) or "mapgen_tree"
local default_leaves = find_existing_node(fallback_leaves_nodes) or "mapgen_leaves"

local function verify_node(nodename, fallback)
    if minetest.registered_nodes[nodename] then
        return nodename
    end
    return fallback
end

-- Helper to check if a node is a thin dust layer (like snow cover) or non-ground decor
local function is_dust_or_decor(nodename)
    if nodename == "air" or nodename == "ignore" then
        return true
    end
    -- Ignore thin snow cover (but keep solid snow blocks)
    if nodename:find("snow") and not nodename:find("snowblock") and not nodename:find("snow_block") then
        return true
    end
    -- Ignore typical decorative/vegetation nodes that shouldn't define the ground level
    local grp_attached = minetest.get_item_group(nodename, "attached_node")
    local grp_flora = minetest.get_item_group(nodename, "flora")
    local grp_plant = minetest.get_item_group(nodename, "plant")
    if grp_attached > 0 or grp_flora > 0 or grp_plant > 0 then
        return true
    end
    return false
end

-- Helper to check if a node can be replaced by block placement
local function is_replaceable(nodename)
    if not nodename or nodename == "air" or nodename == "ignore" then
        return true
    end
    local def = minetest.registered_nodes[nodename]
    if def and def.buildable_to then
        return true
    end
    -- Explicitly allow replacing thin snow cover
    if nodename:find("snow") and not nodename:find("snowblock") and not nodename:find("snow_block") then
        return true
    end
    return false
end

-- Find the highest walkable solid block directly below a coordinate
local function find_ground_level(pos, spawn_y)
    local start_y = spawn_y + 40
    local end_y = spawn_y - 40
    
    for y = start_y, end_y, -1 do
        local check_pos = {x = pos.x, y = y, z = pos.z}
        local node = minetest.get_node_or_nil(check_pos)
        if node and node.name ~= "air" and node.name ~= "ignore" then
            local def = minetest.registered_nodes[node.name]
            if def and def.walkable and not is_dust_or_decor(node.name) then
                return y
            end
        end
    end
    return spawn_y -- Fallback
end

-- Get a new flying target position within a 50-block radius
local function get_new_target(self)
    local rx = math.random(-50, 50)
    local rz = math.random(-50, 50)
    local target_x = self.spawn_pos.x + rx
    local target_z = self.spawn_pos.z + rz
    
    -- Find ground level at target coordinates
    local ground_y = find_ground_level({x = target_x, y = self.spawn_pos.y, z = target_z}, self.spawn_pos.y)
    local target_y = ground_y + math.random(5, 12) -- Fly 5 to 12 blocks above ground
    
    return {x = target_x, y = target_y, z = target_z}
end

-- Resolve biome materials and decorations
local function get_biome_materials(pos)
    local biome_data = minetest.get_biome_data(pos)
    local biome_name = biome_data and minetest.get_biome_name(biome_data.biome)
    
    local node_top = default_node_top
    local node_filler = default_node_filler
    local node_stone = default_node_stone
    local trunk = default_trunk
    local leaves = default_leaves
    local decos = {}
    local trees = {}

    if biome_name and minetest.registered_biomes[biome_name] then
        local def = minetest.registered_biomes[biome_name]
        node_top = def.node_top or node_top
        node_filler = def.node_filler or node_filler
        node_stone = def.node_stone or node_stone
        
        -- Resolve tree materials based on biome name
        local name_lower = biome_name:lower()
        if name_lower:find("desert") or name_lower:find("sand") then
            trunk = "default:cactus"
            leaves = "air"
        elseif name_lower:find("conifer") or name_lower:find("pine") or name_lower:find("taiga") or name_lower:find("tundra") then
            trunk = "default:pine_tree"
            leaves = "default:pine_needles"
        elseif name_lower:find("savanna") or name_lower:find("acacia") then
            trunk = "default:acacia_tree"
            leaves = "default:acacia_leaves"
        elseif name_lower:find("jungle") or name_lower:find("rainforest") then
            trunk = "default:jungle_tree"
            leaves = "default:jungleleaves"
        elseif name_lower:find("aspen") or name_lower:find("birch") then
            trunk = "default:aspen_tree"
            leaves = "default:aspen_leaves"
        end

        -- Scan registered decorations for this biome
        if minetest.registered_decorations then
            for _, deco in pairs(minetest.registered_decorations) do
                local matches = false
                if deco.biomes then
                    if type(deco.biomes) == "string" then
                        matches = (deco.biomes == biome_name)
                    elseif type(deco.biomes) == "table" then
                        for _, b in ipairs(deco.biomes) do
                            if b == biome_name then
                                matches = true
                                break
                            end
                        end
                    end
                end
                if matches then
                    if deco.deco_type == "schematic" then
                        table.insert(trees, deco)
                    elseif deco.deco_type == "simple" then
                        table.insert(decos, deco)
                    end
                end
            end
        end
    end

    -- Verify that the resolved nodes exist in the game
    local function check_node(nodename, fallback)
        if minetest.registered_nodes[nodename] then
            return nodename
        end
        return fallback
    end

    node_top = check_node(node_top, default_node_top)
    node_filler = check_node(node_filler, default_node_filler)
    node_stone = check_node(node_stone, default_node_stone)
    trunk = check_node(trunk, default_trunk)
    leaves = check_node(leaves, default_leaves)

    return {
        node_top = node_top,
        node_filler = node_filler,
        node_stone = node_stone,
        trunk = trunk,
        leaves = leaves,
        trees = trees,
        decos = decos,
        biome_name = biome_name or "unknown"
    }
end

-- Procedural fallback tree generation
local function spawn_fallback_tree(pos, trunk_node, leaves_node)
    local height = math.random(4, 6)
    
    -- Build trunk
    for y = 0, height - 1 do
        local trunk_pos = {x = pos.x, y = pos.y + y, z = pos.z}
        local node = minetest.get_node_or_nil(trunk_pos)
        if node and (is_replaceable(node.name) or minetest.get_item_group(node.name, "leaves") > 0) then
            minetest.set_node(trunk_pos, {name = trunk_node})
        end
    end
    
    -- Build leaves canopy (if leaves node is not air)
    if leaves_node ~= "air" then
        for lx = -2, 2 do
            for lz = -2, 2 do
                for ly = height - 3, height do
                    -- Spherical shape check
                    if math.abs(lx) + math.abs(lz) + math.abs(ly - (height - 1.5)) <= 3.5 then
                        local leaf_pos = {x = pos.x + lx, y = pos.y + ly, z = pos.z + lz}
                        local node = minetest.get_node_or_nil(leaf_pos)
                        if node and is_replaceable(node.name) then
                            minetest.set_node(leaf_pos, {name = leaves_node})
                        end
                    end
                end
            end
        end
    end
end

-- Main landscaping logic
local function perform_landscaping(self, pos)
    -- Find ground level directly below the drone
    local ground_y = find_ground_level(pos, self.spawn_pos.y)
    local ground_pos = {x = pos.x, y = ground_y, z = pos.z}
    
    -- Respect the 50-block radius from spawn point (horizontal check)
    local spawn_dist = vector.distance(
        {x = ground_pos.x, y = self.spawn_pos.y, z = ground_pos.z},
        {x = self.spawn_pos.x, y = self.spawn_pos.y, z = self.spawn_pos.z}
    )
    if spawn_dist > 50 then
        return
    end

    local materials = get_biome_materials(ground_pos)
    local r = math.random(1, 100)
    
    -- Neon green scanner visual laser effect
    local function spawn_laser()
        local steps = 15
        for i = 0, steps do
            local t = i / steps
            local particle_pos = {
                x = pos.x + (ground_pos.x - pos.x) * t,
                y = (pos.y - 0.5) + (ground_pos.y + 1 - (pos.y - 0.5)) * t,
                z = pos.z + (ground_pos.z - pos.z) * t
            }
            minetest.add_particle({
                pos = particle_pos,
                velocity = {x = 0, y = 0, z = 0},
                acceleration = {x = 0, y = 0, z = 0},
                expirationtime = 0.4,
                size = 1.2,
                collisiondetection = false,
                texture = "menotics_landscaper_particle.png^[colorize:#00ff55:255",
                glow = 14,
            })
        end
    end

    if r <= 60 then
        -- 60% chance: Shape terrain (place a ground block)
        local target_build_pos = {x = ground_pos.x, y = ground_pos.y + 1, z = ground_pos.z}
        local target_node = minetest.get_node_or_nil(target_build_pos)
        
        if target_node and is_replaceable(target_node.name) then
            local build_r = math.random(1, 100)
            local node_to_place = materials.node_top
            if build_r > 90 then
                node_to_place = materials.node_stone
            elseif build_r > 60 then
                node_to_place = materials.node_filler
            end
            
            minetest.set_node(target_build_pos, {name = node_to_place})
            spawn_laser()
            minetest.sound_play("default_place_node", {pos = target_build_pos, gain = 0.3, max_hear_distance = 15}, true)
            
            -- Turn covered top node into filler
            local old_ground_node = minetest.get_node_or_nil(ground_pos)
            if old_ground_node and old_ground_node.name == materials.node_top then
                minetest.set_node(ground_pos, {name = materials.node_filler})
            end
        end
        
    elseif r <= 75 then
        -- 15% chance: Place decorative plants
        local target_deco_pos = {x = ground_pos.x, y = ground_pos.y + 1, z = ground_pos.z}
        local target_node = minetest.get_node_or_nil(target_deco_pos)
        
        if target_node and is_replaceable(target_node.name) then
            local placed = false
            
            if #materials.decos > 0 then
                local deco = materials.decos[math.random(1, #materials.decos)]
                if deco.decoration then
                    local node_name
                    if type(deco.decoration) == "table" then
                        node_name = deco.decoration[math.random(1, #deco.decoration)]
                    else
                        node_name = deco.decoration
                    end
                    
                    if node_name and minetest.registered_nodes[node_name] then
                        minetest.set_node(target_deco_pos, {name = node_name})
                        placed = true
                    end
                end
            end
            
            if not placed then
                local fallback_deco = "default:grass_3"
                local name_lower = materials.biome_name:lower()
                if name_lower:find("desert") or name_lower:find("sand") then
                    fallback_deco = "default:dry_shrub"
                elseif name_lower:find("snow") or name_lower:find("cold") or name_lower:find("tundra") then
                    fallback_deco = "default:dry_shrub"
                end
                
                fallback_deco = verify_node(fallback_deco, nil)
                if fallback_deco then
                    minetest.set_node(target_deco_pos, {name = fallback_deco})
                    placed = true
                end
            end
            
            if placed then
                spawn_laser()
                minetest.sound_play("default_place_node", {pos = target_deco_pos, gain = 0.2, max_hear_distance = 12}, true)
            end
        end
        
    elseif r <= 85 then
        -- 10% chance: Plant a tree
        -- Check spacing to avoid dense overcrowding (radius 2 horizontally, height 8)
        local check_radius = 2
        local near_trees = minetest.find_nodes_in_area(
            {x = ground_pos.x - check_radius, y = ground_pos.y, z = ground_pos.z - check_radius},
            {x = ground_pos.x + check_radius, y = ground_pos.y + 8, z = ground_pos.z + check_radius},
            {"group:tree"}
        )
        
        if near_trees and #near_trees == 0 then
            local target_tree_pos = {x = ground_pos.x, y = ground_pos.y + 1, z = ground_pos.z}
            local ground_node = minetest.get_node_or_nil(ground_pos)
            
            if ground_node and minetest.registered_nodes[ground_node.name] then
                local is_soil = (ground_node.name == materials.node_top or ground_node.name == materials.node_filler or
                                 minetest.get_item_group(ground_node.name, "soil") > 0 or
                                 minetest.get_item_group(ground_node.name, "sand") > 0)
                                 
                if is_soil then
                    local placed = false
                    spawn_laser()
                    
                    if #materials.trees > 0 then
                        local tree_deco = materials.trees[math.random(1, #materials.trees)]
                        if tree_deco.schematic then
                            local success, err = pcall(function()
                                minetest.place_schematic(target_tree_pos, tree_deco.schematic, tree_deco.rotation or "random", tree_deco.replacements, true)
                            end)
                            if success then
                                placed = true
                            else
                                minetest.log("warning", "[menotics_landscaper] Failed to place schematic: " .. tostring(err))
                            end
                        end
                    end
                    
                    if not placed then
                        spawn_fallback_tree(target_tree_pos, materials.trunk, materials.leaves)
                        placed = true
                    end
                    
                    if placed then
                        minetest.sound_play("default_place_node", {pos = target_tree_pos, gain = 0.4, max_hear_distance = 20}, true)
                    end
                end
            end
        end
    end
end

-- Register Drone Entity
minetest.register_entity("menotics_landscaper:drone", {
    initial_properties = {
        physical = false,
        collisionbox = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5},
        visual = "cube",
        textures = {
            "menotics_landscaper_drone_top.png",
            "menotics_landscaper_drone_bottom.png",
            "menotics_landscaper_drone_side.png",
            "menotics_landscaper_drone_side.png",
            "menotics_landscaper_drone_side.png",
            "menotics_landscaper_drone_front.png",
        },
        static_save = true,
    },
    
    timer = 0,
    thrust_timer = 0,
    bob_timer = 0,
    spawn_pos = nil,
    target_pos = nil,

    on_activate = function(self, staticdata, dtime_s)
        self.object:set_armor_groups({fleshy = 100})
        
        -- Restore state
        local data = minetest.deserialize(staticdata)
        if data then
            self.spawn_pos = data.spawn_pos
            self.target_pos = data.target_pos
        end
        
        local pos = self.object:get_pos()
        if pos then
            if not self.spawn_pos then
                self.spawn_pos = vector.new(pos)
            end
            if not self.target_pos then
                self.target_pos = get_new_target(self)
            end
        end
    end,

    get_staticdata = function(self)
        local data = {
            spawn_pos = self.spawn_pos,
            target_pos = self.target_pos,
        }
        return minetest.serialize(data)
    end,

    on_step = function(self, dtime)
        self.timer = (self.timer or 0) + dtime
        self.thrust_timer = (self.thrust_timer or 0) + dtime
        self.bob_timer = (self.bob_timer or 0) + dtime

        local pos = self.object:get_pos()
        if not pos then return end

        if not self.spawn_pos then
            self.spawn_pos = vector.new(pos)
        end
        if not self.target_pos then
            self.target_pos = get_new_target(self)
        end

        -- Spawning thrust flame particles (every 0.1s)
        if self.thrust_timer >= 0.1 then
            self.thrust_timer = 0
            minetest.add_particle({
                pos = {x = pos.x, y = pos.y - 0.5, z = pos.z},
                velocity = {
                    x = math.random(-10, 10) * 0.05,
                    y = -1.2 - math.random() * 0.5,
                    z = math.random(-10, 10) * 0.05
                },
                acceleration = {x = 0, y = -0.2, z = 0},
                expirationtime = 0.5 + math.random() * 0.3,
                size = 1.0 + math.random() * 1.5,
                collisiondetection = true,
                vertical = false,
                texture = "menotics_landscaper_particle.png^[colorize:#ff5a00:200",
                glow = 12,
            })
        end

        local dist = vector.distance(pos, self.target_pos)
        if dist < 2.0 or dist > 100 then
            self.target_pos = get_new_target(self)
        else
            -- Smooth gliding towards target
            local speed = 2.0
            local dir = vector.direction(pos, self.target_pos)
            
            -- Sinusoidal hover bobbing
            local bob = math.sin(self.bob_timer * 3.0) * 0.15
            local velocity = vector.multiply(dir, speed)
            velocity.y = velocity.y + bob
            
            self.object:set_velocity(velocity)
            
            -- Rotate facing direction
            local yaw = math.atan2(-dir.x, dir.z)
            self.object:set_yaw(yaw)
        end

        -- Trigger landscaping every 3.0s
        if self.timer >= 3.0 then
            self.timer = 0
            perform_landscaping(self, pos)
        end
    end,

    on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir)
        -- Hitting the drone destroys it and drops it back as an item
        if puncher and puncher:is_player() then
            local pos = self.object:get_pos()
            if pos then
                minetest.add_item(pos, "menotics_landscaper:drone_spawner")
                
                -- Spawn breakdown explosion particles
                for _ = 1, 15 do
                    minetest.add_particle({
                        pos = {
                            x = pos.x + math.random(-5, 5)*0.1,
                            y = pos.y + math.random(-5, 5)*0.1,
                            z = pos.z + math.random(-5, 5)*0.1
                        },
                        velocity = {
                            x = math.random(-15, 15)*0.1,
                            y = math.random(-5, 15)*0.1,
                            z = math.random(-15, 15)*0.1
                        },
                        expirationtime = 0.6,
                        size = 1.0 + math.random()*1.5,
                        texture = "menotics_landscaper_particle.png^[colorize:#888888:200",
                        glow = 10,
                    })
                end
                minetest.sound_play("default_dig_node", {pos = pos, gain = 0.5}, true)
            end
            self.object:remove()
        end
    end,
})

-- Register Spawner Node (the placed block that deploys the drone)
minetest.register_node("menotics_landscaper:drone_spawner", {
    description = S("Menotics Landscaper Drone"),
    tiles = {
        "menotics_landscaper_drone_top.png",
        "menotics_landscaper_drone_bottom.png",
        "menotics_landscaper_drone_side.png",
        "menotics_landscaper_drone_side.png",
        "menotics_landscaper_drone_side.png",
        "menotics_landscaper_drone_front.png"
    },
    groups = {cracky = 3, oddy = 3},
    on_construct = function(pos)
        local spawn_pos = {x = pos.x, y = pos.y + 0.5, z = pos.z}
        local obj = minetest.add_entity(spawn_pos, "menotics_landscaper:drone")
        if obj then
            minetest.remove_node(pos)
        end
    end,
})

-- Register Crafting Recipe (dynamically mapped based on game base)
local resolved_iron = find_existing_node({"default:steel_ingot", "mcl_core:iron_ingot"}) or "group:coal"
local resolved_gold = find_existing_node({"default:copper_ingot", "mcl_core:gold_ingot"}) or "group:wood"
local resolved_mese = find_existing_node({"default:mese_crystal", "mcl_core:diamond"}) or "group:stone"

-- Look up items registry as fallback (for non-node ingredients)
local function find_existing_item(names)
    for _, name in ipairs(names) do
        if minetest.registered_items[name] then
            return name
        end
    end
    return nil
end

local item_iron = find_existing_item({"default:steel_ingot", "mcl_core:iron_ingot"})
local item_gold = find_existing_item({"default:copper_ingot", "mcl_core:gold_ingot"})
local item_mese = find_existing_item({"default:mese_crystal", "mcl_core:diamond"})

if item_iron and item_gold and item_mese then
    minetest.register_craft({
        output = "menotics_landscaper:drone_spawner",
        recipe = {
            {item_iron, item_mese, item_iron},
            {item_iron, item_gold, item_iron},
            {item_iron, item_iron, item_iron},
        }
    })
end

-- Register chat command to clear all landscaper drones in loaded chunks
minetest.register_chatcommand("clear_drones", {
    params = "",
    description = "Removes all active Menotics Landscaper Drones from loaded mapblocks",
    privs = {server = true},
    func = function(name, param)
        local count = 0
        local entities_table = minetest.luaentities or (core and core.luaentities) or {}
        for _, entity in pairs(entities_table) do
            if entity.name == "menotics_landscaper:drone" then
                if entity.object then
                    entity.object:remove()
                    count = count + 1
                end
            end
        end
        return true, "Removed " .. count .. " active landscaper drone(s) from loaded mapblocks."
    end,
})
