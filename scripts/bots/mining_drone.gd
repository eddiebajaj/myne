class_name MiningDrone
extends BotBase
## Follower mining bot. Follows the player, mines nearby ore nodes.

var follow_target: Node2D = null
const FOLLOW_DISTANCE := 50.0
const FOLLOW_SPEED_MULT := 1.2


func _ready() -> void:
	super._ready()
	await get_tree().process_frame
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		follow_target = players[0]


func _find_target() -> void:
	if target and is_instance_valid(target):
		if global_position.distance_to(target.global_position) > attack_range * 1.2:
			target = null
	if target == null:
		target = _get_nearest_in_group("ore_nodes", attack_range)


func _act(_delta: float) -> void:
	if target and is_instance_valid(target):
		var dist := global_position.distance_to(target.global_position)
		if dist > 30.0:
			velocity = global_position.direction_to(target.global_position) * data.move_speed
			move_and_slide()
		else:
			velocity = Vector2.ZERO
			if attack_timer <= 0:
				attack_timer = 1.0 / attack_speed
				if target.has_method("take_hit"):
					target.take_hit(1)
				if sprite:
					var base_color := sprite.color
					var tween := create_tween()
					sprite.color = Color.ORANGE
					tween.tween_property(sprite, "color", base_color, 0.15)


func _idle(_delta: float) -> void:
	if follow_target and is_instance_valid(follow_target):
		var dist := global_position.distance_to(follow_target.global_position)
		if dist > FOLLOW_DISTANCE:
			velocity = global_position.direction_to(follow_target.global_position) * data.move_speed * FOLLOW_SPEED_MULT
		else:
			velocity = Vector2.ZERO
		move_and_slide()
