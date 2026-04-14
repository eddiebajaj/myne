extends Node2D
## Controller for the mining floor scene. Wires up player, generator, HUD, and bots.

@onready var floor_generator: FloorGenerator = $FloorGenerator
@onready var player: Player = $Player
@onready var camera: Camera2D = $Player/Camera2D
@onready var hud: Control = $CanvasLayer/MiningHUD

# Per-bot texture filename mapping. Backpack bot's id is "backpack_bot" but the
# sprite file is just "backpack.png" for brevity.
const BOT_TEXTURE_FILES: Dictionary = {
	"scout": "scout.png",
	"miner": "miner.png",
	"striker": "striker.png",
	"backpack_bot": "backpack.png",
}


func _ready() -> void:
	# Ensure game is not paused (in case we came from a paused build menu)
	get_tree().paused = false
	player.add_to_group("player")
	# Position player near stairs up (randomized per sprint 2c). Offset slightly
	# downward so the player doesn't overlap the stair collider on spawn.
	player.position = floor_generator.stairs_up_position + Vector2(0, 40)
	# Wire up HUD
	hud.set_player(player)
	# Camera
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(FloorGenerator.FLOOR_WIDTH)
	camera.limit_bottom = int(FloorGenerator.FLOOR_HEIGHT)
	# Spawn permanent companion bots from run party
	_respawn_permanent_bots()


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
	## Applies Lab upgrade levels (hp_upgrade_level / damage_upgrade_level) to
	## the base stats for the bot type.
	var bot_id: String = entry.get("id", "")
	var dname: String = entry.get("display_name", "Companion")
	var hp_up: int = int(entry.get("hp_upgrade_level", 0))
	var dmg_up: int = int(entry.get("damage_upgrade_level", 0))

	# Per-bot base stats (Sprint 5 Round 2 spec §1)
	var atk_range: float = 130.0
	var atk_speed: float = 1.2
	var move_spd: float = 120.0
	var follow_dist: float = 50.0
	var bot_color: Color = Color(0.3, 0.9, 1.0)
	var bot_size: Vector2 = Vector2(28, 28)
	var script_path: String = "res://scripts/bots/permanent_bot.gd"

	match bot_id:
		"miner":
			atk_range = 80.0
			atk_speed = 1.0 / 1.5  # one mining hit every 1.5s
			move_spd = 100.0
			follow_dist = 50.0
			bot_color = Color(0.9, 0.7, 0.3)  # amber/yellow
			script_path = "res://scripts/bots/permanent_bot_miner.gd"
		"striker":
			atk_range = 45.0
			atk_speed = 0.8
			move_spd = 110.0
			follow_dist = 50.0
			bot_color = Color(1.0, 0.35, 0.35)  # red
			script_path = "res://scripts/bots/permanent_bot_striker.gd"
		"backpack_bot":
			atk_range = 0.0
			atk_speed = 0.0
			move_spd = 100.0
			follow_dist = 50.0
			bot_color = Color(0.5, 0.35, 0.2)  # brown
			script_path = "res://scripts/bots/permanent_bot_backpack.gd"
		"scout", _:
			atk_range = 130.0
			atk_speed = 1.2
			move_spd = 120.0
			follow_dist = 50.0
			bot_color = Color(0.3, 0.9, 1.0)  # cyan
			script_path = "res://scripts/bots/permanent_bot.gd"

	# Upgrade bonuses apply on top of base stats stored in the entry
	var base_max_hp: float = float(entry.get("max_health", 40.0)) + hp_up * 10.0
	var base_damage: float = float(entry.get("damage", 0.0)) + dmg_up * 1.0
	var current_hp: float = minf(float(entry.get("health", base_max_hp)), base_max_hp)
	# Keep the entry's max_health in sync so HUD / merge respawn use upgraded value
	entry["max_health"] = base_max_hp
	entry["damage"] = base_damage

	# Build the scene tree
	var root := CharacterBody2D.new()
	root.name = dname.replace(" ", "")
	root.set_script(load(script_path))
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
	root.setup_permanent(bot_id, dname, base_max_hp, base_damage, atk_range, atk_speed, move_spd, follow_dist)
	root.health = current_hp
	if root.health_bar:
		root.health_bar.value = current_hp
	# Tint the sprite using the per-bot color resolved above
	var sprite_rect: ColorRect = root.get_node_or_null("Sprite") as ColorRect
	if sprite_rect:
		sprite_rect.color = bot_color
	# Optional pixel-art texture. If res://resources/sprites/bots/<file> exists,
	# add a Sprite2D and hide the ColorRect fallback.
	var tex_file: String = BOT_TEXTURE_FILES.get(bot_id, "")
	if tex_file != "":
		var tex_path: String = "res://resources/sprites/bots/" + tex_file
		var tex_sprite: Sprite2D = SpriteUtil.try_load_sprite(tex_path, bot_size)
		if tex_sprite:
			tex_sprite.name = "BodyTexture"
			root.add_child(tex_sprite)
			if sprite_rect:
				sprite_rect.visible = false
	root.add_to_group("bots")
	root.add_to_group("permanent_bots")
