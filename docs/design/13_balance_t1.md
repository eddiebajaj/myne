# T1 Balance Values (B1F-B5F)

Concrete numbers for the first tier playable mine loop. All values are implementation-ready.
Items marked **(tuning needed)** are best guesses that should be revisited during playtesting.

---

## 1. Player Baseline (Reference)

Already in code, restated here for context:

| Stat | Value | Source |
|---|---|---|
| HP | 50 | `player.gd` |
| Armor | 0 (none at start) | `player.gd` |
| Pickaxe damage | 3 + pickaxe_tier = **4** at T1 | `player.gd` swing |
| Move speed | 200 px/s | `player.gd` |
| Swing cooldown | 0.35 s | `player.gd` |

---

## 2. Ore Costs Per Bot Type

Building uses ore of ONE type (no mixing) + 1 Battery.

| Bot | Category | Ore Cost | Battery | Design Rationale |
|---|---|---|---|---|
| Turret | Static | **3** | 1 | Cheap — buildable from 1-2 nodes. Disposable floor defense. |
| Mining Rig | Static | **4** | 1 | Slightly more than a turret; you invest ore to get ore back faster. |
| Combat Drone | Follower | **8** | 1 | Expensive — roughly half a floor's haul. Big commitment. |
| Mining Drone | Follower | **6** | 1 | Between rig and combat drone. Long-term mining investment. |

### Why These Numbers

- A T1 floor spawns ~10-14 ore nodes (see section 5). Each node yields 1 ore piece.
- A turret at 3 ore is buildable after mining 3 nodes (~15 seconds of work). Feels cheap and disposable.
- A combat drone at 8 ore costs roughly half the floor's total haul. Building one mid-floor is a real sacrifice.
- Mining drone at 6 is a meaningful spend but pays for itself over 2-3 floors via faster mining.
- Mining rig at 4 is only slightly more than a turret — appropriate since it only helps on the current floor.

**NOTE:** The codebase currently has placeholder values of 5/4/8/6 in `05_ore_and_minerals.md`. Update `BotData` resources to match: Turret=3, Mining Rig=4, Combat Drone=8, Mining Drone=6.

---

## 3. Enemy Stats — T1 (B1F-B5F)

### 3a. Natural Fauna (Cave Enemies)

| Enemy | Archetype | HP | Damage | Speed (px/s) | Attack Rate (hits/s) | Aggro Range | Leash Range |
|---|---|---|---|---|---|---|---|
| Cave Beetle | Rusher | **12** | **5** | **90** | **0.8** | 180 | 300 |
| Tunnel Rats | Swarm | **6** | **3** | **110** | **1.2** | 160 | 250 |

**Cave Beetle** — The basic melee threat. At 5 damage per hit, the player dies in 10 unarmored hits (matches the "8-10 hits" design target). 12 HP means the pickaxe (4 damage) kills it in 3 swings. Slow enough to kite but fast enough to pressure. **(tuning needed)**

**Tunnel Rats** — Individually weak (6 HP = 2 pickaxe hits), but spawn in groups of 3-4. Their higher speed and attack rate make them dangerous in numbers. 3 damage per hit is forgiving per rat but adds up fast with 3+ rats. **(tuning needed)**

### 3b. Mineral Entities (Portal Enemies)

| Enemy | Archetype | HP | Damage | Speed (px/s) | Attack Rate (hits/s) | Aggro Range | Notes |
|---|---|---|---|---|---|---|---|
| Crystal Mite | Rusher | **10** | **4** | **80** | **1.0** | 400 | Portal rusher. No leash. |
| Ore Shards | Swarm | **5** | **2** | **100** | **1.5** | 400 | Portal swarm. No leash. Spawn in groups. |

**Crystal Mite** — Slightly weaker than Cave Beetle (10 HP vs 12, 4 dmg vs 5) since they come from portals in waves, not as isolated cave fights. Pickaxe kills in 3 hits. A wave of 2-3 is manageable with a turret; 4+ requires multiple bots or careful kiting.

**Ore Shards** — Glass cannons in bulk. 5 HP means 2 pickaxe hits each. Individually trivial but a wave spawns 3-5 of them. High attack rate (1.5/s) punishes standing still. Their role is to overwhelm single-target defenses.

### 3c. Cave Bat (T2 — Skip for Now)

Cave Bat is a T2 ranged fauna enemy. Not needed for T1 implementation. Placeholder exists in code at T2.

### 3d. Code Reconciliation

The codebase (`floor_generator.gd` and `portal_spawner.gd`) has existing values that differ slightly from the above. The values in this doc supersede those placeholders. Key changes:

| Enemy | Code HP | Doc HP | Code Dmg | Doc Dmg | Code Speed | Doc Speed |
|---|---|---|---|---|---|---|
| Cave Beetle | 15 | **12** | 3 | **5** | 70 | **90** |
| Tunnel Rat | 10 | **6** | 4 | **3** | 90 | **110** |
| Crystal Mite | 15 | **10** | 4 | **4** | 70 | **80** |
| Ore Shard | 8 | **5** | 2 | **2** | 90 | **100** |

Rationale: Beetle HP lowered so pickaxe kills feel responsive (3 swings). Beetle damage raised to create real threat. Tunnel Rat HP cut in half to emphasize "weak but many" identity. Speeds raised slightly so enemies feel urgent on T1's small floors.

---

## 4. Portal Timer Values — T1

### 4a. Timed Wave System

| Parameter | B1F | B2F | B3F | B4F | B5F |
|---|---|---|---|---|---|
| First wave delay | N/A | N/A | **45s** | **40s** | **35s** |
| Subsequent wave interval | N/A | N/A | **35s** | **30s** | **25s** |
| Max waves per floor | 0 | 0 | **3** | **4** | **5** |
| Warning duration | — | — | **3s** | **3s** | **2.5s** |

- **B1F-B2F have no portals.** Peaceful tutorial floors. The code already handles this via `get_portal_chance()` returning 0 for floor < 3.
- **B3F** is the player's first portal encounter. Long initial delay (45s) gives time to mine before the first scare. **(tuning needed)**
- By **B5F**, the timer is tight enough to create urgency but still allows ~25s of mining between waves.

### 4b. Wave Composition (T1 Portals)

| Wave # | Enemy Count | Composition |
|---|---|---|
| Wave 1 | **2** | 2 Crystal Mites |
| Wave 2 | **3** | 2 Crystal Mites + 1 Ore Shard group (3 shards) |
| Wave 3 | **4** | 1 Crystal Mite + 2 Ore Shard groups (3 shards each) |
| Wave 4 | **5** | 3 Crystal Mites + 1 Ore Shard group (4 shards) |
| Wave 5 | **6** | 3 Crystal Mites + 2 Ore Shard groups (4 shards each) |

"Ore Shard group" means shards spawn together as a cluster. The count column refers to individual spawn calls, not individual enemies (since shards come in groups). **(tuning needed)**

### 4c. Rock Portal Trigger

| Parameter | Value |
|---|---|
| Base trigger chance (B1F) | **0%** |
| Base trigger chance (B3F) | **5%** |
| Base trigger chance (B5F) | **10%** |
| Time modifier | +1% per 10 seconds on floor (caps at +10%) |
| Ore volume modifier | +1% per 4 ore in backpack (caps at +8%) |
| Mineral ore modifier | +2% per mineral ore piece (on top of normal ore modifier) |

Formula: `trigger_chance = base + time_bonus + ore_bonus + mineral_bonus`

At B5F with a full backpack (16 ore, 2 mineral) after 60 seconds: `10% + 6% + 4% + 4% = 24%` — roughly 1 in 4 rocks triggers a portal. Tense but not overwhelming. **(tuning needed)**

Rock-triggered portals spawn a single wave equivalent to the floor's current timed wave number (e.g., if you've had 2 timed waves, a rock portal spawns wave-3 composition). Warning time is **1.5s** (shorter than timed portals).

---

## 5. Ore Node and Rock Counts — T1

### 5a. Ore Nodes Per Floor

| Parameter | Value |
|---|---|
| Base ore node count | **12** |
| Random variance | **-2 to +3** (so 10-15 per floor) |
| Density scaling | +5% per floor (via `get_ore_density()`) |
| Effective range B1F | **10-15 nodes** |
| Effective range B5F | **12-18 nodes** |
| Ore per node | **1 piece** (each node yields exactly 1 ore) |
| Mineral chance | **25%** of nodes have a mineral modifier |
| Hits to break (T1 pickaxe on T1 node) | **3 hits** |

Expected T1 floor haul: ~10-15 ore pieces. A turret costs 3 (cheap), a combat drone costs 8 (over half).

### 5b. Rocks Per Floor

| Parameter | Value |
|---|---|
| Total rocks per floor | **8-12** |
| Rocks hiding stairs down | **1** (always exactly 1) |
| Rocks hiding treasure | **1-2** (small ore bonus, occasionally a battery) |
| Empty rocks | **5-9** (the majority) |
| Hits to break a rock | **1 hit** (rocks break instantly, unlike ore nodes) |

Rocks are the "search for stairs" mechanic. With 8-12 rocks and 1 hiding stairs, the player breaks ~4-6 rocks on average before finding stairs. Each rock break risks a portal trigger (from B3F onward).

### 5c. Treasure Rock Loot (T1)

| Loot | Chance per treasure rock | Amount |
|---|---|---|
| Bonus ore (random T1 type) | **60%** | 1-2 pieces |
| Battery | **25%** | 1 |
| Nothing special (just rubble) | **15%** | — |

---

## 6. Backpack

| Parameter | Value |
|---|---|
| Starting grid dimensions | **4 wide x 4 tall** = 16 cells |
| Each ore piece | **1 cell** (no Tetris shapes, 1x1 uniform) |
| Starting capacity | **16 ore pieces** |
| Upgrade increment | **+1 row** (4 cells per upgrade, via Smith) |
| Batteries | **Do NOT take backpack space** (separate counter) |
| Artifacts | **Do NOT take backpack space** (separate list) |

### Why 4x4

- 16 slots means a full backpack holds roughly 1-1.5 floors of ore.
- Building a combat drone (8 ore) consumes half your backpack — the cost is viscerally visible.
- The "push or bank" decision hits around floor 2-3 of a run when the backpack is getting full.
- Upgrade to 4x5 (20 slots) is a meaningful early-game Smith purchase that extends runs by ~1 floor.

### Ore Grid Shapes

All ore is 1x1. No Tetris-style shapes. The backpack is a capacity tracker, not a packing puzzle. The grid exists so the player can visually see what they're carrying and tap to discard specific ore types.

---

## 7. Bot Stats — T1 Baseline

These are the base stats when built from T1 ore. Higher tier ore scales via the existing `TIER_SCALING` multiplier (T1=1.0x, T2=1.5x, T3=2.0x, T4=3.0x).

| Bot | HP | Damage | Range (px) | Attack Rate (hits/s) | Move Speed | Notes |
|---|---|---|---|---|---|---|
| Turret | **30** | **6** | **150** | **1.0** | 0 (static) | Kills a Crystal Mite in 2 shots. Dies to ~5 beetle hits. |
| Mining Rig | **20** | **0** | **80** | — | 0 (static) | No combat. Mines nodes in range at 1 hit per 1.5s. |
| Combat Drone | **50** | **8** | **120** | **1.0** | **100** | Kills a beetle in 2 shots. Tanky enough to survive a wave. |
| Mining Drone | **35** | **3** | **100** | **0.5** | **90** | Light self-defense. Mines nodes at 1 hit per 2s while following. |

### Bot vs Enemy Matchups (T1)

| Scenario | Outcome |
|---|---|
| 1 Turret vs 1 Crystal Mite | Turret wins. Mite dead in 2 shots (1.0s/shot, mite at 80 speed takes ~2s to close 150px). Turret takes 0-1 hits. |
| 1 Turret vs 3 Ore Shards | Turret wins but takes damage. Kills each shard in 1 shot, but shards are fast (100 speed) and some reach melee. |
| 1 Combat Drone vs 2 Crystal Mites | Drone wins. 8 damage kills each mite in 2 hits. Drone takes ~4-8 damage (out of 50 HP). |
| 1 Turret vs Wave 3 (mixed) | Turret dies. Too many targets. Needs player help or a second turret. |
| Player (pickaxe only) vs 1 Crystal Mite | Player wins but takes 1-2 hits (4-8 damage). Risky with multiple enemies. |

---

## 8. Floor Pacing Summary — T1

| Floor | Ore Nodes | Rocks | Portal | Cave | Intended Feel |
|---|---|---|---|---|---|
| B1F | 10-15 | 8-10 | None | None | Tutorial. Mine freely, learn controls. |
| B2F | 10-15 | 8-11 | None | 25% chance | Introduction to caves (opt-in danger). |
| B3F | 11-16 | 9-11 | First portal (45s) | 28% chance | First forced threat. Build first turret. |
| B4F | 11-16 | 9-12 | Portal (40s) | 31% chance | Tension ramps. Consider combat drone. |
| B5F | 12-18 | 10-12 | Portal (35s) | 34% chance | Checkpoint floor. Survive to save progress. |

### Time Budget Per Floor (Target)

| Activity | Time |
|---|---|
| Mining all ore nodes | ~20-30s (3 hits x 0.35s cooldown x 12 nodes, plus movement) |
| Searching rocks for stairs | ~5-15s (break 4-6 rocks at 1 hit each) |
| Portal wave (combat) | ~10-15s per wave |
| Total floor time | **30-60 seconds** (matches doc 01 target) |

---

## 9. Derived Values for Code

Quick-reference table for the tech agent.

### EnemyData Updates (portal_spawner.gd + floor_generator.gd)

```
cave_beetle:   hp=12, dmg=5, speed=90,  atk_range=28, atk_speed=0.8, aggro=180, leash=300
tunnel_rat:    hp=6,  dmg=3, speed=110, atk_range=24, atk_speed=1.2, aggro=160, leash=250
crystal_mite:  hp=10, dmg=4, speed=80,  atk_range=28, atk_speed=1.0, aggro=400, leash=0
ore_shard:     hp=5,  dmg=2, speed=100, atk_range=24, atk_speed=1.5, aggro=400, leash=0
```

### BotData Updates

```
turret:        ore_count=3,  hp=30, dmg=6, range=150, atk_speed=1.0, move_speed=0
mining_rig:    ore_count=4,  hp=20, dmg=0, range=80,  atk_speed=0,   move_speed=0
combat_drone:  ore_count=8,  hp=50, dmg=8, range=120, atk_speed=1.0, move_speed=100
mining_drone:  ore_count=6,  hp=35, dmg=3, range=100, atk_speed=0.5, move_speed=90
```

### PortalSpawner Updates

```
base_interval:     45.0  (B3F first wave)
interval_per_floor: -5.0  (subtract per floor after B3F)
subsequent_factor:  0.78  (multiply interval for subsequent waves: 45*0.78=35, 40*0.78=31, etc.)
warning_time:       3.0   (timed), 1.5 (rock-triggered)
rock_base_chance:   0.05  (at B3F), +0.025 per floor
rock_time_bonus:    0.001 per second on floor, cap 0.10
rock_ore_bonus:     0.0025 per ore piece, cap 0.08
rock_mineral_bonus: 0.02 per mineral ore piece (additive)
```

### Inventory (unchanged, confirming)

```
grid_width:  4
grid_height: 4
ore_per_cell: 1
batteries_take_space: false
```
