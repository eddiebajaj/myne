# Sprint 02 — Economy & Mine Polish Spec

**Author:** Design Agent
**Date:** 2026-04-11
**Scope:** Town economy loop (Smith / Lab / Market) + visible ore drops + openable backpack UI. Everything in this doc is implementable today by the tech agent without further clarification. Items flagged `[EDDIE?]` are decisions the PO should confirm but have a default answer the tech agent can ship if no response.

**Balance source of truth:** `docs/design/13_balance_t1.md`. This doc references that where applicable and only invents numbers where T1 balance is silent.

---

## 1. Visible Ore Drops + Auto-Magnet Pickup

### 1.1 Current behavior (to be replaced)
`scripts/dungeon/ore_node.gd::_break()` currently calls `Inventory.add_ore(...)` directly on break. Remove that auto-collect. Instead, spawn pickup entities in the world.

### 1.2 Drop scatter pattern
When an ore node breaks, spawn **1 `OrePickup` per ore yielded** (currently always 1 piece per node per `13_balance_t1.md` §5a, but the code should loop so this scales if nodes ever yield >1).

- Spawn origin: ore node `global_position`.
- Per-pickup offset: random point in a ring, `radius = randf_range(6, 14)` px, `angle = randf() * TAU`.
- Apply a short "pop" tween on spawn: pickup scales 0→1 over 0.12s and tweens from origin to `origin + offset` via `Tween.TRANS_QUAD`, `EASE_OUT`, duration 0.18s.
- During pop (0.18s), pickup is **not magnet-eligible** (prevents it snapping back to the player mid-pop).

### 1.3 Pickup visual spec (`OrePickup` scene)
New scene: `scenes/dungeon/ore_pickup.tscn` + `scripts/dungeon/ore_pickup.gd` (Area2D).

- Root: `Area2D` with a `CircleShape2D` collision radius **10 px** (used only for player overlap detection; magnet pull is done in `_physics_process`, not via signals).
- Visual: `ColorRect` **12x12 px**, centered, `color = ore_data.color`.
- Mineral glow: if `mineral != null`, add a second `ColorRect` **16x16 px** behind the main rect with `color = Color(mineral.color, 0.4)`. Mirrors how `ore_node.gd` currently draws `mineral_glow`.
- Bobbing: `_process` adds `position.y = base_y + sin(time * 3.0) * 1.5` (subtle, 3 px peak-to-peak).
- Pulse (mineral only): modulate alpha of the glow rect between 0.25 and 0.55 over 0.8s using a looping tween.
- `z_index = 5` so pickups render above the floor but below the player.

### 1.4 Auto-magnet behavior
Viewport is 1280x720, player is ~32x32. Values chosen to feel generous on mobile but not trivialize positioning:

| Parameter | Value | Rationale |
|---|---|---|
| Magnet start radius | **140 px** | ~4 player-widths. Visible from a comfortable distance on 1280x720. |
| Instant-collect radius | **14 px** | When the pickup overlaps the player hitbox, collect immediately. |
| Initial pull speed | **60 px/s** | Slow drift at the edge of the magnet field. |
| Max pull speed | **520 px/s** | Faster than player top speed (200 px/s) so pickups always catch up. |
| Acceleration | `speed += 900 * delta` while within magnet radius | Reaches max in ~0.5s. |
| Pull direction | Normalized vector from pickup to `player.global_position` each frame. | Pickups home in, not straight lines. |

Implementation sketch (reference, not binding):
```gdscript
func _physics_process(delta):
    if not _magnet_eligible: return
    var to_player = player.global_position - global_position
    var dist = to_player.length()
    if dist <= INSTANT_RADIUS:
        _collect(); return
    if dist <= MAGNET_RADIUS:
        _speed = min(_speed + ACCEL * delta, MAX_SPEED)
        position += to_player.normalized() * _speed * delta
    else:
        _speed = INITIAL_SPEED  # reset if player walks away
```

### 1.5 Lifetime
**No despawn.** Pickups persist until collected or the floor is regenerated. Rationale: floors are small (30-60s per `13_balance_t1.md` §8), ore is precious, and despawning would feel punishing. Floor transition already frees the whole dungeon tree.

### 1.6 Edge case: backpack full
**Recommendation: pickup stays on the ground, bounces gently away on contact.**

- On `_collect()`, call `Inventory.can_add_ore(ore, mineral, 1)`. If false:
  - Abort the collect.
  - Push the pickup away from the player along `-to_player.normalized() * 40` over 0.15s (quick nudge).
  - Disable magnet for **0.6s** after the bounce so it doesn't immediately snap back.
  - Emit no sound/flash (avoid spam).
- This gives the player natural visual feedback that the backpack is full, matches the existing `backpack_full` signal, and lets them come back for it after selling.

`[EDDIE?]` — Alternative is "auto-discard oldest ore to make room" but that feels hostile. Default: bounce-back.

---

## 2. Openable Backpack UI

### 2.1 Input
- **Desktop:** `Tab` key. Add a new input action `toggle_backpack` (default: `Tab`) to `project.godot`.
- **Mobile/touch:** A dedicated on-screen button in the mining HUD top-right, **72x72 px**, backpack icon, tap to toggle. Reuse the existing touch-button pattern from the Space/mine button (see commit `5c3bb31`).
- **Close:** same input (`Tab` or button tap), `ui_cancel` (Esc), or the in-panel `[Close]` button.

### 2.2 Pause behavior
Backpack panel follows the **build menu pattern**: while open, `get_tree().paused = true`. The backpack scene root must have `process_mode = PROCESS_MODE_ALWAYS` so it can still receive input. Confirm against the existing build menu code — if build menu uses a different pause approach, match it exactly so both overlays behave identically.

### 2.3 Layout

```
┌──────────────────────────────────┐
│ BACKPACK                  12/16  │
│ ┌────┬────┬────┬────┐            │
│ │ Fe │ Fe │ Cr │    │  Gold: 340 │
│ │    │    │    │    │  🔋 x 3    │
│ ├────┼────┼────┼────┤            │
│ │ Cr │ Cr │ Ag │    │  FOLLOWERS │
│ │ 🔥 │ 🔥 │    │    │  ⚔ Drone   │
│ ├────┼────┼────┼────┤  ⛏ MineBot │
│ │ Au │ Au │ Au │ Ob │            │
│ ├────┼────┼────┼────┤            │
│ │ Ob │ Ob │ Ob │    │            │
│ │ ⚡ │ ⚡ │ ⚡ │    │            │
│ └────┴────┴────┴────┘            │
│                                   │
│             [  Close  ]           │
└──────────────────────────────────┘
```

- **Grid:** 4 columns × (4 + `upgrade_levels.grid_rows`) rows, matching `Inventory.get_max_capacity()`. Expandable up to 4×8 (max `grid_rows = 4`, see §3).
- **Cell size:** **80×80 px** on mobile, **64×64 px** on desktop. Mobile meets the ≥64 px touch target requirement and leaves breathing room.
- **Cell contents:**
  - Background: `ColorRect` using `slot.ore.color`.
  - Mineral indicator: small icon in top-right corner tinted to `slot.mineral.color` if mineral is present. Use a 16×16 filled circle placeholder.
  - Quantity label: bottom-right, white text with 1 px black outline, e.g. `x3`. Only shown if quantity > 1.
  - Empty cells: dark gray (`Color(0.15, 0.15, 0.18)`) with a 1 px border.
- **Stacking:** one cell per stack (matching `carried_ore` structure), not one cell per ore piece. A stack of 5 Iron shows as a single cell with `x5`. This makes the UI trivial to render and is consistent with how Inventory actually stores data.

`[EDDIE?]` — The 09_ui_ux.md mockup showed one cell per piece (Tetris-ish). I'm recommending one cell per stack because the code already stacks, and 16 individual iron cells would look worse. Flag for Eddie.

### 2.4 Side panel
Always visible while backpack is open:

- **Gold:** `Gold: N` with coin icon. Shown **always** (mining and town). Redundant with town HUD, but useful mid-run for planning sells.
- **Battery count:** `🔋 x N` — always visible.
- **Follower bot list:** each entry shows bot name + a colored pip for ore_tier/mineral. Scrollable if >4. Empty state: "No followers".

### 2.5 Action buttons
For Sprint 2, just `[Close]`. Discard ore is deferred (not critical for shipping the economy loop; bounce-back handles the "too full" pain).

### 2.6 Mobile sizing
- Panel min size: 640×720 px centered.
- All interactive elements ≥ 64 px square.
- Close button: 120×72 px.

---

## 3. Smith Upgrades — Concrete Prices & Effects

Source: `06_player_stats.md` hits-table and `13_balance_t1.md` pacing. Current `npc_smith.gd` already has provisional numbers — this section supersedes them.

### 3.1 Pickaxe upgrades

| Upgrade | From → To | Gold cost | Effect on T1 node | Effect on T2 node | Effect on T3 node | Effect on T4 node |
|---|---|---|---|---|---|---|
| Pickaxe 1 → 2 | Starter → T2 | **40** | 3 → 2 hits | 6 → 4 hits | 12 → 8 hits | 20 → 14 hits |
| Pickaxe 2 → 3 | T2 → T3 | **120** | 2 → 1 hit | 4 → 3 hits | 8 → 5 hits | 14 → 9 hits |
| Pickaxe 3 → 4 | T3 → T4 | **320** | 1 → 1 hit | 3 → 2 hits | 5 → 3 hits | 9 → 5 hits |

Hits values come straight from `OreData.HITS_TABLE` — no new numbers invented. Gold costs chosen so:
- 40g is reachable after ~2 full B1F-B2F runs (10-15 ore × ~2-3g each).
- 120g requires a deeper run pushing into B3F-B5F, matches unlocking first portal.
- 320g is end-of-T1 goal; fits the "save up across many runs" feel.

`npc_smith.gd` currently uses `[0, 25, 60, 150]`. Update to `[0, 40, 120, 320]`.

### 3.2 Armor levels

4 levels, flat armor values. Armor absorbs damage before HP (per `06_player_stats.md`).

| Level | Name | Gold cost | Armor value |
|---|---|---|---|
| 1 | Leather Armor | **30** | 10 |
| 2 | Chain Armor | **90** | 20 |
| 3 | Plate Armor | **220** | 35 |
| 4 | Crystal Armor | **500** | 55 |

Smith UI shows only the **next unlocked level** as a buyable row (same pattern as current `npc_smith.gd`). Each purchase sets `Inventory.upgrade_levels.armor_value` to the new flat value (not additive — you replace the armor set).

Armor repair: **deferred to Sprint 3**. Armor is full-value on each run start for now. Flag: no armor degradation system exists yet in code.

### 3.3 Backpack row upgrades

Starting grid is 4×4 = 16 slots. Each upgrade adds one row of 4 cells.

| Upgrade | Grid result | Gold cost |
|---|---|---|
| Row 5 (+1st row) | 4×5 = 20 | **60** |
| Row 6 (+2nd row) | 4×6 = 24 | **150** |
| Row 7 (+3rd row) | 4×7 = 28 | **320** |
| Row 8 (+4th row, MAX) | 4×8 = 32 | **600** |

Escalating costs match the pickaxe pacing. `npc_smith.gd` currently uses `30 * (extra_rows + 1)` linear — replace with the explicit table above. Cap at `grid_rows = 4`.

### 3.4 Smith UI display format

Panel layout (vertical list):

```
SMITH
Gold: 340g

— PICKAXE —
  [ Pickaxe T1 → T2    40g   ] [Buy]    <- enabled, affordable
  (grayed-out lower tiers hidden)

— ARMOR —
  [ Leather Armor     30g   ] [Buy]

— BACKPACK —
  [ 4×4 → 4×5         60g   ] [Buy]
  Current: 16 slots

[ Close ]
```

Rules:
- Each row: description + cost + [Buy] button.
- `[Buy]` disabled if `GameManager.gold < cost`.
- Maxed categories show `MAX` label instead of a button.
- Only the **next** purchasable item per category is shown (don't clutter with future tiers).
- Result text ("Upgraded!") shown for 2 seconds after purchase, then clears.

---

## 4. Lab Crafting — Ore → Battery Recipe

Per `04_town_and_progression.md`, battery tier is determined by the ore tier used. For Sprint 2, ship **Basic batteries only** (T1 ore → Basic battery). Higher tiers are structurally ready but gated until T2 ore exists in the mine.

### 4.1 Recipe

| Battery tier | Ore requirement | Gold fee | Output |
|---|---|---|---|
| Basic | **3 × T1 ore** (any T1 type, mixable across types) | **5g** | 1 Basic battery |

**3 ore per battery** chosen because:
- A T1 floor yields ~10-15 ore (`13_balance_t1.md` §5a).
- At 3 ore/battery, a clean B1F run crafts 3-5 batteries — enough for several bot builds but not infinite.
- Creates real competition between selling ore for gold vs crafting batteries.
- Market sells a battery for 8g (current `npc_market.gd` `BATTERY_PRICE`). Crafting at the Lab costs 5g + 3 ore. If 3 T1 ore sells for ~6g, total crafting cost ≈ 11g — slightly worse than buying, but meaningful when ore is held over from a run and gold is tight.

`[EDDIE?]` — Alternative: drop the gold fee, make crafting purely ore-based. Default kept as 5g to give Lab a gold sink. Flag for review.

### 4.2 Mineral-infused ore in recipes
**Recommendation: NO for Sprint 2.** Mineral-infused ore is more valuable to sell and more interesting in bots. Forcing it into a battery is a waste. Plain ore only in the recipe.

If the player tries to craft with only mineral-infused ore available, show a disabled button with tooltip: "Requires plain ore — extract minerals at the Lab first."

### 4.3 UI (simplest viable)
Add a new section to the existing Lab panel:

```
— BATTERY CRAFTING —
  Basic Battery
  Requires: 3 × T1 ore + 5g
  Have: 7 T1 ore, 340g
  [ Craft Battery ]
```

One button, no recipe selector, no quantity picker. Click = craft one battery. Re-click to craft more. Button disabled if player lacks ore or gold, with reason text. No confirmation dialog.

### 4.4 Implementation notes
- "T1 ore" = any slot where `slot.mineral == null and slot.ore.tier == 1`. Spend 3 across any stacks, preferring smallest stacks first (to consolidate inventory).
- Add `Inventory.craft_battery() -> bool` helper that encapsulates the spend logic.

---

## 5. Market Polish

### 5.1 Per-ore breakdown
Replace the current single `inventory_label` string with a mini-table before the sell button.

```
— SELL ORE —
Iron          x8    @2g    =  16g
Copper        x3    @3g    =   9g
Crystal 🔥    x2   @15g    =  30g
────────────────────────────
TOTAL                         55g

[ Sell All ]
```

- Columns: name (includes mineral label), quantity, unit price (base + mineral bonus), subtotal.
- Use a `GridContainer` with 4 columns for clean alignment.
- Total row at the bottom in bold (larger font, white).
- If inventory is empty: show "Backpack is empty." and disable `[Sell All]`.

### 5.2 Feedback animation
On successful sell:
- Spawn a `Label` at the total-row position: `+55g`, gold color, bold.
- Tween: position.y -= 40 over 0.6s, modulate.a 1 → 0 over 0.6s, then `queue_free`.
- Play any available "coin" sfx if one exists; otherwise skip (no new assets this sprint).

### 5.3 Confirmation
**None.** The `[Sell All]` button is an intentional action. Confirmation would add friction for the most common operation. Matches the recommendation in the prompt.

---

## 6. Town HUD

### 6.1 Persistent gold display
Add a `CanvasLayer`-based HUD to the town scene (not the mining scene — mining has its own HUD).

- Position: top-right, 16 px margin.
- Layout: horizontal `HBoxContainer` with a 24×24 gold-colored circle (coin placeholder) + `Label` showing `GameManager.gold`.
- Updates via `GameManager.gold_changed` signal (add if missing).
- Font size: 24 px, white, 1 px black outline.

### 6.2 Battery count in town
**Optional, include it.** Same HBox, left of gold: `🔋 x N`. Useful because the Lab menu now lets the player craft batteries, and they want to see the running total without opening a menu.

### 6.3 Floor number / backpack bar
Not shown in town HUD — those are mining-only.

---

## Summary: Values Table Cheat-Sheet

| Thing | Value |
|---|---|
| Magnet radius | 140 px |
| Instant collect radius | 14 px |
| Magnet max speed | 520 px/s |
| Pickup size | 12×12 px |
| Backpack keybind | Tab |
| Backpack cell size | 80 px mobile / 64 px desktop |
| Pickaxe T1→T2 / T2→T3 / T3→T4 | 40g / 120g / 320g |
| Armor 1/2/3/4 cost | 30 / 90 / 220 / 500 |
| Armor 1/2/3/4 value | 10 / 20 / 35 / 55 |
| Backpack row 5/6/7/8 cost | 60 / 150 / 320 / 600 |
| Battery recipe | 3 T1 ore + 5g → 1 Basic battery |
| Market battery price | 8g (unchanged) |
| Floor gold HUD | Top-right, always shown in town |

---

## Decisions Confirmed by Eddie (2026-04-11)

1. **Backpack full behavior:** **Bounce-back.** (As specced in §1.6.)
2. **Backpack display:** **Cell-per-piece.** Override the per-stack default in §2.3. Render one cell per ore piece (sum of all stack quantities). Cells fill in row-major order. Inventory data model stays stacked (`carried_ore`) — only the UI iteration changes. `get_used_slots()` is already piece-based, so capacity math is unchanged.
3. **Lab battery gold fee:** **FREE — drop the 5g fee.** Recipe is just 3 × T1 ore → 1 Basic battery. Update §4.1 accordingly.
4. **Armor repair/degradation:** Confirmed deferred to Sprint 3.
5. **Mineral ore in battery recipes:** Confirmed NO.
6. **Free batteries on `begin_run()`:** **Keep at 3** for Sprint 2 (testing convenience).

## 2D-Friendly-for-Future-3D Guidance

Eddie has decided to stay 2D for now (see `docs/research_3d_feasibility.md`), but wants to keep the door open. When implementing Sprint 2, the tech agent should write code that would be cheaper to migrate to 3D later:

- **Position math:** prefer `Vector2` operations that have a clean `Vector3` analog (`.length()`, `.normalized()`, `.distance_to()`). Avoid `Vector2.angle()` tricks that don't translate.
- **Magnet/movement code:** use named direction vectors (`to_player`, `pull_dir`) rather than baking in 2D-only assumptions like `position.x` / `position.y` indexing.
- **Pickup scene:** keep the `OrePickup` script's collect/magnet logic in plain functions that operate on a position vector — don't intertwine it with `Area2D`-specific signals where avoidable. A future 3D port would swap the root node and reuse the logic.
- **No tilemap-specific assumptions** in new code (we don't have any yet — keep it that way for new pickup/UI work).
- **UI:** backpack panel and Smith/Lab/Market panels are CanvasLayer-based and would port to 3D unchanged. No special concern.
- **Don't over-engineer.** This is "pick the 3D-friendly option when it costs nothing", not "build an abstraction layer". If a 2D-only approach is significantly simpler, use it and add a `# 2D-only` comment.

## Contradictions Found Between Existing Docs & Code

1. **`09_ui_ux.md` Backpack mockup shows 16 individual ore cells** (e.g. `Fe|Fe|Cr|·`), suggesting one cell per ore piece. But `Inventory.carried_ore` stacks by (ore+mineral), so the code model is per-stack. Spec goes with per-stack and flags for Eddie.
2. **`npc_smith.gd` PICKAXE_COSTS is `[0, 25, 60, 150]`**, invented before T1 balance was finalized. No doc blessed these numbers. This spec replaces them with `[0, 40, 120, 320]`.
3. **`npc_smith.gd` ARMOR_TIERS has 4 entries** with costs `[20, 50, 100, 200]` and armor `[10, 20, 35, 50]`. No doc specifies armor values. This spec updates to `[30, 90, 220, 500]` / `[10, 20, 35, 55]` — minor bump to level-4 armor and higher gold costs to match the harder-to-reach pickaxe/backpack pacing.
4. **`npc_smith.gd` BACKPACK_ROW_COST is linear** (`30 * (extra_rows + 1)`). Replaced with explicit escalating table `[60, 150, 320, 600]`.
5. **`npc_market.gd` BATTERY_PRICE = 8g** — kept. But note that if Lab crafting at 5g + 3 ore is worse than buying, the Market becomes the default battery source. Intentional: Lab crafting is for players who want to hold ore over a run; Market is for players who already sold.
6. **`ore_node.gd::_break()` auto-collects via `Inventory.add_ore`**. Must be removed/replaced by the pickup spawn in §1.
7. **`Inventory.begin_run()` resets batteries to 3 "for testing"**. With the Lab now crafting batteries, consider whether this should stay at 3 or drop to 0. Flagging — default is leave at 3 for Sprint 2, tune in Sprint 3 once Lab crafting is in.
8. **`04_town_and_progression.md` battery tier table** mentions Improved/Advanced/Superior tiers requiring T2/T3/T4 ore. Sprint 2 ships Basic only; the structure is in place for future tiers.
