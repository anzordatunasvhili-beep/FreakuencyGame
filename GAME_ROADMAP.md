# Freakuency RPG roadmap

## Current playable foundation

- Isometric tile map with click-to-move navigation
- Eight-direction player animation
- One interactable NPC with online dialog and mission hooks
- Inventory data, nine-slot hotbar, health/mana HUD, currency, and save/load services

## Recommended implementation order

1. **Offline-safe core**: player input, interactions, health/death, local saves, scene transitions, and test scenes must work without a network connection.
2. **Data-driven content**: define items, weapons, spells, enemies, NPCs, quests, loot tables, and gathering resources as Godot `Resource` data rather than hard-coding them in scenes.
3. **Combat slice**: weapon equip/use, hitboxes, damage, enemy state machine, drops, XP, death, and respawn.
4. **Quest slice**: local quest objectives and rewards, NPC roles, journal, and optional cloud synchronization.
5. **World structure**: reusable maps, portals, interiors, the other-world transition, dungeon entrances, and persistent world state.
6. **Activities**: fishing first, then hunting/gathering. Each should use the same item, quest, XP, and reward systems.
7. **Dungeon framework**: room flow, encounters, treasure, checkpoints, bosses, and generated or authored variants.
8. **Maze framework**: reusable maze rules, timer/reward options, and dungeon integration.
9. **Content and polish**: more NPCs, monsters, buildings, weapons, spells, audio, VFX, balancing, accessibility, and save migration.

## Architecture boundaries

- Autoloads own cross-scene state and services only.
- Scenes own presentation and moment-to-moment behavior.
- Reusable definitions live as custom `Resource` types under a future `data/` tree.
- Feature code should be grouped under a future `features/` tree (`combat`, `quests`, `fishing`, `hunting`, `dungeons`, `mazes`).
- Every major system should have a small isolated test scene before it is added to the main world.

The health HUD artwork and node layout are intentionally unchanged. Its values are driven by `GameState.stats_changed` and should remain the single display path for damage, healing, loading, and respawning.
