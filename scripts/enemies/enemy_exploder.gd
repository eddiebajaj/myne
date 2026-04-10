class_name EnemyExploder
extends EnemyBase
## Charges at target and explodes on death, dealing AoE damage.

var charging: bool = false
const CHARGE_SPEED_MULT := 1.8
const DETONATE_RANGE := 25.0


func _move_toward_target(_delta: float) -> void:
	if not target or not is_instance_valid(target):
		return
	var dist := global_position.distance_to(target.global_position)
	var speed := data.move_speed * slow_mult
	# Start charging when close
	if dist < data.aggro_range * 0.6:
		charging = true
	if charging:
		speed *= CHARGE_SPEED_MULT
		# Visual: pulse red
		if sprite and Engine.get_physics_frames() % 10 == 0:
			sprite.color = Color.RED if sprite.color != Color.RED else data.color
	velocity = global_position.direction_to(target.global_position) * speed
	move_and_slide()
	# Detonate on contact
	if dist < DETONATE_RANGE:
		_explode()


func _attack() -> void:
	# Exploders don't do normal attacks — they explode
	_explode()


func _on_death() -> void:
	_explode()


func _explode() -> void:
	# AoE damage to everything nearby
	var radius := data.explode_radius
	var dmg := data.explode_damage
	for node in get_tree().get_nodes_in_group("player"):
		if node is Node2D and global_position.distance_to(node.global_position) < radius:
			if node.has_method("take_damage"):
				node.take_damage(dmg, data.damage_type)
	for node in get_tree().get_nodes_in_group("bots"):
		if node is Node2D and global_position.distance_to(node.global_position) < radius:
			if node.has_method("take_damage"):
				node.take_damage(dmg, data.damage_type)
	# Visual: expand and fade
	if sprite:
		var tween := create_tween()
		tween.tween_property(self, "scale", Vector2(3, 3), 0.15)
		tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.15)
		tween.tween_callback(func():
			enemy_killed.emit(self)
			queue_free()
		)
	else:
		enemy_killed.emit(self)
		queue_free()
