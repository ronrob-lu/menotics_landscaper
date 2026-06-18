# Menotics Landscaper Drone

A Luanti (Minetest) mod that introduces automated, autonomous landscaping drones. Once crafted and deployed, these drones fly around within a 50-block radius and shape the local terrain. The mod features two types of drones: a **Blue Landscaper Drone** for biome-specific terrain/plants/trees, and a **Yellow Lake Landscaper Drone** for carving lakes, placing sand beaches, and building sand dunes.

> [!WARNING]
> **Map Modification Warning**: Deployed drones autonomously place, replace, and excavate blocks in a 50-block horizontal radius around their spawn point. Drones will override pre-existing blocks, player builds, and resources. **Do not deploy drones near valuable structures, player bases, or custom maps without a backup!**


## Features

- **Autonomous Flight**: Drones fly smoothly, adapting their height (5–12 blocks) to follow the contours of the terrain.
- **Biomes & Lakes**: 
  - **Blue Drone**: Queries the local biome and places matching top soil, filler blocks, stone, plants, and trees.
  - **Yellow Drone**: Carves a deep lake basin centered on its spawn point, fills it with water (level with the spawn point), creates a flat sandy beach transition, and mounds wavy sand dunes with beach grass further out.
- **Overcrowding Protection**: Blue drones plant trees with built-in spacing protection (minimum 5-block distance between trees) to prevent overcrowding.
- **High-Quality Visual Effects**: Custom pixel-art textures (blue/yellow themed solar panels, thrusters, camera lenses, and chassis lights) and glowing, neon-colored scanning laser beams.
- **Multi-Drone Capability**: Spawn multiple drones in the same area to shape the landscape faster. Drones will work independently and cover their respective 50-block radiuses.

## Crafting

### 1. Landscaper Drone (Blue)
You can craft a standard **Landscaper Drone** using the following recipe:

| | | |
|---|---|---|
| Steel Ingot | Mese Crystal | Steel Ingot |
| Steel Ingot | Copper Ingot | Steel Ingot |
| Steel Ingot | Steel Ingot | Steel Ingot |

- **Output**: 1 x Landscaper Drone block (`menotics_landscaper:drone_spawner`)

### 2. Lake Landscaper Drone (Yellow)
You can craft a **Lake Landscaper Drone** using a water bucket in the center of the grid:

| | | |
|---|---|---|
| Steel Ingot | Mese Crystal | Steel Ingot |
| Steel Ingot | Water Bucket | Steel Ingot |
| Steel Ingot | Steel Ingot | Steel Ingot |

- **Output**: 1 x Lake Landscaper Drone block (`menotics_landscaper:lake_drone_spawner`)

## How to Use

1. Craft the Landscaper Drone.
2. Place the drone block anywhere on the map where you want it to begin work.
3. Upon placement, the block will activate, convert into a flying drone entity, and immediately take off to begin landscaping.
4. The drone will fly around its spawn coordinates within a 50-block radius, placing blocks, plants, and trees.

## Commands

- `/clear_drones`: Removes all active Menotics Landscaper Drones in currently loaded mapblocks (requires `server` privilege).

## Technical Details

- **Save States**: Drone paths and spawn centers are saved in the entity static data, meaning they will resume where they left off after server restarts.
- **Non-Physical Collisions**: The drone entity is non-physical (`physical = false`) to avoid getting stuck inside leaves, branches, or high cliffs, ensuring smooth continuous operation.
- **Safety Checks**: The drone verifies that target blocks are air or replaceable before placing anything, and checks that target placements are supported.

## Author & License

- **Author**: ronrob-lu
- **License**: MIT
