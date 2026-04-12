class_name Stairs
extends Area2D
## Stairs — interact to go deeper or return to town.

enum StairType { DOWN, UP }

@export var stair_type: StairType = StairType.DOWN

@onready var sprite: ColorRect = $Sprite
@onready var label: Label = $Label
var player_in_range: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	var touch := get_node_or_null("/root/TouchControls")
	if touch:
		touch.action_a_pressed.connect(_on_touch_a)
	if stair_type == StairType.DOWN:
		sprite.color = Color(0.3, 0.3, 0.7)
		label.text = "Stairs Down [E/A]"
	else:
		sprite.color = Color(0.2, 0.7, 0.3)
		label.text = "Return to Town [E/A]"
	label.visible = false


func _process(_delta: float) -> void:
	if player_in_range and (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("action_a")):
		_do_transition()


func _on_touch_a() -> void:
	if player_in_range:
		_do_transition()


func _do_transition() -> void:
	if stair_type == StairType.DOWN:
		GameManager.go_deeper()
		# Reload the floor scene to generate a new floor
		get_tree().reload_current_scene()
	else:
		GameManager.return_to_town()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		player_in_range = true
		label.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_in_range = false
		label.visible = false
