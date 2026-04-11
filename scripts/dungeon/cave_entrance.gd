class_name CaveEntrance
extends Area2D
## Opt-in danger zone. Contains Fauna enemies guarding loot.
## Loot: mineral cores, equipment, blueprints, batteries, artifacts.

@onready var sprite: ColorRect = $Sprite
@onready var label: Label = $Label

var player_in_range: bool = false
var activated: bool = false
var cave_roll: String = "standard"
var glow_rect: ColorRect = null
var x_marker: Label = null
var empty_border: ColorRect = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	sprite.color = Color(0.6, 0.1, 0.1)
	label.text = "Cave [E]"
	label.visible = false
	_roll_cave_contents()
	_build_visual_states()


func _roll_cave_contents() -> void:
	## Sprint 2b locked table: 40 standard / 15 treasure / 20 ambush / 10 big_ambush / 15 empty.
	var roll: float = randf()
	if roll < 0.40:
		cave_roll = "standard"
	elif roll < 0.55:
		cave_roll = "treasure"
	elif roll < 0.75:
		cave_roll = "ambush"
	elif roll < 0.85:
		cave_roll = "big_ambush"
	else:
		cave_roll = "empty"


func _build_visual_states() -> void:
	## Pulsing glow for unexplored, hidden X marker for activated, dark border for empty.
	glow_rect = ColorRect.new()
	glow_rect.name = "Glow"
	glow_rect.size = Vector2(64, 64)
	glow_rect.position = Vector2(-32, -32)
	glow_rect.color = Color(1.0, 0.4, 0.2, 0.35)
	glow_rect.show_behind_parent = true
	glow_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow_rect)
	var tween: Tween = create_tween().set_loops()
	tween.tween_property(glow_rect, "color:a", 0.5, 0.6)
	tween.tween_property(glow_rect, "color:a", 0.2, 0.6)

	x_marker = Label.new()
	x_marker.name = "XMarker"
	x_marker.text = "X"
	x_marker.position = Vector2(-6, -12)
	x_marker.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
	x_marker.visible = false
	add_child(x_marker)

	if cave_roll == "empty":
		empty_border = ColorRect.new()
		empty_border.name = "EmptyBorder"
		empty_border.size = Vector2(52, 52)
		empty_border.position = Vector2(-26, -26)
		empty_border.color = Color(0, 0, 0, 0.25)
		empty_border.show_behind_parent = true
		empty_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(empty_border)


func _process(_delta: float) -> void:
	if player_in_range and not activated and Input.is_action_just_pressed("interact"):
		_activate()


func _activate() -> void:
	activated = true
	label.text = "Cave (cleared)"
	sprite.color = Color(0.3, 0.1, 0.1, 0.5)
	if glow_rect:
		glow_rect.visible = false
	if x_marker:
		x_marker.visible = true
	var floor_num: int = GameManager.current_floor
	match cave_roll:
		"standard":
			_spawn_loot_n(1)
			_spawn_cave_ore_fixed(2, false)
		"treasure":
			_spawn_loot_n(2)
			_spawn_cave_ore_fixed(4, true)
		"ambush":
			var comp: Array[String] = _ambush_composition(floor_num)
			_spawn_ambush(comp)
			_spawn_loot_n(2)
			_spawn_cave_ore_fixed(3, false)
		"big_ambush":
			var comp2: Array[String] = _big_ambush_composition(floor_num)
			_spawn_ambush(comp2)
			_spawn_loot_n(3)
			_spawn_cave_ore_fixed(3, true)
		"empty":
			_spawn_cave_ore_fixed(1, false)
			_spawn_dust_particle()


func _ambush_composition(floor_num: int) -> Array[String]:
	if floor_num <= 2:
		return ["cave_beetle", "cave_beetle"]
	return ["cave_beetle", "tunnel_rat"]


func _big_ambush_composition(floor_num: int) -> Array[String]:
	if floor_num <= 3:
		return ["cave_beetle", "crystal_mite"]
	return ["cave_beetle", "crystal_mite", "ore_shard"]


func _spawn_ambush(composition: Array[String]) -> void:
	var floor_gen := _find_floor_generator()
	if floor_gen == null:
		return
	for id in composition:
		var offset: Vector2 = Vector2.from_angle(randf() * TAU) * randf_range(60.0, 100.0)
		var pos: Vector2 = global_position + offset
		var enemy: EnemyBase = floor_gen.spawn_enemy_by_id(pos, id)
		if enemy == null or enemy.data == null:
			continue
		# Leash cave ambush enemies to the cave so they don't overrun the whole floor.
		enemy.spawn_position = global_position
		if enemy.data.faction == EnemyData.Faction.MINERAL_ENTITY:
			# Override: mineral entities normally have no leash; clamp per sprint 2b spec.
			enemy.data.leash_range = 300.0
		else:
			enemy.data.leash_range = 200.0


func _spawn_loot_n(count: int) -> void:
	var tier: int = GameManager.get_current_tier()
	for i in range(count):
		var loot: Dictionary = _generate_loot(tier)
		if loot.is_empty():
			continue
		_create_loot_pickup(loot)


func _spawn_cave_ore_fixed(count: int, force_first_mineral: bool) -> void:
	var floor_gen := _find_floor_generator()
	if floor_gen == null:
		return
	var rare_ores: Array[OreData] = floor_gen.get_rare_ores()
	if rare_ores.is_empty():
		return
	var all_minerals: Array[MineralData] = MineralData.get_all_minerals()
	for i in range(count):
		var ore_data: OreData = rare_ores[randi() % rare_ores.size()]
		var mineral: MineralData = null
		if force_first_mineral and i == 0:
			mineral = all_minerals[randi() % all_minerals.size()]
		elif randf() < 0.5:
			mineral = all_minerals[randi() % all_minerals.size()]
		var offset: Vector2 = Vector2.from_angle(randf() * TAU) * randf_range(60.0, 120.0)
		floor_gen.spawn_ore_node_at(global_position + offset, ore_data, mineral)


func _spawn_dust_particle() -> void:
	## Single ColorRect that fades out over 2s — "already looted ages ago" feedback.
	var dust := ColorRect.new()
	dust.name = "Dust"
	dust.size = Vector2(40, 40)
	dust.position = Vector2(-20, -20)
	dust.color = Color(0.7, 0.65, 0.55, 0.6)
	dust.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dust)
	var tween: Tween = create_tween()
	tween.tween_property(dust, "color:a", 0.0, 2.0)
	tween.tween_callback(dust.queue_free)


func _spawn_loot() -> void:
	## Spawn 1-3 loot pickups from the loot table.
	var loot_count := randi_range(1, 3)
	var tier := GameManager.get_current_tier()
	for i in range(loot_count):
		var loot := _generate_loot(tier)
		if loot.is_empty():
			continue
		_create_loot_pickup(loot)


func _generate_loot(tier: int) -> Dictionary:
	## Weighted random loot by category. Deeper = better categories more likely.
	var categories := ["mineral_core", "battery", "artifact", "equipment", "blueprint"]
	var weights := [5.0, 4.0, 3.0, 2.0, 1.0]
	# Deeper tiers shift weight toward rarer categories
	if tier >= 2:
		weights[2] += 1.0  # More artifacts
		weights[3] += 1.0  # More equipment
	if tier >= 3:
		weights[4] += 1.0  # More blueprints
	var total := 0.0
	for w in weights:
		total += w
	var roll := randf() * total
	var cumulative := 0.0
	var picked := "mineral_core"
	for j in range(categories.size()):
		cumulative += weights[j]
		if roll <= cumulative:
			picked = categories[j]
			break
	return _create_loot_data(picked, tier)


func _create_loot_data(category: String, tier: int) -> Dictionary:
	match category:
		"mineral_core":
			var minerals := MineralData.get_all_minerals()
			var m: MineralData = minerals[randi() % minerals.size()]
			return {"category": "mineral_core", "mineral": m, "label": "%s Core" % m.display_name, "color": m.color}
		"battery":
			return {"category": "battery", "count": randi_range(1, 2), "label": "Battery x%d" % randi_range(1, 2), "color": Color(0.2, 0.9, 0.2)}
		"artifact":
			var artifacts := ["miners_lantern", "ore_magnet", "bot_overclock", "deep_pockets",
				"thick_boots", "lucky_strike", "scrap_recycler", "emergency_battery"]
			var art_id: String = artifacts[randi() % artifacts.size()]
			return {"category": "artifact", "id": art_id, "label": art_id.replace("_", " ").capitalize(), "color": Color(1.0, 0.85, 0.2)}
		"equipment":
			var armor_val := tier * 5.0 + randf_range(0, 5)
			return {"category": "equipment", "armor": armor_val, "label": "T%d Armor (+%d)" % [tier, int(armor_val)], "color": Color(0.6, 0.6, 0.7)}
		"blueprint":
			return {"category": "blueprint", "id": "blueprint_t%d" % tier, "label": "Blueprint (T%d)" % tier, "color": Color(0.3, 0.5, 1.0)}
	return {}


func _create_loot_pickup(loot: Dictionary) -> void:
	## Create a pickup Area2D the player walks into to collect.
	var pickup := Area2D.new()
	pickup.collision_layer = 64
	pickup.collision_mask = 1
	var rect := ColorRect.new()
	rect.name = "Sprite"
	rect.size = Vector2(16, 16)
	rect.position = Vector2(-8, -8)
	rect.color = loot.get("color", Color.WHITE)
	pickup.add_child(rect)
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 16.0
	col.shape = shape
	pickup.add_child(col)
	var lbl := Label.new()
	lbl.text = loot.get("label", "Loot")
	lbl.position = Vector2(-30, -24)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pickup.add_child(lbl)
	var offset := Vector2.from_angle(randf() * TAU) * randf_range(30, 60)
	pickup.global_position = global_position + offset
	# Connect pickup logic
	var loot_copy := loot
	pickup.body_entered.connect(func(body):
		if body is Player:
			_collect_loot(loot_copy)
			pickup.queue_free()
	)
	get_parent().add_child(pickup)


func _collect_loot(loot: Dictionary) -> void:
	match loot.category:
		"mineral_core":
			Inventory.store_mineral(loot.mineral)
		"battery":
			Inventory.add_batteries(loot.get("count", 1))
		"artifact":
			Inventory.add_artifact(loot.id)
		"equipment":
			# Apply armor directly
			var armor_val: float = loot.get("armor", 5.0)
			var player_nodes := get_tree().get_nodes_in_group("player")
			if player_nodes.size() > 0 and player_nodes[0] is Player:
				var p: Player = player_nodes[0]
				p.max_armor = maxf(p.max_armor, armor_val)
				p.armor = p.max_armor
				p.health_changed.emit(p.health, p.max_health, p.armor, p.max_armor)
		"blueprint":
			if not Inventory.blueprints.has(loot.id):
				Inventory.blueprints.append(loot.id)


func _find_floor_generator() -> Node:
	var parent := get_parent()
	while parent:
		if parent.has_method("spawn_ore_node_at"):
			return parent
		parent = parent.get_parent()
	return null


func _on_body_entered(body: Node2D) -> void:
	if body is Player and not activated:
		player_in_range = true
		label.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_in_range = false
		label.visible = false
