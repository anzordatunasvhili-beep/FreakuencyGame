# Isometric pixel tree sets

Four transparent sprite sheets contain four plants each, for sixteen generated
plants in total. They use a consistent 2 by 2 layout:

1. top left
2. top right
3. bottom left
4. bottom right

| Sheet | Style |
| --- | --- |
| `pixel_sets/tree_set_01_wild_green.png` | Windswept green trees and living roots |
| `pixel_sets/tree_set_02_lush_village.png` | Healthy village trees, orchard tree, and flowering shrub |
| `pixel_sets/tree_set_03_ancient_teal.png` | Ancient fallen wood with enchanted teal growth |
| `pixel_sets/tree_set_04_crimson_twist.png` | Twisted scarlet and burgundy maples |

The sheets have genuine transparent backgrounds and no labels or panel lines.
Use nearest-neighbor filtering when scaling them in game. The exact built-in
image-generation prompt set is stored in
`pixel_sets/generation_prompts.json`.

`world/village_tree.gd` slices these sheets into sixteen tightly framed
variants. `world/village_trees.gd` chooses among all sixteen deterministically
while preserving the existing tree placement, root anchoring, Y sorting, and
trunk collision.
