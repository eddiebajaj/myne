class_name OreNode
extends StaticBody2D
## A mineable ore node. Hits-to-break depends on pickaxe tier vs ore tier.
## ~20-30% of nodes carry a mineral modifier (visual glow).

signal mined(ore: OreData, mineral: MineralData)

const ORE_PICKUP_SCENE: PackedScene = preload("res://scenes/dungeon/ore_pickup.tscn")

var ore_data: OreData
var mineral: MineralData  # null = plain ore
var hits_remaining: int = 1

@onready var sprite: ColorRect = $Sprite
@onready var health_bar: ProgressBar = $HealthBar
@onready var mineral_glow: ColorRect = $MineralGlow


func _ready() -> void:
	add_to_group("ore_nodes")
	if ore_data:
		setup(ore_data, mineral)


func setup(data: OreData, mineral_mod: MineralData = null) -> void:
	ore_data = data
	mineral = mineral_mod
	# Hits based on player's pickaxe tier vs ore tier
	var pickaxe_tier: int = 1
	if Inventory:
		pickaxe_tier = Inventory.upgrade_levels.get("pickaxe_tier", 1)
	hits_remaining = OreData.get_hits_to_break(pickaxe_tier, data.tier)
	if sprite:
		sprite.color = data.color
	if health_bar:
		health_bar.max_value = hits_remaining
		health_bar.value = hits_remaining
		health_bar.visible = hits_remaining > 1
	# Mineral visual
	if mineral_glow:
		if mineral:
			mineral_glow.visible = true
			mineral_glow.color = Color(mineral.color, 0.4)
		else:
			mineral_glow.visible = false


func take_hit(power: int = 1) -> void:
	hits_remaining -= power
	if health_bar:
		health_bar.value = hits_remaining
	# Shake feedback
	var original_pos := position
	var tween := create_tween()
	tween.tween_property(self, "position", original_pos + Vector2(3, 0), 0.04)
	tween.tween_property(self, "position", original_pos + Vector2(-3, 0), 0.04)
	tween.tween_property(self, "position", original_pos, 0.04)
	if hits_remaining <= 0:
		_break()


func _break() -> void:
	mined.emit(ore_data, mineral)
	# Spawn one OrePickup per piece yielded. Currently 1 piece per node
	# (13_balance_t1.md §5a); loop in case that scales up later.
	_spawn_pickups(1)
	# Pop animation — ore node itself disappears
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.08)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.12)
	tween.tween_callback(queue_free)


func _spawn_pickups(count: int) -> void:
	if ore_data == null:
		return
	var origin: Vector2 = global_position
	# Parent pickups to our parent container (OreNodes) so they persist
	# after this node is queue_freed. The container lives for the whole floor.
	var container: Node = get_parent()
	if container == null:
		return
	for i in range(count):
		var pickup: OrePickup = ORE_PICKUP_SCENE.instantiate()
		pickup.setup(ore_data, mineral, origin)
		container.add_child(pickup)
		var angle: float = randf() * TAU
		var radius: float = randf_range(6.0, 14.0)
		var offset: Vector2 = Vector2(cos(angle), sin(angle)) * radius
		pickup.start_pop(offset)
