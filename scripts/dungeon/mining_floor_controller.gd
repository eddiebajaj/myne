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
