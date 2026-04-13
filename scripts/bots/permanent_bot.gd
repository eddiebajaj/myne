class_name PermanentBot
extends BotBase
## Permanent companion bot. Follows player, fights enemies.
## Unlike disposable bots: no ore/battery cost, knocked out on death (not lost).

signal bot_knocked_out(bot_id: String)

var bot_id: String = ""
var display_name: String = ""
var knocked_out: bool = false

var follow_target: Node2D = null
var follow_distance: float = 50.0
const FOLLOW_SPEED_MULT := 1.2


func _ready() -> void:
	# Skip BotBase._ready() data-driven setup — permanent bots configure stats directly.
	await get_tree().process_frame
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		follow_target = players[0]
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health
	# Bot Overclock artifact
	if Inventory.has_artifact("bot_overclock"):
		attack_speed *= 1.3


func setup_permanent(id: String, dname: String, hp: float, dmg: float, atk_range: float,
		atk_speed: float, move_spd: float, follow_dist: float) -> void:
	bot_id = id
	display_name = dname
	max_health = hp
	health = hp
	damage = dmg
	attack_range = atk_range
	attack_speed = atk_speed
	follow_distance = follow_dist
	# Store move_speed on a local var (BotBase uses data.move_speed, but we have no BotData)
	set_meta("move_speed", move_spd)


func _get_move_speed() -> float:
	return get_meta("move_speed", 120.0)


func _find_target() -> void:
	if target and is_instance_valid(target):
		if global_position.distance_to(target.global_position) > attack_range * 1.5:
			target = null
	if target == null:
		target = _get_nearest_in_group("enemies", attack_range)


func _act(_delta: float) -> void:
	if attack_timer <= 0 and target and is_instance_valid(target):
		attack_timer = 1.0 / attack_speed
		# Fire a cyan projectile
		_fire_projectile_at(target, Color(0.3, 0.9, 1.0))
		# Visual flash
		if sprite:
			var base_color := sprite.color
			var tween := create_tween()
			sprite.color = Color.WHITE
			tween.tween_property(sprite, "color", base_color, 0.1)
	# Move toward enemy
	if target and is_instance_valid(target):
		var dist := global_position.distance_to(target.global_position)
		if dist > attack_range * 0.3:
			velocity = global_position.direction_to(target.global_position) * _get_move_speed()
			move_and_slide()


func _idle(_delta: float) -> void:
	if follow_target and is_instance_valid(follow_target):
		var dist := global_position.distance_to(follow_target.global_position)
		if dist > follow_distance:
			velocity = global_position.direction_to(follow_target.global_position) * _get_move_speed() * FOLLOW_SPEED_MULT
		else:
			velocity = Vector2.ZERO
		move_and_slide()


func take_damage(amount: float, _damage_type: int = 0) -> void:
	health -= amount
	if health_bar:
		health_bar.value = health
	if sprite:
		var tween := create_tween()
		sprite.color = Color.RED
		tween.tween_property(sprite, "color", Color(0.3, 0.9, 1.0), 0.2)
	_spawn_damage_number(amount, Color(1.0, 0.6, 0.0))
	if health <= 0:
		_destroy()


func _destroy() -> void:
	## Permanent bots are knocked out, not freed from data.
	knocked_out = true
	Inventory.knock_out_bot(bot_id)
	bot_knocked_out.emit(bot_id)
	bot_destroyed.emit(self)
	queue_free()
