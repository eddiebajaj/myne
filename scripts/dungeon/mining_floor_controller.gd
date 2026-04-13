extends Node2D
## Controller for the mining floor scene. Wires up player, generator, HUD, and bots.

@onready var floor_generator: FloorGenerator = $FloorGenerator
@onready var player: Player = $Player
@onready var camera: Camera2D = $Player/Camera2D
@onready var hud: Control = $CanvasLayer/MiningHUD
@onready var bot_placer: BotPlacer = $BotPlacer


func _ready() -> void:
	# Ensure game is not paused (in case we came from a paused build menu)
	get_tree().paused = false
	player.add_to_group("player")
	# Position player near stairs up (randomized per sprint 2c). Offset slightly
	# downward so the player doesn't overlap the stair collider on spawn.
	player.position = floor_generator.stairs_up_position + Vector2(0, 40)
	# Wire up HUD
	hud.set_player(player)
	hud.set_bot_placer(bot_placer)
	# Camera
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(FloorGenerator.FLOOR_WIDTH)
	camera.limit_bottom = int(FloorGenerator.FLOOR_HEIGHT)
	# Re-spawn follower bots that survived from the previous floor
	_respawn_follower_bots()
	# Spawn permanent companion bots from run party
	_respawn_permanent_bots()


func _respawn_follower_bots() -> void:
	## Follower bots persist across floors via Inventory.follower_bots.
	## Re-create them near the player on each new floor.
	for entry in Inventory.follower_bots:
		var bot_data: BotData = entry.get("data")
		if bot_data == null:
			continue
		var tier: int = entry.get("ore_tier", 1)
		var mineral_mod: MineralData = entry.get("mineral")
		var spawn_offset := Vector2(randf_range(-40, 40), randf_range(-40, 40))
		var spawn_pos := player.position + spawn_offset
		bot_placer._spawn_bot(bot_data, spawn_pos, tier, mineral_mod)


func _respawn_permanent_bots() -> void:
	## Permanent bots persist across floors via Inventory.run_party.
	## Re-create them near the player on each new floor. Skip knocked-out bots.
	## Skip bots that are currently merged (absorbed by player).
	for entry in Inventory.run_party:
		if entry.get("knocked_out", false):
			continue
		# If merge is active, skip the merged bot (it's absorbed by the player)
		if GameManager.merge_active and entry.get("id", "") == "scout":
			continue
		var spawn_offset := Vector2(randf_range(-50, 50), randf_range(-50, 50))
		var spawn_pos := player.position + spawn_offset
		_spawn_permanent_bot(entry, spawn_pos)


func _spawn_permanent_bot(entry: Dictionary, pos: Vector2) -> void:
	## Build a permanent bot scene programmatically and add it to the floor.
	var bot_id: String = entry.get("id", "")
	var dname: String = entry.get("display_name", "Companion")
	var max_hp: float = entry.get("max_health", 40.0)
	var hp: float = entry.get("health", max_hp)

	# Scout-specific stats (from spec A3)
	var dmg := 5.0
	var atk_range := 130.0
	var atk_speed := 1.2
	var move_spd := 120.0
	var follow_dist := 50.0
	var bot_color := Color(0.3, 0.9, 1.0)  # bright cyan
	var bot_size := Vector2(28, 28)

	# Build the scene tree
	var root := CharacterBody2D.new()
	root.name = dname.replace(" ", "")
	root.set_script(load("res://scripts/bots/permanent_bot.gd"))
	root.collision_layer = 8
	root.collision_mask = 20

	# Sprite — 28x28 cyan
	var rect := ColorRect.new()
	rect.name = "Sprite"
	rect.size = bot_size
	rect.position = -bot_size / 2.0
	rect.color = bot_color
	root.add_child(rect)

	# Crown/star indicator — 8x8 yellow diamond above the bot
	var crown := ColorRect.new()
	crown.name = "Crown"
	crown.size = Vector2(8, 8)
	crown.position = Vector2(-4, -bot_size.y / 2.0 - 12)
	crown.color = Color(1.0, 0.9, 0.2)
	crown.rotation = deg_to_rad(45)
	root.add_child(crown)

	# Collision shape
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = bot_size
	col.shape = shape
	root.add_child(col)

	# Health bar
	var bar := ProgressBar.new()
	bar.name = "HealthBar"
	bar.size = Vector2(28, 4)
	bar.position = Vector2(-14, -20)
	bar.show_percentage = false
	root.add_child(bar)

	# Add to scene tree first so _ready can find player group
	root.global_position = pos
	add_child(root)

	# Configure the permanent bot
	root.setup_permanent(bot_id, dname, max_hp, dmg, atk_range, atk_speed, move_spd, follow_dist)
	root.health = hp
	if root.health_bar:
		root.health_bar.value = hp
	root.add_to_group("bots")
	root.add_to_group("permanent_bots")
