class_name SpriteUtil
extends RefCounted
## Shared helper for loading optional pixel-art textures with a graceful fallback.
##
## Two modes supported:
## 1. Legacy `try_load_sprite(path, size)` — whole PNG per entity (used by
##    ore_node, enemy_base, mining_floor_controller for bots).
## 2. Atlas mode via `load_atlas_region` / `try_sprite_or_colorrect` — slices
##    a region out of a Kenney spritesheet. See `scripts/util/asset_paths.gd`
##    for the atlas_info Dictionary shape.
##
## Missing textures are expected (pack may not be installed yet) — callers
## keep their ColorRect fallback and the game stays visually identical.


static func try_load_sprite(path: String, size: Vector2 = Vector2.ZERO) -> Sprite2D:
	## Returns a Sprite2D with the texture loaded, or null if the texture is
	## missing / fails to load. Does not push errors — missing sprites are expected.
	if path.is_empty():
		return null
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		return null
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = true
	if size != Vector2.ZERO:
		var tex_size: Vector2 = tex.get_size()
		if tex_size.x > 0 and tex_size.y > 0:
			sprite.scale = Vector2(size.x / tex_size.x, size.y / tex_size.y)
	return sprite


static func load_atlas_region(sheet_path: String, rect: Rect2) -> AtlasTexture:
	## Loads a base Texture2D from `sheet_path` and wraps it in an AtlasTexture
	## with the given region. Returns null if the sheet is missing / fails to load.
	if sheet_path.is_empty():
		return null
	if not ResourceLoader.exists(sheet_path):
		return null
	var base_tex: Texture2D = load(sheet_path) as Texture2D
	if base_tex == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = base_tex
	atlas.region = rect
	return atlas


static func try_sprite_or_colorrect(
	parent: Node,
	atlas_info: Dictionary,
	fallback_color: Color,
	size: Vector2
) -> Node:
	## Creates a child of `parent` showing either the Kenney atlas region
	## (if the sheet loads) or a ColorRect fallback of `fallback_color`/`size`.
	## Returns the created node so the caller can position it.
	##
	## `atlas_info` shape: {"sheet": String, "col": int, "row": int}
	## Missing keys / missing file both fall through to the ColorRect path.
	var atlas: AtlasTexture = null
	if atlas_info != null and atlas_info.has("sheet") and atlas_info.has("col") and atlas_info.has("row"):
		var sheet: String = String(atlas_info["sheet"])
		var col: int = int(atlas_info["col"])
		var row: int = int(atlas_info["row"])
		atlas = load_atlas_region(sheet, AssetPaths.tile_rect(col, row))

	if atlas != null:
		# Parent type decides 2D node vs UI node.
		if parent is Control:
			var tex_rect := TextureRect.new()
			tex_rect.texture = atlas
			tex_rect.custom_minimum_size = size
			tex_rect.size = size
			tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
			tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			parent.add_child(tex_rect)
			return tex_rect
		else:
			var sprite := Sprite2D.new()
			sprite.texture = atlas
			sprite.centered = true
			# Kenney tiles are 16x16; scale uniformly to hit requested size.
			if size.x > 0 and size.y > 0:
				sprite.scale = Vector2(
					size.x / float(AssetPaths.TILE_SIZE),
					size.y / float(AssetPaths.TILE_SIZE)
				)
			parent.add_child(sprite)
			return sprite

	# Fallback: ColorRect centered (for 2D) or filling parent (for Control).
	var rect := ColorRect.new()
	rect.color = fallback_color
	rect.size = size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not (parent is Control):
		# Center the ColorRect on the 2D parent's origin to match Sprite2D behavior.
		rect.position = -size * 0.5
	parent.add_child(rect)
	return rect
