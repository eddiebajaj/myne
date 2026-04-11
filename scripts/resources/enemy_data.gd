class_name EnemyData
extends Resource
## Enemy definition with faction, archetype, and tier.

enum Faction { FAUNA, MINERAL_ENTITY }
enum Archetype { RUSHER, RANGED, TANK, SWARM, EXPLODER }
enum DamageType { PHYSICAL, VENOM }

@export var id: String = ""
@export var display_name: String = ""
@export var color: Color = Color.RED
@export var faction: Faction = Faction.FAUNA
@export var archetype: Archetype = Archetype.RUSHER
@export var tier: int = 1
@export var health: float = 30.0
@export var damage: float = 5.0
@export var damage_type: DamageType = DamageType.PHYSICAL
@export var move_speed: float = 80.0
@export var attack_range: float = 30.0
@export var attack_speed: float = 1.0
@export var aggro_range: float = 200.0
@export var leash_range: float = 300.0  # Fauna: stop chasing past this. Entities: 0 = no leash
@export var projectile_speed: float = 200.0  # For RANGED archetype
@export var explode_radius: float = 60.0     # For EXPLODER archetype
@export var explode_damage: float = 15.0     # For EXPLODER archetype
## Idle behavior dispatch for enemy_base.gd. One of:
##   "wander_aggro"    — wanders spawn area, aggros when player enters aggro_range (default).
##   "passive_wander"  — wanders, only aggros after being damaged (has_been_provoked).
##   "always_aggro"    — no wandering, chases when player in aggro_range, idle otherwise.
@export var behavior: String = "wander_aggro"
