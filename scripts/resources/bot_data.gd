class_name BotData
extends Resource
## Bot blueprint. Actual stats at build time depend on ore tier used.

enum BotCategory { STATIC, FOLLOWER }
enum BotRole { DEFENSE, MINING }

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var color: Color = Color.WHITE
@export var category: BotCategory = BotCategory.STATIC
@export var role: BotRole = BotRole.DEFENSE
@export var ore_count: int = 5         # How many ore pieces of ONE type needed

# Base stats (T1 baseline). Scaled by ore tier at build time.
@export var base_health: float = 40.0
@export var base_damage: float = 8.0
@export var base_range: float = 150.0
@export var base_attack_speed: float = 1.0
@export var move_speed: float = 0.0    # 0 for static bots

## Tier scaling: T1=1.0, T2=1.5, T3=2.0, T4=3.0
const TIER_SCALING: Array[float] = [1.0, 1.5, 2.0, 3.0]


static func get_tier_mult(ore_tier: int) -> float:
	var idx := clampi(ore_tier - 1, 0, 3)
	return TIER_SCALING[idx]


func get_scaled_health(ore_tier: int) -> float:
	return base_health * get_tier_mult(ore_tier)


func get_scaled_damage(ore_tier: int) -> float:
	return base_damage * get_tier_mult(ore_tier)


func get_scaled_range(ore_tier: int) -> float:
	return base_range * get_tier_mult(ore_tier)
