extends Node2D
## Controller for the mining floor scene. Wires up player, generator, HUD, and bots.

@onready var floor_generator: FloorGenerator = $FloorGenerator
@onready var player: Player = $Player
@onready var camera: Camera2D = $Player/Camera2D
@onready var hud: Control = $CanvasLayer/MiningHUD
@onready var bot_placer: BotPlacer = $BotPlacer


func _ready() -> void:
	player.add_to_group("player")
	# Position player near stairs up
	player.position = Vector2(120, 120)
	# Wire up HUD
	hud.set_player(player)
	hud.set_bot_placer(bot_placer)
	# Camera
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(FloorGenerator.FLOOR_WIDTH)
	camera.limit_bottom = int(FloorGenerator.FLOOR_HEIGHT)
