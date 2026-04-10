class_name PortalSpawner
extends Node2D
## Spawns Mineral Entity enemies on timed waves starting at B3F.
## Values from 13_balance_t1.md section 9.

signal wave_spawned(count: int)
signal portal_warning

var waves_spawned: int = 0
var max_waves: int = 0
var warning_active: bool = false
var spawn_radius: float = 40.0
var current_warning_time: float = 3.0

@onready var timer: Timer = $Timer
@onready var sprite: ColorRect = $Sprite


func _ready() -> void:
	_build_entity_defs()
	var is_rock_triggered := has_meta("rock_triggered") and get_meta("rock_triggered")
	var floor_num := GameManager.current_floor
	if is_rock_triggered:
		# Rock-triggered portal: 1.5s warning, single wave
		max_waves = 1
		current_warning_time = 1.5
		timer.wait_time = current_warning_time
		timer.one_shot = true
		timer.timeout.connect(_on_timer)
		# Start with warning immediately
		warning_active = true
		portal_warning.emit()
		_show_warning()
		timer.start()
		# Pulse visual
		var tween := create_tween().set_loops()
		tween.tween_property(sprite, "modulate:a", 0.4, 0.5)
		tween.tween_property(sprite, "modulate:a", 1.0, 0.5)
		return
	if floor_num < 3:
		# No portals on B1F-B2F
		sprite.visible = false
		return
	# Set max waves based on floor
	match floor_num:
		3: max_waves = 3
		4: max_waves = 4
		_: max_waves = 5  # B5F+
	# Warning time
	if floor_num >= 5:
		current_warning_time = 2.5
	else:
		current_warning_time = 3.0
	# First wave delay based on floor
	var first_delay := _get_first_wave_delay()
	timer.wait_time = first_delay
	timer.one_shot = true
	timer.timeout.connect(_on_timer)
	timer.start()
	# Pulse visual
	var tween := create_tween().set_loops()
	tween.tween_property(sprite, "modulate:a", 0.4, 0.8)
	tween.tween_property(sprite, "modulate:a", 1.0, 0.8)


func _get_first_wave_delay() -> float:
	## B3F=45s, B4F=40s, B5F=35s, further floors keep subtracting
	var floor_num := GameManager.current_floor
	return maxf(45.0 - (floor_num - 3) * 5.0, 15.0)


func _get_subsequent_interval() -> float:
	## B3F=35s, B4F=30s, B5F=25s
	var floor_num := GameManager.current_floor
	return maxf(35.0 - (floor_num - 3) * 5.0, 10.0)


func _on_timer() -> void:
	if waves_spawned >= max_waves:
		timer.stop()
		# Portal fades out
		var tween := create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 1.0)
		tween.tween_callback(func(): visible = false)
		return
	if not warning_active:
		# Show warning first
		warning_active = true
		portal_warning.emit()
		_show_warning()
		timer.wait_time = current_warning_time
		timer.start()
	else:
		# Spawn wave
		warning_active = false
		_spawn_wave()
		timer.wait_time = _get_subsequent_interval()
		timer.start()


func _show_warning() -> void:
	if sprite:
		var tween := create_tween().set_loops(3)
		tween.tween_property(sprite, "modulate", Color(1, 0.3, 0.3), 0.15)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)


func _spawn_wave() -> void:
	waves_spawned += 1
	# Wave composition from 13_balance_t1.md section 4b
	var crystal_mites := 0
	var ore_shard_groups := 0
	var shards_per_group := 3
	match waves_spawned:
		1:
			crystal_mites = 2
		2:
			crystal_mites = 2
			ore_shard_groups = 1
			shards_per_group = 3
		3:
			crystal_mites = 1
			ore_shard_groups = 2
			shards_per_group = 3
		4:
			crystal_mites = 3
			ore_shard_groups = 1
			shards_per_group = 4
		_:  # Wave 5+
			crystal_mites = 3
			ore_shard_groups = 2
			shards_per_group = 4
	var total_spawned := 0
	# Spawn Crystal Mites
	for i in range(crystal_mites):
		var enemy_scene := _build_enemy_scene()
		var enemy: CharacterBody2D = enemy_scene.instantiate()
		var angle := randf() * TAU
		enemy.global_position = global_position + Vector2.from_angle(angle) * spawn_radius
		enemy.setup(_get_crystal_mite_data())
		get_parent().add_child(enemy)
		total_spawned += 1
	# Spawn Ore Shard groups
	for g in range(ore_shard_groups):
		var group_angle := randf() * TAU
		var group_center := global_position + Vector2.from_angle(group_angle) * spawn_radius
		for s in range(shards_per_group):
			var enemy_scene := _build_enemy_scene()
			var enemy: CharacterBody2D = enemy_scene.instantiate()
			var offset := Vector2.from_angle(randf() * TAU) * randf_range(5, 20)
			enemy.global_position = group_center + offset
			enemy.setup(_get_ore_shard_data())
			get_parent().add_child(enemy)
			total_spawned += 1
	wave_spawned.emit(total_spawned)


# === T1 Entity Data (from 13_balance_t1.md section 9) ===

func _get_crystal_mite_data() -> EnemyData:
	var e := EnemyData.new()
	e.id = "crystal_mite"; e.display_name = "Crystal Mite"
	e.color = Color(0.6, 0.8, 0.9)
	e.faction = EnemyData.Faction.MINERAL_ENTITY
	e.archetype = EnemyData.Archetype.RUSHER
	e.tier = 1
	e.health = 10.0; e.damage = 4.0; e.move_speed = 80.0
	e.attack_range = 28.0; e.attack_speed = 1.0; e.aggro_range = 400.0
	e.leash_range = 0.0  # No leash
	return e


func _get_ore_shard_data() -> EnemyData:
	var e := EnemyData.new()
	e.id = "ore_shard"; e.display_name = "Ore Shard"
	e.color = Color(0.7, 0.5, 0.3)
	e.faction = EnemyData.Faction.MINERAL_ENTITY
	e.archetype = EnemyData.Archetype.SWARM
	e.tier = 1
	e.health = 5.0; e.damage = 2.0; e.move_speed = 100.0
	e.attack_range = 24.0; e.attack_speed = 1.5; e.aggro_range = 400.0
	e.leash_range = 0.0  # No leash
	return e


# === Higher tier entity defs (kept for future use) ===

var entity_defs: Array[Array] = []

func _build_entity_defs() -> void:
	entity_defs.resize(4)
	# T1 - now using dedicated functions above
	entity_defs[0] = [_get_ore_shard_data(), _get_crystal_mite_data()]
	# T2
	entity_defs[1] = [
		_make_entity("mineral_stalker", "Mineral Stalker", Color(0.4, 0.6, 0.5), EnemyData.Archetype.RUSHER, 2, 30.0, 6.0, 80.0, 28.0),
		_make_entity("prism_crawler", "Prism Crawler", Color(0.8, 0.6, 0.9), EnemyData.Archetype.RANGED, 2, 20.0, 5.0, 50.0, 180.0),
	]
	# T3
	entity_defs[2] = [
		_make_entity("corruption_golem", "Corruption Golem", Color(0.3, 0.25, 0.2), EnemyData.Archetype.TANK, 3, 80.0, 10.0, 35.0, 35.0),
		_make_entity("shard_spitter", "Shard Spitter", Color(0.9, 0.7, 0.4), EnemyData.Archetype.RANGED, 3, 30.0, 8.0, 55.0, 200.0),
	]
	# T4
	entity_defs[3] = [
		_make_entity("abyssal_crystal", "Abyssal Crystal", Color(0.2, 0.1, 0.3), EnemyData.Archetype.EXPLODER, 4, 40.0, 5.0, 60.0, 30.0),
		_make_entity("vein_horror", "Vein Horror", Color(0.5, 0.1, 0.15), EnemyData.Archetype.TANK, 4, 120.0, 14.0, 40.0, 32.0),
	]


func _make_entity(id: String, dname: String, color: Color, archetype: EnemyData.Archetype,
		tier: int, hp: float, dmg: float, speed: float, atk_range: float) -> EnemyData:
	var e := EnemyData.new()
	e.id = id; e.display_name = dname; e.color = color
	e.faction = EnemyData.Faction.MINERAL_ENTITY
	e.archetype = archetype; e.tier = tier
	e.health = hp; e.damage = dmg; e.move_speed = speed
	e.attack_range = atk_range; e.aggro_range = 400.0
	e.leash_range = 0.0
	e.attack_speed = 1.0
	if archetype == EnemyData.Archetype.RANGED:
		e.projectile_speed = 220.0
		e.attack_range = 200.0
	if archetype == EnemyData.Archetype.EXPLODER:
		e.explode_radius = 70.0
		e.explode_damage = hp * 0.5
	return e


func _build_enemy_scene() -> PackedScene:
	var scene := PackedScene.new()
	var root := CharacterBody2D.new()
	root.name = "Enemy"
	root.set_script(load("res://scripts/enemies/enemy_base.gd"))
	root.collision_layer = 4
	root.collision_mask = 17
	var rect := ColorRect.new()
	rect.name = "Sprite"
	rect.size = Vector2(20, 20)
	rect.position = Vector2(-10, -10)
	root.add_child(rect); rect.owner = root
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20, 20)
	col.shape = shape
	root.add_child(col); col.owner = root
	var bar := ProgressBar.new()
	bar.name = "HealthBar"
	bar.size = Vector2(20, 4)
	bar.position = Vector2(-10, -16)
	bar.show_percentage = false
	root.add_child(bar); bar.owner = root
	scene.pack(root)
	return scene
