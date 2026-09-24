class_name VillageBuildingRecipe
extends Resource
## Swappable parts of one isometric timber-and-stone building.

enum RoofShape { GABLE, HIP, CROSS_GABLE }
enum EntryStyle { COTTAGE, SHOP, PORCH }

@export_range(1, 3) var stories := 2
@export var roof_shape: RoofShape = RoofShape.GABLE
@export var entry_style: EntryStyle = EntryStyle.COTTAGE
@export_range(0, 3) var dormers := 1
@export var chimney := true
@export var balcony := false
@export var roof_color := Color("#477f82")
@export var plaster_color := Color("#e7d9bc")
@export var timber_color := Color("#654632")
@export var stone_color := Color("#737676")
@export var accent_color := Color("#8bb29e")
