# Sprint 7 — Build-Your-Own-Bot Crafting + Mineral Ramp

**Sprint goal:** Replace fixed bot recipes with a flexible point-based crafting system. Apply mineral bonuses at build time. Smooth the early-game mineral introduction.

**Pillars:**
1. **A:** Build-your-own-bot crafting (point system, recipe UI, mineral bonuses, multi-instance bots)
2. **B:** Mineral spawn rate ramp (5/15/25% by floor depth)

Pillar A is the big one. B is tiny — likely 5 lines of code.

---

## Pillar A — Build-Your-Own-Bot Crafting

### A1. Point system (constants)

```gdscript
const ORE_POINTS_BY_TIER := {
    1: 1,    # T1 ore = 1 point
    2: 3,    # T2 ore = 3 points
    3: 9,    # T3 ore = 9 points
    4: 27,   # T4 ore = 27 points
}
const BOT_BUILD_THRESHOLD := 10  # All bots cost 10 points (uniform for now)
```

If allocated points exceed threshold (e.g. 11), build proceeds and the excess is wasted. No refunds.

### A2. Bot data model changes

Update `permanent_bots` entries in `Inventory`:

```gdscript
{
    "id": "scout",                    # Bot type
    "instance_number": 1,             # Auto-incremented per type for display ("Scout #1", "Scout #2")
    "display_name": "Scout #1",       # User-facing name (rename feature future)
    "max_health": 40.0,
    "health": 40.0,
    "damage": 5.0,
    "cp_cost": 1,
    "knocked_out": false,
    "mineral_profile": {              # Accumulated minerals from build
        "fire": 0,
        "ice": 0,
        "earth": 0,
        "thunder": 0,
        "venom": 0,
        "wind": 0,
        "void": 0,
    },
    "void_resolved": [],              # Realized random bonuses from void minerals (so they're stable across floor reloads)
    "hp_upgrade_level": 0,            # Legacy from Sprint 5 — kept for compatibility, used by old upgrade view (which we hide)
    "damage_upgrade_level": 0,        # Legacy from Sprint 5
}
```

Multiple instances of the same `id` are allowed. `has_permanent_bot(id)` no longer prevents builds.

Add helper:
```gdscript
func count_permanent_bots_of_type(id: String) -> int:
    var n := 0
    for bot in permanent_bots:
        if bot.get("id", "") == id:
            n += 1
    return n
```

### A3. Mineral bonus values (per piece)

| Mineral | Bonus per piece | Storage on bot |
|---|---|---|
| Fire | +1 base damage | `damage += fire_count` |
| Ice | +0.3s slow duration on hit | Stored, applied to projectile/melee hit code |
| Earth | +5 max HP | `max_health += earth_count * 5` |
| Thunder | +10% chain-hit chance | Stored, used in attack code |
| Venom | +1 armor pierce | Stored, applied to damage calc |
| Wind | +5% attack speed | `attack_speed *= 1 + wind_count * 0.05` |
| Void | Random — one effect from the above 6 per piece | Resolved at build time, stored in `void_resolved` |

For Sprint 7: implement Fire, Earth, Wind, Void at full bonus level. Ice/Thunder/Venom store the data but actual hit-side mechanics may stub if not already in place. Verify which effects already exist in `bot_base.gd` and `enemy_base.gd` mineral on-hit code.

### A4. Crafting UI (Lab Build Bot view)

Replace the existing Build Bot view in `npc_lab.gd` with a recipe-grid layout:

```
┌──────────────────────────────────────┐
│ Build: Scout                          │
│ Stats: 40 HP, 5 dmg, 130 range        │
│                                       │
│ ┌─ Inventory ─────┐ ┌─ Build slot ─┐ │
│ │ Iron T1   x12   │ │ Iron x5        │ │
│ │ Copper T1 x3    │ │ Crystal x1     │ │
│ │ Crystal T2 x2   │ │ Fire-Iron x1   │ │
│ │ Fire-Iron x4    │ │                │ │
│ │ ...              │ │ Total: 9/10    │ │
│ └──────────────────┘ │ Bonuses:       │ │
│                       │   +1 dmg (Fire)│ │
│ [Auto-assign]         └────────────────┘│
│ [Build] (disabled until ≥10 points)     │
│ [Cancel/Back]                            │
└──────────────────────────────────────┘
```

UI structure (built programmatically):
- Header: bot type + base stats
- Two columns: Inventory (left) + Build Slot (right)
- Inventory entries: each ore stack with quantity. Pressing A adds 1 to Build Slot.
- Build Slot entries: ores added so far. Pressing A removes 1.
- Running total below Build Slot showing X/10 points.
- Bonus preview: lists which mineral bonuses would apply.
- Auto-assign button: greedy fill cheapest-first (T1 plain → T1 mineral → T2 plain → T2 mineral → ...).
- Build button: disabled until total ≥ threshold; on press, executes build.
- Cancel: close panel without committing.

For initial implementation, focus on functionality over polish. The recipe grid can be a simple list of buttons with quantity labels.

### A5. Per-bot Build Bot list (entry point)

Lab > Build Bot view shows the bot type list (Miner, Striker, Backpack Bot, Scout if blueprint owned). Selecting a type opens the recipe UI for THAT type.

Multiple instances allowed, so don't grey out "owned" types — player can build a 2nd Scout with different minerals.

### A6. Build execution

When player presses Build:
1. Validate total points ≥ threshold (defensive; button is disabled otherwise)
2. Spend allocated ores from Inventory.carried_ore + Inventory.storage (storage first, matching existing pattern)
3. For each Void mineral allocated: roll a random bonus type, store in `void_resolved` array
4. Calculate `mineral_profile` from non-void minerals
5. Create new bot entry with auto-incremented `instance_number`, `display_name = "%s #%d" % [TypeName, instance_number]`
6. Apply mineral bonuses to base stats (max_health, damage)
7. Append to `permanent_bots`
8. Emit `bots_changed`
9. Close crafting UI, return to Build Bot list

### A7. Auto-assign algorithm

Greedy:
1. Reset build slot
2. List all available ore stacks (backpack + storage), sorted by tier ascending (cheapest first), then plain before mineral within a tier (preserve minerals for intentional builds)
3. Iterate: while running_total < threshold, take 1 piece from current source. Move to next source when current is exhausted.
4. Stop when threshold reached or all ore used (insufficient warning if latter)

### A8. Spawn-time stat application

In `mining_floor_controller._spawn_permanent_bot`, read `mineral_profile` from entry and apply bonuses to the base stats:
- `damage += mineral_profile.fire * 1`
- `max_health += mineral_profile.earth * 5`
- `attack_speed *= 1.0 + (mineral_profile.wind * 0.05)`
- For Void: iterate `void_resolved` and apply each as if it were the corresponding mineral
- Store ice/thunder/venom counts on the bot via meta or new fields for runtime hit code to read

The spawn function already applies upgrade levels (hp_upgrade_level, damage_upgrade_level) — keep that; minerals stack on top.

### A9. Hide old "Upgrade Bots" Lab view

The legacy ore+gold per-stat upgrade view doesn't fit the new design (Sprint 8 will reimplement upgrades using crafting mechanic). For Sprint 7:
- Hide the "Upgrade Bots" button in Lab main menu
- Or show "Coming Soon" placeholder
- Don't delete the code (keep for reference)

### A10. Display mineral profile on bot

Show mineral bonuses on bots in:
- Lab build confirmation
- Backpack followers list (e.g. "Scout #2 (Fire+3, Earth+1)")
- Party selection in mine entrance

Compact format: "(Fire+3, Earth+1)" — only show non-zero mineral counts. Void shows as "(Void+N)" with N being the count.

---

## Pillar B — Mineral Spawn Rate Ramp

In `floor_generator.gd` `_spawn_ore_nodes`, replace the constant `MINERAL_CHANCE = 0.25` with a per-floor lookup:

```gdscript
func _get_mineral_chance() -> float:
    var floor_num: int = GameManager.current_floor
    if floor_num <= 3:
        return 0.05
    elif floor_num <= 5:
        return 0.15
    else:
        return 0.25
```

Replace the existing `MINERAL_CHANCE` usage with a call to this. Keep the Lucky Strike artifact bonus on top of the floor chance.

---

## Acceptance criteria

### Pillar A
- [ ] All bot types buildable from any ore combination totaling ≥10 points
- [ ] Multiple instances of same bot type allowed (Scout #1, Scout #2, etc.)
- [ ] Mineral ores allocated at build time apply bonuses to the built bot
- [ ] Void mineral resolves to a random bonus type at build time (stored, not re-rolled)
- [ ] Auto-assign fills cheapest available ore first
- [ ] Build button disabled until threshold met
- [ ] Storage spent before backpack on build
- [ ] Mineral bonuses visible on bot in Backpack Followers panel
- [ ] Multiple Scouts have distinct names ("Scout #1", "Scout #2", etc.)
- [ ] Old "Upgrade Bots" Lab view hidden

### Pillar B
- [ ] Mineral chance is 5% on B1-B3, 15% on B4-B5, 25% on B6+
- [ ] Lucky Strike artifact still adds its bonus on top

---

## Out of Scope (Explicit)

- Bot upgrades using crafting mechanic (Sprint 8)
- Bot rename UI (future)
- Storage tabs / paginated storage (future)
- Tetris-like backpack (future)
- Variable bot threshold (10 pts for all; per-bot tuning future)
- New bot types (Guardian, Healer, Amplifier — future)
- Ice/Thunder/Venom on-hit mechanics changes (just ensure data flows through if mechanics already exist)

---

## Risks

- **Crafting UI complexity** — recipe grid + auto-assign + bonus preview is the most complex UI we've built. Test focus navigation carefully.
- **Bot data migration** — existing saved bots (if any) won't have `mineral_profile` field. Add safe defaults via `entry.get("mineral_profile", {})` everywhere.
- **Mineral bonus stacking math** — verify that bot stats don't double-apply (e.g. base + mineral = displayed value; spawn shouldn't add minerals twice).

---

## Delivery Order

1. **Pillar B first** — tiny change, gets the ramp in place for testing builds at depth
2. **Pillar A** — point system + data model + UI + spawn integration
3. **Playtest checkpoint** after A
4. **Sprint review**
