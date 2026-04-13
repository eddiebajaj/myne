# Sprint 4 — First Companion + Solo Merge

**Sprint goal:** Deliver the game's signature mechanic — a permanent companion bot that merges with Myne for timed combat transformation.

**Themes:** 2 (per Sprint 3 lesson: cap scope)

1. **Scout companion** — permanent bot that follows and fights, earned at B5F
2. **Solo merge** — Myne absorbs Scout for a timed power-up (upper or lower body)

---

## Pillar A — Scout Companion

### A1. Permanent bot data

A new concept separate from disposable bots. Lives in `Inventory` (not GameManager, since Inventory already handles bot state).

```
Inventory.permanent_bots: Array[Dictionary]
# [{id: "scout", display_name: "Scout", health: float, max_health: float, knocked_out: bool}]

Inventory.run_party: Array[Dictionary]
# The 1-2 permanent bots selected for this run (subset of permanent_bots)
```

- Permanent bots are EARNED (not built from ore)
- They persist across ALL runs — never lost
- On "death" in a run: knocked out (can't fight, can't merge), restored to full HP in town
- Not affected by checkpoint/death rollback (they're permanent)

### A2. Scout unlock

- After reaching B5F checkpoint for the first time, a cutscene/popup in town grants the Scout
- For Sprint 4: simple popup when returning to town after B5F checkpoint. "You found a crystal companion in the mines! Scout joins your party."
- Scout is automatically added to `Inventory.permanent_bots`
- Scout is automatically added to `Inventory.run_party` (only 1 slot used for now)

### A3. Scout stats (T1 baseline)

| Stat | Value | Notes |
|---|---|---|
| HP | 40 | Tankier than Combat Drone (50) but doesn't scale with ore tier |
| Damage | 5 | Between beetle (5) and combat drone (8) |
| Attack range | 130 | Slightly more than combat drone (120) |
| Attack speed | 1.2/s | Faster than combat drone (1.0) — "fast attacks, low damage" |
| Move speed | 120 | Faster than combat drone (100) — scout is quick |
| Follow distance | 50 | Stays close to Myne |

### A4. Scout behavior

Same as CombatDrone: follows player when idle, targets nearest enemy in range, attacks on cooldown. Uses the existing `bot_base.gd` + a new `permanent_bot.gd` that extends it.

Key difference from disposable bots:
- Does NOT consume ore or battery to deploy
- Spawns automatically at run start (from `run_party`)
- On death: set `knocked_out = true`, remove from floor. NOT removed from `run_party`.
- On return to town: `knocked_out = false`, HP restored to max
- Does NOT save/restore at checkpoints (permanent bots are simpler: alive or knocked out)

### A5. Scout spawning

In `mining_floor_controller._ready()`:
- After respawning follower bots, also spawn permanent bots from `Inventory.run_party`
- Skip any that are `knocked_out`
- Spawn near player position (same offset pattern as follower bots)

### A6. Scout visual

- Larger than disposable bots (28x28 vs 20x20)
- Distinct color: bright cyan `Color(0.3, 0.9, 1.0)`
- Small crown/star indicator above to distinguish from disposable bots
- Health bar visible

---

## Pillar B — Solo Merge

### B1. Merge concept

Myne absorbs the Scout to transform. One bot, assigned to either upper (weapons) or lower (movement) body. Costs 1 battery. Duration based on battery tier.

### B2. Merge trigger

- New **X button** on touch controls (below A in the diamond: Y top, B left, A right, X bottom)
- Desktop: X key
- Only available when a permanent bot in `run_party` is alive (not knocked out) and player has ≥1 battery
- Pressing X opens the **Merge Panel** (same pattern as build menu — PanelContainer in MiningHUD, pauses game)

### B3. Merge Panel UI

```
┌─────────────────────────┐
│     MERGE WITH SCOUT     │
│                          │
│  [Upper Body]            │
│  Rapid-fire crystal      │
│  shots for 15s           │
│                          │
│  [Lower Body]            │
│  Dash movement +         │
│  high speed for 15s      │
│                          │
│  Cost: 1 battery         │
│  Duration: 15s (T1)      │
│                          │
│  [Cancel]                │
└─────────────────────────┘
```

- Two buttons: Upper Body, Lower Body
- Each shows what the merge does
- Battery cost + duration shown
- Cancel button closes panel

### B4. Merge execution

When player selects Upper or Lower:
1. Consume 1 battery
2. Remove Scout from the floor (it merges into Myne)
3. Apply merge stat changes to player
4. Start merge timer (duration based on battery tier)
5. Visual change on player (color shift + size increase)
6. When timer expires: revert stats, re-spawn Scout near player

### B5. Merge stats

**Scout Upper (weapons):**
| Stat | Change | Duration |
|---|---|---|
| Damage | +8 (pickaxe becomes crystal rapid-fire) |  Battery tier dependent |
| Attack speed | 3.0/s (was ~2.8/s from swing cooldown) | |
| Attack range | 180px (was 48px pickaxe) | |
| Visual | Player turns cyan, size 36x36 | |

**Scout Lower (movement):**
| Stat | Change | Duration |
|---|---|---|
| Move speed | 350 px/s (was 200) | Battery tier dependent |
| Armor | +5 (crystal legs absorb hits) | |
| Dodge | Invulnerability frames doubled (1.0s vs 0.5s) | |
| Visual | Player turns cyan, legs glow | |

### B6. Merge duration by battery tier

| Battery Tier | Duration |
|---|---|
| T1 (basic) | 15s |
| T2 (improved) | 30s |
| T3 (advanced) | 45s |
| T4 (superior) | 60s |

Currently only T1 batteries exist, so 15s is the practical duration.

### B7. Merge timer UI

- Add a merge timer bar to the HUD (below HP bar or as an overlay)
- Shows remaining merge time
- Flashes when <3s remaining
- On expire: stats revert, Scout re-appears

### B8. Merge restrictions

- Can't merge if Scout is knocked out
- Can't merge if no batteries
- Can't merge while already merged
- Can't open build menu while merged (bot building still works normally after merge ends)
- CAN mine while merged (merge enhances combat, doesn't replace mining)
- Taking stairs while merged: merge continues, timer keeps running

---

## Implementation Notes for Tech Agent

### New files
- `scripts/bots/permanent_bot.gd` — extends BotBase, adds knocked_out state, no ore/battery cost

### Modified files
- `scripts/autoload/inventory.gd` — add `permanent_bots`, `run_party`, unlock/knockout/restore methods
- `scripts/autoload/game_manager.gd` — trigger Scout unlock on first B5F checkpoint
- `scripts/dungeon/mining_floor_controller.gd` — spawn permanent bots from run_party
- `scripts/autoload/touch_controls.gd` — add X button
- `project.godot` — add `action_x` input action
- `scripts/ui/mining_hud.gd` — merge panel UI, merge timer display, X button handling
- `scripts/player/player.gd` — merge state (stat overrides, timer, visual changes, revert)

### Key integration points
- Merge stat changes: override player stats temporarily. Store original values, restore on expire.
- Scout follows same respawn pattern as follower bots in mining_floor_controller
- Merge timer: use a Timer node on the player, or track in _process with a float

---

## Out of Scope (Explicit)

- Dual merge (2 bots, upper + lower) — Sprint 5
- Second permanent bot (Guardian) — Sprint 5
- T2 balance / content — deferred until merge is fun
- Save system — deferred until mechanics are fun
- Full sprite art pass — Sprint 5 (style decided: pixel art 32x32, Binding of Isaac reference)
- Merge transformation animation sequence — simple color shift + particle burst for now
- Party selection UI (only 1 bot, auto-selected)
- Bot upgrades at Lab
- Story/narrative beyond the unlock popup

---

## Pillar C — Combat Readability

Code-driven visual feedback. No sprite assets — just tweens, particles, and colored shapes. Makes combat readable instead of invisible.

### C1. Enemy attack visual
- When an enemy deals damage: flash the enemy sprite **red** for 0.1s + brief lunge toward target (tween position 8px toward player, snap back)
- Makes it clear WHEN and WHO is hitting you

### C2. Bot/turret projectile
- When a turret or drone attacks: spawn a small colored circle (6px) that moves from bot to target at 600px/s
- Color matches the bot's color (yellow for turret, red for combat drone)
- Disappears on reaching target
- Makes bot combat visible — you can SEE your turret working

### C3. Player damage feedback
- On taking damage: brief white flash on player sprite (0.1s) + camera shake (2px random offset for 0.15s)
- Already has 0.5s invulnerability flash (modulate.a = 0.5) — this adds impact to the hit moment

### C4. Damage numbers
- When any entity takes damage: floating number rises and fades (same pattern as pickup popups)
- Color-coded: white for normal, red for player damage taken, yellow for bot damage dealt
- Shows the actual damage value — helps players understand balance

### C5. Merge transformation
- On merge: player color shifts to cyan, size increases 24→36, brief particle burst (8 small colored rects flying outward)
- On merge expire: reverse burst, size/color revert
- Merge timer bar on HUD pulses when <3s remaining

---

## Art Direction (Sprint 5 prep)

**Style:** Pixel art, 32x32 tiles. Reference: Binding of Isaac (top-down, readable silhouettes, expressive with minimal pixels).

**Sprint 5 target:** First sprite pass covering player, 4 enemy types, 4 disposable bots, Scout companion, ore nodes, rocks, walls, stairs. Style guide and palette decided in Sprint 4, sprites produced in Sprint 5.

---

## Acceptance Criteria

### Scout Companion
- [ ] Scout unlocked after first B5F checkpoint return to town
- [ ] Scout appears automatically at run start, follows player, fights enemies
- [ ] Scout survives floor transitions (stairs down)
- [ ] Scout knocked out on death (removed from floor, not lost permanently)
- [ ] Scout restored to full HP on return to town
- [ ] Scout visually distinct from disposable bots (larger, cyan, indicator)

### Solo Merge
- [ ] X button opens merge panel when Scout is alive and player has battery
- [ ] Upper merge: increased damage + attack speed + range for duration
- [ ] Lower merge: increased move speed + armor + dodge for duration
- [ ] 1 battery consumed on merge
- [ ] Merge timer shows on HUD, flashes near end
- [ ] Stats revert and Scout re-appears when timer expires
- [ ] Can't merge when knocked out / no battery / already merged
- [ ] Merge persists across floor transitions

### Combat Readability
- [ ] Enemies flash red + lunge when dealing damage
- [ ] Turrets and drones fire visible projectiles at targets
- [ ] Player flashes white + camera shakes on taking damage
- [ ] Floating damage numbers on all combat hits
- [ ] Merge transformation has visual burst effect + HUD timer

---

## Delivery Order

1. **Pillar C first** — combat visuals (small, independent, improves feel for everything after)
2. **Pillar A second** — Scout companion spawning, following, fighting
3. **Pillar B third** — merge UI + mechanics on top of working companion
4. **Playtest checkpoint** after each pillar
5. **Sprint review** after all verified
