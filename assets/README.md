# Asset layout

Keep source art grouped by its gameplay role. Godot `.import` files stay beside their source files.

- `characters/player`: player sprites and animation sheets
- `characters/npcs`: NPC and vendor sprites
- `world/tilesets/static`: regular terrain tilesets
- `world/tilesets/animated`: water, lava, doors, and other animated tiles
- `world/buildings`: building sprites and modular building pieces
- `world/props`: trees, rocks, furniture, and decorations
- `items/weapons`, `armor`, `consumables`: item art by equipment type
- `effects/spells`, `combat`: visual effects and animation sheets
- `ui/hud`, `ui/inventory`, `ui/shared`: interface art by screen and reusable UI art
- `audio/music`, `audio/sfx`: music and sound effects
- `minigames/*`: art that belongs only to fishing, hunting, dungeons, or mazes

Use lowercase folder names and descriptive filenames. Put reusable art in the shared gameplay category instead of duplicating it inside a scene or minigame folder.

Combat VFX are configured through `AbilityDefinition` resources in `data/abilities`.
Adding another attack normally requires only its sprite strip and a new `.tres` definition.
