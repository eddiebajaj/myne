# Sprint Review #8 — 2026-04-20

## Sprint Goal
Move from prototype-functional UI to a finalized tabbed layout. Convert Lab, Backpack, and Town Storage to a consistent horizontal-tab pattern. Add bot upgrade crafting and scrap as new Lab tabs.

## Team
- **PO:** Claude (PO Agent)
- **Game Designer:** User (Eddie Bajaj)
- **Tech Lead:** Claude (Tech Agent)
- **Stakeholder:** User (Eddie Bajaj)

---

## Deliverables

### Pillar A — Shared TabBar + Lab
| Feature | Status | Notes |
|---|---|---|
| Shared `TabBarUI` component | Complete | Custom extends `HBoxContainer`, emits `tab_changed` |
| Sub-view lock during crafting / scrap | Complete | Tab bar dims to 0.5 alpha, cycling blocked |
| Lab 5-tab layout (Build/Upgrade/Scrap/Merge/Necklace) | Complete | Panel widened to 500px |
| Upgrade crafting UI | Complete | Shipped during step 2 as spec creep — met §A3/§A4 without rework |
| Upgrade thresholds 10/15/25/40/60 pts | Complete | Per-level scaling formula in `Inventory.UPGRADE_THRESHOLDS` |
| Stat scaling (+20% HP / +15% dmg / +5% atk_speed per level) | Complete | Applied in `mining_floor_controller._spawn_permanent_bot` |
| Hard material scaling (1x for upgrade) | Complete | `_current_required_materials` mode-aware |
| Scrap tab with ore refund | Complete | 50% of invested points, hard-material-typed |
| `ScrapUtil` pure refund helper | Complete | Kept testable/side-effect-free |
| Legacy Sprint 5 upgrade view deleted | Complete | `_build_upgrade_bots_view` removed |

### Pillar A Mid-Sprint Fixes
| Feature | Status | Notes |
|---|---|---|
| Immutable `base_max_health` / `base_damage` fields | Complete | Fixed stat-compounding bug where spawn mutated and re-read the same field |
| Migration for legacy bot entries | Complete | `ensure_bot_migration` backfills base fields from mirror values |
| Tab switching → Q/E + shoulder buttons | Complete | Post-playtest — joystick L/R was too twitchy |
| Focus loss on add/remove fix | Complete | `await get_tree().process_frame` before `grab_focus` — race with `queue_free`'d node's tree-exit |

### Pillar B — Other Panels
| Feature | Status | Notes |
|---|---|---|
| Backpack tabs (Ores/Bots/Artifacts) | Complete | In-scene panel inside `mining_hud.gd` |
| Town Storage tabs (Deposit/Withdraw) | Complete | Panel shrunk to 520×520, single-column layout |
| Per-row focus preservation on Deposit/Withdraw | Complete | Same index save/restore pattern as crafting |
| Market tab conversion | **Deferred** | No Buy content designed. Current Sell UI already combines backpack + storage cleanly |

### Pillar C — Infrastructure
| Feature | Status | Notes |
|---|---|---|
| Version label autoload | Complete | `GameVersion.VERSION = "v0.8.0a"`, bottom-right grey text on all scenes |
| CI auto-build on push restored | Complete | `.github/workflows/deploy.yml` now triggers on push to main + workflow_dispatch |

---

## Sprint Metrics
- **Commits:** 3 (`8f7c06a`, `85d7c78`, `9d88c11`)
- **Tech agent spawns:** 10 (TabBar, Lab tabs, upgrade data model, step-4 bug fix, Scrap, Backpack tabs, Storage tabs, version label + CI, shoulder buttons, focus race fix)
- **Hotfix iterations:** 3 (stat compounding, shoulder buttons, focus race)
- **Sprint duration:** ~2 days
- **Mid-sprint scope adds:** 2 (CI auto-build restore, version label — both user-requested before sprint close)
- **Mid-sprint scope drops:** 1 (Market tab conversion — deferred with clear rationale)

---

## Key Design Decisions

### TabBar input binding
Initial design cycled tabs via `ui_left`/`ui_right` (joystick + arrow keys). Playtest surfaced frequent accidental tab switches when navigating content. Rebound to dedicated `tab_prev`/`tab_next` actions (Q/E keyboard + LB/RB gamepad). Joystick L/R now free for content-level navigation. Touch users still tap tabs directly.

### Version scheme
Adopted `v<major>.<sprint>.<patch><pillar>` format (e.g. `v0.8.0a` for Sprint 8 Pillar A). Pillar letter suffix distinguishes mid-sprint milestones within the same sprint number. Manually maintained in `GameVersion.VERSION` constant.

### Base-vs-mirror stat invariant
`permanent_bots` entries now carry immutable `base_max_health` / `base_damage` alongside the mutable `max_health` / `damage`. Scaling reads from the base, runtime display uses the mirror. Previous code read and wrote to the same field, compounding stats on every floor entry after the first upgrade.

### Sub-view lock
Crafting, upgrading, and scrap-confirming lock the tab bar (visual dim + input consumed). Prevents mid-operation state loss. Applied uniformly via `TabBarUI.set_locked(bool)`.

### Market left alone
Current Market UI (Sprint 7 rework) already combines backpack + storage as unified source — tabs would be artificial. Will revisit when a Buy flow or Trader NPC exists.

---

## What Went Well
- **Parallelized background agent work.** Steps 6 and 7 (Backpack and Storage tabs) ran in parallel across independent files. Both returned clean.
- **Bug caught by PO review, not playtest.** The stat-compounding bug (step 4) surfaced when reading the `_compute_bot_stats` function — it read `entry["max_health"]` as base, but spawn-time mutated that same field. Fixed before reaching Eddie.
- **Focus race diagnosis was thorough.** Tech agent traced the actual Godot `queue_free` + `gui_remove_focus` timing, identified why Sprint 7's `call_deferred` pattern stopped working in Sprint 8's tree layout, and fixed with `await process_frame`.
- **Memory usage prevented re-asking about CI behavior.** The `feedback_push_ci.md` memory made CI trigger a standing question per push.

## What Needs Improvement
- **Spec creep not caught at review.** Step 2's tech agent built the entire upgrade crafting UI when briefed only to add placeholder list views. PO skimmed the summary but missed the enum additions and `_open_upgrade_craft` function. Step 4 became a review-and-cleanup task instead of an implementation. The code was fine, but the process broke: "step" boundaries should be enforced by reviewing the actual diff, not just the summary.
- **Lab panel fit became cramped.** 5 tabs in a 430px panel required widening to 500px mid-sprint. Should size-check UI at spec-time, not discover at integration.
- **Ice/Thunder/Venom still dormant.** Three of the six mineral types still have no on-hit effect. Data stored, unused. This has been debt since Sprint 7 (D28) and needs a sprint soon.

---

## Retrospective — PO Agent Self-Assessment

### What I did well
- Split Pillar A into 7 reviewable steps with explicit dependencies.
- Ran steps 6 and 7 in parallel once I confirmed they touched independent files.
- Caught the stat-compounding bug during step 4 review before it reached playtest.
- Asked about CI auto-build + version label format before implementing.
- Delegated all code changes — zero direct edits except docs (spec, review, debt tracker).

### What I need to improve
- **Review actual diffs, not just agent summaries.** The step 2 spec creep would have been caught if I'd read `git diff` after the commit instead of trusting the summary.
- **Flag panel-size sanity earlier.** When specifying a 5-tab layout, I should have confirmed the panel had room. Cost half a step to fix.
- **Acknowledge the base-vs-mirror pattern as a repeated lesson.** Sprint 7 had a similar "shared mutable state" issue (mineral profile vs sell_bonus-weighted preview) and Sprint 8 had this one. Worth noting as a class of bug to watch for in stateful game data.

---

## Retrospective — User (Eddie Bajaj) / Stakeholder

### What went well
- _[To be filled by Eddie]_

### What needs improvement
- _[To be filled by Eddie]_

### What I want to see next sprint
- _[To be filled by Eddie]_

---

## Sprint 9 Scope (Preview)

Candidate items from debt tracker and direction lock:

- **Ice / Thunder / Venom on-hit mechanics (D28, high)** — activate the three dormant mineral effects so the crafting system is fully honest.
- **Recipe balance (D26, medium)** — hard material costs tested against actual ore availability curves at B4+.
- **Bot balance tuning (D17)** — ranges, HP, damage per bot type.
- **Merge effect redesign per-bot (D18)** — Eddie flagged since Sprint 5.
- **Void mineral drops (D27)** — wire Void into the spawn table so the crafting Void branch activates.

Not committing to scope yet — Sprint 9 planning happens after Eddie's retrospective.

---

## Milestone Tracking

### Milestone 1: Playable Prototype — 100%
### Milestone 2: Full Economy Loop — 100%
### Milestone 3: Permanent Bots & Merge — 95% (build + upgrade + scrap all shipped; merge redesign is the remaining gap)
### Milestone 4: Story & Progression — 10%
### Milestone 5: Vertical Slice — 45% (UI/UX is no longer prototype-level)
