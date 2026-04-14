extends PermanentBot
## Miner permanent bot. Follows player, auto-mines nearby ore nodes.
## No combat — targets ore_nodes within attack_range and calls take_hit().


func _find_target() -> void:
	if target and is_instance_valid(target):
		if global_position.distance_to(target.global_position) > attack_range * 1.2:
			target = null
	if target == null:
		target = _get_nearest_in_group("ore_nodes", attack_range)


func _act(_delta: float) -> void:
	if not (target and is_instance_valid(target)):
		return
	var dist := global_position.distance_to(target.global_position)
	# Move within mining range
	if dist > 30.0:
		velocity = global_position.direction_to(target.global_position) * _get_move_speed()
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
