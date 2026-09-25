# Asset layout

Keep source art grouped by its gameplay role. Godot `.import` files stay beside their source files.

- `characters/player`: player sprites and animation sheets
- `characters/npcs`: NPC and vendor sprites
- `world/tilesets/static`: regular terrain tilesets
- `world/shaders`: procedural terrain surfaces such as the overworld water shader
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

### Advanced powers

Press **I**, select the **Q** or **R** slot, and choose a power. Aim with the mouse
and press the equipped key. The three advanced powers appear first in the list:

- **Event Horizon** forms ahead of the caster, pulls enemies toward its center,
  then collapses. Its accretion disk, dark core, orbital debris, and shock ring
  are layered over local screen refraction.
- **Astral Lance** locks its direction at cast time, charges for half a second,
  then pierces a narrow line. Braided plasma, converging sparks, and an impact
  burst mark the attack's actual timing.
- **Chronostasis** freezes movement and attacks inside a time dial, then
  shatters its captured enemies. Overlapping fields expire independently.

`combat/superpower_effect.gd` owns presentation and particle cleanup;
`combat/superpower_runtime.gd` owns targeting and damage. Both use the charge,
sustain, and release durations from each `AbilityDefinition`. Field radius and
beam length use the resource's range in world units. Existing power IDs and
saved loadouts remain supported.

`effects/particles` contains authored SVG mote, streak, and crystal textures.
The four new shaders in `effects/shaders` generate the larger surfaces and
refraction procedurally; no downloaded art or external texture generator is needed.

Validation (replace `godot` with your Godot executable):

```text
godot --headless --path . --script tests/superpower_smoke_test.gd
godot --headless --path . --script tests/mob_smoke_test.gd
godot --path . --script tests/superpower_visual_test.gd
```

The visual test casts all three powers in the main world and saves charge,
active, release, and loadout screenshots to the ignored `tmp` directory. Use a
real rendering driver to validate shader compilation and appearance.

The six original powers also have their own combat timing and shaders. Ember
Nova emits three expanding fire rings; Arc Storm chains between four targets;
Void Bloom strikes in three petal waves; Glacial Halo freezes on three crystal
rims; Solar Spear travels, pierces, and bursts; Spirit Pulse heals its caster
and gains more health for enemies hit. Their particles share the SVG mote,
streak, and shard textures but use different emission patterns. Run
`tests/original_power_smoke_test.gd` for their timing and targeting checks, or
`tests/original_power_visual_test.gd` with a rendering driver for screenshots.

The overworld water now uses one shader surface across its generated cells.
`world/water_surface.gd` rasterizes their isometric diamonds into a coverage and
shore-depth mask, then hides only the old water atlas art. The original water
cell IDs remain for navigation and mob spawning. The shader in
`assets/world/shaders/stylized_water.gdshader` draws continuous depth colors,
flowing caustics, and foam that rolls along the mask's shoreline. Run
`tests/water_visual_test.gd` in Godot to check the mask and capture two animation
frames in `tmp`.

The village uses eight generated isometric pixel-art house sprites and three
seeded tree forms. See `assets/world/buildings/README.md` for the house catalog,
placement, and generation prompts. `tests/village_building_gallery_test.gd`
renders all eight houses; `tests/village_visual_test.gd` captures the populated
overworld.

Four additional isometric pixel-tree sheets live in `assets/world/trees`.
Each sheet contains four transparent plant sprites in a distinct visual family;
its README documents the layout and generation prompts.

Weapon art is grouped by type and pack. Runtime weapon stats live in
`data/weapons`; every `WeaponDefinition` also has an ability list ready for future
weapon-specific attacks.
