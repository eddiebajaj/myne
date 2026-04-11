# Sprint 2b — Cave Tension & Early Threat Spec

Sprint patch addressing Eddie's Sprint 2 playtest: the first 30-60s of a floor
feels flat (no threat until portal timer fires) and caves are empty decoration.
This spec adds two things and nothing else:

1. **Floor-start wandering enemies** — cheap, immediate threat on arrival.
2. **Cave roll table** — caves become "do I risk it?" moments with real loot and real danger.

Out of scope this sprint: screamer ore (rejected), environmental hazards
(deferred to Sprint 3), new enemy archetypes. Reuses existing T1 data from
`13_balance_t1.md` §9 wherever possible.

---

## 1. Floor-Start Wandering Enemies (Direction A)

### Purpose
Make the player feel danger within 5-10 seconds of arriving on a floor, before
any portal timer has ticked. Reinforces the "natural fauna live in the mines"
fiction from `08_enemies.md`.

### Spawn Counts per Floor

| Floor | Wanderers at start | Composition |
|---|---|---|
| B1F | **1** | 1 Cave Beetle |
| B2F | **2** | 1 Cave Beetle + 1 Tunnel Rat |
| B3F | **2** | 1 Cave Beetle + 1 Crystal Mite |
| B4F | **3** | 1 Cave Beetle + 1 Tunnel Rat + 1 Crystal Mite |
| B5F | **3** | 2 Cave Beetles + 1 Ore Shard |

Rationale:
- B1F used to be a zero-threat tutorial. One lonely beetle teaches "enemies
  exist" without being punishing. The player can outrun it if scared, or kill
  it in 3 pickaxe swings (12 HP / 4 dmg).
- B2F adds a rat to introduce the "more than one threat" idea while still
  being killable with the pickaxe alone.
- B3F-B5F mix in a Mineral Entity (Crystal Mite / Ore Shard) to foreshadow
  portals, justifying the first turret build.
- No Exploders at floor-start — Exploder archetype isn't in T1 balance tables
  (it's earmarked for T3+ in `08_enemies.md`). Do NOT invent T1 exploder stats.

### Spawn Location Rules
- **Minimum distance from player spawn:** 300 px (hard floor).
- **Maximum distance from player spawn:** 650 px (so they're reachable, not
  stuck in a corner).
- **Must be inside the mine arena:** use `FloorGenerator._random_floor_position(60.0)`
  with a rejection loop if the rolled position is closer than 300 px to the
  player spawn point `(80, 80)` (where stairs up live).
- **Not overlapping existing entities:** re-roll up to 5 times if the position
  is within 40 px of an ore node, rock, cave, or portal. On 6th attempt,
  accept it (good enough for a sprint patch).
- **Spread enemies apart:** minimum 120 px between wanderer spawn points so
  the player doesn't immediately eat a double-hit on arrival.

### AI Behavior — Wandering
Current `enemy_base.gd` behavior when no target is in aggro range:
`target = null; velocity = Vector2.ZERO`. They stand still. This makes the
floor feel dead — the player can't even see the threat until they walk into
it.

**New wander state** (tech work — see §5):
- When idle (no target in aggro range), pick a random point within 150 px of
  spawn position and walk there at **50% of `data.move_speed`**.
- On arrival (within 10 px), idle for `randf_range(0.8, 2.0)` seconds, then
  pick a new point.
- If player enters `data.aggro_range`, switch to chase (existing behavior).
- If player leaves aggro and **fauna** enemy hits `leash_range`, return to
  spawn and resume wandering from there (existing leash logic already returns
  to spawn; just enter wander after arrival instead of standing still).
- Mineral entities (no leash) never return — once aggro'd, they hunt until
  dead. Matches existing lore.

### Respawn & Persistence
- **Floor-start wanderers do NOT respawn** once killed. Clearing them is a
  meaningful progress beat on the floor.
- **They are independent of portal waves.** Killing all wanderers does NOT
  reduce or delay portal timers.
- **Portal timer is unchanged.** B3F still fires first timed wave at 45s.
  Players on B3F get ~45s of "wanderer-only" pressure before portal chaos
  layers on top — matches Eddie's "solo players get breath" note.

### Pacing Sanity Check
Current B1F kill-cost on the player (at 50 HP, 0 armor):
- 1 Cave Beetle: player takes 1-2 hits (5-10 dmg) to kill it. Survivable.
- Pickaxe kill: 3 swings × 0.35s = ~1.05s in melee range. Player needs 1
  trade of hits. Teaches "stand, swing, back off" without death.
- B5F with 3 enemies + portal waves on 35s timer: tight but fair — player
  should have a turret up by then (3 ore = 15s of mining).

---

## 2. Cave Contents Roll Table (Direction B)

Currently `cave_entrance.gd` unconditionally spawns 3-5 fauna, 3-6 rare ore
nodes, and 1-3 loot pickups on activation. Every cave is identical and loud.
Replace with a single roll on cave creation:

### T1 Cave Roll Table

| Roll | Outcome | Danger | Reward |
|---|---|---|---|
| **40%** | **Standard** | 0 enemies | 1 loot pickup (roll on loot table below) + 2 rare ore nodes |
| **15%** | **Treasure Vault** | 0 enemies | 2 loot pickups + 4 rare ore nodes (1 guaranteed mineral) |
| **20%** | **Ambush** | 2 fauna enemies | 2 loot pickups + 3 rare ore nodes |
| **10%** | **Big Ambush** | 1 fauna melee + 1 mineral entity | 3 loot pickups + 3 rare ore nodes (1 guaranteed mineral) |
| **15%** | **Empty** | 0 | 1 rare ore node + dust particle (disappointment beat) |

**Decisions locked by Eddie (2026-04-11):** Combat total 30% (20+10, down from
45%), Empty 15% (up from 5%). Total non-empty reward chance: 85%.

### Standard / Treasure Vault Loot Rolls
Use the existing `_generate_loot()` weighted category system in
`cave_entrance.gd`. No changes to category weights for this sprint.

Treasure Vault's "guaranteed mineral" means one of the 4 rare ore nodes it
spawns must have `mineral != null` regardless of the 50% cave mineral roll.

### Ambush Enemy Composition (T1, B1F-B5F)

**Ambush (30% roll):**
- **2 Cave Beetles** (floor 1-2) — stats from §3a of `13_balance_t1.md`
- **1 Cave Beetle + 1 Tunnel Rat** (floor 3-5)

**Big Ambush (15% roll):**
- **1 Cave Beetle + 1 Crystal Mite** (floor 1-3)
- **1 Cave Beetle + 1 Crystal Mite + 1 Ore Shard** (floor 4-5) — bumps total
  danger from 2 to 3 on deeper T1 floors

All values from §3 of `13_balance_t1.md`. No new stat blocks.

### Ambush Spawn Trigger & Leash
- Ambush enemies are **NOT pre-spawned** on floor generation. The roll result
  is stored on the `CaveEntrance` node; enemies spawn when the player enters
  the `Area2D` for the first time (existing `_on_body_entered` signal).
- Enemies spawn **inside the cave zone**: use 3-5 positions in a 60-100 px
  radius around the cave entrance, same pattern as current `_spawn_fauna()`.
- **Leash to cave:** override `spawn_position = cave.global_position` on
  spawn. Fauna already have `leash_range = 300`. For cave ambushes, tech
  should **clamp leash_range to 200 px** (so they don't chase the player
  across the whole floor if the player kites out).
- Mineral entities in Big Ambush: give them an explicit **300 px leash**
  override (override `leash_range` on the EnemyData copy at spawn time).
  Normally mineral entities have no leash; this is a cave-specific
  constraint so they don't make the rest of the floor unwinnable.
- Ambush enemies do **NOT** increment portal timers or trigger portals when
  killed.

### Empty Caves — Subtle Tell
Empty caves must feel different from unexplored loot caves or the rolling
"is this worth it?" decision collapses. But they must NOT read as "empty"
before entry — the mystery is the hook.

Visual tell for **empty caves before entry** (visible from outside):
- Entrance sprite color matches unexplored (see §3)
- Add a **2 px darker border overlay** (ColorRect child, `Color(0, 0, 0, 0.25)`,
  same rect size as sprite but 4 px larger)
- No particles, no label change. Players will not consciously notice on first
  play; after 2-3 empty caves they'll start to feel "that one looks a bit
  dimmer" — reward for pattern recognition without spoiling first-time
  discovery.

On entry, an empty cave:
- Still triggers the "activated" state transition (dim color, see §3)
- Spawns **1 rare ore node + 1 dust particle effect** (single `ColorRect` that
  fades out over 2s using `create_tween`) so the player sees *something*
  happen. It's not zero feedback — it's "this cave was already looted ages
  ago" narrative.

---

## 3. Cave Entrance Visual States

Three states total. All use `ColorRect` placeholders — team has no art
pipeline yet.

### State: Unexplored (default)
- **Sprite color:** `Color(0.6, 0.1, 0.1)` — current code default, dark red
  glowing entrance. Keep as-is.
- **Sprite size:** `Vector2(48, 48)` — current default.
- **Glow child:** add a second `ColorRect` behind the sprite, size
  `Vector2(64, 64)`, position `Vector2(-32, -32)`, color
  `Color(1.0, 0.4, 0.2, 0.35)`. Pulse its alpha via `create_tween().set_loops()`
  between 0.2 and 0.5 over 1.2s. Signals "mystery, something's here."
- **Label:** `"Cave [E]"` on proximity (current behavior, drop "Danger!"
  text — it spoils the ambush roll).

### State: Activated/Looted (player entered, rewards collected)
- **Sprite color:** `Color(0.3, 0.1, 0.1, 0.5)` — current code, dimmed. Keep.
- **Glow child:** set visible = false. No more pulse.
- **Label:** `"Cave (cleared)"` — current behavior, keep.
- **Optional X marker:** add a `Label` child with text `"X"`, color
  `Color(0.8, 0.3, 0.3)`, positioned at `Vector2(-6, -12)` (center of sprite).
  Only shown in activated state. Reads as "done with this."

### State: Empty (entered, was an empty roll)
- **Visually identical to Activated/Looted.** Same color, same X marker, same
  "cleared" label. From the player's perspective, an entered empty cave and
  an entered looted cave are indistinguishable after the fact. This is
  intentional — the player remembers "I got nothing from that one" but the
  world state is just "visited."

### Color Quick Reference

| State | Main rect color | Glow rect color | Size | Glow size |
|---|---|---|---|---|
| Unexplored | `(0.6, 0.1, 0.1, 1.0)` | `(1.0, 0.4, 0.2, 0.35)` pulsing | 48×48 | 64×64 |
| Unexplored (Empty roll) | same + dark 4px border overlay `(0, 0, 0, 0.25)` | same | 48×48 | 64×64 |
| Activated | `(0.3, 0.1, 0.1, 0.5)` | hidden | 48×48 | — |

---

## 4. Integration with Existing Portal System

- **Floor-start wanderers are independent.** `_spawn_portal()` is unchanged.
  `portal_spawner.gd` continues to fire on its own timer (see
  `13_balance_t1.md` §4a).
- **Cave ambushes are independent.** They do NOT touch `floor_time`, do NOT
  call `spawn_rock_triggered_portal()`, and do NOT increment portal wave
  counts.
- **Rock-triggered portals** are unchanged. A player breaking rocks on B3F+
  still risks portal pops on top of wandering enemies and cave ambushes.
- **Wanderers do not count toward portal wave limits.** The portal spawner's
  `max_waves_per_floor` (§4a) stays at B1F=0, B2F=0, B3F=3, etc.

### Difficulty Sanity — B1F-B5F Pacing Curve

| Floor | Wanderers | Cave chance | Portal waves | Total max threat on floor |
|---|---|---|---|---|
| B1F | 1 | 25% (existing) | 0 | 1 wanderer + (maybe cave, avg 1 ambush enemy) ≈ **1-3 enemies** |
| B2F | 2 | 25% | 0 | 2 + avg 1 = **2-4 enemies** |
| B3F | 2 | 28% | 3 waves (first at 45s) | 2 + 1 + 9 over 90s = **12 spread across time** |
| B4F | 3 | 31% | 4 waves | 3 + 1 + 13 = **17 spread** |
| B5F | 3 | 34% | 5 waves | 3 + 2 + 17 = **22 spread** |

B3F gets a clean 45-second "wanderer-only" window before first portal wave,
honoring Eddie's "solo players get a breath before chaos" note. B5F is
deliberately dense — it's a checkpoint, it should feel earned.

---

## 5. Implementation Hooks for Tech Agent

### New data / config
- **No new EnemyData types.** Reuse existing T1 `cave_beetle`, `tunnel_rat`,
  `crystal_mite`, `ore_shard` from `_random_enemy()` in `floor_generator.gd`.
  Optionally extract these into a helper that takes an `id: String` and
  returns a configured `EnemyData` so both floor-start and cave ambush code
  paths can request specific enemies by name (currently `_random_enemy()`
  50/50s between beetle and rat at T1 — too random for the new comp tables).

### `floor_generator.gd` changes
- **New function `_spawn_floor_wanderers()`**, called from `generate_floor()`
  after `_spawn_rocks()` and before `_spawn_cave()`.
- Reads floor number from `GameManager.current_floor`, looks up the
  composition from a const dictionary, calls `spawn_enemy_at(pos)` with the
  position rejection loop described in §1.
- **New helper `spawn_enemy_by_id(pos: Vector2, id: String)`** — wraps
  `spawn_enemy_at` but configures the EnemyData explicitly rather than 50/50.

### `enemy_base.gd` changes (wander state)
- **New state machine minimal:** add `var wander_target: Vector2` and
  `var wander_idle_timer: float` to the class.
- In `_physics_process`, when no target found and either fauna-at-spawn or
  mineral-entity-idle, run `_wander(delta)` instead of setting velocity to
  zero.
- `_wander()` picks a point within 150 px of `spawn_position`, moves at
  `data.move_speed * 0.5`, idles `0.8-2.0s` on arrival, repeats.
- This is a **small, isolated addition** — all existing target-seeking logic
  is untouched.

### `cave_entrance.gd` changes
- **New `var cave_roll: String`** set on ready via weighted roll against the
  table in §2. Values: `"standard"`, `"treasure"`, `"ambush"`, `"big_ambush"`,
  `"empty"`.
- **`_activate()`** dispatches on `cave_roll`:
  - `standard` → existing `_spawn_loot()` (1 pickup) + `_spawn_cave_ore()` (2 ore, not 3-6)
  - `treasure` → `_spawn_loot()` 2× + `_spawn_cave_ore()` (4 ore, force first to have mineral)
  - `ambush` → spawn ambush enemies via tech helper + `_spawn_loot()` 2× + 3 cave ore
  - `big_ambush` → spawn bigger ambush + `_spawn_loot()` 3× + 3 cave ore (force mineral)
  - `empty` → no loot, no ore, dust particle tween, done
- **`_spawn_fauna()`** is replaced by `_spawn_ambush(composition: Array[String])`
  that takes enemy ids and calls `spawn_enemy_by_id`. Override each spawned
  enemy's `spawn_position` to the cave position and clamp its `leash_range`
  per §2.
- **Visual state:** add the glow ColorRect child on ready for unexplored
  state, pulse with tween, hide on activate. Dark border overlay added when
  `cave_roll == "empty"`.

### `_build_cave_scene()` in `floor_generator.gd`
- Add the `Glow` ColorRect child (64×64, behind parent).
- Add the `XMarker` Label child (initially hidden) for activated state.

### No changes needed
- `portal_spawner.gd` — untouched
- `enemy_data.gd` — untouched
- `enemy_ranged.gd`, `enemy_exploder.gd` — untouched (no T1 exploders/ranged
  at floor start)
- Balance doc `13_balance_t1.md` — no new values, this spec only references it

### Tech Complexity Estimate

| Item | Complexity |
|---|---|
| Floor-start wanderer spawns (position roll + `spawn_enemy_by_id`) | **Data + small plumbing** — ~1 hour |
| Enemy wander state in `enemy_base.gd` | **New system, small scope** — ~2 hours + playtest |
| Cave roll table dispatch in `cave_entrance.gd` | **Refactor existing, mostly data** — ~1-2 hours |
| Cave visual states (glow pulse, X marker, empty border) | **Data + tween** — ~1 hour |
| Ambush enemy leash clamping | **One-line override at spawn** — <30 min |

Total: roughly **half a day of tech work**. No new scenes, no new
EnemyData resources, no new UI. Fits a sprint patch.

---

## Decisions Confirmed by Eddie (2026-04-11)

1. **B1F = 1 lonely beetle.** Confirmed.
2. **Cave combat rate = 30% total** (20% Ambush + 10% Big Ambush, down from 45%).
3. **Empty caves = 15%** (up from 5%). Standard bumped to 40% to absorb the delta.
4. **Empty caves give 1 ore + dust.** Confirmed (kept for feedback, not a zero-feedback moment).
5. **Fauna AI varies by species:**
   - **Cave Beetle:** passive wander, aggro on detection (standard wander-and-chase).
   - **Tunnel Rat:** **fully passive** — wanders, never initiates, only aggros if the player attacks it first. Teaches the player "not everything wants to kill me."
   - **Crystal Mite / Ore Shard / any mineral entity:** **always aggressive** — no wander state, beeline for the player on detection. Matches "crystallized, hostile, no retreat" lore.

This gives three distinct fauna/mineral behaviors from existing archetypes with no new data. Tech implementation:
- Add a `behavior: String` field on the configured EnemyData (values: `"passive_wander"`, `"wander_aggro"`, `"always_aggro"`).
- `enemy_base.gd` dispatches on this field in its idle state.
- `passive_wander` enemies ignore the aggro check unless they've already taken damage (add a `has_been_provoked: bool` flag).
- `always_aggro` enemies skip the wander state entirely — go straight to pursuit when player is in aggro range, stand still otherwise (or pick a long-range wander ~300 px if fully idle).

## Remaining Open Questions (non-blocking — tech can make the call)

These are calls I made that Eddie should confirm before tech starts:

- **B1F "1 lonely beetle" is very gentle.** Is one enemy enough to set the
  tone, or do you want B1F to start with 2? (I went with 1 to preserve the
  tutorial feel.)
- **Cave roll table uses 30% Ambush + 15% Big Ambush.** That's 45% of caves
  having combat. Too spicy or about right? (I started spicier than the
  example 20% because Eddie's note was "caves are decoration" — wanted the
  risk to feel real.)
- **Empty cave = 5%.** Low enough to feel rare, high enough to sting. OK?
- **Empty caves still give 1 rare ore node + dust particle on entry.** Is
  that too generous (defeats the "empty" feeling) or right (avoids a zero-
  feedback moment)? I could make it literally nothing.
- **B5F gets 3 wanderers including 1 Ore Shard.** Ore Shard spawns as a
  single enemy here rather than the "group of 3-4" its wave comp uses. Is
  that OK as a floor-start case, or should B5F swap Ore Shard for a second
  Crystal Mite to keep Ore Shard "group only" identity?
- **Wander state:** 50% movement speed and 150 px radius — good numbers for
  first pass or should they be configurable per-enemy (fauna wander slower,
  mineral wander faster/further)?
- **Unexplored empty caves** have a 4 px dark border tell. If this is too
  subtle for placeholder art, we could instead give empty caves a slightly
  desaturated red `(0.5, 0.15, 0.15)` — easier to see but reveals info
  pre-entry. I went subtle to preserve mystery; Eddie's call.
- **Cave ambush mineral entities have a 300 px leash override.** Normally
  mineral entities don't leash per `08_enemies.md` ("they don't retreat").
  This breaks the lore rule to keep caves bounded. Is the trade-off OK?

---

## Contradictions Found Between Docs and Code

- **`13_balance_t1.md` §3a** says Cave Beetle `aggro_range = 180` and
  `leash_range = 300`. Current `floor_generator.gd._random_enemy()` **does
  not set `aggro_range` or `leash_range`** on the T1 EnemyData block — only
  HP, damage, speed, attack_range, attack_speed. Tech should add the missing
  fields when updating this function. (Not new work from this spec — it's
  an existing gap, but wandering behavior depends on it.)
- **`08_enemies.md`** says fauna are "passive floor wanderers on some floors
  (non-aggressive until provoked)." This spec honors the wandering part but
  makes them aggressive on aggro — matches `enemy_base.gd` current behavior.
  Eddie should confirm "wandering but aggressive on detection" is the
  intended read of the fauna fiction.
- **`cave_entrance.gd`** currently labels caves "Cave [E] (Danger!)". This
  spec drops the "(Danger!)" text because cave rolls include non-danger
  outcomes now. Visually the cave still pulses red/orange — mystery
  preserved.
