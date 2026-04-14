extends PermanentBot
## Striker permanent bot. Melee glass cannon — high damage, short range, no projectile.
## Damage is applied directly on contact.


func _act(_delta: float) -> void:
	# Move toward enemy
	if target and is_instance_valid(target):
		var dist := global_position.distance_to(target.global_position)
		if dist > attack_range * 0.6:
			velocity = global_position.direction_to(target.global_position) * _get_move_speed()
			move_and_slide()
		else:
			velocity = Vector2.ZERO
		# Melee attack when in range
		if attack_timer <= 0 and dist <= attack_range:
			attack_timer = 1.0 / attack_speed
			if target.has_method("take_damage"):
				if target is EnemyBase:
					target.take_damage(damage, 0, "bot")
				else:
					target.take_damage(damage, 0)
			if sprite:
				var base_color := sprite.color
				var tween := create_tween()
				sprite.color = Color.WHITE
				tween.tween_property(sprite, "color", base_color, 0.1)
