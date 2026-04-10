class_name UpgradeData
extends Resource
## Town upgrade / purchase definition. Used by Smith and Market NPCs.

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var max_level: int = 4
@export var base_cost: int = 10
@export var cost_multiplier: float = 1.5

enum UpgradeType { PICKAXE_TIER, ARMOR, BACKPACK_ROWS }
@export var type: UpgradeType = UpgradeType.PICKAXE_TIER
@export var value_per_level: float = 1.0


func get_cost(current_level: int) -> int:
	return int(base_cost * pow(cost_multiplier, current_level))
