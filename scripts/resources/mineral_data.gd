class_name MineralData
extends Resource
## A mineral modifier that can be attached to ore. Affects bot behavior when built.

enum MineralType { FIRE, ICE, THUNDER, EARTH, WIND, VENOM }

@export var id: String = ""
@export var display_name: String = ""
@export var color: Color = Color.WHITE
@export var type: MineralType = MineralType.FIRE
@export var sell_bonus: int = 2        # Extra gold when selling mineral ore
@export var bot_effect_description: String = ""

## Tier multiplier for effect strength (ore tier 1-4 → multiplier).
const TIER_EFFECT_MULT: Array[float] = [1.0, 1.5, 2.0, 3.0]


static func get_effect_strength(ore_tier: int) -> float:
	var idx := clampi(ore_tier - 1, 0, 3)
	return TIER_EFFECT_MULT[idx]


## All 6 minerals — created at runtime since they're fixed data.
static func get_all_minerals() -> Array[MineralData]:
	var minerals: Array[MineralData] = []
	minerals.append(_make("fire", "Fire", Color(1.0, 0.4, 0.1), MineralType.FIRE, 2, "Burn: damage over time"))
	minerals.append(_make("ice", "Ice", Color(0.3, 0.7, 1.0), MineralType.ICE, 2, "Chill: slows enemies"))
	minerals.append(_make("thunder", "Thunder", Color(1.0, 0.9, 0.2), MineralType.THUNDER, 3, "Chain: arcs to nearby enemies"))
	minerals.append(_make("earth", "Earth", Color(0.3, 0.8, 0.3), MineralType.EARTH, 2, "Fortify: increased bot HP"))
	minerals.append(_make("wind", "Wind", Color(0.9, 0.95, 1.0), MineralType.WIND, 2, "Haste: increased attack speed/range"))
	minerals.append(_make("venom", "Venom", Color(0.6, 0.2, 0.8), MineralType.VENOM, 3, "Poison: ramping damage over time"))
	return minerals


static func _make(id: String, dname: String, color: Color, type: MineralType, bonus: int, desc: String) -> MineralData:
	var m := MineralData.new()
	m.id = id; m.display_name = dname; m.color = color
	m.type = type; m.sell_bonus = bonus; m.bot_effect_description = desc
	return m
