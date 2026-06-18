# Menotics Landscaper Drone

A Luanti (Minetest) mod that introduces automated, autonomous landscaping drones. Once crafted and deployed, these drones fly around within a 50-block radius and shape the local terrain based on the biome they are in. They place ground blocks (building hills and valleys) and plant biome-appropriate flora and trees.

## Features

- **Autonomous Flight**: Drones fly smoothly, adapting their height (5–12 blocks) to follow the contours of the terrain.
- **Dynamic Biome Placement**: The drone queries the local biome at its coordinates and places top blocks, filler blocks, and stone blocks belonging to that specific biome.
- **Tree Planting**: Plants trees from the local biome, with built-in spacing protection (minimum 5-block distance between trees) to prevent dense overcrowding.
- **High-Quality Visual Effects**: The drone has custom pixel-art textures (solar panel, thruster, cameras, and status lights) and projects a neon-colored scanning laser beam from its chassis to the ground when performing landscaping tasks.
- **Multi-Drone Capability**: Spawn multiple drones in the same area to shape the landscape faster. Drones will work independently and cover their respective 50-block radiuses.

## Crafting

You can craft a **Landscaper Drone** using the following recipe in a standard crafting grid:

| | | |
|---|---|---|
| Steel Ingot | Mese Crystal | Steel Ingot |
| Steel Ingot | Copper Ingot | Steel Ingot |
| Steel Ingot | Steel Ingot | Steel Ingot |

- **Output**: 1 x Landscaper Drone block (`menotics_landscaper:drone_spawner`)

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
