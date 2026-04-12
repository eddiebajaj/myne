# Sprint 3 — Floor Templates + Disposable Bot Fix & Polish

**Sprint goal:** Make the mine feel different every floor (templates) and give the player their core tactical tool (working bots).

**Themes:** 2 only (per Sprint 2 retro: cap at ~3 themes, no scope creep)

1. **Floor Templates** — implement the 3 hand-authored layouts from the existing spec
2. **Disposable Bot Fix & Polish** — diagnose the broken build menu, fix it, balance all 4 bot types for T1

---

## Pillar A — Floor Templates

**Spec:** `docs/design/sprint_02c_floor_templates_spec.md` (design-locked, ready for tech)

### Summary of work

| Task | Detail |
|---|---|
| Arena resize | 800×600 → 1400×1000. Update `FLOOR_WIDTH`, `FLOOR_HEIGHT` in `floor_generator.gd` |
| Template data | New `scripts/dungeon/floor_templates.gd` with 3 template dicts (Open Arena, Two Chambers, Cross Corridor) |
| Template selection | Weighted roll in `generate_floor()`. B1F hardcoded to Open Arena |
| Interior walls | Iterate template `walls[]`, call `_add_wall()` + reserve wall footprint in occupied positions |
| Zone-biased spawning | Ore, rocks, cave, stairs-down-rock respect template `zones{}` with fallback to arena-wide |
| Stairs-up from template | Player spawn position follows `template.stairs_up` instead of hardcoded `(80, 80)` |
| Density rebalance | Ore base 12 → 22, rocks 8-12 → 14-20 (sublinear scaling for bigger arena) |
| Camera verification | Confirm Camera2D follow-player works on 1400×1000, no fit-arena clamping on mobile |

### Acceptance criteria

- [ ] B1F is always Open Arena
- [ ] B2F+ randomly rolls between all 3 templates at correct weights (36/36/27)
- [ ] Interior walls in Two Chambers and Cross Corridor are solid — player and enemies cannot walk through them
- [ ] Ore, rocks, stairs, cave entrances never spawn on top of or inside walls
- [ ] Stairs-down rock prefers the "far" zone (lower chamber / SE quadrant) per template spec
- [ ] Player spawns at template's stairs-up position, not hardcoded corner
- [ ] Floor still completable in 40-70s (slightly longer than old 30-60s target due to traversal)
- [ ] Camera follows player correctly on all 3 templates, no edge-clamping weirdness on mobile web

### Open questions for Eddie (max 3 per retro commitment)

1. **Two Chambers gap width (160px):** Feels like a chokepoint — good or too tight? Widen to 200 if bots/enemies get stuck.
2. **Cross Corridor hub (240×240):** Big enough for a portal wave + 3 enemies without wall-clipping?
3. **Treasure rocks zone-biased or arena-wide?** Spec says arena-wide (simpler). Biasing to far-zone rewards exploration but may frustrate early.

---

## Pillar B — Disposable Bot Fix & Polish

### B1. Bug fix — build menu not opening

**Symptom:** Tapping the "Bld" button on mobile (and possibly pressing B on desktop) opens nothing. The build menu UI doesn't appear.

**Instructions for tech agent:** This is a symptom report, not a diagnosis. Read the input flow from button press through to `_open_build_step1()` in `mining_hud.gd` and trace why it fails. Common suspects: input action not firing, pause-state blocking, visibility flag, node path broken — but diagnose from code, don't anchor on these.

### B2. Playtest the full bot flow

Once the menu opens, verify end-to-end:

1. Press B / tap Bld → build menu appears, game pauses
2. See 4 bot options with correct costs (Turret 3, Rig 4, Combat Drone 8, Mining Drone 6)
3. Unavailable bots (not enough ore/batteries) are greyed out
4. Select bot → step 2 shows ore stacks from backpack
5. Select ore stack → ghost placement appears
6. Tap/click to place → bot spawns at placement location
7. Bot is active and doing its job (turret shoots, rig mines, drones follow)
8. Cancel button works at every step

### B3. Bot balance — T1 values

Apply the values from `docs/design/13_balance_t1.md` §7 if not already in code:

| Bot | HP | Damage | Range (px) | Attack Rate | Move Speed |
|---|---|---|---|---|---|
| Turret | 30 | 6 | 150 | 1.0/s | 0 (static) |
| Mining Rig | 20 | 0 | 80 | — | 0 (static) |
| Combat Drone | 50 | 8 | 120 | 1.0/s | 100 |
| Mining Drone | 35 | 3 | 100 | 0.5/s | 90 |

### B4. Bot behavior verification

| Bot | Expected behavior |
|---|---|
| Turret | Stays put. Targets nearest enemy in 150px range. Fires every 1s. Yellow flash on fire. |
| Mining Rig | Stays put. Targets nearest ore node in 80px range. Mines at 1 hit per 1.5s. Orange flash. |
| Combat Drone | Follows player (~60px distance). Chases enemies in 120px range. Fires every 1s. |
| Mining Drone | Follows player (~50px distance). Chases ore nodes in 100px range. Mines every 2s. Light self-defense (3 dmg). |

### B5. Bot ore costs reconciliation

Balance doc says Turret=3, Rig=4, Drone=8, Mining Drone=6. Verify code matches. The balance doc notes code may have placeholder values of 5/4/8/6 — update if needed.

### Acceptance criteria

- [ ] Build menu opens reliably on both desktop (B key) and mobile (Bld button)
- [ ] All 4 bot types can be built and placed when player has sufficient ore + battery
- [ ] Bots that can't be afforded are visibly disabled in the menu
- [ ] Placed turrets shoot at nearby enemies
- [ ] Placed mining rigs auto-mine nearby ore nodes
- [ ] Combat drones follow the player and engage enemies
- [ ] Mining drones follow the player and mine nearby nodes
- [ ] Follower bots (drones) persist across floor transitions via stairs-down
- [ ] Static bots (turret, rig) are left behind when changing floors
- [ ] Bot ore costs match balance doc: 3 / 4 / 8 / 6
- [ ] Bot stats match balance doc §7 values
- [ ] Building a bot correctly deducts ore from backpack + 1 battery

---

## Out of Scope (Explicit)

- Permanent bots & merge system (Sprint 4)
- Save system (Sprint 4)
- T2+ balance / content (Sprint 4)
- Enemy pathfinding around walls (watch for wall-clipping bugs, but full A* pathfinding is deferred)
- Visual polish / shaders / juicing
- New enemy types
- Mineral extraction at Lab
- Story / narrative wiring

---

## Carried Debt (from Sprint 2 retro)

These are acknowledged but NOT in Sprint 3 scope unless they directly block a pillar:

| Debt | Status |
|---|---|
| `_random_enemy()` aggro/leash gap at T2-T4 | Open — Sprint 4 |
| Dead code `_spawn_loot()` in `cave_entrance.gd` | Open — cleanup candidate |
| `Player._apply_upgrades()` armor sync fragility | Open — watch |
| Design T2 balance values | Open — Sprint 4 |
| Create `docs/open_debt.md` | **Do this sprint** (small, process improvement) |

---

## Process Commitments (from Sprint 2 retro)

- [ ] PO briefs tech with **symptoms + file paths**, no diagnoses
- [ ] Tech verifies every deliverable: `git status`, `git log origin/main`, scene validity
- [ ] Eddie does a structured playtest pass before "done" — PO provides a checklist
- [ ] No more than 3 follow-up commits per pillar before stopping for root-cause review
- [ ] Cap sprint at 2 themes (this sprint: templates + bots)

---

## Delivery Order

1. **Pillar A first** (floor templates) — it changes the arena size which affects everything else
2. **Pillar B second** (bot fix + polish) — bots need to work on the new templates
3. **Playtest checkpoint** after each pillar lands — Eddie verifies before moving on
4. **Sprint review** after both pillars are verified
