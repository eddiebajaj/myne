class_name CombatDrone
extends BotBase
## Follower defense bot. Follows the player, attacks nearby enemies.

var follow_target: Node2D = null
const FOLLOW_DISTANCE := 60.0
const FOLLOW_SPEED_MULT := 1.2


func _ready() -> void:
	super._ready()
	await get_tree().process_frame
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		follow_target = players[0]


func _find_target() -> void:
	if target and is_instance_valid(target):
		if global_position.distance_to(target.global_position) > attack_range * 1.5:
			target = null
	if target == null:
		target = _get_nearest_in_group("enemies", attack_range)


func _act(_delta: float) -> void:
	if attack_timer <= 0 and target and is_instance_valid(target):
		attack_timer = 1.0 / attack_speed
		# Fire a red projectile instead of instant damage
		_fire_projectile_at(target, Color.RED)
		# Visual flash on the drone itself
		if sprite:
			var base_color := sprite.color
			var tween := create_tween()
			sprite.color = Color.RED
			tween.tween_property(sprite, "color", base_color, 0.1)
	# Move toward enemy
	if target and is_instance_valid(target):
		var dist := global_position.distance_to(target.global_position)
		if dist > attack_range * 0.3:
			velocity = global_position.direction_to(target.global_position) * data.move_speed
			move_and_slide()


func _idle(_delta: float) -> void:
	if follow_target and is_instance_valid(follow_target):
		var dist := global_position.distance_to(follow_target.global_position)
		if dist > FOLLOW_DISTANCE:
			velocity = global_position.direction_to(follow_target.global_position) * data.move_speed * FOLLOW_SPEED_MULT
		else:
			velocity = Vector2.ZERO
		move_and_slide()
