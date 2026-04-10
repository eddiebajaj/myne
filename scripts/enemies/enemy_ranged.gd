class_name EnemyRanged
extends EnemyBase
## Keeps distance from target, fires projectiles.

const PREFERRED_DISTANCE := 120.0
const FLEE_DISTANCE := 60.0


func _move_toward_target(_delta: float) -> void:
	if not target or not is_instance_valid(target):
		return
	var dist := global_position.distance_to(target.global_position)
	var speed := data.move_speed * slow_mult
	if dist < FLEE_DISTANCE:
		# Too close — back away
		velocity = target.global_position.direction_to(global_position) * speed
	elif dist > data.attack_range * 0.8:
		# Too far — move closer
		velocity = global_position.direction_to(target.global_position) * speed
	else:
		# Good range — strafe slightly
		var perp := global_position.direction_to(target.global_position).orthogonal()
		velocity = perp * speed * 0.5
	move_and_slide()


func _attack() -> void:
	if attack_timer > 0:
		return
	attack_timer = 1.0 / data.attack_speed
	_fire_projectile()
	if sprite:
		var tween := create_tween()
		sprite.color = Color.YELLOW
		tween.tween_property(sprite, "color", data.color, 0.15)


func _fire_projectile() -> void:
	if not target or not is_instance_valid(target):
		return
	var proj := _create_projectile()
	proj.global_position = global_position
	var dir := global_position.direction_to(target.global_position)
	proj.set_meta("direction", dir)
	proj.set_meta("speed", data.projectile_speed)
	proj.set_meta("damage", data.damage)
	proj.set_meta("damage_type", data.damage_type)
	get_parent().add_child(proj)


func _create_projectile() -> Area2D:
	var proj := Area2D.new()
	proj.collision_layer = 0
	proj.collision_mask = 9  # player + bots
	var rect := ColorRect.new()
	rect.size = Vector2(8, 8)
	rect.position = Vector2(-4, -4)
	rect.color = data.color.lightened(0.3)
	proj.add_child(rect)
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 5.0
	col.shape = shape
	proj.add_child(col)
	# Script-like behavior via process
	var script := GDScript.new()
	script.source_code = """extends Area2D
var lifetime := 3.0
func _physics_process(delta):
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
		return
	var dir: Vector2 = get_meta("direction", Vector2.ZERO)
	var spd: float = get_meta("speed", 200.0)
	position += dir * spd * delta
	for body in get_overlapping_bodies():
		if body.has_method("take_damage"):
			var dmg: float = get_meta("damage", 5.0)
			var dtype: int = get_meta("damage_type", 0)
			body.take_damage(dmg, dtype)
			queue_free()
			return
"""
	script.reload()
	proj.set_script(script)
	return proj
