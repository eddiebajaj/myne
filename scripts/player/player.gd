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
	health_changed.emit(health, max_health, armor, max_armor)


func _physics_process(_delta: float) -> void:
	var input_dir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	if input_dir.length() > 0:
		facing_dir = input_dir.normalized()
	velocity = input_dir.normalized() * MOVE_SPEED
	move_and_slide()
	_update_pickaxe_position()

	if Input.is_action_just_pressed("mine") and can_swing:
		swing_pickaxe()


func swing_pickaxe() -> void:
	can_swing = false
	swing_timer.start()
	# Animate
	var tween := create_tween()
	pickaxe_sprite.visible = true
	tween.tween_property(pickaxe_sprite, "rotation", pickaxe_sprite.rotation + deg_to_rad(90), 0.15)
	tween.tween_callback(func():
		pickaxe_sprite.visible = false
		pickaxe_sprite.rotation = 0
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


func _apply_upgrades() -> void:
	var levels: Dictionary = Inventory.upgrade_levels
	pickaxe_tier = levels.get("pickaxe_tier", 1)
	max_armor = levels.get("armor_value", 0.0)
	armor = max_armor
