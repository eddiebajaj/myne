# Sprint Review #5 — 2026-04-14

## Sprint Goal
Replace the battery/disposable-bot system with Crystal Power + Lab bot hub. Validate art pipeline with AI-generated sprite swap.

## Team
- **Product Owner:** Claude (PO Agent)
- **Game Designer:** User (Eddie Bajaj) — creative direction + playtesting
- **Tech Lead:** Claude (Tech Agent)
- **Stakeholder:** User (Eddie Bajaj)

---

## Deliverables

### Path A — Crystal Power Economy Rework
| Feature | Status | Notes |
|---|---|---|
| Removed battery system | Complete | Crafting, consumption, HUD all gone |
| Removed disposable bots in mine | Complete | Build menu no longer opens in mine |
| Crystal Power capacity (CP) | Complete | Start 1, upgraded via Lab (max 5) |
| Merge charges (not batteries) | Complete | Reset on run start, 30s cooldown |
| Lab rework (bot hub) | Complete | Build Bot / Upgrade Bots / Upgrade Necklace / Upgrade Merge |
| Scout buildable blueprint | Complete | No longer auto-unlocks at B5F |
| Party selection UI | Complete | Checkboxes at mine entrance, CP-limited |
| B button = pure cancel | Complete | No more build menu to open |

### Round 2 — Starter Bots + Blueprints + Storage + Merge Gating
| Feature | Status | Notes |
|---|---|---|
| Miner bot (starter) | Complete | Auto-mines nearby ore, 10 ore cost |
| Striker bot (starter) | Complete | Melee glass cannon, 10 ore cost |
| Backpack Bot (starter) | Complete | Passive +8 slots, 10 ore cost |
| Scout via blueprint | Complete | Drops on B4, buildable after pickup for 10 ore |
| Blueprint pickup system | Complete | Purple item drops on B4, walk-over to collect |
| Merge unlock at B5F | Complete | X button gated until first B5F reach |
| Merge unlock popup | Complete | Shows on floor change after unlock |
| Storage Shed | Complete | 48 slots, deposit/withdraw, persists across runs |
| Lab checks storage+backpack combined | Complete | Spends storage first, preserves backpack |
| All bots 10 ore (no gold) | Complete | Uniform cost for easy early access |

### Path B — Sprite Pipeline Infrastructure
| Feature | Status | Notes |
|---|---|---|
| Sprite infrastructure (`SpriteUtil`) | Complete | Centralized texture loader with fallback |
| Player/bot/enemy/ore scripts wired | Complete | All entity types try to load textures |
| ColorRect fallback | Complete | Game looks identical without sprites |
| Resources/sprites/ folder structure | Complete | 4 subfolders with .gitkeep |
| AI-generated sprite prompts | Complete | PO provided 9 prompts for user |
| Actual sprite generation | **Deferred** | User hit free-tier limits on Retro Diffusion, decided to skip for Sprint 5 |

---

## Sprint Metrics
- **Commits:** 6 (Path A spec, Path A impl, Round 2 spec, Round 2 impl, Sprite infra, closeout)
- **Hotfix commits:** 0 — clean sprint
- **Sub-agent spawns:** 3 (Path A impl, Round 2 impl, Sprite infra)
- **PO diff reviews:** 3 — all caught no issues
- **Sprint duration:** ~1 day

---

## Key Design Decisions Made During Sprint

### Mid-sprint scope expansion (Round 2)
Playtesting Path A revealed UX friction:
- 20 ore Scout cost + 16 slot backpack = can't buy on first run
- Only Scout as buildable = no variety
- No persistent resource storage between runs

Fix: Round 2 added 3 starter bots + blueprint drops + Storage Shed. Increased scope but delivered clean.

### Bot variety design
All bots cost 10 ore, 1 CP — uniform pricing for parity. Differentiation by role:
- Miner — mining QoL (amber)
- Striker — damage (red)
- Backpack Bot — capacity (brown)
- Scout — balanced ranged combat (cyan, blueprint-gated)

### Merge gating
Moved from "always available with batteries" to "unlock at B5F" — creates a progression beat. Player can invest in merge upgrades at Lab earlier but can't use merge until first B5F reach.

### Art deferred
User attempted Retro Diffusion (free tier) but hit 2-sprite limit. Decided to defer sprite generation to future sprint when budget allows or asset pack is found. Infrastructure ships with fallback so game remains playable.

---

## What Went Well
- **Clean sprint.** 6 commits, 0 hotfixes. Cleanest so far.
- **PO review before push worked.** Caught nothing this time because tech agent produced clean code — but the discipline is the point.
- **Scope discipline.** Round 2 expanded scope but delivered end-to-end.
- **Fallback-first art pipeline.** Game doesn't break without sprites — this was the right call.
- **Eddie's playtesting drove design.** The UX problems (Scout cost vs backpack, no variety) were invisible until played.

## What Needs Improvement
- **Sprint scope growing.** Sprint 5 = Path A + Round 2 + Path B infra + 4 new bots + blueprints + storage + merge gating. Risk of future sprints repeating this pattern.
- **Art pipeline still unvalidated end-to-end.** Infrastructure exists, but no sprite has actually been displayed in-game. Real test comes when sprites drop in.
- **Starter bot balance untested.** Miner/Striker/Backpack stats are guesses. Need playtest data.

---

## Retrospective — PO Agent Self-Assessment

### What I did well
- Zero code edits by PO this sprint. All changes through tech agents.
- Reviewed every tech agent diff before pushing. No "rubber-stamp" commits.
- Caught design issues through Eddie's playtest feedback and adjusted scope appropriately.
- Produced 9 detailed sprite prompts when user asked, even though it turned out to be deferred.

### What I need to improve
- **Overpromised on image generation.** Didn't verify my own tool access before suggesting "I'll generate sprites for you." User expected output, got prompts instead.
- **Sprint scoping getting optimistic.** Sprint 5 shipped a lot but was planned as "Path A + maybe B." Adding Round 2 mid-sprint worked this time but is a pattern that could bite later.
- **Tech agent debug practices.** No debug popups this sprint (good) but still should set clearer boundaries on what constitutes "test mentally" vs "ship and playtest."

---

## Retrospective — User (Eddie Bajaj) / Stakeholder

### What went well
- _[To be filled by Eddie]_

### What needs improvement
- _[To be filled by Eddie]_

### What I want to see next sprint
- _[To be filled by Eddie]_

---

## Sprint 6 Candidates

From the debt tracker + Sprint 5 design directions:

### High priority
- **Bot balance iteration** — playtest the 4 bot types, tune stats (ranges, HP, damage)
- **Merge effects rework** — Eddie mentioned "merge effect will be different than what you listed" — design new merge forms per bot
- **Sprite pass** — if user finds asset pack or paid tool, drop in 9 sprites

### Medium priority
- **T2 content (B6F-B10F)** — new ores, enemies, balance — extends play past current 5 floors
- **Tetris-like backpack** — irregular ore shapes for packing puzzle (Eddie mentioned this coming)
- **Storage tabs** — upgrade path for more storage space once base 48 slots fill up
- **Rare bot blueprints** — Guardian, Healer, Amplifier from deeper floors or sidequests

### Low priority
- **Save system** — still deferred per Eddie's "fun first" rule
- **Story wiring** — letters, NPC dialogue, story gates

---

## Milestone Tracking

### Milestone 1: Playable Prototype — 100%
### Milestone 2: Full Economy Loop — 100% (economy rework complete)
### Milestone 3: Permanent Bots & Merge — 60% (4 bots + solo merge + blueprints done. Dual merge + more bots pending)
### Milestone 4: Story & Progression — 10% (merge unlock + blueprint drop infrastructure)
### Milestone 5: Vertical Slice — 25%
