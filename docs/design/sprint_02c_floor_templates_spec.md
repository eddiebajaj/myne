# Sprint 02c — Floor Templates Spec

Status: design locked with Eddie + PO. Ready for tech agent.
Scope: bigger arena + 3 hand-authored layout templates. Procedural generation is explicitly out of scope.

Related docs:
- `docs/design/03_dungeon_structure.md` — dungeon intent (open room, stairs-up safe corner, cave opt-in)
- `docs/design/13_balance_t1.md` §5-6 — density / pacing targets
- `scripts/dungeon/floor_generator.gd` — current implementation

---

## 1. Arena Size Change

| Parameter | Old | New |
|---|---|---|
| `FLOOR_WIDTH` | 800 | **1400** |
| `FLOOR_HEIGHT` | 600 | **1000** |
| `WALL_THICKNESS` | 32 | 32 (unchanged) |
| Playable area | 480k px² | **1.4M px²** (~2.9x) |

### Camera flag for tech
`player.gd` has a child `Camera2D`. Verify on the 1400x1000 arena:
- No clamping / limits set such that the camera "sticks" when player walks near the old 800x600 bounds.
- No `zoom` change needed — the design intent stays "see most of the room at once" but not all of it. Bigger arena = partial visibility is fine and is in fact the point of templates C/D.
- On mobile portrait web, confirm the camera still centers on the player; if it tries to fit-to-arena the player sprite will shrink. **Flag: tech must keep camera follow-player, not fit-arena.**

### Density scaling (sublinear, per balance doc §5 / §8 pacing target of 30-60s per floor)

Arena area is 2.9x but walking distance only ~1.7x (sqrt scaling). Keep the floor completable in 30-60s by scaling density sublinearly — fewer nodes per unit area than before, but more per floor.

| Parameter | Old base | **New base** | Effective B1F range | Effective B5F range |
|---|---|---|---|---|
| Ore node count | `12 * density + randi(-2,+3)` | **`22 * density + randi(-3,+4)`** | 19-26 | 22-31 |
| Rock count | `randi(8,12)` | **`randi(14,20)`** | 14-20 | 14-20 |
| Cave chance | `get_cave_chance()` | unchanged | — | — |

Rationale:
- 22 ore nodes vs 12 is ~1.83x, under the 2.9x area ratio → floors feel sparser per-square-pixel but produce a bigger haul per run (aligns with backpack 4x4 = 16 slots → player fills up mid-floor and still has to decide push/bank).
- 14-20 rocks vs 8-12 is ~1.75x. Still exactly 1 stairs-down rock, 1-2 treasure rocks, rest empty.
- Density multiplier from `GameManager.get_ore_density()` (+5%/floor) still applies on top.
- **Contradiction with balance doc §5a:** doc currently says "base 12 ore". This spec supersedes that line for the post-sprint-02c arena. Doc §5a should be updated to say "base 22 ore (post 02c arena change)". Flagging for Eddie to ack.

---

## 2. FloorTemplate Concept

A template is a plain data dictionary (no new Resource type — avoid ceremony). Fields:

```gdscript
{
    "id": "open_arena",          # String, unique
    "name": "Open Arena",         # String, display-only
    "weight": 3.0,                # Float, roll weight when rolled
    "min_floor": 1,               # Int, earliest floor this can roll on
    "walls": [                    # Array of {pos, size}, arena coordinates
        # {"pos": Vector2(700, 500), "size": Vector2(400, 32)},
    ],
    "stairs_up": Vector2(80, 80), # Vector2, fixed stairs-up position
    "zones": {                    # Optional preferred zones (Rect2)
        "cave":       Rect2(...),  # cave prefers this rect
        "ore":        Rect2(...),  # ore prefers this rect (omit for arena-wide)
        "rocks":      Rect2(...),  # rocks prefers this rect
        "stairs_down_rock": Rect2(...),  # the stairs-hiding rock prefers this rect
    },
}
```

Rules:
- `walls` are axis-aligned rectangles only. No circles, no polygons, no diagonals. `pos` is the **center** (matches `_add_wall()` convention); `size` is full width/height.
- Wall rectangles must leave at least **96 px** of passable gap between any two walls or between a wall and the arena border. This is ~3x the player collision radius and leaves room for enemies and dropped bots.
- `zones` are soft biases. Reservation sampler tries in-zone first, falls back to arena-wide after N failures. Omitting a zone = arena-wide for that entity type.
- `stairs_up` is mandatory and overrides both the old hardcoded `(80,80)` AND any "random stairs" work the PO is doing in parallel. Templates own stair placement.
- Enemies (wanderers + portals) are NOT in templates — they keep rolling off the existing logic. Wanderer placement just needs to respect the new walls via the reservation system.

---

## 3. The 3 Templates

Shipping **3** templates, not 4. Template D (Spiral) is cut — too fiddly to tune in one tech pass and redundant with Cross Corridor for exploration feel. Revisit in a later sprint if playtest asks for more variety.

Arena coordinate system: origin (0,0) top-left, (1400,1000) bottom-right. Wall `pos` is the center of the wall rectangle. Wall thickness is always 32 for interior walls (match the exterior look).

### Template A — Open Arena

**Purpose:** baseline, tutorial-feel, "mine freely". Identical layout philosophy to the current game, just in the bigger box.

```gdscript
{
    "id": "open_arena",
    "name": "Open Arena",
    "weight": 2.0,
    "min_floor": 1,
    "walls": [],   # no interior walls
    "stairs_up": Vector2(100, 100),
    "zones": {},   # everything arena-wide
}
```

- Stairs-up in the top-left "safe corner" (matches doc 03: "Stairs up always near the entry point").
- **Hardcoded on B1F** regardless of weights (see §4).
- Cave, if rolled, spawns arena-wide.

### Template B — Two Chambers

**Purpose:** introduces spatial decision-making. Upper chamber feels "safe and dense", lower chamber feels "open and exposed".

```gdscript
{
    "id": "two_chambers",
    "name": "Two Chambers",
    "weight": 2.0,
    "min_floor": 2,
    "walls": [
        # Horizontal divider at y=400. Split into two segments with a 160-wide gap centered at x=700.
        {"pos": Vector2(350,  400), "size": Vector2(668, 32)},   # left segment: x in [16,684]
        {"pos": Vector2(1050, 400), "size": Vector2(668, 32)},   # right segment: x in [716,1384]
    ],
    "stairs_up": Vector2(120, 120),
    "zones": {
        "cave":              Rect2(100, 450, 1200, 500),   # cave prefers lower chamber
        "stairs_down_rock":  Rect2(100, 450, 1200, 500),   # stairs-down rock prefers lower chamber (player must go "down")
        # ore/rocks: arena-wide, naturally split 40/60 by the divider
    },
}
```

- Upper chamber is ~400 tall (0 to 400), lower is ~600 tall (400 to 1000). 40/60 split.
- Gap at x=684 to x=716 = 32-wide wall thickness adjustment: actual passage is **x=684 to x=716 centered, giving ~160 px of clear floor once you account for player radius**. Tech: verify player (collision radius ~12-16) fits through with breathing room. If the gap feels tight in playtest, widen to 200.
- Ore/rock counts are unchanged from §1; they just distribute across both chambers via normal reservation.
- Stairs-up in upper chamber safe corner. Player must find stairs-down rock in lower chamber → forces them to cross the gap → meaningful traversal.

### Template C — Cross Corridor

**Purpose:** 4 quadrants connected only through a center clearing. Real exploration — the player literally cannot see the whole floor from any one quadrant.

```gdscript
{
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
    "stairs_up": Vector2(150, 150),   # NW quadrant
    "zones": {
        "cave":             Rect2(720, 520, 660, 460),    # cave prefers SE quadrant (opposite stairs-up)
        "stairs_down_rock": Rect2(720, 520, 660, 460),    # stairs-down also SE — forces full traversal
        # ore/rocks: arena-wide; naturally split across 4 quadrants
    },
}
```

- Center clearing is 240 px wide (x=580 to x=820) and 240 px tall (y=380 to y=620). Every quadrant connects via this hub only.
- Each quadrant is roughly 580 x 380 (NW, NE, SW, SE). Similar ore density because rocks/ore roll arena-wide.
- Stairs-up NW, stairs-down-rock prefers SE → player walks diagonally across the whole arena, through the hub, to leave. Maximum exploration per floor.
- Cave in SE quadrant (if rolled) compounds the "deep corner" feel.

---

## 4. Template Selection

```gdscript
# In generate_floor(), before anything spawns:
func _pick_template() -> Dictionary:
    if GameManager.current_floor == 1:
        return TEMPLATES["open_arena"]  # hardcoded tutorial
    var eligible := []
    var total := 0.0
    for t in TEMPLATES.values():
        if GameManager.current_floor >= t["min_floor"]:
            eligible.append(t)
            total += t["weight"]
    var roll := randf() * total
    var acc := 0.0
    for t in eligible:
        acc += t["weight"]
        if roll <= acc:
            return t
    return eligible[-1]
```

Resulting weights:

| Floor | open_arena (w=2) | two_chambers (w=2) | cross_corridor (w=1.5) | Effective % |
|---|---|---|---|---|
| B1F | forced | — | — | 100 / 0 / 0 |
| B2F | 2.0 | 2.0 | 1.5 | 36 / 36 / 27 |
| B3F | 2.0 | 2.0 | 1.5 | 36 / 36 / 27 |
| B4F | 2.0 | 2.0 | 1.5 | 36 / 36 / 27 |
| B5F | 2.0 | 2.0 | 1.5 | 36 / 36 / 27 |

- B1F is always Open Arena — guarantees the first-time player sees the simplest layout.
- Cross Corridor is slightly rarer (1.5 vs 2.0) because it's the most disorienting layout. Two Chambers is the "middle-complexity" template and the most common non-open roll.
- Rationale for not gating C to B3F+: only 5 tier-1 floors exist, gating too aggressively would mean most runs never see template C.

---

## 5. Tech Implementation Hooks

### 5.1 New file
`scripts/dungeon/floor_templates.gd` — a const `TEMPLATES` dictionary (or a `class_name FloorTemplates` with a static getter if the tech agent prefers). No new Resource type. Content is the 3 template dicts above verbatim.

### 5.2 `floor_generator.gd` changes

1. Update `FLOOR_WIDTH = 1400.0`, `FLOOR_HEIGHT = 1000.0`.
2. Add a member `var _current_template: Dictionary`.
3. In `generate_floor()`:
   - `_current_template = _pick_template()`
   - `_create_walls()` as before (exterior) → then iterate `_current_template["walls"]` and call `_add_wall(wall.pos, wall.size)` for each.
   - For each interior wall, also call new helper `_reserve_wall(rect)` which adds entries to `_occupied_positions` so ore/rocks/cave can't spawn on top of the wall.
   - Stairs-up uses `_current_template["stairs_up"]` instead of the hardcoded `Vector2(80,80)`.
   - Ore / rocks / cave spawning: add an optional `zone: Rect2` parameter to `_reserve_position`. If a zone is passed, sample inside the zone first; if all attempts fail, fall back to arena-wide sampling. Pass `_current_template["zones"].get("ore")` etc. when calling.

4. `_reserve_wall(rect: Rect2)` helper: approximates the wall with a chain of circular "occupied" markers so rejection sampling avoids the wall footprint. Simple implementation: place markers every 48 px along the long axis with radius = half the short axis + 24.

5. `_random_floor_position()` already uses `FLOOR_WIDTH` / `FLOOR_HEIGHT` — no change.

6. Wanderer placement (`_roll_wanderer_position`): no template-specific logic. It already uses `_reserve_position()`, which will now avoid walls via the wall markers. The 300-650 px distance-from-player filter still applies and should still work because the bigger arena provides more "far" candidate positions.

### 5.3 Player spawn
Player currently relies on `Vector2(80,80)` as the de facto spawn via the stairs-up fixed pos. After this change, player spawn must follow the template's `stairs_up`. Tech: check how the player entrance position is set in `mining_floor.tscn` / `player.gd` `_ready()`. If the player is placed via scene file, we'll need a runtime move in `floor_generator.generate_floor()` after template is picked, something like `get_tree().get_first_node_in_group("player").global_position = _current_template["stairs_up"]`.

### 5.4 Coordination with parallel "random stairs" work
PO mentioned a parallel fix that randomizes stairs-up position. **This spec supersedes that.** Stairs-up is template-owned. If the random-stairs PR lands first, the template code should overwrite its output. If this PR lands first, random-stairs should be dropped. Flag both directions in the commit message.

---

## 6. Open Questions for Eddie

1. **Gap width in Two Chambers:** 160 px clear passable — tight enough to feel like a choke, wide enough for bot pathing? If bots get stuck, widen to 200.
2. **Cross Corridor hub size:** 240x240 center clearing. Is that enough to host a timed portal spawn + 2-4 enemies without them glitching into the 4 walls? May need a hub-size bump.
3. **Treasure rock zone bias:** should treasure rocks also prefer the "far" zone (SE in Cross, lower in Two Chambers) to reward traversal, or stay arena-wide so the player sometimes lucks into one near the entrance? Spec currently says arena-wide (simpler).
4. **Density numbers:** 22 ore / 14-20 rocks is a gut-feel scale-up. First playtest should measure per-floor time and tune up or down. Target band: 40-70s per floor (a hair longer than the doc §8 target of 30-60s, because traversal is longer in the new arena).
5. **Should B1F always be open?** Current spec: yes, hardcoded. Alternative: B1F also rolls templates so every run feels fresh. Eddie to decide — recommendation is "keep it hardcoded, tutorial value > variety on the first floor".
6. **Cave placement in Open Arena:** no zone bias — cave spawns anywhere. Should it at least avoid the stairs-up corner? Spec currently relies on `_reserve_position` separation to keep it far enough away organically.

---

## 7. Out of Scope (Explicit)

- Procedural generation (rooms-and-corridors, BSP, cellular automata). Deferred.
- New wall art / tilesets. Walls stay `Color(0.4, 0.32, 0.25)` via `_add_wall()`.
- Per-template music / ambient audio.
- Per-template enemy composition overrides.
- Decorative props, destructible non-rock environment, hazard tiles.
- Template D (Spiral). Cut from this sprint.
