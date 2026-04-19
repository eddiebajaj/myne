# Sprint Review #7 — 2026-04-16

## Sprint Goal
Replace fixed bot recipes with a flexible point-based crafting system. Apply mineral bonuses at build time. Smooth the early-game mineral introduction.

## Team
- **PO:** Claude (PO Agent)
- **Game Designer:** User (Eddie Bajaj)
- **Tech Lead:** Claude (Tech Agent)
- **Stakeholder:** User (Eddie Bajaj)

---

## Deliverables

### Pillar A — Build-Your-Own-Bot Crafting
| Feature | Status | Notes |
|---|---|---|
| Point system by tier (T1=1, T2=3, T3=9, T4=27) | Complete | Constants in `Inventory` |
| Per-bot 10-point threshold | Complete | Uniform across all bots |
| Multi-instance bots with auto-numbering | Complete | "Scout #1", "Scout #2", etc. |
| `mineral_profile` + `void_resolved` on bot entries | Complete | Legacy entries self-migrate via `ensure_bot_migration` |
| Mineral bonuses at spawn (Fire/Earth/Wind/Void) | Complete | Ice/Thunder/Venom stored as meta for future on-hit code |
| Void resolves to random real type at build | Complete | Persists across floor reloads |
| Recipe-grid UI (Inventory / Build Slot columns) | Complete | Programmatic build in `npc_lab.gd` |
| Running total + bonus preview (live) | Complete | Raw-count profile used for both preview and build |
| Auto-assign (cheapest-first, plain before mineral) | Complete | Fills required materials first, then greedy |
| Build execution (storage-first spend) | Complete | Uses new `spend_ore_combined` helper |
| Mineral profile display in bot lists | Complete | Backpack followers + party picker |
| Old "Upgrade Bots" view disabled | Complete | "(Coming Soon)", Sprint 8 rework |

### Pillar A Polish (mid-sprint additions)
| Feature | Status | Notes |
|---|---|---|
| Sub-menu focus bug fix | Complete | `is_queued_for_deletion()` filter across Lab/Smith/Storage |
| Focus restoration on add/remove | Complete | Saved index clamped across UI rebuild |
| Market: sell from storage with manual selection | Complete | Same two-column pattern as crafting |
| Hard material requirements per bot | Complete | Miner: 3 Iron, Striker: 3 Copper, Backpack: 2 Iron + 2 Copper, Scout: 2 Crystal |

### Pillar B — Mineral Spawn Rate Ramp
| Feature | Status | Notes |
|---|---|---|
| 5% chance B1-B3, 15% B4-B5, 25% B6+ | Complete | `_get_mineral_chance()` in `floor_generator.gd` |
| Lucky Strike stacks on top | Complete | Logic untouched |

---

## Sprint Metrics
- **Commits:** 3 (`ab7cb75`, `1455d92`, `d0de855`)
- **Tech agent spawns:** 9 (Pillar B, Pillar A steps 1-6, focus fix, market rework, focus restore + hard materials)
- **Hotfix iterations:** 2 (focus loss in sub-menus, focus loss on add/remove)
- **Sprint duration:** ~1 day
- **Scope expansions during sprint:** 4 (all Eddie-requested mid-flight)

---

## Key Design Decisions

### Hard material requirements (mid-sprint add)
Eddie flagged that fully-flexible recipes erased bot identity — any bot could be built from any ore. Added thematic hard requirements (Miner=Iron, Striker=Copper, etc.) that count toward the 10-point total but must be present. Preserves flexibility for the remaining 7 points while giving each bot a signature material.

### Market rework scope
Original Sprint 7 spec did not include market changes. Eddie requested manual sell UI reusing the crafting pattern. Delivered the same two-column layout (available / staged) with running gold total. Storage and backpack merged in the source list.

### Focus restoration pattern
Two related focus-loss bugs surfaced during playtest:
1. Sub-menu transitions lost focus because `queue_free()`'d nodes were still returned by `get_children()` when focus helpers ran.
2. Add/remove in crafting/market UIs rebuilt the entire view, losing focus each time.

Solution pattern, now applied across Lab/Smith/Market/Storage:
- Always filter with `is_queued_for_deletion()` when collecting focusables
- Save focused-button index before mutation, restore (clamped) after rebuild

### Void mineral data flow
Void isn't in `MineralData.get_all_minerals()` yet, so no Void pieces drop today. Built the data flow anyway: allocating a Void piece at build time rolls one of the six real types and persists to `void_resolved`. When Void drops are added later, the feature activates without further code changes.

---

## What Went Well
- **Delivery-order discipline.** Pillar A split into 6 sub-steps with diff-review gates between each. Zero regressions surfaced at the seams.
- **Data model migration is safe.** `ensure_bot_migration` backfills legacy fields on read, so existing saves (if any) don't break.
- **Preview/build parity.** Initial implementation had divergent preview math (sell-bonus weighted) vs build math (raw counts). Caught during review and unified into one helper — preview now always matches actual build result.
- **Three mid-sprint scope adds integrated cleanly** without breaking the original pillars.

## What Needs Improvement
- **Focus-loss class of bug should have been caught architecturally after Sprint 6.** Sprint 6 fixed one instance of focus loss; didn't generalize. The `queue_free`+`get_children` interaction and the rebuild-loses-focus pattern are both things to scan for proactively when reviewing any dynamic UI.
- **Hard material balance untested in full progression.** Values (3 Iron for Miner etc.) feel right at B1-B3 but haven't been validated against ore availability curves at deeper floors or across multiple bot builds per run.
- **`gh` CLI not installed locally.** PO couldn't trigger CI workflow_dispatch from commands — Eddie had to trigger builds manually this sprint.

---

## Retrospective — PO Agent Self-Assessment

### What I did well
- Kept Pillar A in 6 reviewable chunks rather than one monolithic tech-agent spawn.
- Reviewed every diff before pushing.
- Flagged the preview/build math divergence myself during step 5 briefing instead of letting it ship.
- Asked about CI auto-build vs manual before pushing, per new feedback memory.

### What I need to improve
- **Anticipate focus-loss earlier.** After the Sprint 6 focus bugs, I should have briefed step 3 with an explicit "check that every rebuild re-grabs focus" line. Instead I relied on the agent and Eddie caught both bugs in playtest.
- **Balance check before shipping.** Hard materials went to Eddie for playtest without any PO-side check that the required quantities are actually attainable at depth. Should at least run a quick drop-rate back-of-envelope check.

---

## Retrospective — User (Eddie Bajaj) / Stakeholder

### What went well
- _[To be filled by Eddie]_

### What needs improvement
- _[To be filled by Eddie]_

### What I want to see next sprint
- _[To be filled by Eddie]_

---

## Sprint 8 Scope (Preview)

From direction lock C3:

**Bot upgrade flow → same crafting mechanic as building**
- Spend ore points to level up an existing bot (tier-pointed like build)
- Each level = base stat increase
- Minerals applied at upgrade time = additional bonuses on top, stacking with build-time profile
- A single bot accumulates a layered mineral profile across upgrades

**Likely secondary items:**
- Balance tuning of hard material requirements (if playtest surfaces issues)
- Recipe balance review (ore costs per bot) once full-depth play data exists
- D18 (merge effect redesign per-bot) — may fold in if scope allows

Full Sprint 8 spec to be drafted after this review.

---

## Milestone Tracking

### Milestone 1: Playable Prototype — 100%
### Milestone 2: Full Economy Loop — 100%
### Milestone 3: Permanent Bots & Merge — 85% (build crafting shipped; upgrade crafting is Sprint 8)
### Milestone 4: Story & Progression — 10%
### Milestone 5: Vertical Slice — 35%
