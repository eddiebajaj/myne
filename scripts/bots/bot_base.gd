class_name BotBase
extends CharacterBody2D
## Base class for all bots. Stats scale with ore tier. Mineral adds special effects.

signal bot_destroyed(bot: BotBase)

var data: BotData
var ore_tier: int = 1
var mineral: MineralData  # null = plain bot
var health: float = 50.0
var max_health: float = 50.0
var damage: float = 8.0
var attack_range: float = 150.0
var attack_speed: float = 1.0
var attack_timer: float = 0.0
var target: Node2D = null

@onready var sprite: ColorRect = $Sprite
@onready var health_bar: ProgressBar = $HealthBar


func _ready() -> void:
	if data:
		setup_with_tier(data, ore_tier, mineral)


func setup_with_tier(bot_data: BotData, tier: int, mineral_mod: MineralData = null) -> void:
	data = bot_data
	ore_tier = tier
	mineral = mineral_mod
	# Scale stats by ore tier
	max_health = data.get_scaled_health(tier)
	health = max_health
	damage = data.get_scaled_damage(tier)
	attack_range = data.get_scaled_range(tier)
	attack_speed = data.base_attack_speed
	# Earth mineral: bonus HP
	if mineral and mineral.type == MineralData.MineralType.EARTH:
		var bonus := 0.3 * MineralData.get_effect_strength(ore_tier)
		max_health *= (1.0 + bonus)
		health = max_health
	# Wind mineral: bonus attack speed
	if mineral and mineral.type == MineralData.MineralType.WIND:
		var bonus := 0.2 * MineralData.get_effect_strength(ore_tier)
		attack_speed *= (1.0 + bonus)
	# Bot Overclock artifact
	if Inventory.has_artifact("bot_overclock"):
		attack_speed *= 1.3
	if sprite:
		sprite.color = data.color
		if mineral:
			# Tint sprite slightly with mineral color
			sprite.color = data.color.lerp(mineral.color, 0.3)
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health


# Backward compat — old callers using setup()
func setup(bot_data: BotData) -> void:
	setup_with_tier(bot_data, 1, null)


func _physics_process(delta: float) -> void:
	attack_timer -= delta
	_find_target()
	if target and is_instance_valid(target):
		_act(delta)
	else:
		target = null
		_idle(delta)


func _find_target() -> void:
	pass


func _act(_delta: float) -> void:
	pass


func _idle(_delta: float) -> void:
	pass


func _deal_damage_to(target_node: Node2D) -> void:
	## Apply damage with mineral effects.
	if not target_node.has_method("take_damage"):
		return
	# Determine damage type
	var dmg_type: int = 0  # PHYSICAL
	if mineral and mineral.type == MineralData.MineralType.VENOM:
		dmg_type = 1  # VENOM — bypasses armor
	target_node.take_damage(damage, dmg_type)
	# Apply mineral on-hit effects
	if mineral:
		_apply_mineral_on_hit(target_node)


func _apply_mineral_on_hit(hit_target: Node2D) -> void:
	var strength := MineralData.get_effect_strength(ore_tier)
	match mineral.type:
		MineralData.MineralType.FIRE:
			# Burn: deal extra damage over time
			if hit_target.has_method("apply_burn"):
				hit_target.apply_burn(damage * 0.15 * strength, 3.0)
		MineralData.MineralType.ICE:
			# Chill: slow the enemy
			if hit_target.has_method("apply_slow"):
				hit_target.apply_slow(0.4 * strength, 2.0)
		MineralData.MineralType.THUNDER:
			# Chain: damage nearby enemies
			_chain_damage(hit_target, damage * 0.3 * strength)
		MineralData.MineralType.VENOM:
			# Poison: ramping DoT
			if hit_target.has_method("apply_poison"):
				hit_target.apply_poison(damage * 0.1 * strength, 4.0)
		# EARTH and WIND are passive (applied in setup)


func _chain_damage(origin: Node2D, chain_dmg: float) -> void:
	## Thunder effect: hit nearby enemies.
	var chain_range := 80.0
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == origin or not is_instance_valid(node):
			continue
		if node is Node2D and origin.global_position.distance_to(node.global_position) < chain_range:
			if node.has_method("take_damage"):
				node.take_damage(chain_dmg)
			break  # Chain to one extra target


func take_damage(amount: float, _damage_type: int = 0) -> void:
	health -= amount
	if health_bar:
		health_bar.value = health
	if sprite:
		var tween := create_tween()
		sprite.color = Color.RED
		var base_color: Color = data.color if data else Color.WHITE
		if mineral:
			base_color = base_color.lerp(mineral.color, 0.3)
		tween.tween_property(sprite, "color", base_color, 0.2)
	if health <= 0:
		_destroy()


func _destroy() -> void:
	# Scrap Recycler artifact: return partial ore
	if Inventory.has_artifact("scrap_recycler"):
		# Return ~30% of ore cost as the cheapest available ore type
		# (simplified: just add gold equivalent)
		if data:
			var refund := int(data.ore_count * 0.3)
			GameManager.add_gold(refund)
	bot_destroyed.emit(self)
	queue_free()


func _get_nearest_in_group(group_name: String, max_range: float) -> Node2D:
	var nearest: Node2D = null
	var nearest_dist := max_range
	for node in get_tree().get_nodes_in_group(group_name):
		if node is Node2D:
			var dist := global_position.distance_to(node.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = node
	return nearest
