class_name FloorGenerator
extends Node2D
## Generates a single dungeon floor — open room with ore nodes, rocks, stairs, caves, portals.
## Ore spawns are tier-gated by depth. ~25% of nodes get a mineral modifier.
## Rocks hide stairs down (1 rock), treasure (1-2 rocks), rest are empty.

const FLOOR_WIDTH := 1400.0
const FLOOR_HEIGHT := 1000.0
const WALL_THICKNESS := 32.0

var ore_types: Array[OreData] = []
var all_minerals: Array[MineralData] = []
var ore_node_scene: PackedScene
var portal_scene: PackedScene
var cave_scene: PackedScene
var stairs_scene: PackedScene
var rock_scene: PackedScene
var floor_time: float = 0.0  # Track time on floor for rock portal trigger
var _occupied_positions: Array[Dictionary] = []  # Each entry: {"pos": Vector2, "radius": float}
var stairs_up_position: Vector2 = Vector2.ZERO  # Set by _spawn_stairs_up(); consumed by controller + wanderer spawner
var _current_template: Dictionary = {}  # Active floor template (from FloorTemplates.TEMPLATES)

@onready var walls: Node2D = $Walls
@onready var ore_container: Node2D = $OreNodes
@onready var entities: Node2D = $Entities


func _ready() -> void:
	_create_ore_types()
	all_minerals = MineralData.get_all_minerals()
	_build_scenes()
	generate_floor()


func _process(delta: float) -> void:
	floor_time += delta


func generate_floor() -> void:
	floor_time = 0.0
	_occupied_positions.clear()
	_current_template = _pick_template()
	_create_walls()
	_create_interior_walls()
	# Stairs-up first so it reserves its slot before anything else claims it.
	_spawn_stairs_up()
	_spawn_ore_nodes()
	_spawn_rocks()
	_spawn_floor_wanderers()
	if randf() < GameManager.get_cave_chance():
		_spawn_cave()
	# Portal spawner for B3F+
	if GameManager.current_floor >= 3:
		_spawn_portal()
	# Blueprint drops — Scout blueprint on B4 (first visit only).
	if GameManager.current_floor == 4 and not ("scout" in Inventory.blueprints):
		_spawn_blueprint("scout", "Scout")


# === Ore spawning ===

func _spawn_ore_nodes() -> void:
	var density := GameManager.get_ore_density()
	var count := int(22 * density) + randi_range(-3, 4)
	var ore_zone = _current_template["zones"].get("ore") if not _current_template.is_empty() else null
	for i in range(count):
		var ore := pick_ore_for_depth()
		if ore == null:
			continue
		var mineral: MineralData = null
		var mineral_roll := _get_mineral_chance()
		# Check for Lucky Strike artifact
		if Inventory.has_artifact("lucky_strike"):
			mineral_roll += 0.15
		if randf() < mineral_roll:
			mineral = all_minerals[randi() % all_minerals.size()]
		var pos: Vector2 = _reserve_position(60.0, 40.0, 20, ore_zone)
		spawn_ore_node_at(pos, ore, mineral)


func _get_mineral_chance() -> float:
	var floor_num: int = GameManager.current_floor
	if floor_num <= 3:
		return 0.05
	elif floor_num <= 5:
		return 0.15
	else:
		return 0.25


func spawn_ore_node_at(pos: Vector2, ore: OreData, mineral: MineralData = null) -> void:
	var node: StaticBody2D = ore_node_scene.instantiate()
	node.global_position = pos
	node.setup(ore, mineral)
	ore_container.add_child(node)


func pick_ore_for_depth() -> OreData:
	var floor_num := GameManager.current_floor
	var valid: Array[OreData] = []
	var total_weight := 0.0
	for ore in ore_types:
		if floor_num >= ore.min_depth and floor_num <= ore.max_depth:
			valid.append(ore)
			total_weight += ore.rarity
	if valid.is_empty():
		return null
	var roll := randf() * total_weight
	var cumulative := 0.0
	for ore in valid:
		cumulative += ore.rarity
		if roll <= cumulative:
			return ore
	return valid[-1]


func get_rare_ores() -> Array[OreData]:
	## Returns specialist/high-tier ores valid for this depth (cave rewards).
	var floor_num := GameManager.current_floor
	var rare: Array[OreData] = []
	for ore in ore_types:
		if floor_num >= ore.min_depth and floor_num <= ore.max_depth:
			if ore.specialist or ore.tier >= GameManager.get_current_tier():
				rare.append(ore)
	if rare.is_empty() and not ore_types.is_empty():
		rare.append(ore_types[-1])
	return rare


# === Stairs ===

func _spawn_stairs_up() -> void:
	## Stairs up are always visible from the start. Position owned by template.
	var up: Area2D = stairs_scene.instantiate()
	up.stair_type = Stairs.StairType.UP
	var pos: Vector2 = _current_template["stairs_up"] if not _current_template.is_empty() else Vector2(100, 100)
	# Reserve the template position so nothing else spawns on top.
	_occupied_positions.append({"pos": pos, "radius": 80.0})
	up.position = pos
	stairs_up_position = pos
	entities.add_child(up)


func spawn_stairs_down_at(pos: Vector2) -> void:
	## Called when a rock hiding stairs is broken.
	var down: Area2D = stairs_scene.instantiate()
	down.stair_type = Stairs.StairType.DOWN
	down.position = pos
	entities.add_child(down)


# === Rocks (from 13_balance_t1.md section 5b) ===

func _spawn_rocks() -> void:
	## 14-20 rocks per floor. 1 hides stairs down, 1-2 hide treasure, rest are empty.
	var total_rocks := randi_range(14, 20)
	var treasure_count := randi_range(1, 2)
	# Assign rock types
	var rock_types: Array[String] = []
	rock_types.append("stairs")
	for i in range(treasure_count):
		rock_types.append("treasure")
	while rock_types.size() < total_rocks:
		rock_types.append("empty")
	# Shuffle
	rock_types.shuffle()
	# Zone lookups for biased spawning
	var zones: Dictionary = _current_template["zones"] if not _current_template.is_empty() else {}
	var stairs_down_zone = zones.get("stairs_down_rock")
	var rock_zone = zones.get("rocks")
	# Spawn rocks spread across the floor
	for i in range(rock_types.size()):
		var zone = null
		if rock_types[i] == "stairs":
			zone = stairs_down_zone
		elif rock_zone != null:
			zone = rock_zone
		var pos: Vector2 = _reserve_position(50.0, 38.0, 20, zone)
		var rock: StaticBody2D = rock_scene.instantiate()
		rock.global_position = pos
		rock.rock_content = rock_types[i]
		rock.floor_generator = self
		ore_container.add_child(rock)


# === Rock portal trigger chance (from 13_balance_t1.md section 4c) ===

func get_rock_portal_chance() -> float:
	## Returns the chance (0.0-1.0) that breaking a rock triggers a portal.
	var floor_num := GameManager.current_floor
	if floor_num < 3:
		return 0.0
	# Base chance: 5% at B3F, +2.5% per floor
	var base := 0.05 + (floor_num - 3) * 0.025
	# Time bonus: +0.1% per second, cap 10%
	var time_bonus := minf(floor_time * 0.001, 0.10)
	# Ore bonus: +0.25% per ore, cap 8%
	var ore_bonus := minf(Inventory.get_used_slots() * 0.0025, 0.08)
	# Mineral ore bonus: +2% per mineral piece
	var mineral_bonus := 0.0
	for slot in Inventory.get_ore_stacks():
		if slot.mineral != null:
			mineral_bonus += slot.quantity * 0.02
	return base + time_bonus + ore_bonus + mineral_bonus


func spawn_rock_triggered_portal(pos: Vector2) -> void:
	## Rock-triggered portal: shorter warning (1.5s), spawns a single wave.
	## Spawns at the rock's old position (rock was just destroyed) — no collision check
	## needed since the rock freed its slot.
	var portal: Node2D = portal_scene.instantiate()
	portal.position = pos + Vector2(randf_range(-40, 40), randf_range(-40, 40))
	# Override to rock-triggered behavior
	portal.set_meta("rock_triggered", true)
	entities.add_child(portal)


# === Cave ===

func _spawn_cave() -> void:
	var cave_zone = _current_template["zones"].get("cave") if not _current_template.is_empty() else null
	var cave: Area2D = cave_scene.instantiate()
	cave.position = _reserve_position(100.0, 80.0, 20, cave_zone)
	entities.add_child(cave)


# === Portal ===

func _spawn_portal() -> void:
	var portal: Node2D = portal_scene.instantiate()
	portal.position = _reserve_position(80.0, 50.0)
	entities.add_child(portal)


func _spawn_blueprint(bot_id: String, display_name: String) -> void:
	## Drop a walk-over blueprint pickup at a random free floor position.
	var bp: Area2D = Area2D.new()
	bp.set_script(load("res://scripts/dungeon/blueprint_pickup.gd"))
	bp.position = _reserve_position(50.0, 40.0)
	entities.add_child(bp)
	bp.setup(bot_id, display_name)


# === Enemy spawning (used by caves and floor wanderers) ===

const T1_WANDERER_COMPOSITIONS: Dictionary = {
	1: ["cave_beetle"],
	2: ["cave_beetle", "tunnel_rat"],
	3: ["cave_beetle", "crystal_mite"],
	4: ["cave_beetle", "tunnel_rat", "crystal_mite"],
	5: ["cave_beetle", "cave_beetle", "ore_shard"],
}


func spawn_enemy_at(pos: Vector2) -> EnemyBase:
	var enemy_scene := _build_enemy_scene()
	var enemy: EnemyBase = enemy_scene.instantiate()
	enemy.global_position = pos
	var data := _random_enemy()
	enemy.setup(data)
	entities.add_child(enemy)
	return enemy


func spawn_enemy_by_id(pos: Vector2, id: String) -> EnemyBase:
	var enemy_scene := _build_enemy_scene()
	var enemy: EnemyBase = enemy_scene.instantiate()
	enemy.global_position = pos
	var data: EnemyData = _make_enemy_data(id)
	enemy.setup(data)
	entities.add_child(enemy)
	return enemy


func _make_enemy_data(id: String) -> EnemyData:
	var e := EnemyData.new()
	match id:
		"cave_beetle":
			e.id = "cave_beetle"; e.display_name = "Cave Beetle"; e.color = Color(0.4, 0.3, 0.2)
			e.faction = EnemyData.Faction.FAUNA
			e.health = 12.0; e.damage = 5.0; e.move_speed = 90.0
			e.attack_range = 28.0; e.attack_speed = 0.8
			e.aggro_range = 180.0; e.leash_range = 300.0
			e.behavior = "wander_aggro"
		"tunnel_rat":
			e.id = "tunnel_rat"; e.display_name = "Tunnel Rat"; e.color = Color(0.5, 0.4, 0.3)
			e.faction = EnemyData.Faction.FAUNA
			e.health = 6.0; e.damage = 3.0; e.move_speed = 110.0
			e.attack_range = 24.0; e.attack_speed = 1.2
			e.aggro_range = 160.0; e.leash_range = 250.0
			e.behavior = "passive_wander"
		"crystal_mite":
			e.id = "crystal_mite"; e.display_name = "Crystal Mite"; e.color = Color(0.7, 0.9, 1.0)
			e.faction = EnemyData.Faction.MINERAL_ENTITY
			e.health = 10.0; e.damage = 4.0; e.move_speed = 80.0
			e.attack_range = 28.0; e.attack_speed = 1.0
			e.aggro_range = 400.0; e.leash_range = 0.0
			e.behavior = "always_aggro"
		"ore_shard":
			e.id = "ore_shard"; e.display_name = "Ore Shard"; e.color = Color(0.9, 0.7, 1.0)
			e.faction = EnemyData.Faction.MINERAL_ENTITY
			e.health = 5.0; e.damage = 2.0; e.move_speed = 100.0
			e.attack_range = 24.0; e.attack_speed = 1.5
			e.aggro_range = 400.0; e.leash_range = 0.0
			e.behavior = "always_aggro"
		_:
			# Fallback — treat unknown id as cave beetle
			e.id = "cave_beetle"; e.display_name = "Cave Beetle"; e.color = Color(0.4, 0.3, 0.2)
			e.faction = EnemyData.Faction.FAUNA
			e.health = 12.0; e.damage = 5.0; e.move_speed = 90.0
			e.attack_range = 28.0; e.attack_speed = 0.8
			e.aggro_range = 180.0; e.leash_range = 300.0
			e.behavior = "wander_aggro"
	return e


func _spawn_floor_wanderers() -> void:
	## Spawn floor-start wandering enemies per sprint_02b spec §1.
	## Only T1 compositions are defined; deeper tiers fall back to existing portal/wave flow.
	var floor_num: int = GameManager.current_floor
	if not T1_WANDERER_COMPOSITIONS.has(floor_num):
		return
	var comp: Array = T1_WANDERER_COMPOSITIONS[floor_num]
	# Wanderers must stay away from the player's spawn (which is the stairs-up).
	var player_spawn: Vector2 = stairs_up_position
	var placed: Array[Vector2] = []
	for id in comp:
		var pos: Vector2 = _roll_wanderer_position(player_spawn, placed)
		spawn_enemy_by_id(pos, id)
		placed.append(pos)


func _roll_wanderer_position(player_spawn: Vector2, placed: Array[Vector2]) -> Vector2:
	## Rejection-roll a wanderer spawn position: 300-650 px from player,
	## >=120 px from other wanderers, not too close to walls or other entities.
	## 5 retries then accept.
	var best: Vector2 = _reserve_position(60.0, 50.0)
	for attempt in range(5):
		var candidate: Vector2 = _reserve_position(60.0, 50.0)
		var d_player: float = candidate.distance_to(player_spawn)
		if d_player < 300.0 or d_player > 650.0:
			continue
		var too_close: bool = false
		for other in placed:
			if candidate.distance_to(other) < 120.0:
				too_close = true
				break
		if too_close:
			continue
		return candidate
	return best


func _random_enemy() -> EnemyData:
	var e := EnemyData.new()
	var tier := GameManager.get_current_tier()
	# Cave enemies are fauna (territorial)
	match tier:
		1:
			if randf() < 0.5:
				e.id = "cave_beetle"; e.display_name = "Cave Beetle"; e.color = Color(0.4, 0.3, 0.2)
				e.health = 12.0; e.damage = 5.0; e.move_speed = 90.0
				e.attack_range = 28.0; e.attack_speed = 0.8; e.aggro_range = 180.0; e.leash_range = 300.0
			else:
				e.id = "tunnel_rat"; e.display_name = "Tunnel Rat"; e.color = Color(0.5, 0.4, 0.3)
				e.health = 6.0; e.damage = 3.0; e.move_speed = 110.0
				e.attack_range = 24.0; e.attack_speed = 1.2; e.aggro_range = 160.0; e.leash_range = 250.0
		2:
			if randf() < 0.5:
				e.id = "rock_crab"; e.display_name = "Rock Crab"; e.color = Color(0.6, 0.5, 0.4)
				e.health = 35.0; e.damage = 5.0; e.move_speed = 45.0
			else:
				e.id = "cave_bat"; e.display_name = "Cave Bat"; e.color = Color(0.5, 0.2, 0.6)
				e.health = 18.0; e.damage = 4.0; e.move_speed = 110.0
		3:
			if randf() < 0.5:
				e.id = "stone_golem"; e.display_name = "Stone Golem"; e.color = Color(0.5, 0.45, 0.4)
				e.health = 70.0; e.damage = 10.0; e.move_speed = 35.0
			else:
				e.id = "tunnel_serpent"; e.display_name = "Tunnel Serpent"; e.color = Color(0.3, 0.5, 0.3)
				e.health = 40.0; e.damage = 7.0; e.move_speed = 80.0
		_:  # T4
			if randf() < 0.5:
				e.id = "crystal_beast"; e.display_name = "Crystal Beast"; e.color = Color(0.7, 0.8, 0.9)
				e.health = 100.0; e.damage = 12.0; e.move_speed = 50.0
			else:
				e.id = "deep_wurm"; e.display_name = "Deep Wurm"; e.color = Color(0.4, 0.3, 0.5)
				e.health = 80.0; e.damage = 15.0; e.move_speed = 60.0
	return e


# === Template Selection ===

func _pick_template() -> Dictionary:
	if GameManager.current_floor == 1:
		return FloorTemplates.TEMPLATES["open_arena"]
	var eligible := []
	var total := 0.0
	for t in FloorTemplates.TEMPLATES.values():
		if GameManager.current_floor >= t["min_floor"]:
			eligible.append(t)
			total += t["weight"]
	var roll := randf() * total
	var acc := 0.0
	for t in eligible:
		acc += t["weight"]
		if roll <= acc:
			return t
	return eligible[-1]


func _create_interior_walls() -> void:
	## Add interior walls from the current template and reserve their footprints.
	if _current_template.is_empty():
		return
	var template_walls: Array = _current_template["walls"]
	for w in template_walls:
		_add_wall(w["pos"], w["size"])
		_reserve_wall(w["pos"], w["size"])


func _reserve_wall(pos: Vector2, size: Vector2) -> void:
	## Approximate a wall rectangle with a chain of circular occupied markers so
	## rejection sampling avoids spawning entities on walls.
	## Place markers every 48px along the long axis; radius = half short axis + 24.
	var is_horizontal: bool = size.x >= size.y
	var long_len: float = size.x if is_horizontal else size.y
	var short_len: float = size.y if is_horizontal else size.x
	var marker_radius: float = short_len / 2.0 + 24.0
	var half_long: float = long_len / 2.0
	var step: float = 48.0
	var count: int = int(ceil(long_len / step)) + 1
	for i in range(count):
		var t: float = -half_long + i * step
		t = clampf(t, -half_long, half_long)
		var marker_pos: Vector2
		if is_horizontal:
			marker_pos = Vector2(pos.x + t, pos.y)
		else:
			marker_pos = Vector2(pos.x, pos.y + t)
		_occupied_positions.append({"pos": marker_pos, "radius": marker_radius})


# === Walls ===

func _create_walls() -> void:
	_add_wall(Vector2(FLOOR_WIDTH / 2, 0), Vector2(FLOOR_WIDTH + WALL_THICKNESS * 2, WALL_THICKNESS))
	_add_wall(Vector2(FLOOR_WIDTH / 2, FLOOR_HEIGHT), Vector2(FLOOR_WIDTH + WALL_THICKNESS * 2, WALL_THICKNESS))
	_add_wall(Vector2(0, FLOOR_HEIGHT / 2), Vector2(WALL_THICKNESS, FLOOR_HEIGHT))
	_add_wall(Vector2(FLOOR_WIDTH, FLOOR_HEIGHT / 2), Vector2(WALL_THICKNESS, FLOOR_HEIGHT))


func _add_wall(pos: Vector2, size: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.collision_layer = 16
	wall.position = pos
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	wall.add_child(col)
	var rect := ColorRect.new()
	rect.size = size
	rect.position = -size / 2
	rect.color = Color(0.4, 0.32, 0.25)
	wall.add_child(rect)
	walls.add_child(wall)


# === Helpers ===

func _random_floor_position(margin: float) -> Vector2:
	return Vector2(
		randf_range(WALL_THICKNESS + margin, FLOOR_WIDTH - WALL_THICKNESS - margin),
		randf_range(WALL_THICKNESS + margin, FLOOR_HEIGHT - WALL_THICKNESS - margin)
	)


func _reserve_position(margin: float, min_separation: float, max_attempts: int = 20, zone = null) -> Vector2:
	## Rejection-sample a floor position that is at least min_separation + other.radius
	## away from every previously-reserved entity. Returns the last candidate if all
	## attempts fail (no infinite loop). Registers the chosen position in the occupied list.
	## If zone (Rect2) is provided, tries in-zone first for half the attempts, then
	## falls back to arena-wide.
	var zone_attempts: int = max_attempts / 2 if zone is Rect2 else 0
	var candidate: Vector2 = _random_floor_position(margin)
	for attempt in range(max_attempts):
		if attempt < zone_attempts and zone is Rect2:
			candidate = _random_zone_position(zone, margin)
		else:
			candidate = _random_floor_position(margin)
		var ok: bool = true
		for entry in _occupied_positions:
			var other_pos: Vector2 = entry["pos"]
			var other_radius: float = entry["radius"]
			if candidate.distance_to(other_pos) < (min_separation + other_radius):
				ok = false
				break
		if ok:
			break
	_occupied_positions.append({"pos": candidate, "radius": min_separation})
	return candidate


func _random_zone_position(zone: Rect2, margin: float) -> Vector2:
	## Sample a random position within the given zone rect, clamped to arena bounds.
	var min_x: float = maxf(zone.position.x, WALL_THICKNESS + margin)
	var max_x: float = minf(zone.position.x + zone.size.x, FLOOR_WIDTH - WALL_THICKNESS - margin)
	var min_y: float = maxf(zone.position.y, WALL_THICKNESS + margin)
	var max_y: float = minf(zone.position.y + zone.size.y, FLOOR_HEIGHT - WALL_THICKNESS - margin)
	return Vector2(
		randf_range(min_x, max_x),
		randf_range(min_y, max_y)
	)


# === Ore type definitions (8 ores, 4 tiers) ===

func _create_ore_types() -> void:
	# T1: B1F - B5F
	ore_types.append(_make_ore("iron", "Iron", Color(0.7, 0.7, 0.75), 1, false, 2, 1, 5, 4.0))
	ore_types.append(_make_ore("copper", "Copper", Color(0.8, 0.5, 0.2), 1, true, 3, 1, 5, 2.0))
	# T2: B6F - B10F
	ore_types.append(_make_ore("crystal", "Crystal", Color(0.6, 0.8, 0.9), 2, false, 6, 6, 10, 4.0))
	ore_types.append(_make_ore("silver", "Silver", Color(0.85, 0.85, 0.9), 2, true, 8, 6, 10, 2.0))
	# T3: B11F - B15F
	ore_types.append(_make_ore("gold_ore", "Gold", Color(1.0, 0.84, 0.0), 3, false, 15, 11, 15, 4.0))
	ore_types.append(_make_ore("obsidian", "Obsidian", Color(0.15, 0.1, 0.2), 3, true, 20, 11, 15, 2.0))
	# T4: B16F - B20F
	ore_types.append(_make_ore("diamond", "Diamond", Color(0.6, 0.9, 1.0), 4, false, 35, 16, 20, 4.0))
	ore_types.append(_make_ore("mythril", "Mythril", Color(0.5, 0.7, 1.0), 4, true, 50, 16, 20, 2.0))


func _make_ore(id: String, dname: String, color: Color, tier: int, specialist: bool, value: int, min_d: int, max_d: int, rarity: float) -> OreData:
	var ore := OreData.new()
	ore.id = id; ore.display_name = dname; ore.color = color
	ore.tier = tier; ore.specialist = specialist; ore.value = value
	ore.min_depth = min_d; ore.max_depth = max_d; ore.rarity = rarity
	return ore


# === Scene building (programmatic) ===

func _build_scenes() -> void:
	ore_node_scene = _build_ore_node_scene()
	stairs_scene = _build_stairs_scene()
	cave_scene = _build_cave_scene()
	portal_scene = _build_portal_scene()
	rock_scene = _build_rock_scene()


func _build_ore_node_scene() -> PackedScene:
	var scene := PackedScene.new()
	var root := StaticBody2D.new()
	root.name = "OreNode"
	root.set_script(load("res://scripts/dungeon/ore_node.gd"))
	root.collision_layer = 2
	root.collision_mask = 0
	var rect := ColorRect.new()
	rect.name = "Sprite"
	rect.size = Vector2(32, 32)
	rect.position = Vector2(-16, -16)
	root.add_child(rect); rect.owner = root
	# Mineral glow (slightly larger, behind sprite)
	var glow := ColorRect.new()
	glow.name = "MineralGlow"
	glow.size = Vector2(38, 38)
	glow.position = Vector2(-19, -19)
	glow.visible = false
	glow.show_behind_parent = true
	root.add_child(glow); glow.owner = root
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(32, 32)
	col.shape = shape
	root.add_child(col); col.owner = root
	var bar := ProgressBar.new()
	bar.name = "HealthBar"
	bar.size = Vector2(30, 4)
	bar.position = Vector2(-15, -22)
	bar.show_percentage = false; bar.visible = false
	root.add_child(bar); bar.owner = root
	scene.pack(root)
	return scene


func _build_rock_scene() -> PackedScene:
	var scene := PackedScene.new()
	var root := StaticBody2D.new()
	root.name = "Rock"
	root.set_script(load("res://scripts/dungeon/rock.gd"))
	root.collision_layer = 2  # Same as ore nodes so pickaxe hits them
	root.collision_mask = 0
	var rect := ColorRect.new()
	rect.name = "Sprite"
	rect.size = Vector2(28, 28)
	rect.position = Vector2(-14, -14)
	rect.color = Color(0.4, 0.35, 0.3)
	root.add_child(rect); rect.owner = root
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(28, 28)
	col.shape = shape
	root.add_child(col); col.owner = root
	scene.pack(root)
	return scene


func _build_stairs_scene() -> PackedScene:
	var scene := PackedScene.new()
	var root := Area2D.new()
	root.name = "Stairs"
	root.set_script(load("res://scripts/dungeon/stairs.gd"))
	root.collision_layer = 32
	root.collision_mask = 1
	var rect := ColorRect.new()
	rect.name = "Sprite"
	rect.size = Vector2(40, 40)
	rect.position = Vector2(-20, -20)
	root.add_child(rect); rect.owner = root
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(40, 40)
	col.shape = shape
	root.add_child(col); col.owner = root
	var lbl := Label.new()
	lbl.name = "Label"
	lbl.position = Vector2(-40, 24)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(lbl); lbl.owner = root
	scene.pack(root)
	return scene


func _build_cave_scene() -> PackedScene:
	var scene := PackedScene.new()
	var root := Area2D.new()
	root.name = "CaveEntrance"
	root.set_script(load("res://scripts/dungeon/cave_entrance.gd"))
	root.collision_layer = 64
	root.collision_mask = 1
	var rect := ColorRect.new()
	rect.name = "Sprite"
	rect.size = Vector2(48, 48)
	rect.position = Vector2(-24, -24)
	root.add_child(rect); rect.owner = root
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(48, 48)
	col.shape = shape
	root.add_child(col); col.owner = root
	var lbl := Label.new()
	lbl.name = "Label"
	lbl.position = Vector2(-50, 28)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(lbl); lbl.owner = root
	scene.pack(root)
	return scene


func _build_portal_scene() -> PackedScene:
	var scene := PackedScene.new()
	var root := Node2D.new()
	root.name = "PortalSpawner"
	root.set_script(load("res://scripts/enemies/portal_spawner.gd"))
	var rect := ColorRect.new()
	rect.name = "Sprite"
	rect.size = Vector2(36, 36)
	rect.position = Vector2(-18, -18)
	rect.color = Color(0.8, 0.1, 0.8)
	root.add_child(rect); rect.owner = root
	var timer := Timer.new()
	timer.name = "Timer"
	root.add_child(timer); timer.owner = root
	scene.pack(root)
	return scene


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
