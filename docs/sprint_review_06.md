# Sprint Review #6 — 2026-04-15

## Sprint Goal
Make every UI navigable with A/B/X/Y/joystick — no tapping required. Then playtest end-to-end and lock direction before further design changes.

## Team
- **PO:** Claude (PO Agent)
- **Game Designer:** User (Eddie Bajaj)
- **Tech Lead:** Claude (Tech Agent)
- **Stakeholder:** User (Eddie Bajaj)

---

## Deliverables

### Pillar A — Global UI Input Mapping
| Feature | Status | Notes |
|---|---|---|
| `action_a` → `ui_accept` injection | Complete | Touch button injects both |
| `action_b` → `ui_cancel` injection | Complete | Same pattern |
| Joystick → `ui_up/down/left/right` | Complete | Active when game paused (UI mode) |
| Joystick threshold (0.5 activate / 0.3 release) | Complete | Hysteresis prevents jitter |
| Auto-focus first button on panel open | Complete | All panels |
| Focus visual (yellow 3px outline) | Complete | Applied via default theme |
| Focus wrap-around (last → first) | Complete | `FocusUtil.wire_vertical_wrap` |

### Pillar A Polish (post-playtest fixes)
| Feature | Status | Notes |
|---|---|---|
| `grab_focus` deferred to next frame | Complete | Fixes reopen-loses-nav + sticky A activation |
| Disabled buttons navigable | Complete | Focus lands; A press does nothing (Godot native) |
| Joystick hold-to-repeat | Complete | 0.4s initial delay, 0.1s repeat interval |

### Pillar C — Direction Lock
| Feature | Status | Notes |
|---|---|---|
| Full end-to-end playthrough | Complete | Eddie played start-to-finish |
| Direction lock document | Complete | `docs/direction_lock_sprint_6.md` |
| Sprint 7 spec drafted from lock | Complete | `docs/sprint_07_spec.md` |

### Pillar B — Per-Panel Focus Polish
**Deferred.** Direction lock identified bot crafting as the next major redesign, so per-panel polish for soon-to-be-replaced UIs would have been wasted work. Pillar B work folds into Sprint 7.

---

## Sprint Metrics
- **Commits:** 4 (spec, Pillar A, focus bug fix, polish + hold-repeat)
- **Hotfix iterations:** 1 (focus bugs found in playtest, fixed same day)
- **Sub-agent spawns:** 3 (Pillar A, focus bug fix, polish)
- **Sprint duration:** ~1 day

---

## Key Design Decisions

### UI input wiring (architectural)
- Touch buttons inject TWO action events: gameplay (action_a) AND UI (ui_accept). Lets touch drive both gameplay and UI navigation cleanly.
- Joystick UI nav only activates when paused — preserves player movement when not in menus.
- `call_deferred("grab_focus")` solved both reopen-nav-loss AND sticky-A-activation bugs in one fix.

### Disabled buttons stay focusable
Eddie's call: greyed-out options should be visible/navigable so player understands what exists. Activation is blocked (Godot native), but exploration isn't.

### Direction lock outcomes
Most Sprint 5 systems are KEEP. Two REDESIGN items:
- **C1:** Bot building → flexible point-based crafting with mineral bonuses (Sprint 7)
- **C2:** Mineral spawn rate → ramped curve B1-B3 → B4-B5 → B6+ (Sprint 7)
- **C3:** Bot upgrades → same crafting mechanic as build (Sprint 8)

---

## What Went Well
- **Cleanest sprint planning yet** — 3 pillars, clear sequence (A → C → B), one pillar properly deferred mid-sprint.
- **PO review caught no issues this sprint.** Diff reviews remain disciplined but tech is producing clean code.
- **Direction lock is concrete.** Replaces the open "what should we do next?" question with a specific next-sprint scope.
- **Disabled buttons + hold-repeat** were tiny polish items that materially improved feel.

## What Needs Improvement
- **First Pillar A had two real bugs in playtest** (sticky A + reopen focus loss). Both should have been caught by mental trace. PO review should mentally simulate "tap A to open menu" not just "verify code structure."
- **Crafting UI is the next complexity test.** Sprint 7 has the most complex UI we've built. Need to brief tech carefully.

---

## Retrospective — PO Agent Self-Assessment

### What I did well
- Zero direct code edits.
- Reviewed every diff before pushing.
- Structured the playtest feedback prompt to elicit usable design info.
- Wrote direction lock doc concretely (not "we should figure out crafting" but "here are the values").

### What I need to improve
- **Mental simulation of input flows.** The sticky-A bug was foreseeable — when A press is injected, I should have asked "what happens to the release event?" instead of just trusting the code.
- **Sprint scoping is creeping toward "do everything in one sprint."** Sprint 7 has Pillar A which is genuinely one big feature. Need to resist adding "while we're at it..." items mid-sprint.

---

## Retrospective — User (Eddie Bajaj) / Stakeholder

### What went well
- _[To be filled by Eddie]_

### What needs improvement
- _[To be filled by Eddie]_

### What I want to see next sprint
- _[To be filled by Eddie]_

---

## Sprint 7 Scope (Locked)

**Pillar A:** Build-your-own-bot crafting
- Point system per ore tier (T1=1, T2=3, T3=9, T4=27)
- 10-point threshold per bot
- Mix any ores from inventory + storage
- Mineral bonuses (Fire/Earth/Wind/Void implemented; Ice/Thunder/Venom data-flow only)
- Multiple bot instances per type (auto-numbered)
- Recipe grid UI with auto-assign
- Old "Upgrade Bots" view hidden

**Pillar B:** Mineral spawn rate ramp (B1-B3: 5%, B4-B5: 15%, B6+: 25%)

Full spec at `docs/sprint_07_spec.md`.

---

## Milestone Tracking

### Milestone 1: Playable Prototype — 100%
### Milestone 2: Full Economy Loop — 100%
### Milestone 3: Permanent Bots & Merge — 70% (4 bots + merge + crafting redesign incoming)
### Milestone 4: Story & Progression — 10%
### Milestone 5: Vertical Slice — 30%
