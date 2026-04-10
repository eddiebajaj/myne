class_name OreNode
extends StaticBody2D
## A mineable ore node. Hits-to-break depends on pickaxe tier vs ore tier.
## ~20-30% of nodes carry a mineral modifier (visual glow).

signal mined(ore: OreData, mineral: MineralData)

var ore_data: OreData
var mineral: MineralData  # null = plain ore
var hits_remaining: int = 1

@onready var sprite: ColorRect = $Sprite
@onready var health_bar: ProgressBar = $HealthBar
@onready var mineral_glow: ColorRect = $MineralGlow


func _ready() -> void:
	add_to_group("ore_nodes")
	if ore_data:
		setup(ore_data, mineral)


func setup(data: OreData, mineral_mod: MineralData = null) -> void:
	ore_data = data
	mineral = mineral_mod
	# Hits based on player's pickaxe tier vs ore tier
	var pickaxe_tier: int = 1
	if Inventory:
		pickaxe_tier = Inventory.upgrade_levels.get("pickaxe_tier", 1)
	hits_remaining = OreData.get_hits_to_break(pickaxe_tier, data.tier)
	if sprite:
		sprite.color = data.color
	if health_bar:
		health_bar.max_value = hits_remaining
		health_bar.value = hits_remaining
		health_bar.visible = hits_remaining > 1
	# Mineral visual
	if mineral_glow:
		if mineral:
			mineral_glow.visible = true
			mineral_glow.color = Color(mineral.color, 0.4)
		else:
			mineral_glow.visible = false


func take_hit(power: int = 1) -> void:
	hits_remaining -= power
	if health_bar:
		health_bar.value = hits_remaining
	# Shake feedback
	var original_pos := position
	var tween := create_tween()
	tween.tween_property(self, "position", original_pos + Vector2(3, 0), 0.04)
	tween.tween_property(self, "position", original_pos + Vector2(-3, 0), 0.04)
	tween.tween_property(self, "position", original_pos, 0.04)
	if hits_remaining <= 0:
		_break()


func _break() -> void:
	mined.emit(ore_data, mineral)
	# Auto-collect
	if Inventory.can_add_ore(ore_data, mineral):
		Inventory.add_ore(ore_data, mineral)
	# Pop animation
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.08)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.12)
	tween.tween_callback(queue_free)
