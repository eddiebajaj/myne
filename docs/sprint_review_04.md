# Sprint Review #4 — 2026-04-14

## Sprint Goal
Deliver the game's signature mechanic — a permanent companion bot that merges with Myne for timed combat transformation. Secondary: make combat visible.

## Team
- **Product Owner:** Claude (PO Agent)
- **Game Designer:** User (Eddie Bajaj) — creative direction + playtesting
- **Tech Lead:** Claude (Tech Agent) — sub-agent spawns
- **Stakeholder:** User (Eddie Bajaj)

---

## Deliverables

### Pillar C — Combat Readability
| Feature | Status | Notes |
|---|---|---|
| Enemy attack flash + lunge | Complete | Red flash, 8px lunge toward target |
| Bot/turret projectiles | Complete | 6px colored bullets (yellow turret, red drone, cyan Scout) |
| Player damage feedback | Complete | White flash + camera shake (5x ±2px) |
| Floating damage numbers | Complete | Color-coded: white/yellow/red/orange per source |

### Pillar A — Scout Companion
| Feature | Status | Notes |
|---|---|---|
| Scout unlock at B5F checkpoint | Complete | Popup in town on first return |
| Scout follows player + fights enemies | Complete | 28x28 cyan, yellow crown indicator |
| Scout persists across floors | Complete | Respawns from run_party each floor |
| Scout knocked out on death | Complete | Removed from floor, restored in town |
| Scout in backpack followers panel | Complete | Shows with KO indicator |

### Pillar B — Solo Merge
| Feature | Status | Notes |
|---|---|---|
| X button (console diamond complete) | Complete | Y/B/A/X layout |
| Merge panel UI | Complete | Upper/Lower selection, cost/duration display |
| Upper merge (Crystal Shots) | Complete | +8 damage, 0.12s swing, 180px range |
| Lower merge (Crystal Dash) | Complete | 350 speed, +5 armor, 1.0s i-frames |
| Merge timer on HUD | Complete | Cyan bar, flashes <3s remaining |
| Merge visual (cyan + burst) | Complete | Color shift, size grow, 8-particle burst |
| Merge persists across floors | Complete | State in GameManager, reapplied on load |
| Scout removal/respawn on merge | Complete | Disappears during, reappears on expire |
| Mutual exclusion (all panels) | Complete | Merge/build/backpack can't overlap |

### Infrastructure
| Item | Status | Notes |
|---|---|---|
| CI changed to manual deploy | Complete | workflow_dispatch only, no auto-deploy on push |

---

## Sprint Metrics
- **Commits:** 4 (combat visuals, Scout, merge, CI change)
- **Hotfix commits:** 0 — cleanest sprint yet
- **Sub-agent spawns:** 4 (1 explore, 3 tech)
- **Playtest feedback:** No tech issues reported
- **Sprint duration:** 2 days

---

## Key Design Decisions Made During Sprint

### Economy Rework (Sprint 5 scope, decided during Sprint 4 playtesting)

Eddie identified fundamental design issues during playtesting:

1. **Disposable bots don't make narrative sense.** Why would a bot you built disappear when you safely return to town? Decision: drop ALL disposable bots (turret, mining rig, combat drone, mining drone).

2. **Batteries replaced by Crystal Power.** Instead of consumable batteries, the player's crystal necklace has a permanent power capacity (CP). CP limits how many permanent bots you can bring. Upgraded through story + Lab.

3. **Lab becomes the bot hub.** Build bots from blueprints (ore + gold), upgrade bot stats, upgrade necklace capacity, upgrade merge. Common blueprints available early, rare ones from progression.

4. **Merge fuel simplified.** Free to use with cooldown (30s). Charges per run start at 1, upgraded through story. Duration starts at 15s, upgraded at Lab.

5. **Mine becomes pure gameplay.** No mid-run economy — just risk/reward of pushing deeper. Town = prepare, mine = execute.

6. **Art direction locked.** Pixel art 32x32, Binding of Isaac reference. Sprint 5 target.

### New Economy Design

```
ORE ──┬── Sell for gold (Market)
      └── Upgrades at Lab (ore + gold)
          ├── Build bots (from blueprints)
          ├── Upgrade bot stats
          ├── Upgrade Crystal Power capacity
          └── Upgrade merge (duration, potency, charges)
```

### New Town Hub

| NPC | Role |
|---|---|
| Market | Sell ore for gold |
| Smith | Upgrade pickaxe, armor, backpack |
| Lab | Build bots, upgrade bots, upgrade necklace, upgrade merge |

### Progression Arc (revised)

| Milestone | Unlocks |
|---|---|
| Game start | Mining only, common bot blueprints at Lab |
| B5F checkpoint | Scout buildable, necklace found (1 CP) |
| Story ~B7F | Solo merge unlocked (1 charge, 15s) |
| B10F checkpoint | +1 CP, merge charge +1, rare blueprint |
| Lab upgrades | Merge duration, bot stats, CP capacity |

---

## What Went Well
- **Cleanest sprint yet.** 4 commits, 0 hotfixes. All three pillars landed without rework.
- **PO reviewed code before pushing.** Sprint 3 lesson applied — read diffs, traced logic, caught nothing wrong because tech agent produced clean code.
- **Eddie's design instincts drove major improvements.** Console A/B/X/Y (Sprint 3), now the full economy rework. PO role is listening to the stakeholder, not overriding them.
- **Combat readability transformed game feel.** Projectiles, damage numbers, and camera shake make combat legible.
- **Merge system feels good.** Upper merge = power fantasy, lower merge = mobility fantasy. Both distinct.

## What Needs Improvement
- **Design rework came late.** The economy issues (disposable bots don't make sense) were in the design docs from Sprint 1 but never questioned until Eddie playtested. PO should challenge design assumptions earlier.
- **Sprint 5 is a big rework.** Removing batteries, disposable bots, build menu, and adding Crystal Power + Lab bot hub is a lot of changes. Need to scope carefully.

---

## Retrospective — PO Agent Self-Assessment

### What I did well
- Delegated all code to tech agents — zero lane crossings this sprint.
- Reviewed every tech agent diff before pushing.
- Listened when Eddie flagged design issues instead of defending the existing design.
- Wrote clear, detailed specs that tech agents could implement in single passes.

### What I need to improve
- Should have questioned the disposable bot narrative earlier (Sprint 1 design doc flagged "open questions" about bot lifecycle — I let them sit).
- Sprint 5 spec needs to be tighter on scope — the economy rework could spiral.

---

## Retrospective — User (Eddie Bajaj) / Stakeholder

### What went well
- _[To be filled by Eddie]_

### What needs improvement
- _[To be filled by Eddie]_

### What I want to see next sprint
- _[To be filled by Eddie]_

---

## Sprint 5 Scope (Planned)

### Theme: Economy Rework + Art Pass

**Pillar A — Crystal Power System**
- Remove batteries, disposable bots, build menu
- Add Crystal Power (necklace capacity)
- Lab: build bots from blueprints, upgrade bots/necklace/merge

**Pillar B — Art Direction**
- Pixel art 32x32, Binding of Isaac reference
- First sprite pass: player, enemies, bots, ore, environment

**Pillar C — Blueprint Progression**
- Common blueprints at Lab (Scout, Mining Buddy)
- Rare blueprints from story milestones
- Bot variety through blueprints, not disposable builds

---

## Milestone Tracking

### Milestone 1: Playable Prototype — 100%
### Milestone 2: Full Economy Loop — 70% (rework needed)
### Milestone 3: Permanent Bots & Merge — 40% (Scout + solo merge done, dual merge + roster pending)
### Milestone 4: Story & Progression — 5% (Scout unlock only)
### Milestone 5: Vertical Slice — 10%
