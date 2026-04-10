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
- Collaborative design process worked well — user provides vision, PO proposes options, user decides

## What Needs Improvement
- PO agent did tech work multiple times instead of delegating — corrected mid-sprint
- Sub-agents frequently blocked on bash permissions — need skip-permissions enabled
- CI/CD took 6 iterations to get right — should have researched godot-ci setup better upfront
- Touch controls took 3 iterations to fix — should have caught invalid UIDs and positioning issues earlier
- Tech agent couldn't commit its own work due to permission blocks — slowed the pipeline

## Retrospective — PO Agent Self-Assessment

### What I did well
- Kept design discussions focused and decision-oriented — proposed options, let the user choose
- Built design docs incrementally, updating them as decisions were made
- Caught pacing issues (user flagged B5F-B10F being too fast — I should have caught this myself)
- Established a clear agent delegation structure by end of sprint

### What I need to improve

**1. Stay in my lane.**
I fixed GDScript errors, CI/CD configs, and export settings directly instead of delegating to the tech agent. This happened 4+ times. Even "simple" fixes should go through the tech agent — that's their job. My role is to brief clearly, review output, and coordinate.

**2. Brief tech agents more thoroughly.**
Multiple tech agent runs failed because my briefs didn't include enough context about the runtime environment (container limitations, Godot web export quirks, permission constraints). Better briefs = fewer iterations.

**3. Validate tech output before shipping.**
The touch controls scene had an obviously invalid UID (`uid://touch_controls_scene`) that I should have caught during review. I committed and pushed without checking the .tscn file contents. Review means actually reading the output, not just checking that the agent completed.

**4. Anticipate platform constraints earlier.**
The Forward+ → GL Compatibility switch, the container vs host action issue, the butler URL change — these were all knowable problems that could have been avoided with upfront research instead of reactive fixes.

**5. Track design decisions in real-time.**
Several times I had to re-explain decisions to new agents because I hadn't documented them yet. Design decisions should be written to docs immediately, not batched.

### Process improvements for next sprint
- Always delegate tech work to tech agent, no exceptions
- Review all agent output file-by-file before committing
- Research platform constraints (web export, CI/CD) before implementation
- Brief agents with explicit file paths, line numbers, and expected behavior
- Run a quick validation check after each deploy (not just "did CI pass" but "does it actually work")

## Retrospective — Design Agent

### Tasks completed
- Created T1 balance document (13_balance_t1.md) with implementation-ready values
- Defined ore costs per bot type (Turret=3, Mining Rig=4, Mining Drone=6, Combat Drone=8)
- Defined enemy stats for all T1 enemies (HP, damage, speed, attack rate, aggro ranges)
- Defined portal timer values (first wave delays, subsequent intervals, wave composition)
- Defined floor layout numbers (ore nodes, rocks, treasure distribution)
- Confirmed backpack dimensions (4x4, 1x1 ore, batteries separate)
- Provided code-ready reference tables for tech agent (Section 9)

### What went well
- Produced concrete, implementable numbers — not vague ranges or "TBD"
- Cross-referenced existing code values and noted where they diverged
- Included rationale for every number ("turret at 3 ore is buildable after mining 3 nodes")
- Bot vs enemy matchup scenarios helped validate balance
- Time budget per floor confirmed the 30-60 second target from design docs

### What needs improvement
- Only covered T1 balance — T2-T4 still unbalanced and unspecified
- Some values are marked "(tuning needed)" — need playtesting to validate
- Did not address mineral effects on bot stats (Fire turret damage bonus, etc.)
- Did not define difficulty scaling curves across the full 50 floors

### Action items for next sprint
- [ ] Define T2 balance values once T1 is playtested and validated
- [ ] Design mineral effect multipliers per mineral type
- [ ] Create a difficulty scaling curve document for floors 1-50

## Retrospective — Tech Agent

### Tasks completed
- Implemented Phase 1 playable mine loop (10 files, 402 lines added)
- Created Rock class with stairs discovery, treasure loot, portal triggers
- Rewrote PortalSpawner for timed wave system matching balance doc
- Updated all bot and enemy stats to match T1 balance values
- Added sell button to town scene
- Added build menu pause functionality
- Created touch controls autoload (3 iterations to fix)
- Fixed CI/CD workflow multiple times (butler action, container splitting)

### What went well
- Built on existing scaffold rather than rewriting — understood the codebase
- Matched balance doc values exactly (Section 9 code-ready tables helped)
- Rock system cleanly integrates stairs discovery, treasure, and portal triggers in one class
- Portal spawner correctly implements both timed and rock-triggered portals

### What needs improvement

**1. Code quality issues shipped to CI.**
- GDScript type inference errors (`:=` on expressions Godot can't infer) — these should have been caught before committing. The agent should test-parse scripts or at least know Godot 4.2's type inference limitations.

**2. Scene files with invalid data.**
- Touch controls .tscn had a made-up UID (`uid://touch_controls_scene`) that caused silent autoload failure. The agent fabricated a UID instead of omitting it. Scene files should either use Godot-generated UIDs or no UID at all.

**3. UI positioning assumptions.**
- Touch controls used anchor-relative negative offsets that placed buttons offscreen. Should have used absolute viewport coordinates from the start, since the viewport size (1280x720) is known.

**4. Insufficient self-testing.**
- Multiple issues (invisible colors, offscreen buttons, broken input routing) would have been caught with basic "does this render" validation. The agent should describe expected visual output and flag uncertainty.

**5. Bash permission blocks.**
- Agent was blocked from running git commands in 4+ sessions, requiring the PO to commit manually. This slowed every delivery cycle. Root cause: sub-agent permission settings.

### Action items for next sprint
- [ ] Always omit UIDs in manually-created .tscn files
- [ ] Use explicit types instead of `:=` for any non-trivial expressions
- [ ] Use absolute positioning for UI elements when viewport size is known
- [ ] Include a "visual verification checklist" in commit messages for UI changes
- [ ] Resolve bash permission issue for sub-agents (user to enable skip-permissions)

## Retrospective — User (Eddie Bajaj) / Stakeholder

### What went well
- _[To be filled by Eddie]_

### What needs improvement
- Touch controls went through 3+ iterations and still weren't working on mobile — virtual pad never appeared on phone web build
- _[More to be filled by Eddie]_

### What surprised me
- _[To be filled by Eddie]_

### What I want to see next sprint
- _[To be filled by Eddie]_

---

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
