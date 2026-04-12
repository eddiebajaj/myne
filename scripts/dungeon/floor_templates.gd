class_name FloorTemplates
## Hand-authored floor layout templates for the mining dungeon.
## Each template defines interior walls, stairs-up position, and optional spawn zones.
## See docs/design/sprint_02c_floor_templates_spec.md for full spec.

static var TEMPLATES: Dictionary = {
	"open_arena": {
		"id": "open_arena",
		"name": "Open Arena",
		"weight": 2.0,
		"min_floor": 1,
		"walls": [],
		"stairs_up": Vector2(100, 100),
		"zones": {},
	},
	"two_chambers": {
		"id": "two_chambers",
		"name": "Two Chambers",
		"weight": 2.0,
		"min_floor": 2,
		"walls": [
			# Horizontal divider at y=400. Two segments with 160px gap centered at x=700.
			{"pos": Vector2(350, 400), "size": Vector2(668, 32)},
			{"pos": Vector2(1050, 400), "size": Vector2(668, 32)},
		],
		"stairs_up": Vector2(120, 120),
		"zones": {
			"cave": Rect2(100, 450, 1200, 500),
			"stairs_down_rock": Rect2(100, 450, 1200, 500),
		},
	},
	"cross_corridor": {
		"id": "cross_corridor",
		"name": "Cross Corridor",
		"weight": 1.5,
		"min_floor": 2,
		"walls": [
			# Vertical wall, upper half. From y=50 to y=380 at x=700.
			{"pos": Vector2(700, 215), "size": Vector2(32, 330)},
			# Vertical wall, lower half. From y=620 to y=950 at x=700.
			{"pos": Vector2(700, 785), "size": Vector2(32, 330)},
			# Horizontal wall, left half. From x=50 to x=580 at y=500.
			{"pos": Vector2(315, 500), "size": Vector2(530, 32)},
			# Horizontal wall, right half. From x=820 to x=1350 at y=500.
			{"pos": Vector2(1085, 500), "size": Vector2(530, 32)},
		],
		"stairs_up": Vector2(150, 150),
		"zones": {
			"cave": Rect2(720, 520, 660, 460),
			"stairs_down_rock": Rect2(720, 520, 660, 460),
		},
	},
}
