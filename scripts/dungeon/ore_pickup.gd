class_name OrePickup
extends Area2D
## World pickup for ore dropped when an ore node breaks.
## Area2D collision is only used to be part of the scene tree — magnet and
## collect logic both run in _physics_process and operate on plain position
## vectors so the logic would port cleanly to 3D.

const MAGNET_RADIUS: float = 140.0
const INSTANT_RADIUS: float = 14.0
const INITIAL_SPEED: float = 60.0
const MAX_SPEED: float = 520.0
const ACCEL: float = 900.0
const POP_DURATION: float = 0.18
const BOUNCE_COOLDOWN: float = 0.6

var ore_data: OreData
var mineral: MineralData  # null = plain ore

var _magnet_eligible: bool = false
var _speed: float = INITIAL_SPEED
var _base_y: float = 0.0
var _time: float = 0.0
var _bounce_timer: float = 0.0

@onready var sprite: ColorRect = $Sprite
@onready var glow: ColorRect = $MineralGlow


func _ready() -> void:
	add_to_group("ore_pickups")
	z_index = 5
	# Start small for pop animation
	scale = Vector2.ZERO
	if sprite and ore_data:
		sprite.color = ore_data.color
	if glow:
		if mineral:
			glow.visible = true
			glow.color = Color(mineral.color, 0.4)
		else:
			glow.visible = false


func setup(data: OreData, mineral_mod: MineralData, origin: Vector2) -> void:
	## Call before adding to tree. [origin] is the ore node's global_position.
	ore_data = data
	mineral = mineral_mod
	global_position = origin


func start_pop(offset: Vector2) -> void:
	## Play the scatter/pop tween from the pickup's current position to
	## current + offset. Enables magnet after POP_DURATION.
	var origin: Vector2 = global_position
	var target: Vector2 = origin + offset
	_base_y = target.y
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, 0.12)
	tween.tween_property(self, "global_position", target, POP_DURATION)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(func(): _magnet_eligible = true)
	# Pulse the glow for mineral pickups
	if mineral and glow:
		var pulse: Tween = create_tween().set_loops()
		pulse.tween_property(glow, "modulate:a", 0.55, 0.4)
		pulse.tween_property(glow, "modulate:a", 0.25, 0.4)


func _process(delta: float) -> void:
	_time += delta
	# Bobbing is disabled during magnet pull so the two systems don't fight.
	# We only bob when the player is far enough away that the magnet isn't active.
	if not _magnet_eligible or _bounce_timer > 0.0:
		return
	var player: Node2D = _find_player()
	if player == null:
		position.y = _base_y + sin(_time * 3.0) * 1.5
		return
	var dist: float = global_position.distance_to(player.global_position)
	if dist > MAGNET_RADIUS:
		position.y = _base_y + sin(_time * 3.0) * 1.5


func _physics_process(delta: float) -> void:
	if _bounce_timer > 0.0:
		_bounce_timer -= delta
		return
	if not _magnet_eligible:
		return
	var player: Node2D = _find_player()
	if player == null:
		return
	_apply_magnet(player.global_position, delta)


func _apply_magnet(player_pos: Vector2, delta: float) -> void:
	## Keeps magnet logic isolated and vector-based (3D-port friendly).
	var to_player: Vector2 = player_pos - global_position
	var dist: float = to_player.length()
	if dist <= INSTANT_RADIUS:
		_try_collect(player_pos)
		return
	if dist <= MAGNET_RADIUS:
		_speed = minf(_speed + ACCEL * delta, MAX_SPEED)
		var pull_dir: Vector2 = to_player.normalized()
		global_position += pull_dir * _speed * delta
		_base_y = global_position.y
	else:
		_speed = INITIAL_SPEED


func _try_collect(player_pos: Vector2) -> void:
	if ore_data == null:
		queue_free()
		return
	if not Inventory.can_add_ore(ore_data, mineral, 1):
		_bounce_away(player_pos)
		return
	Inventory.add_ore(ore_data, mineral, 1)
	queue_free()


func _bounce_away(player_pos: Vector2) -> void:
	## Backpack full — nudge the pickup away so it doesn't snap right back.
	var away_dir: Vector2 = (global_position - player_pos).normalized()
	if away_dir == Vector2.ZERO:
		away_dir = Vector2.RIGHT
	var target: Vector2 = global_position + away_dir * 40.0
	_bounce_timer = BOUNCE_COOLDOWN
	_magnet_eligible = false
	var tween: Tween = create_tween()
	tween.tween_property(self, "global_position", target, 0.15)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		_base_y = global_position.y
		_magnet_eligible = true
	)


func _find_player() -> Node2D:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0] as Node2D
