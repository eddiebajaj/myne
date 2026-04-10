class_name OreData
extends Resource
## Defines a base ore type. Ore is currency, bot material, and lab research material.
## Hits-to-break is NOT stored here — it's a function of ore tier vs pickaxe tier.

@export var id: String = ""
@export var display_name: String = ""
@export var color: Color = Color.GRAY
@export var tier: int = 1              # 1-4, determines bot quality and sell value
@export var specialist: bool = false   # Specialist ores are rarer, better for lab research
@export var value: int = 1             # Gold when sold (base, mineral adds bonus)
@export var min_depth: int = 1         # First floor it appears
@export var max_depth: int = 5         # Last floor it appears (ore is depth-gated)
@export var rarity: float = 1.0        # Spawn weight (higher = more common)

## Pickaxe tier vs ore tier → hits to break.
## Row = pickaxe tier (0-indexed), Column = ore tier (0-indexed).
const HITS_TABLE: Array[Array] = [
	[3, 6, 12, 20],   # Starter pickaxe (tier 1)
	[2, 4, 8, 14],    # Tier 2 pickaxe
	[1, 3, 5, 9],     # Tier 3 pickaxe
	[1, 2, 3, 5],     # Tier 4 pickaxe
]


static func get_hits_to_break(pickaxe_tier: int, ore_tier: int) -> int:
	var pick_idx := clampi(pickaxe_tier - 1, 0, 3)
	var ore_idx := clampi(ore_tier - 1, 0, 3)
	return HITS_TABLE[pick_idx][ore_idx]
