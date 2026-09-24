# Isometric village building kit

`VillageBuilding` draws a timber-and-stone building from a `VillageBuildingRecipe`. Its local origin is the front tip of a roughly 128 × 54 pixel ground footprint. The building includes a `StaticBody2D` footprint for collisions. Place its origin on dry ground and draw it in the world's normal Y order.

The five ready-made variants use `building.configure(style_id, seed)`, with IDs 0–4: cottage (gable), inn (cross-gable), shop (hip), tall house (gable), and hall (hip). The seed changes the small surface details without changing the composition.

For a new combination, create a `VillageBuildingRecipe`, set its exposed properties, then call `building.apply_recipe(recipe, seed)` before adding the building to the scene. Available parts are one to three stories; gable, hip, or cross-gable roof; cottage door, shop awning, or porch entry; zero to three dormers; optional chimney and balcony; and roof, plaster, timber, stone, and accent colors. For example:

```gdscript
var workshop := VillageBuildingRecipe.new()
workshop.stories = 1
workshop.roof_shape = VillageBuildingRecipe.RoofShape.CROSS_GABLE
workshop.entry_style = VillageBuildingRecipe.EntryStyle.SHOP
workshop.dormers = 0
workshop.roof_color = Color("#557f90")
var building := VillageBuilding.new()
building.apply_recipe(workshop, 61)
building.position = village_position
add_child(building)
```

Run `godot --path . --rendering-method forward_plus --script tests/village_building_gallery_test.gd` to check all five presets and two custom combinations. It writes `tmp/village_building_gallery.png` when a graphics renderer is available.
