# Isometric pixel houses

Eight generated transparent PNG sprites now replace the procedural/vector village houses.

| ID | File | House |
| --- | --- | --- |
| 0 | pixel_houses/house_01.png | Cottage |
| 1 | pixel_houses/house_02.png | Inn |
| 2 | pixel_houses/house_03.png | Merchant shop |
| 3 | pixel_houses/house_05.png | Village hall |
| 4 | pixel_houses/house_06.png | Herbalist |
| 5 | pixel_houses/house_07.png | Bakery |
| 6 | pixel_houses/house_09.png | Merchant manor |
| 7 | pixel_houses/house_10.png | Riverside cottage |

Instantiate `scenes/village_building.tscn` and set `house_index`, or call
`configure(index)` on a new `VillageBuilding` before adding it to the scene.
The node origin is the front of the ground footprint for Y sorting.
`world/village_placement.gd` places all eight on dry sites around the plaza.
Each instance has a physical footprint; saved positions and mob spawns avoid it.

Original PNGs retain their generated alpha and resolution.
`pixel_house.gdshader` samples a fixed world-pixel grid with nearest filtering
and a crisp alpha cutoff, matching terrain pixel density at gameplay zoom.
`ART_BOUNDS` and `WORLD_WIDTHS` in `world/village_building.gd` control framing
and display size. These are complete house sprites, not recolorable roof/wall
modules; the former `VillageBuildingRecipe` resource no longer drives their appearance.

Generated with the built-in image_gen tool. The exact eight retained prompts are saved in
`pixel_houses/generation_prompts.json`. They request isometric pixel art with
teal shingle roofs, cream plaster, dark timber, stone bases and transparent backgrounds.

Run `godot --path . --rendering-method forward_plus --script tests/village_building_gallery_test.gd`
for all eight sprites (`tmp/pixel_houses_gallery.png`), or
`tests/village_visual_test.gd` for in-game screenshots.
