# Sprint Review #9 — 2026-04-22

## Sprint Goal
Replace fixed template floors with organically-generated cave layouts. Replace ColorRect placeholder sprites with Kenney Roguelike assets for the most visible entities.

## Team
- **PO:** Claude (PO Agent)
- **Game Designer:** User (Eddie Bajaj)
- **Tech Lead:** Claude (Tech Agent)
- **Stakeholder:** User (Eddie Bajaj)

---

## Deliverables

### Pillar A — Procgen Caves (SHIPPED)
| Feature | Status | Notes |
|---|---|---|
| `cave_gen.gd` cellular automata helper | Complete | Pure static functions, seeded RNG, 4-5 rule |
| Flood-fill connectivity | Complete | Guarantees single reachable floor region |
| BFS farthest-cell for exit placement | Complete | Exit rocks always distant from player spawn |
| Procgen-vs-template roll (80/20) | Complete | Set-piece template floors retain variety |
| Depth-based parameters | Complete | B1-3 open, B4-5 standard, B6+ tight |
| Floor cell spawn masking | Complete | Ores/enemies/rocks/blueprints land on floor only |
| Degenerate seed fallback | Complete | Tiny floor regions trigger template fallback |
| Deterministic per-floor within a run | Complete | Re-entry produces same layout |

### Infrastructure (SHIPPED)
| Feature | Status | Notes |
|---|---|---|
| Godot 4.2 → 4.6.2 upgrade | Complete | Editor + CI image + project.godot migration |
| `.uid` files (Godot 4.4+) | Complete | All scripts got UIDs |
| `BackpackPanel.accept_event` 4.6 fix | Complete | Swapped to `get_viewport().set_input_as_handled()` |
| Version label → v0.9.1a | Complete | GameVersion autoload bumped |

### Pillar B — Environment Art (DROPPED)
| Feature | Status | Notes |
|---|---|---|
| Kenney pack integration (player, walls, floor, ores) | Attempted, reverted | Visuals didn't satisfy |
| TileMap + autotile migration | Attempted, reverted | Kenney is hand-placement art, not bitmask-compatible |
| Anokolisa pack exploration | Attempted, reverted | Same hand-placement limitation |
| Rocky-rubble random variant fallback | Attempted, reverted | Still didn't convince |

See D33 in debt tracker. Full rationale in "What Needs Improvement" below.

---

## Sprint Metrics
- **Commits (final):** 5 (`d670a63`, `ad6910a`, `6a78606`, `658a247`, `d427264`)
- **Commits reverted:** 2 (`bcd3cb3`, `5a660db`)
- **Tech agent spawns:** 9 (cave_gen, procgen integration, Godot 4.6 ramp, Kenney wiring, tile fixes, tile_picker scene, TileMap migration, autotile reconfig to random variants, revert)
- **Playtest iterations on Pillar B:** 4 (broken coords, then floor tiling bug, then autotile wrong tiles, then rocky rubble unconvincing)
- **Sprint duration:** ~3 days
- **Scope dropped mid-sprint:** Pillar B (environment art)

---

## Key Design Decisions

### Pragmatic path vs TileMap migration
Initially planned to keep per-tile `StaticBody2D` for walls (pragmatic) instead of migrating to Godot's `TileMapLayer`. Eddie asked about autotile after seeing the uniform walls — this forced the TileMap migration, which we did. Migration infrastructure landed cleanly; the autotile attempt itself failed because Kenney's art doesn't encode bitmask variants. Reverted both pillars together.

### Godot 4.6 upgrade mid-sprint
Eddie's local editor auto-migrated `project.godot` and `town.tscn` from 4.2 → 4.6 format. Chose to upgrade CI rather than downgrade the editor. Minor friction: `accept_event()` on `CanvasLayer` became a parse error in 4.6 (was lenient in 4.2) — caught via Eddie running tile_picker and seeing the error trace back to `backpack_panel.gd`.

### Art pack exploration: three strikes
1. **Kenney Roguelike Caves & Dungeons**: Hand-placement art. Autotile doesn't work. Single-tile walls looked flat.
2. **Anokolisa Pixel Crawler Free**: Same hand-placement limitation. Nicer floors (autotile-ready grass/stone/dirt) but walls are top-view dungeon style. The promised "Mines and Caves" content is in a later/paid tier not in the free pack.
3. **Rocky-rubble random variants**: Workaround — use N different wall tiles picked randomly per cell. Didn't convince Eddie, who called the sprint closed with art deferred.

Honest conclusion: the free autotile-ready cave tilesets I recommended weren't actually autotile-ready in practice. Should have vetted harder before recommending.

### Keep what worked
Pillar A (procgen) is genuinely a big improvement. Ships this sprint. Godot 4.6 upgrade was mandatory once the project file migrated. BackpackPanel 4.6 fix unblocked everyone.

---

## What Went Well
- **Procgen caves landed clean** — `cave_gen.gd` as a pure module with seeded RNG + flood-fill + BFS made integration straightforward. Zero bugs in Pillar A after playtest.
- **Godot 4.6 upgrade was lower-friction than expected** — only one deprecation hit (BackpackPanel).
- **Revert discipline** — PO kept `git revert` + separate commits for the dropped work so history is honest and re-attempts can cherry-pick if helpful.
- **Tile picker debug scene** — `scenes/dev/tile_picker.tscn` (discarded) was the right idea even though the underlying approach failed. For future art work, this pattern of "visual debug tool so design can iterate without code round-trips" is worth revisiting.

## What Needs Improvement
- **Art pack vetting before recommending** — I pitched "proper autotile-ready tilesets" (safwyl remix, Anokolisa Pixel Crawler) in the art search but didn't actually confirm they had bitmask-compatible wall variants. Both turned out to be hand-placement art. Wasted 2 playtest rounds.
- **Didn't recognize the fundamental mismatch sooner** — Kenney's caves sheet preview clearly shows wall tiles with shading that only reads from specific angles. I should have flagged this in Sprint 9 planning, not after Pillar B shipped.
- **Over-attempted iterative fixes** — Four tile-coord tuning rounds before admitting the art was wrong for the use case. Should have proposed "this approach isn't working, let's revert" after round 2, not waited until round 4.
- **Version bumping discipline slipped** — multiple pushes during Pillar B at the same v0.9.0a constant. Made it hard for Eddie to tell which build was live. Will bump per-push going forward (already agreed, still failed).

---

## Retrospective — PO Agent Self-Assessment

### What I did well
- Split Pillar A into two reviewable steps (pure algo, then integration). Zero regressions at the seams.
- Caught the stat-compounding bug during step 3 review before playtest (carryover discipline from Sprint 8).
- Asked about Godot version upgrade impact before bumping, including the CI implications.
- When rocky-rubble didn't satisfy, didn't push further — reverted as Eddie requested without arguing.

### What I need to improve
- **Verify art pack autotile support before recommending** — download the pack myself, look at its tile layout, confirm bitmask variants exist before pitching it. A 2-minute check would have saved 2 playtest rounds.
- **Propose reverts earlier when a design direction isn't working** — the "one more iteration" reflex cost us time in Sprint 9. Default should be "3 failed rounds → propose revert", matching the `feedback_agent_code_sanity` memory but applied to design direction, not just code.
- **Version bump on every push** — mechanical, cheap, avoids "is this the new build?" confusion. Still keep missing this.

---

## Retrospective — User (Eddie Bajaj) / Stakeholder

### What went well
- _[To be filled by Eddie]_

### What needs improvement
- _[To be filled by Eddie]_

### What I want to see next sprint
- _[To be filled by Eddie]_

---

## Sprint 10 Scope (Preview)

Candidate items:

- **Enemy pathfinding (D9, medium)** — procgen caves have irregular walls. Template-floor enemy steering may break more often in the organic layouts. Budget a playtest audit.
- **Ice / Thunder / Venom on-hit mechanics (D28, medium)** — still dormant since Sprint 7. Crafting system promises effects that don't exist.
- **Environment art (D33, medium)** — if revisiting, explore a purpose-built autotile pack or commit to a stylized non-Kenney look. Design-forward decision needed, not a pack search.
- **Recipe balance (D26, medium)** — hard material costs vs actual ore availability at B4+.

Not committing — Sprint 10 planning after Eddie's retrospective.

---

## Milestone Tracking

### Milestone 1: Playable Prototype — 100%
### Milestone 2: Full Economy Loop — 100%
### Milestone 3: Permanent Bots & Merge — 95% (unchanged)
### Milestone 4: Story & Progression — 10% (unchanged)
### Milestone 5: Vertical Slice — 50% (procgen moves the needle; art still placeholder)
