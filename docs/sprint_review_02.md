# Sprint Review #2 — 2026-04-11

## Sprint Goal
Ship the town economy loop and polish the mine into something that actually feels like a game — not just a tech demo. Secondary: make the mine tense instead of meditative.

## Team
- **Product Owner:** Claude (PO Agent)
- **Game Designer:** Claude (Design Agent) + User (creative direction)
- **Tech Lead:** Claude (Tech Agent) — multiple sub-agent spawns
- **Stakeholder:** User (Eddie Bajaj)

---

## Deliverables

### Sprint 2 — Economy + Mine Polish
| Feature | Status | Notes |
|---|---|---|
| Visible ore drops + auto-magnet pickup | Complete | Ring scatter, 140px magnet, bounce-back on full backpack |
| Openable backpack panel (Tab / touch button) | Complete | Per-piece cells, pause-on-open, side panel |
| Smith upgrades (pickaxe, armor, backpack rows) | Complete | Explicit pricing tables, next-tier-only display |
| Lab battery crafting (3 T1 ore → 1 battery, free) | Complete | T1 only, plain ore only |
| Market polish (per-ore breakdown, gold popup) | Complete | Sell-all still one-click |
| Persistent town HUD (gold + battery) | Complete | Top-right CanvasLayer |
| Player facing direction + nose indicator | Complete | 4-cardinal snap |
| Pickup name popup on collect | Complete | Floats up, fades, staggers |
| Build menu touch support + Cancel button | Complete | Tap-to-place, Cancel replaces right-click |

### Sprint 2b — Cave Tension
| Feature | Status | Notes |
|---|---|---|
| Floor-start wandering enemies | Complete | B1-B5 compositions, 300-650px from spawn |
| Cave roll table (40/15/20/10/15) | Complete | Standard / Treasure / Ambush / Big Ambush / Empty |
| Enemy AI behaviors: passive_wander, wander_aggro, always_aggro | Complete | Per-species dispatch in `enemy_base.gd` |
| Cave entrance visual states (glow pulse, X marker) | Complete | Empty caves get subtle dark border |
| Ambush leash clamping | Complete | 200px fauna / 300px mineral |

### Sprint 2b Polish
| Feature | Status | Notes |
|---|---|---|
| Entity-aware spawn reservation | Complete | No more stacked ore/rock/cave pixels |
| Mine entrance panel (replaces floating selector) | Complete | NPC-menu pattern, pause on open |
| Checkpoint off-by-one fix | Complete | B5F checkpoint now warps to B5F, not B6F |
| Checkpoint selector reset bug | Complete | Split refresh into stats-only + options-on-unlock |
| HP reset across floor descent | Complete | Vitals moved to GameManager, restored on scene reload |

### Sprint 2c — Partial (backpack + HP + stairs only)
| Feature | Status | Notes |
|---|---|---|
| Backpack drop (tap cell → inspect + drop one) | Complete | Per-piece mapping resolved via metadata |
| HP nerf 50 → 12 | Complete | Grepped for stray refs, clean |
| Randomized stairs-up + matching player spawn | Complete | Reserved first in `generate_floor()` |
| Floor templates (1400×1000 arena + 3 templates) | **Deferred to Sprint 3** | Spec complete at `docs/design/sprint_02c_floor_templates_spec.md` |

### Infrastructure
| Item | Status | Notes |
|---|---|---|
| 3D migration feasibility research | Complete | Doc at `docs/research_3d_feasibility.md`. Recommendation: stay 2D (85% confidence). Godot 4.2 web export locked to GL Compatibility / WebGL 2.0. |
| Project-level `.claude/settings.json` | Complete | Permission allowlist for `git *` + `godot *` — fixes sub-agent silent push failures |

---

## Sprint Metrics
- **Commits:** 8 (6e61381 → 842e603)
- **Sub-agent spawns:** 11 (design: 3, tech: 6, research: 1, retros: 2)
- **Design docs created:** 4 (sprint_02, sprint_02b, sprint_02c, research_3d_feasibility)
- **Iterations on Sprint 2 core:** 4 hotfix/polish rounds before it stabilized
- **Playtest feedback cycles:** 5

---

## Key Design Decisions

1. **Stay 2D** — Godot web export limits 3D to GL Compatibility path, no Vulkan/Metal on web until Godot 5+. Migration would cost 7–13 sprints; 2D juicing delivers the same "depth in caves" feel for 3–6.
2. **Cell-per-piece backpack** — overrode design's per-stack default. Piece count = weight = tension, and it ties into the 4-way ore pillar.
3. **Fauna AI varies by species** — Cave Beetle wanders + aggros, Tunnel Rat is fully passive unless attacked, mineral entities are always aggressive. Three behaviors from existing archetypes, no new data.
4. **Cave combat rate 30%** (20 Ambush + 10 Big Ambush), down from design's 45% proposal. Empty caves bumped to 15% for disappointment-beat pacing.
5. **HP 50 → 12** — playtest revealed the old value made early floors trivial. 12 HP = 3 beetle hits = real "uh oh" moments.
6. **Mine entrance becomes a panel, not a floating button** — matches NPC shop pattern, pauses game, reads more like a proper interface.

---

## Blockers & Issues

| Issue | Status | Resolution |
|---|---|---|
| Touch+mouse double-emit causing Bag button double-toggle | Resolved | Frame debounce in touch handler |
| Town HUD Control eating taps (`mouse_filter=STOP` default) | Resolved | Set to IGNORE on the root Control |
| Player movement not blocked during NPC menus | Resolved | `get_tree().paused = true` + `PROCESS_MODE_ALWAYS` on menu roots |
| Pickaxe swing stuck rotating in place | Resolved | Recompute position per swing, set pivot_offset to rect center |
| Ore/cave/stairs pixel stacking | Resolved | `_reserve_position()` rejection sampler with occupied list |
| Checkpoint selector off-by-one + auto-reset | Resolved | Fixed `run_start_floor` + split `_refresh_ui` |
| HP resetting on every floor descent (from Sprint 1) | Resolved | Vitals persisted on GameManager autoload |
| Sub-agent silent `git push` failures | Resolved | Project-level `.claude/settings.json` with `Bash(git *)` allowlist |
| `_random_enemy()` aggro/leash gap at T2-T4 | **Open — Sprint 3** | T1 patched via `_make_enemy_data()`, T2-T4 still use EnemyData defaults |
| Dead code in `cave_entrance.gd::_spawn_loot()` | **Open — Sprint 3** | Kept to minimize diff; cleanup candidate |
| `Player._apply_upgrades()` armor sync vs GameManager restore | **Open — watch** | Harmless today, fragile if Smith upgrade logic forks |

---

## What Went Well
- Shipped a real economy loop in one sprint — the game now has a "why am I mining" answer.
- Cave tension work landed cleanly in 2 commits — abstract behaviors (`passive_wander` / `wander_aggro` / `always_aggro`) compose well from existing archetypes.
- 3D feasibility call was made with data, not vibes — saved a potential 7-13 sprint detour.
- Design agent produced implementation-ready specs with explicit numeric tables — no "TBD" land.
- Tech agent self-diagnosed when PO hypotheses were wrong (Sprint 2 hotfix bug 2a) — refused to just patch the symptom.
- End-of-sprint permission fix (`.claude/settings.json`) unblocks all future sub-agent git work.

## What Needs Improvement
- **Four rounds of hotfix on Sprint 2 core before stabilization.** The first ship shipped with broken backpack button, broken town NPC input, wrong swing direction, and broken build menu on mobile — most of which a single playtest caught immediately.
- **Visual/transform code shipped broken twice from static reading** (swing direction). Pivot/rotation/anchor math cannot be validated by reading.
- **HP reset bug hid for a full sprint** because floor 1 was easy enough to surface the symptom. State-persistence changes need explicit checklists.
- **Silent push failures** wasted two delivery cycles before the permission fix.
- **PO hypotheses were wrong twice** on the first hotfix — tech agent had to re-diagnose. PO should present symptoms, not causes, and let tech own the diagnosis.
- **Design "open questions" became a deferral crutch** on numeric decisions design could have made with rationale.

---

## Retrospective — PO Agent Self-Assessment

### What I did well
- Delegated all code work to tech agents — no lane crossings this sprint (the #1 action item from Sprint 1 retro).
- Caught the spec/code contradictions when tech agents flagged them and kept the docs as source of truth.
- Made the 3D call quickly instead of letting it sit as an open question.
- Verified git state after tech agent commits after the first silent push failure — caught the second one before it became invisible.

### What I need to improve

**1. I present diagnoses as symptoms.**
On the Sprint 2 hotfix, I wrote hypotheses into the tech agent brief ("H1a: layer ordering", "H2a: touch_controls RootControl blocking") — and both were wrong. The tech agent solved the bugs by ignoring my hypotheses and reading the code. I should brief symptoms ("tapping the Bag button does nothing; Tab key untested") and let tech own the diagnosis. My hypotheses are noise at best, anchoring at worst.

**2. I accept tech agent success reports without verification.**
Two silent push failures this sprint where the tech agent reported "pushed to origin/main" and the push hadn't actually landed. After the first one I started verifying with `git log origin/main`, but I should have been doing that from the start — and should be doing it for more than just pushes (scene file validity, autoload registration, etc.).

**3. Playtest cycle is too slow.**
Eddie found the broken swing direction, broken backpack button, and broken town UI in a single 5-minute playtest. I should have asked for playtest before declaring "shipped" — or at minimum, delivered a visual-verification checklist to Eddie so he could target-test the risky areas first.

**4. I'm adding scope mid-sprint without a cost conversation.**
Sprint 2 was "economy + polish." Sprint 2b (cave tension) and Sprint 2c (floor templates) are legitimate follow-ups, but I folded them into the same "sprint" without flagging that scope was growing. Sprint 3 should plan in smaller commits with clearer boundaries.

**5. I don't track action items across sprints.**
The Sprint 1 action item "design T2 balance" is still open. The `_random_enemy()` T2-T4 gap is a new version of the same pattern. I should maintain a cross-sprint "open debt" list so these don't silently vanish.

### Process improvements for Sprint 3
- Brief tech agents with **symptoms + file paths only**, no diagnoses
- Verify every tech agent deliverable: `git status`, `git log origin/main`, scene file validity, autoload registration
- Ask Eddie for a structured playtest pass before marking anything "done"
- Maintain a `docs/open_debt.md` carried forward each sprint
- Cap each sprint at ~3 themes; follow-ups become their own sprint

---

## Retrospective — Design Agent

### Tasks completed
- Authored `docs/sprint_02_economy_spec.md` — Smith upgrade prices, backpack UI layout, Lab crafting recipes, market sell polish, ore drop/magnet behavior
- Authored `docs/design/sprint_02b_cave_tension_spec.md` — floor-start wanderer spawns, cave roll table with weighted outcomes, enemy AI behavior trees for chase/leash/attack
- Authored `docs/design/sprint_02c_floor_templates_spec.md` — 1400×1000 arena bounds plus three floor templates (spec only, implementation deferred)
- Key decisions: arena size jump from 1280×720 viewport to 1400×1000 scrollable; cave roll as weighted table not pure RNG; wanderers spawn pre-placed at floor start rather than timed waves

### What went well
- Specs were concrete and implementation-ready — tables, exact values, no "TBD"
- Cross-referenced existing balance doc and flagged divergences rather than silently overwriting
- Separated concerns cleanly across three specs instead of one mega-doc — let 2c slip to "spec only" without blocking 2a/2b
- Cave tension spec tied new enemy behaviors back to existing portal aggro system, kept the design coherent

### What needs improvement

**1. "Open questions for Eddie" became a crutch.**
Every spec shipped with a flagged-questions section. Some are legitimate escalations (backpack pieces-vs-stacks is a player-facing core-loop decision). But others were me deferring numeric choices I was fully equipped to propose with rationale. Escalation should be for vision/direction calls, not "I don't want to commit to a number." Default to proposing a value with reasoning; let Eddie override.

**2. Contradictions with existing docs caught too late.**
On all three specs I surfaced conflicts with `13_balance_t1.md` and `04_town_and_progression.md` mid-draft rather than reconciling first. I should read the relevant existing docs end-to-end before writing a new spec, build a short "what currently exists / what I'm changing / why" delta at the top, and only then write the new values.

**3. Per-stack backpack default was the wrong instinct.**
Eddie overrode my per-stack backpack UI to per-piece. Lesson: per-stack is the UI-engineer default (fewer sprites, cleaner grid); per-piece is the game-feel default (weight matters, hoarding has a tangible cost, ties into the 4-way ore tension pillar). I optimized for implementation simplicity over the pillar I myself documented in Sprint 1. When a UI decision touches a core pillar, re-read the pillar first.

### Action items for Sprint 3
- [ ] Before writing any new spec, produce a 5-line "delta vs existing docs" summary and reconcile conflicts inline
- [ ] Limit "open questions for Eddie" to 3 max per spec, and only for vision/direction calls — propose values with rationale for everything else
- [ ] When a spec touches player-facing feel (inventory, controls, combat), explicitly check against the pillars in `00_game_overview.md` before defaulting to implementation-convenient options
- [ ] Complete the 2c floor templates implementation-ready pass (pickups, enemy placements per template)
- [ ] Extend balance coverage to T2 (still outstanding from Sprint 1 action items)

---

## Retrospective — Tech Agent

### Tasks completed
- **`6e61381` Sprint 2 main:** Town economy (sell flow, Smith, Lab stub), mine polish (pickup animations, HUD tweaks)
- **`cd20043` Hotfix 1:** Backpack toggle key, town UI input routing, player facing direction (broken)
- **`948f7fe` Polish pass:** Pickup scatter, *actual* swing direction fix, pickup popup text, build menu touch support
- **`71ce59d` Sprint 2b:** Floor-start wanderer spawns, cave roll table
- **`40455be` Sprint 2b polish:** Entity spawn collision checks, mine entrance panel
- **`2732ff3` HP bug fix:** Persist run HP across scene reloads
- **`0bdf4f1` Sprint 2c part 1:** Backpack drop, HP nerf, randomized stairs

### What went well
- **Self-diagnosis on hotfix 1.** PO handed me two bug reports with wrong root-cause hypotheses. I reproduced symptoms from the code, found the actual causes, and fixed those. Right loop — treat PO hypotheses as symptom reports, not diagnoses.
- **Sprint 2b scope was clean.** Cave roll table and wanderer spawn shipped in two commits with one polish follow-up — mostly because the behavior was easy to reason about statically (timers, probabilities, spawn lists).
- **Caught the `_random_enemy()` aggro/leash gap at T1** while scanning enemy code.

### What needs improvement

**1. Seven commits for one sprint is diagnostic.** Four of seven were fixes/polish on top of `6e61381`. Root cause: I ship code after static reading without runtime verification, then the playtest finds what I should have found.

**2. The swing direction fix shipped broken twice in a row.** `cd20043` "fixed" swing by rotating a ColorRect whose pivot was its own top-left — so the rect spun in place instead of swinging around the player. I never ran it; I read the rotation code and convinced myself it was right. `948f7fe` fixed it for real. **Shipping the same bug twice from the same failure mode (read-only reasoning about visual transforms) is the sprint's biggest lesson.** Visual/transform code must be runtime-verified, full stop. Pivot, anchor, and parent-space math are exactly the class of bugs static reading cannot catch.

**3. The HP reset bug hid for an entire sprint.** HP was resetting to full on every floor descent from Sprint 1 onward; nobody noticed until mid-Sprint 2. Because floor 1 was easy enough that max HP was never threatened, the reset *felt* like a reward ("new floor, fresh start") rather than a bug. **Lesson:** after any scene-reload or state-persistence change, write down what state should persist and verify each line explicitly.

**4. Two silent `git push` failures.** Reported success both times; PO pushed manually. Root cause: missing project-level `.claude/settings.json` permission config, fixed at end of sprint. What I should have done: when `git push` returns without printing remote ref updates, treat that as a failure signal, not success.

**5. `_random_enemy()` fix was only T1.** Found the aggro/leash inconsistency, patched T1, moved on. T2-T4 still have the same gap. Same pattern as Sprint 1 (T1 balance shipped, T2-T4 deferred). Flagging loudly.

### Action items for Sprint 3
- [ ] **No visual/transform code ships without a runtime screenshot or video from the playtester.** Pivot, rotation, anchor, parent-transform bugs cannot be caught by reading.
- [ ] **State-persistence checklist:** after any change touching scene reloads or autoloads, enumerate every piece of run-state (HP, backpack, battery, floor, bots) and verify each survives reload.
- [ ] **Treat PO bug reports as symptoms, never diagnoses.** Keep doing what worked in hotfix 1.
- [ ] **Verify git push output, not exit codes.** If push doesn't print remote ref updates, report failure.
- [ ] **Fix `_random_enemy()` aggro/leash gap at T2-T4** and audit all other "T1 only" patches for the same debt.
- [ ] **Floor templates (deferred from 2c)** should land early in Sprint 3 before more content piles on top.
- [ ] When iterating on a single sprint hits 3+ follow-up commits, **stop and do a root-cause review** instead of shipping commit 4.

---

## Retrospective — User (Eddie Bajaj) / Stakeholder

### What went well
- _[To be filled by Eddie]_

### What needs improvement
- _[To be filled by Eddie]_

### What surprised me
- _[To be filled by Eddie]_

### What I want to see next sprint
- _[To be filled by Eddie]_

---

## Action Items for Sprint 3
- [ ] Implement floor templates (1400×1000 arena + 3 templates) — spec ready at `docs/design/sprint_02c_floor_templates_spec.md`
- [ ] Extend `_random_enemy()` aggro/leash fix to T2-T4
- [ ] Design T2 balance values (still open from Sprint 1)
- [ ] Design mineral effect multipliers per mineral type
- [ ] Implement save system (3 manual + 1 auto)
- [ ] Design permanent bot roster and acquisition points
- [ ] Add enemy AI: pathfinding around interior walls (needed for templates B/C)
- [ ] Investigate 2D juicing: normal-mapped sprites, CanvasItem lights, shader fog
- [ ] Create and maintain `docs/open_debt.md` — cross-sprint debt tracking
- [ ] Clean up dead `_spawn_loot()` in `cave_entrance.gd`

---

## Milestone Tracking

### Milestone 1: Playable Prototype
**Goal:** Player can complete a full mine loop.
**Status:** 100% — shipped in Sprint 1, hardened in Sprint 2.

### Milestone 2: Full Economy Loop
**Goal:** Town economy functional — Smith upgrades, Lab crafting, batteries, backpack management.
**Status:** 90% — all four NPCs functional. Missing: mineral extraction at Lab, bot purchase flow, mid-run armor repair.

### Milestone 3: Permanent Bots & Merge
**Goal:** Party selection, permanent bot combat, merge transformation.
**Status:** Designed, not implemented.

### Milestone 4: Story & Progression
**Goal:** Region 1 story — checkpoints, letters, NPC dialogue, story gate.
**Status:** Designed, not implemented. Checkpoint mechanic exists (B5F), narrative not wired.

### Milestone 5: Vertical Slice
**Goal:** Region 1 fully playable with story, economy, bots, merge, polish.
**Status:** Not started.
