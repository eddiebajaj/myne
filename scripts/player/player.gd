class_name Player
extends CharacterBody2D
## Top-down player. Fixed HP, armor layer, tiered pickaxe, fixed move speed.
## You're a miner, not a fighter — pickaxe does low damage, bots handle combat.

signal health_changed(current_hp: float, max_hp: float, current_armor: float, max_armor: float)
signal died

const MOVE_SPEED := 200.0              # Fixed — not upgradeable
const PICKAXE_RANGE := 48.0
const BASE_SWING_COOLDOWN := 0.35
const BASE_PICKAXE_DAMAGE := 3.0       # Low — you're a miner

enum DamageType { PHYSICAL, VENOM }

var max_health: float = 50.0           # Fixed — ~8-10 hits from enemies
var health: float = 50.0
var max_armor: float = 0.0             # From equipment (Smith / cave loot)
var armor: float = 0.0                 # Absorbs physical damage before HP. Venom bypasses.
var pickaxe_tier: int = 1              # 1-4, determines hits-to-break via lookup table
var can_swing: bool = true
var facing_dir: Vector2 = Vector2.DOWN
var is_invulnerable: bool = false

@onready var swing_timer: Timer = $SwingTimer
@onready var pickaxe_area: Area2D = $PickaxeArea
@onready var body_sprite: ColorRect = $BodySprite
@onready var pickaxe_sprite: ColorRect = $PickaxeSprite
@onready var invuln_timer: Timer = $InvulnTimer
var facing_nose: ColorRect = null


func _ready() -> void:
	_apply_upgrades()
	swing_timer.wait_time = BASE_SWING_COOLDOWN
	swing_timer.one_shot = true
	swing_timer.timeout.connect(func(): can_swing = true)
	invuln_timer.wait_time = 0.5
	invuln_timer.one_shot = true
	invuln_timer.timeout.connect(func(): is_invulnerable = false; modulate.a = 1.0)
	health = max_health
	armor = max_armor
	# Small facing indicator ("nose") so the player can read which way they're aimed.
	facing_nose = ColorRect.new()
	facing_nose.color = Color(1.0, 0.95, 0.4)
	facing_nose.size = Vector2(10, 10)
	facing_nose.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(facing_nose)
	_update_facing_visuals()
	health_changed.emit(health, max_health, armor, max_armor)


func _physics_process(_delta: float) -> void:
	var input_dir: Vector2 = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	if input_dir.length() > 0:
		# Snap facing to 4 cardinals for crisp readability.
		if absf(input_dir.x) >= absf(input_dir.y):
			facing_dir = Vector2(signf(input_dir.x), 0.0)
		else:
			facing_dir = Vector2(0.0, signf(input_dir.y))
	velocity = input_dir.normalized() * MOVE_SPEED
	move_and_slide()
	_update_pickaxe_position()
	_update_facing_visuals()

	if Input.is_action_just_pressed("mine") and can_swing:
		swing_pickaxe()


func swing_pickaxe() -> void:
	can_swing = false
	swing_timer.start()
	# The ColorRect's rect is offset to the right of its node origin (see player.tscn),
	# so rotating the node around its origin sweeps an arc on whichever side the
	# player is facing.  Set the base rotation to face_dir first, then tween +90deg.
	var base_rot: float = facing_dir.angle()
	pickaxe_sprite.rotation = base_rot - deg_to_rad(45)
	pickaxe_sprite.visible = true
	var tween: Tween = create_tween()
	tween.tween_property(pickaxe_sprite, "rotation", base_rot + deg_to_rad(45), 0.15)
	tween.tween_callback(func():
		pickaxe_sprite.visible = false
		pickaxe_sprite.rotation = 0.0
	)
	# Hit everything in pickaxe area
	for body in pickaxe_area.get_overlapping_bodies():
		if body.has_method("take_hit"):
			body.take_hit(1)  # Ore nodes: 1 hit per swing regardless of tier (tier affects total hits needed)
		if body.has_method("take_damage"):
			body.take_damage(BASE_PICKAXE_DAMAGE + pickaxe_tier, DamageType.PHYSICAL)


func take_damage(amount: float, damage_type: int = DamageType.PHYSICAL) -> void:
	if is_invulnerable:
		return
	var remaining := amount
	# Armor absorbs physical damage. Venom bypasses armor entirely.
	if damage_type == DamageType.PHYSICAL and armor > 0:
		var absorbed := minf(armor, remaining)
		armor -= absorbed
		remaining -= absorbed
	if remaining > 0:
		health -= remaining
	is_invulnerable = true
	invuln_timer.start()
	modulate.a = 0.5
	health_changed.emit(health, max_health, armor, max_armor)
	if health <= 0:
		_die()


func _die() -> void:
	died.emit()
	GameManager.die()


func _update_pickaxe_position() -> void:
	pickaxe_area.position = facing_dir * PICKAXE_RANGE
	pickaxe_area.rotation = facing_dir.angle()


func _update_facing_visuals() -> void:
	if facing_nose == null:
		return
	# Position the nose just outside the body (14px half-extent) in facing_dir.
	var nose_center: Vector2 = facing_dir * 18.0
	facing_nose.position = nose_center - facing_nose.size * 0.5


func _apply_upgrades() -> void:
	var levels: Dictionary = Inventory.upgrade_levels
	pickaxe_tier = levels.get("pickaxe_tier", 1)
	max_armor = levels.get("armor_value", 0.0)
	armor = max_armor
