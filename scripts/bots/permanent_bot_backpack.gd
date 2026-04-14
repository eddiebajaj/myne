extends PermanentBot
## Backpack Bot — non-combat. Passive +8 backpack slots granted by Inventory.get_max_capacity().
## Just follows the player; no targeting, no attacks.


func _find_target() -> void:
	target = null


func _act(_delta: float) -> void:
	# Never active (target is always null)
	pass
