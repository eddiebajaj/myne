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

# Wander / provocation state (sprint 2b)
var wander_target: Vector2 = Vector2.ZERO
var wander_idle_timer: float = 0.0
var has_wander_target: bool = false
var has_been_provoked: bool = false

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
	_try_apply_texture()


func _try_apply_texture() -> void:
	## If a pixel-art texture exists at res://resources/sprites/enemies/<id>.png,
	## add a Sprite2D child and hide the ColorRect fallback. No-op if missing.
	if data == null or data.id.is_empty():
		return
	if has_node("BodyTexture"):
		return  # setup() can be called more than once; don't double-add
	var tex_path: String = "res://resources/sprites/enemies/%s.png" % data.id
	var sprite_size: Vector2 = Vector2(20, 20)
	if sprite:
		sprite_size = sprite.size
	var tex_sprite: Sprite2D = SpriteUtil.try_load_sprite(tex_path, sprite_size)
	if tex_sprite:
		tex_sprite.name = "BodyTexture"
		add_child(tex_sprite)
		if sprite:
			sprite.visible = false


func _physics_process(delta: float) -> void:
	attack_timer -= delta
	_process_status_effects(delta)
	# Behavior dispatch: passive_wander ignores aggro scanning unless provoked.
	var should_scan: bool = true
	if data and data.behavior == "passive_wander" and not has_been_provoked:
		should_scan = false
	if should_scan:
		_find_target()
	else:
		target = null
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
		_idle_behavior(delta)


func _idle_behavior(delta: float) -> void:
	## Dispatched when no target. Wander for fauna, stand still for mineral.
	if data == null:
		velocity = Vector2.ZERO
		return
	var effective_behavior: String = data.behavior
	# Provoked passive_wander behaves like wander_aggro for the rest of its life.
	if effective_behavior == "passive_wander" and has_been_provoked:
		effective_behavior = "wander_aggro"
	match effective_behavior:
		"always_aggro":
			velocity = Vector2.ZERO
		"passive_wander", "wander_aggro":
			_wander(delta)
		_:
			velocity = Vector2.ZERO


func _wander(delta: float) -> void:
	## Pick a random point within 150 px of spawn_position, walk at 50% speed,
	## idle 0.8-2.0s on arrival, repeat.
	if wander_idle_timer > 0.0:
		wander_idle_timer -= delta
		velocity = Vector2.ZERO
		return
	if not has_wander_target:
		var offset: Vector2 = Vector2.from_angle(randf() * TAU) * randf_range(20.0, 150.0)
		wander_target = spawn_position + offset
		has_wander_target = true
	var to_target: Vector2 = wander_target - global_position
	if to_target.length() <= 10.0:
		has_wander_target = false
		wander_idle_timer = randf_range(0.8, 2.0)
		velocity = Vector2.ZERO
		return
	var speed: float = data.move_speed * 0.5 * slow_mult
	velocity = to_target.normalized() * speed
	move_and_slide()


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
	# Attack flash: red tint on sprite
	if sprite:
		var flash_tween := create_tween()
		sprite.modulate = Color.RED
		flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	# Lunge: move 8px toward target then snap back
	if target and is_instance_valid(target):
		var lunge_dir := global_position.direction_to(target.global_position)
		var original_pos := global_position
		var lunge_tween := create_tween()
		lunge_tween.tween_property(self, "global_position", original_pos + lunge_dir * 8.0, 0.05)
		lunge_tween.tween_property(self, "global_position", original_pos, 0.10)


func take_damage(amount: float, _damage_type: int = 0, source_type: String = "player") -> void:
	# Any damage flips passive_wander enemies into aggro for the rest of their life.
	has_been_provoked = true
	health -= amount
	if health_bar:
		health_bar.value = health
	if sprite:
		var tween := create_tween()
		sprite.color = Color.WHITE
		tween.tween_property(sprite, "color", data.color if data else Color.RED, 0.1)
	# Floating damage number
	var dmg_color: Color
	match source_type:
		"bot":
			dmg_color = Color.YELLOW
		_:
			dmg_color = Color.WHITE
	_spawn_damage_number(amount, dmg_color)
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


func _spawn_damage_number(amount: float, color: Color) -> void:
	var label := Label.new()
	label.text = str(int(amount))
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 20
	var start_offset := Vector2(-8.0, -28.0)
	label.position = start_offset
	label.modulate = Color(1, 1, 1, 1)
	add_child(label)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", start_offset.y - 30.0, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(func(): label.queue_free())
