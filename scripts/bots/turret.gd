class_name Turret
extends BotBase
## Static defense bot. Stays in place, shoots at nearby enemies.


func _find_target() -> void:
	if target and is_instance_valid(target):
		if global_position.distance_to(target.global_position) > attack_range * 1.2:
			target = null
	if target == null:
		target = _get_nearest_in_group("enemies", attack_range)


func _act(_delta: float) -> void:
	if attack_timer <= 0 and target and is_instance_valid(target):
		attack_timer = 1.0 / attack_speed
		_deal_damage_to(target)
		# Visual flash
		if sprite:
			var base_color := sprite.color
			var tween := create_tween()
			sprite.color = Color.YELLOW
			tween.tween_property(sprite, "color", base_color, 0.1)
