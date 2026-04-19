# Sprint 8 — UI/UX Pass: Tabbed Panels + Upgrade Crafting

**Sprint goal:** Move from prototype-functional UI to a finalized tabbed layout. Convert the four main panels (Lab, Backpack, Market, Town Storage) to a consistent horizontal-tab pattern with L/R navigation. Add bot upgrade crafting as the "Upgrade" tab in Lab.

**Pillars:**
1. **A:** Shared `TabBar` component + Lab conversion (includes new Upgrade crafting + Scrap)
2. **B:** Apply tabbed layout to Backpack, Market, Town Storage

Pillar A is the big one — new component, Lab restructure, new crafting flow. Pillar B is mostly applying the established pattern.

---

## Pillar A — Shared TabBar + Lab

### A1. Shared TabBar component

Build a reusable `TabBar` that all four panels will use. Location: `scripts/ui/tab_bar.gd` (+ a scene if easier).

**Behavior:**
- Horizontal row of tab buttons at the top of the panel
- One tab is "active" at a time (visual: brighter color + underline or bottom border)
- Navigation:
  - **L/R joystick** (or left/right on d-pad / arrow keys) cycles between tabs
  - Cycling wraps around (last → first, first → last)
  - Optional: A press on the tab bar drops focus INTO the tab content; B on content returns focus to the tab bar
- Emits `tab_changed(index: int, id: String)` when active tab changes
- Each tab has an `id` (string) and a `label` (display text). Tab content is NOT managed by TabBar — the panel swaps its own content area.

**Input handling:**
- When a panel is open and its TabBar has focus OR the panel is in "tab mode", consume left/right input events to cycle
- Use Godot's `ui_left` / `ui_right` actions, which are already wired from Sprint 6's joystick UI nav
- If the player is navigating within the tab content (e.g. a list of ores), left/right should navigate within content, not cycle tabs. Simple rule: tab cycling only works when the FOCUS is on the tab bar itself, OR when a panel-level input wrapper decides to route (see §A6).

**Visual spec:**
```
┌────────────────────────────────────────────────────────┐
│  ▌BUILD▐  Upgrade   Merge   Necklace                    │
│  ─────────────────────────────────────                  │
│                                                         │
│  (active tab content)                                   │
│                                                         │
└────────────────────────────────────────────────────────┘
```

Active tab: brighter background or outline + underline. Inactive: default button style. Use Theme overrides so the active state is obvious on touch and with keyboard focus.

### A2. Lab conversion

Current Lab has a main menu with buttons (Build Bot, Upgrade Bots, Merge, Necklace) that route to sub-views. Convert to always-visible tabs:

| Tab | Content |
|---|---|
| Build | Existing build bot list + recipe crafting UI (Sprint 7) |
| Upgrade | NEW — see A3 |
| Scrap | NEW — see A7 |
| Merge | Existing merge upgrade view |
| Necklace | Existing necklace upgrade view |

**Structure change in `npc_lab.gd`:**
- Remove `LabView.MAIN`. The tab bar IS the main navigation.
- `LabView` enum becomes just the tab contents (`BUILD`, `UPGRADE`, `MERGE`, `NECKLACE`) plus sub-views within a tab (e.g. `BUILD_CRAFT` for the recipe grid within Build).
- On panel open: default to `BUILD` tab.
- Left/right on the tab bar swaps the content area.
- B button behavior: if in a sub-view within a tab (e.g. crafting grid), B returns to the tab's main list. If on the tab bar or tab's main list, B closes the panel.

### A3. Upgrade crafting (NEW — the big content)

> **Step 4 note (delivered 2026-04-16):** The upgrade crafting UI was largely implemented during step 2 as spec creep (tech agent went beyond the placeholder brief). The delivered UI meets §A3 and §A4 without rework — same recipe-grid as build, dual-mode header with current/after stats and mineral profile preview. Step 4 added immutable `base_max_health` / `base_damage` fields to permanent bot entries to fix a stat-compounding bug: prior code read and mutated the same `max_health` field at spawn time, causing stats to compound on every floor entry after the first upgrade.

Per direction lock C3. Uses the same build-slot pattern as Sprint 7 build crafting, but applies to an existing permanent bot.

**UI flow:**
1. Upgrade tab shows a list of owned permanent bots: "Scout #1 (Lv 0, Fire+3, Earth+1)", "Miner #1 (Lv 2, ...)" etc.
2. Selecting a bot opens the upgrade crafting UI — same two-column layout as Build.
3. Player allocates ores to reach threshold (see A4), then presses Upgrade.
4. On upgrade: stats bump, mineral_profile accumulates, upgrade level increments.

**Bot data model additions** (extend Sprint 7 entry):
- `upgrade_level: int` — starts 0, +1 per upgrade
- `mineral_profile` — already exists, accumulates across builds + upgrades (not reset)
- `void_resolved` — already exists, appends across upgrades

Legacy `hp_upgrade_level` / `damage_upgrade_level` from Sprint 5 are replaced by `upgrade_level`. Migration: on read, if `upgrade_level` is missing, set it to `max(hp_upgrade_level, damage_upgrade_level)` (most upgraded stat wins as a rough approximation).

**Point threshold per upgrade level:** escalating cost.
- Upgrade 0→1: 10 pts
- Upgrade 1→2: 15 pts
- Upgrade 2→3: 25 pts
- Upgrade 3→4: 40 pts
- Upgrade 4→5 (cap): 60 pts

Hard materials per upgrade: same type as the bot's build requirements but 1x each (e.g. Miner upgrade needs 1 Iron; Scout upgrade needs 1 Crystal).

**Stat progression per upgrade level:**
- max_health: +20% of base per level
- damage: +15% of base per level
- attack_speed: +5% per level (stacks multiplicatively)
- Minerals applied at upgrade time stack additively with existing `mineral_profile`

**Cap:** upgrade level 5. UI shows "MAX" and disables Upgrade button if at cap.

### A4. Upgrade UI layout

Same recipe-grid as Build, but header shows:
```
Scout #1 — Lv 2 → Lv 3
Current: 52 HP, 7 dmg, 150 range
After:   65 HP, 9 dmg, 157 range
Mineral profile: Fire+3, Earth+1  →  Fire+4, Earth+2 (after)
```

Required materials line uses upgrade-level threshold (10/15/25/40/60 pts) and 1x hard material.

### A5. Migration & legacy cleanup

- `hp_upgrade_level` / `damage_upgrade_level` fields kept for backwards compat but no longer written to
- Spawn-time stat code reads new `upgrade_level` and applies scaling formulas
- Old Lab `UPGRADE_BOTS` view (Sprint 5 era) — delete, not just hide. Sprint 7 "Coming Soon" button goes away entirely.

### A6. Input routing for tabs

New helper pattern: `FocusUtil.wire_tab_group(tab_bar, content_container)` or equivalent. When focus is on a tab button, left/right cycles tabs; up/down moves focus into content. When focus is in content, left/right works within content (e.g. switching columns).

Implementation detail: use `focus_neighbor_left` / `focus_neighbor_right` on tab buttons to point at each other (cycling). On content's first row, `focus_neighbor_top` points at the active tab. This is clean Godot-native behavior — no custom input interception needed for the common case.

### A7. Scrap tab (NEW)

Dismantle an owned bot and recover a portion of the invested materials. Use case: clean up a cluttered bot collection, recycle a bot built with wrong minerals, extract materials from duplicates.

**UI:**
1. Scrap tab shows list of owned bots — same format as Upgrade list ("Scout #1 — Lv 2 (Fire+3, Earth+1)").
2. Selecting a bot opens a confirmation view:
   ```
   Scrap Scout #1?
   Lv 2, Fire+3, Earth+1
   Returns: 5 Crystal + 2 Iron

   [Confirm Scrap]  [Cancel]
   ```
3. Confirm removes the bot from `permanent_bots` (emits `bots_changed`) and adds the ores to inventory.
4. Cancel returns to the bot list without changes.

**Refund formula:**
1. `invested_points = BOT_BUILD_THRESHOLD + sum(upgrade_threshold[1..upgrade_level])`
   - Lv 0: 10
   - Lv 1: 10 + 10 = 20
   - Lv 2: 20 + 15 = 35
   - Lv 3: 35 + 25 = 60
   - Lv 4: 60 + 40 = 100
   - Lv 5: 100 + 60 = 160
2. `refund_points = floor(invested_points * 0.5)`
3. Allocate refund points greedily into the bot's hard-material types (using `ORE_POINTS_BY_TIER` to convert points → pieces):
   - For single-hard-material bots (Miner/Striker/Scout): pack as many whole pieces of that material as possible.
   - For Backpack Bot (Iron + Copper): alternate between the two hard materials.
4. Any leftover points (less than one piece of the hard material) → Iron pieces at 1 pt each.

**Examples:**
| Bot | Level | Invested | Refund pts | Return |
|---|---|---|---|---|
| Miner | 0 | 10 | 5 | 5 Iron |
| Miner | 2 | 35 | 17 | 17 Iron |
| Scout | 0 | 10 | 5 | 1 Crystal (3 pts) + 2 Iron |
| Scout | 2 | 35 | 17 | 5 Crystal (15 pts) + 2 Iron |
| Backpack Bot | 0 | 10 | 5 | 1 Iron + 1 Copper (4 pts) + 1 Iron filler = 2 Iron + 1 Copper |
| Scout | 5 | 160 | 80 | 26 Crystal (78 pts) + 2 Iron |

**Ore return destination:**
- Storage first (preserves run-independence — scrapping in town puts materials where they're needed for rebuilds)
- If storage full, overflow to backpack (up to capacity)
- If both full, block scrap with a "Clear space in storage first" message

**Mineral profile handling:**
- Minerals are NOT refunded. The mineral profile accumulated through builds + upgrades is lost.
- Display "Minerals lost: Fire+3, Earth+1" in the confirmation view so the player understands the cost.

**Restrictions (per Eddie: any bot, with confirmation):**
- Any owned bot can be scrapped, including knocked out and party members
- Two-step confirmation (select bot → confirm dialog with return preview)
- If the bot is in `run_party`, remove it from party on scrap (so the run continues minus that bot)

**Helper location:** refund calculation in `Inventory` or a new `scripts/util/scrap_util.gd` — your call. Keep it pure (no side effects) so it can drive both the preview display and the actual scrap execution.

---

## Pillar B — Other Panels

### B1. Backpack panel
Tabs: `Ores`, `Bots`, `Artifacts`
- Ores: existing ore list
- Bots: permanent bots list (what's currently in "Backpack Followers")
- Artifacts: list of artifacts collected

Current Backpack is built inside `scripts/ui/mining_hud.gd` as an in-scene panel (per Sprint 3's autoload-broken-on-web fix). Convert it in place — keep in-scene, just add TabBar + content swap.

### B2. Market panel
Current Market has one flow (sell from combined inventory). Options:
- **If keeping Sell-only:** no tabs needed — skip Market for this sprint
- **If adding Buy:** tabs for `Sell` / `Buy` — but Buy content isn't designed yet

**Decision:** Defer Market tab conversion. No Buy content designed. Strip Market from Pillar B scope. If Eddie disagrees, we can revisit.

### B3. Town Storage
Current flow: one combined view showing storage slots with Deposit / Withdraw buttons per slot. Tabs:
- `Deposit` (from backpack → storage): show backpack ores, press A to deposit 1
- `Withdraw` (from storage → backpack): show storage ores, press A to withdraw 1
- `Deposit All` button on the Deposit tab

Cleaner separation of the two flows, each gets its own focused UI.

---

## Acceptance criteria

### Pillar A
- [ ] Shared TabBar component exists and emits `tab_changed`
- [ ] Lab opens to Build tab by default
- [ ] L/R cycles between 4 tabs (wrap-around)
- [ ] Each tab shows its content, tab bar stays visible
- [ ] B button in sub-view returns to tab's main content; B on tab bar closes panel
- [ ] Upgrade tab lists owned bots with level + mineral profile
- [ ] Selecting a bot opens upgrade crafting UI
- [ ] Upgrade crafting uses same recipe-grid pattern as build
- [ ] Upgrade threshold scales 10/15/25/40/60 by level
- [ ] Hard material = 1x of bot's build requirement type
- [ ] Stats progress per formula (+20% HP, +15% dmg, +5% atk speed per level)
- [ ] Mineral profile accumulates across upgrades
- [ ] Level 5 cap enforced
- [ ] Legacy bots self-migrate `upgrade_level` on read
- [ ] Old Sprint 5 upgrade code deleted
- [ ] Scrap tab lists owned bots with level + mineral profile
- [ ] Scrap confirmation shows accurate ore return preview
- [ ] Scrap removes bot from `permanent_bots` AND from `run_party` if present
- [ ] Ores returned to storage (backpack overflow) per formula
- [ ] Mineral profile loss shown in confirmation to prevent surprise
- [ ] Storage-full case handled gracefully

### Pillar B
- [ ] Backpack has Ores / Bots / Artifacts tabs
- [ ] Town Storage has Deposit / Withdraw tabs
- [ ] Both use shared TabBar component
- [ ] L/R navigation works consistently

---

## Out of Scope (Explicit)

- Market tabs (no Buy content to tab against — revisit in future sprint)
- Ice/Thunder/Venom on-hit mechanics (Sprint 9+)
- Merge effect redesign per-bot (D18 — future)
- Rare bot blueprints (D21 — future)
- Dual merge (D7 — future)
- Save system (D6 — still deferred)
- Visual asset production (D10 — still deferred)

---

## Risks

- **TabBar + keyboard/gamepad nav interaction** — Godot's native `TabContainer` has some rough edges with focus_neighbor wiring. May need to roll our own. First spike: try native `TabBar` with custom focus wiring; fall back to custom component if it fights us.
- **Upgrade crafting UI scope** — shares ~80% with build crafting. Extract shared helpers (`_collect_inventory_stacks`, `_compute_raw_mineral_profile`, auto-assign) into a common module OR parameterize the existing build view to handle both modes. Avoid duplication.
- **Migration of `hp_upgrade_level` / `damage_upgrade_level`** — existing upgraded bots (if Eddie played Sprint 5-6 enough to level any) need graceful conversion. The migration rule (max of the two) is rough; document it so Eddie isn't surprised if stats shift.
- **Tab content height / layout churn** — panels currently auto-size to content. Tabbed layout needs fixed dimensions or content-area sizing so the tab bar doesn't jump. Budget a small polish pass.

---

## Delivery Order

1. **Shared TabBar component + basic integration test** (Lab as first adopter, Build tab only)
2. **Lab conversion complete** (all 5 tabs working, Merge/Necklace tabs wrap existing views)
3. **Upgrade crafting — data model** (upgrade_level, scaling formulas, migration)
4. **Upgrade crafting — UI** (bot list + recipe grid for upgrades, sharing helpers with build)
5. **Scrap tab** (bot list + confirm view + refund calc + ore return)
6. **Backpack tabs**
7. **Town Storage tabs**
8. **Playtest checkpoint**
9. **Sprint review**

Commit per step so PO can review diffs, matching Sprint 7 discipline.
