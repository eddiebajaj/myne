# Sprint Review #1 — 2026-04-10

## Sprint Goal
Establish the full game design foundation, scaffold the project, and deliver a playable web build.

## Team
- **Product Owner:** Claude (PO Agent)
- **Game Designer:** Claude (Design Agent) + User (creative direction)
- **Tech Lead:** Claude (Tech Agent)
- **Stakeholder:** User (Eddie Bajaj)

---

## Deliverables

### Design Documents (15 docs, ~2400 lines)

| Doc | Status | Summary |
|---|---|---|
| 00_game_overview.md | Complete | Core pillars, fantasy, reference games |
| 01_core_loop.md | Complete | Town → mine → return loop, death penalty, pacing |
| 02_bots.md | Complete | 4 disposable bot types, battery cost, Lab upgrades |
| 03_dungeon_structure.md | Complete | Floor layout, stairs discovery, dual portal system, scout detection |
| 04_town_and_progression.md | Complete | 3 NPCs (Lab, Smith, Market), 4-way resource flow |
| 05_ore_and_minerals.md | Complete | 4 ore tiers (2 per tier), 6 mineral modifiers, Lab extract/infuse |
| 06_player_stats.md | Complete | HP, armor shield layer, pickaxe, grid backpack |
| 07_cave_loot.md | Complete | 5 loot types (mineral cores, equipment, blueprints, batteries, artifacts) |
| 08_enemies.md | Complete | 2 factions (fauna + mineral entities), 5 archetypes, portal aggro system |
| 09_ui_ux.md | Complete | Mining HUD, build menu, backpack grid, town screens, loadout |
| 10_permanent_bots_and_merge.md | Complete | Party system (2 slots), upper/lower merge, battery fuel, 42 possible forms |
| 11_narrative_outline.md | Complete | 5 regions, 50 floors, full act structure, characters, letters, codex |
| 12_save_and_camera.md | Complete | 3 manual + 1 auto save slot, top-down camera |
| 13_balance_t1.md | Complete | Implementation-ready T1 values for all systems |
| 14_sidequests.md | Complete | 5 quest types including defense quests, story gates |

### Technical Implementation (35 files, ~3400 lines GDScript)

| Feature | Status | Notes |
|---|---|---|
| Godot 4.2 project scaffold | Complete | 29 scripts, 4 scenes |
| Player movement + pickaxe | Complete | Free movement, mining, low combat damage |
| Ore nodes + grid backpack | Complete | Nodes break in 3 hits, 4x4 grid inventory |
| Rock system + stairs discovery | Complete | 8-12 rocks per floor, 1 hides stairs, treasure rocks |
| Floor transitions | Complete | Stairs down = next floor, stairs up = instant town |
| Portal wave system | Complete | Timed waves (Insaniquarium style) + rock-triggered portals |
| Enemy spawning | Complete | Crystal Mites, Ore Shards with T1 balance values |
| Turret building | Complete | Build menu, 3 ore + 1 battery, game pauses |
| Town scene | Complete | Visible NPCs, mine entrance, sell button |
| Mining HUD | Complete | Floor number, HP, backpack bar, battery count |
| Touch controls (mobile) | In Progress | D-pad + action buttons for phone web play (debugging) |

### Infrastructure

| Item | Status | Notes |
|---|---|---|
| Git repository | Complete | github.com/eddiebajaj/myne |
| GitHub Actions CI/CD | Complete | Auto-build on push to main |
| Web export (Godot → HTML5) | Complete | GL Compatibility renderer |
| itch.io deployment | Complete | bajaj.itch.io/myne via butler |
| Android APK export | Deferred | Removed from CI — too complex for now |

---

## Key Design Decisions Made

### Core Mechanics
1. **Ore is currency AND ammo** — 4-way resource tension (sell, Lab upgrades, craft batteries, build bots mid-run)
2. **Batteries crafted from ore** — ore tier determines battery tier determines merge duration
3. **Two bot categories** — disposable (ore + battery, temporary) and permanent (crystal-powered, party members)
4. **Merge system** — Myne fuses with 2 permanent bots (upper body + lower body), robot anime transformation
5. **Armor is a shield layer** — absorbs damage before HP, bypassed by poison
6. **Portal aggro scales with ore carried** — hoarding attracts danger
7. **Caves = opt-in risk, Portals = forced risk** — two emotional beats from two threat sources

### Narrative
1. **Myne** — mining-obsessed girl, crystal necklace from dad, follows father's footsteps
2. **Father** — legendary miner, discovered crystal civilization, summoned by king, gave Myne the necklace deliberately
3. **Crystal civilization** — ancient people crystallized by their own technology, growing upward, not evil — trapped
4. **5 regions, 50 floors** — Home Village → TBD → TBD → Royal Capital → The Core
5. **Mom** — supportive anchor, tells stories about dad, steady throughout until B25F crack
6. **Father's letters** — delivered in town, tone shifts from cheerful to concerned to silence
7. **Codex** — collectible journal (letters, expedition notes, relics, visions, bestiary)
8. **Defense sidequests** — deploy turrets to protect locations from portals, escalates to portals in the village

### Infrastructure
1. **Web-first deployment** — itch.io for easy testing, especially remote/mobile
2. **GL Compatibility renderer** — required for WebGL to work
3. **Auto-deploy pipeline** — push to main → build → deploy to itch.io in ~2 minutes

---

## Blockers & Issues

| Issue | Status | Resolution |
|---|---|---|
| GDScript type inference errors | Resolved | Replace `:=` with explicit types |
| Export template paths in CI | Resolved | Copy to multiple possible locations |
| Butler download URL broken | Resolved | Switch to jdno/setup-butler action |
| Butler action can't run in container | Resolved | Split export and deploy into separate jobs |
| WebGL context lost | Resolved | Switch to GL Compatibility renderer |
| Blank screen on web build | Resolved | Brighten colors, resize town to viewport |
| Touch controls not appearing | In Progress | Investigating — possible uid/positioning issue |
| Android APK export | Deferred | Removed from CI, will revisit later |

---

## Sprint Metrics

- **Commits:** 10
- **Design docs created:** 15
- **GDScript files:** 29
- **Total lines of code:** ~3,400
- **Design doc lines:** ~2,400
- **CI/CD iterations:** 6 (until web deploy worked)
- **Agents spawned:** ~15 (design, tech, explore)

---

## What Went Well
- Full game design documented in one session — all core systems defined
- Narrative emerged organically from mechanics (crystal = bots AND enemies)
- Resource tension design (4-way ore pull) is strong and unique
- Merge system (upper/lower body) creates massive combo variety from small roster
- CI/CD pipeline established — push-to-deploy workflow
- Mom's character arc hit the right emotional notes
- Father's letters provide pacing without cutscenes

## What Needs Improvement
- PO agent did tech work multiple times instead of delegating — corrected mid-sprint
- Sub-agents frequently blocked on bash permissions — need skip-permissions enabled
- CI/CD took 6 iterations to get right — should have researched godot-ci setup better upfront
- Touch controls still not working on mobile — needs another iteration

## Action Items for Next Sprint
- [ ] Fix touch controls for mobile web play
- [ ] Playtest the mine loop and gather feedback
- [ ] Design Region 2 and 3 (settings, towns, mine aesthetics)
- [ ] Implement town economy (sell ore, buy at Smith, Lab crafting)
- [ ] Implement save system (3 manual + 1 auto)
- [ ] Design permanent bot roster (which bots, where earned)
- [ ] Add enemy AI (pathfinding, attacking player and bots)
- [ ] Implement backpack grid UI (visual inventory management)
- [ ] Add Android APK export back to CI when ready
- [ ] Begin placeholder art direction (color palette, shape language)

---

## Milestone Tracking

### Milestone 1: Playable Prototype (Current)
**Goal:** Player can complete a full mine loop — enter, mine, build, fight, return, sell.
**Status:** 80% — mine loop works, town selling works, touch controls pending.

### Milestone 2: Full Economy Loop
**Goal:** Town economy functional — Smith upgrades, Lab crafting, battery system, backpack management.
**Status:** Not started.

### Milestone 3: Permanent Bots & Merge
**Goal:** Party selection, permanent bot combat, merge transformation.
**Status:** Designed, not implemented.

### Milestone 4: Story & Progression
**Goal:** Region 1 story complete — checkpoints, letters, NPC dialogue, story gate to Region 2.
**Status:** Designed, not implemented.

### Milestone 5: Vertical Slice
**Goal:** Region 1 fully playable with story, economy, bots, merge, and polish.
**Status:** Not started.
