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
	_try_apply_texture()
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


func _try_apply_texture() -> void:
	## Visual priority, in order:
	##   1. Kenney atlas region from AssetPaths.ORE_SPRITES[ore.id]
	##   2. Per-ore PNG at res://resources/sprites/ores/<id>.png (legacy path)
	##   3. ColorRect fallback (sprite.color = ore.color)
	## Mineral modifier is indicated via (a) mineral_glow ColorRect (handled in
	## setup()) and (b) `modulate` on the textured sprite so the ore itself
	## picks up the mineral tint — e.g. fire ore runs red, ice ore runs cyan.
	if ore_data == null or ore_data.id.is_empty():
		return
	var existing := get_node_or_null("BodyTexture") as Sprite2D
	if existing:
		existing.queue_free()

	var sprite_size: Vector2 = Vector2(32, 32)
	if sprite:
		sprite_size = sprite.size

	var tex_sprite: Sprite2D = _try_load_atlas_sprite(sprite_size)
	if tex_sprite == null:
		# Legacy per-ore PNG path (kept so custom art still overrides the atlas).
		var tex_path: String = "res://resources/sprites/ores/%s.png" % ore_data.id
		tex_sprite = SpriteUtil.try_load_sprite(tex_path, sprite_size)

	if tex_sprite:
		tex_sprite.name = "BodyTexture"
		# Mineral ores get their tint applied to the sprite itself.
		if mineral != null:
			tex_sprite.modulate = mineral.color
		add_child(tex_sprite)
		if sprite:
			sprite.visible = false
	else:
		# No texture available — keep the ColorRect fallback visible.
		if sprite:
			sprite.visible = true


func _try_load_atlas_sprite(_size: Vector2) -> Sprite2D:
	## Returns a centered Sprite2D showing the Kenney ore tile for this ore id,
	## or null if ORE_SPRITES has no entry or the atlas fails to load.
	## [_size] is threaded for future auto-scaling off the ColorRect slot;
	## currently we use a fixed ~16px ore scale that reads well on a 32px tile.
	if not AssetPaths.ORE_SPRITES.has(ore_data.id):
		return null
	var info: Dictionary = AssetPaths.ORE_SPRITES[ore_data.id]
	if not (info.has("sheet") and info.has("col") and info.has("row")):
		return null
	var rect: Rect2 = AssetPaths.tile_rect(int(info["col"]), int(info["row"]))
	var atlas: AtlasTexture = SpriteUtil.load_atlas_region(String(info["sheet"]), rect)
	if atlas == null:
		return null
	var tex_sprite := Sprite2D.new()
	tex_sprite.texture = atlas
	tex_sprite.centered = true
	# Kenney tile is 16px. Ores read best at ~16-20px (a bit smaller than
	# 32px walls/floor) so they feel like objects *on* the tile, not *as*
	# the tile. TUNE: bump to 1.25 if Eddie wants ores chunkier.
	tex_sprite.scale = Vector2(1.0, 1.0)
	return tex_sprite


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
		# Sprint 2 bug fix: previous radius (6-14) let pickups stack on one pixel,
		# especially when multiple nodes broke near each other.  Wider ring plus a
		# small per-pickup jitter ensures visual separation.
		var angle: float = randf() * TAU
		var radius: float = randf_range(16.0, 28.0)
		var jitter: Vector2 = Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0))
		var offset: Vector2 = Vector2(cos(angle), sin(angle)) * radius + jitter
		pickup.start_pop(offset)
