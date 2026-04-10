class_name MiningRig
extends BotBase
## Static mining bot. Automatically mines the nearest ore node.


func _find_target() -> void:
	if target and is_instance_valid(target):
		if global_position.distance_to(target.global_position) > attack_range * 1.2:
			target = null
	if target == null:
		target = _get_nearest_in_group("ore_nodes", attack_range)


func _act(_delta: float) -> void:
	if attack_timer <= 0 and target and is_instance_valid(target):
		attack_timer = 1.0 / attack_speed
		if target.has_method("take_hit"):
			target.take_hit(1)
		if sprite:
			var base_color := sprite.color
			var tween := create_tween()
			sprite.color = Color.ORANGE
			tween.tween_property(sprite, "color", base_color, 0.15)
