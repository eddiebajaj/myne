class_name SpriteUtil
extends RefCounted
## Shared helper for loading optional pixel-art textures with a graceful fallback.
##
## Each entity type has a TEXTURE_PATH pointing to a .png under res://resources/sprites/.
## If the file exists, try_load_sprite returns a ready-to-parent Sprite2D scaled to
## target size. If not, it returns null and the caller keeps its ColorRect fallback.
##
## This keeps the game visually identical while letting us drop in AI-generated
## sprites later without code changes.


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
