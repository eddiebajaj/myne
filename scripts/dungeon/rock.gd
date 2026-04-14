class_name Rock
extends StaticBody2D
## A breakable rock. 1 hit to break. May hide stairs down, treasure, or trigger a portal.
## From 13_balance_t1.md: rocks break in 1 hit, 8-12 per floor, 1 hides stairs.

var rock_content: String = "empty"  # "stairs", "treasure", "empty"
var floor_generator: FloorGenerator = null
var broken: bool = false

@onready var sprite: ColorRect = $Sprite


func _ready() -> void:
	add_to_group("rocks")
	sprite.color = Color(0.4, 0.35, 0.3)


func take_hit(_power: int = 1) -> void:
	## Rocks always break in 1 hit.
	if broken:
		return
	broken = true
	_break()


func _break() -> void:
	var pos := global_position
	match rock_content:
		"stairs":
			# Reveal stairs down
			if floor_generator:
				floor_generator.spawn_stairs_down_at(pos)
		"treasure":
			# Spawn treasure loot (from 13_balance_t1.md section 5c)
			_spawn_treasure(pos)
	# Check for rock-triggered portal (B3F+)
	if floor_generator and rock_content != "stairs":
		var chance := floor_generator.get_rock_portal_chance()
		if randf() < chance:
			floor_generator.spawn_rock_triggered_portal(pos)
	# Break animation
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.06)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.1)
	tween.tween_callback(queue_free)


func _spawn_treasure(pos: Vector2) -> void:
	## Treasure rock loot table from 13_balance_t1.md section 5c
	var roll := randf()
	if roll < 0.60:
		# 60%: Bonus ore (1-2 pieces)
		var count := randi_range(1, 2)
		for i in range(count):
			if floor_generator:
				var ore := floor_generator.pick_ore_for_depth()
				if ore and Inventory.can_add_ore(ore):
					Inventory.add_ore(ore)
	elif roll < 0.85:
		# 25%: Small gold drop (replaces former battery drop — Sprint 5 economy rework)
		GameManager.add_gold(5)
		_show_pickup_text(pos, "+5 gold")
	# else 15%: nothing special


func _show_pickup_text(pos: Vector2, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.global_position = pos + Vector2(-30, -30)
	lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
	get_parent().add_child(lbl)
	var tween := create_tween()
	tween.tween_property(lbl, "position:y", lbl.position.y - 40, 0.8)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 0.8)
	tween.tween_callback(lbl.queue_free)
