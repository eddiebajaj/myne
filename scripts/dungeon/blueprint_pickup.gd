class_name BlueprintPickup
extends Area2D
## Walk-over pickup for a bot blueprint. Adds [bot_id] to Inventory.blueprints
## and shows a popup on the player. Single-use, queue_frees on pickup.

var bot_id: String = ""
var display_name: String = ""

var _sprite: ColorRect = null
var _base_y: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	add_to_group("blueprint_pickups")
	z_index = 5
	collision_layer = 64
	collision_mask = 1
	# Build visuals programmatically so floor_generator can spawn us without a scene.
	_sprite = ColorRect.new()
	_sprite.size = Vector2(16, 16)
	_sprite.position = Vector2(-8, -8)
	_sprite.color = Color(0.7, 0.35, 0.95)  # purple
	add_child(_sprite)
	# Glow backdrop (slightly larger)
	var glow := ColorRect.new()
	glow.size = Vector2(24, 24)
	glow.position = Vector2(-12, -12)
	glow.color = Color(0.9, 0.6, 1.0, 0.35)
	glow.show_behind_parent = true
	add_child(glow)
	# Label floating above
	var label := Label.new()
	label.text = "Blueprint"
	label.position = Vector2(-30, -26)
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.95, 0.8, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 2)
	add_child(label)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20, 20)
	shape.shape = rect
	add_child(shape)
	body_entered.connect(_on_body_entered)
	_base_y = position.y


func setup(id: String, dname: String) -> void:
	bot_id = id
	display_name = dname


func _process(delta: float) -> void:
	_time += delta
	if _sprite:
		_sprite.position.y = -8 + sin(_time * 3.0) * 3.0


func _on_body_entered(body: Node) -> void:
	if not (body is Player):
		return
	if bot_id == "":
		queue_free()
		return
	if not (bot_id in Inventory.blueprints):
		Inventory.blueprints.append(bot_id)
	var popup_name: String = display_name if display_name != "" else bot_id.capitalize()
	if body.has_method("show_pickup_popup"):
		body.show_pickup_popup("%s Blueprint! Build at Lab." % popup_name)
	queue_free()
