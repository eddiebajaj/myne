class_name EnemyBase
extends CharacterBody2D
## Base enemy with faction-aware targeting and archetype behavior hooks.
## Fauna: territorial, limited leash. Mineral Entity: relentless, ore-attracted.

signal enemy_killed(enemy: EnemyBase)

var data: EnemyData
var health: float = 30.0
var attack_timer: float = 0.0
var target: Node2D = null
var spawn_position: Vector2 = Vector2.ZERO  # For leash calculation
var burn_timer: float = 0.0
var burn_dps: float = 0.0
var slow_timer: float = 0.0
var slow_mult: float = 1.0
var poison_timer: float = 0.0
var poison_dps: float = 0.0
var poison_ramp: float = 0.0

@onready var sprite: ColorRect = $Sprite
@onready var health_bar: ProgressBar = $HealthBar


func _ready() -> void:
	add_to_group("enemies")
	spawn_position = global_position
	if data:
		setup(data)


func setup(enemy_data: EnemyData) -> void:
	data = enemy_data
	health = data.health
	if sprite:
		sprite.color = data.color
	if health_bar:
		health_bar.max_value = health
		health_bar.value = health


func _physics_process(delta: float) -> void:
	attack_timer -= delta
	_process_status_effects(delta)
	_find_target()
	if target and is_instance_valid(target):
		var dist := global_position.distance_to(target.global_position)
		# Leash check for fauna
		if data and data.faction == EnemyData.Faction.FAUNA and data.leash_range > 0:
			if global_position.distance_to(spawn_position) > data.leash_range:
				target = null
				_return_to_spawn(delta)
				return
		if dist <= data.attack_range:
			_attack()
		else:
			_move_toward_target(delta)
	else:
		target = null
		velocity = Vector2.ZERO


func _find_target() -> void:
	if data == null:
		return
	var nearest: Node2D = null
	var nearest_dist := data.aggro_range
	if data.faction == EnemyData.Faction.MINERAL_ENTITY:
		# Mineral entities prioritize player (attracted to ore)
		for node in get_tree().get_nodes_in_group("player"):
			if node is Node2D:
				var dist := global_position.distance_to(node.global_position)
				if dist < nearest_dist:
					nearest_dist = dist
					nearest = node
	else:
		# Fauna: target nearest threat (player or bots in range)
		for node in get_tree().get_nodes_in_group("player"):
			if node is Node2D:
				var dist := global_position.distance_to(node.global_position)
				if dist < nearest_dist:
					nearest_dist = dist
					nearest = node
		for node in get_tree().get_nodes_in_group("bots"):
			if node is Node2D:
				var dist := global_position.distance_to(node.global_position)
				if dist < nearest_dist:
					nearest_dist = dist
					nearest = node
	target = nearest


func _move_toward_target(_delta: float) -> void:
	if target and is_instance_valid(target):
		var speed := data.move_speed * slow_mult
		velocity = global_position.direction_to(target.global_position) * speed
		move_and_slide()


func _return_to_spawn(_delta: float) -> void:
	var dist := global_position.distance_to(spawn_position)
	if dist > 5.0:
		velocity = global_position.direction_to(spawn_position) * data.move_speed
		move_and_slide()
	else:
		velocity = Vector2.ZERO


func _attack() -> void:
	if attack_timer > 0:
		return
	attack_timer = 1.0 / data.attack_speed
	if target and target.has_method("take_damage"):
		target.take_damage(data.damage, data.damage_type)
	if sprite:
		var tween := create_tween()
		sprite.color = Color.WHITE
		tween.tween_property(sprite, "color", data.color if data else Color.RED, 0.15)


func take_damage(amount: float, _damage_type: int = 0) -> void:
	health -= amount
	if health_bar:
		health_bar.value = health
	if sprite:
		var tween := create_tween()
		sprite.color = Color.WHITE
		tween.tween_property(sprite, "color", data.color if data else Color.RED, 0.1)
	if health <= 0:
		_on_death()


func _on_death() -> void:
	enemy_killed.emit(self)
	queue_free()


# === Status Effects (applied by bot mineral effects) ===

func apply_burn(dps: float, duration: float) -> void:
	burn_dps = dps
	burn_timer = duration


func apply_slow(mult: float, duration: float) -> void:
	slow_mult = clampf(1.0 - mult, 0.2, 1.0)
	slow_timer = duration


func apply_poison(dps: float, duration: float) -> void:
	poison_dps = dps
	poison_timer = duration
	poison_ramp = 0.0


func _process_status_effects(delta: float) -> void:
	# Burn
	if burn_timer > 0:
		burn_timer -= delta
		health -= burn_dps * delta
		if health_bar:
			health_bar.value = health
		if health <= 0:
			_on_death()
			return
	# Slow decay
	if slow_timer > 0:
		slow_timer -= delta
		if slow_timer <= 0:
			slow_mult = 1.0
	# Poison (ramps)
	if poison_timer > 0:
		poison_timer -= delta
		poison_ramp += delta * 0.5
		health -= (poison_dps + poison_ramp) * delta
		if health_bar:
			health_bar.value = health
		if health <= 0:
			_on_death()
			return
