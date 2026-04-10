class_name PortalSpawner
extends Node2D
## Spawns Mineral Entity enemies. Rate driven by time + ore volume + mineral quality.

signal wave_spawned(count: int)
signal portal_warning

@export var base_interval: float = 12.0
@export var enemies_per_wave: int = 2
@export var max_waves: int = 5
@export var spawn_radius: float = 40.0
@export var warning_time: float = 2.0  # Seconds of warning before spawning

var waves_spawned: int = 0
var warning_active: bool = false

@onready var timer: Timer = $Timer
@onready var sprite: ColorRect = $Sprite


func _ready() -> void:
	_build_entity_defs()
	timer.wait_time = _calculate_interval()
	timer.timeout.connect(_on_timer)
	timer.start()
	# Pulse visual
	var tween := create_tween().set_loops()
	tween.tween_property(sprite, "modulate:a", 0.4, 0.8)
	tween.tween_property(sprite, "modulate:a", 1.0, 0.8)


func _calculate_interval() -> float:
	## Dynamic spawn rate: faster with more ore + mineral ore.
	var interval := base_interval
	var ore_count := Inventory.get_used_slots()
	var mineral_count := 0
	for slot in Inventory.get_ore_stacks():
		if slot.mineral != null:
			mineral_count += slot.quantity
	# More ore = faster spawns
	interval -= ore_count * 0.3
	# Mineral ore weighs extra
	interval -= mineral_count * 0.5
	# Floor depth factor
	interval -= GameManager.current_floor * 0.2
	return maxf(interval, 3.0)


func _on_timer() -> void:
	if waves_spawned >= max_waves:
		timer.stop()
		return
	if not warning_active:
		# Show warning first
		warning_active = true
		portal_warning.emit()
		_show_warning()
		timer.wait_time = warning_time
		timer.start()
	else:
		# Spawn wave
		warning_active = false
		_spawn_wave()
		timer.wait_time = _calculate_interval()
		timer.start()


func _show_warning() -> void:
	if sprite:
		var tween := create_tween().set_loops(3)
		tween.tween_property(sprite, "modulate", Color(1, 0.3, 0.3), 0.15)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)


func _spawn_wave() -> void:
	waves_spawned += 1
	var count := enemies_per_wave + (waves_spawned / 2)
	for i in range(count):
		var enemy_scene := _build_enemy_scene()
		var enemy: CharacterBody2D = enemy_scene.instantiate()
		var angle := randf() * TAU
		enemy.global_position = global_position + Vector2.from_angle(angle) * spawn_radius
		var def := _random_entity()
		enemy.setup(def)
		get_parent().add_child(enemy)
	wave_spawned.emit(count)


# === Mineral Entity definitions by tier ===

var entity_defs: Array[Array] = []  # [tier_index] = Array[EnemyData]

func _build_entity_defs() -> void:
	entity_defs.resize(4)
	# T1
	entity_defs[0] = [
		_make_entity("ore_shard", "Ore Shard", Color(0.7, 0.5, 0.3), EnemyData.Archetype.SWARM, 1, 8.0, 2.0, 90.0, 24.0),
		_make_entity("crystal_mite", "Crystal Mite", Color(0.6, 0.8, 0.9), EnemyData.Archetype.RUSHER, 1, 15.0, 4.0, 70.0, 28.0),
	]
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


func _random_entity() -> EnemyData:
	var tier_idx := clampi(GameManager.get_current_tier() - 1, 0, 3)
	var defs: Array = entity_defs[tier_idx]
	return defs[randi() % defs.size()]


func _make_entity(id: String, dname: String, color: Color, archetype: EnemyData.Archetype,
		tier: int, hp: float, dmg: float, speed: float, atk_range: float) -> EnemyData:
	var e := EnemyData.new()
	e.id = id; e.display_name = dname; e.color = color
	e.faction = EnemyData.Faction.MINERAL_ENTITY
	e.archetype = archetype; e.tier = tier
	e.health = hp; e.damage = dmg; e.move_speed = speed
	e.attack_range = atk_range; e.aggro_range = 400.0
	e.leash_range = 0.0  # Entities don't leash
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
	# Pick script based on archetype of a random entity for this tier
	# We'll use base for most, ranged/exploder get subclasses
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
