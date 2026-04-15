# Direction Lock — End of Sprint 6

Captures the design state after end-to-end playtest in Sprint 6. Drives Sprint 7+ planning.

---

## A. KEEP — feels right, no changes

- **Combat readability** (Sprint 4) — projectiles, damage numbers, camera shake all working
- **Floor templates** — Open Arena, Two Chambers, Cross Corridor variety
- **Permanent bot system** — companions persist across runs, knocked out on death, restored in town
- **Scout companion** — basic balance and behavior
- **Solo merge** — Upper/Lower transformation, X button, charge + cooldown
- **Crystal Power** — single-bot CP=1 starting cap, party selection
- **Storage Shed** — 48 slots, deposit/withdraw, persists across runs
- **Lab as bot hub** — central place for all crafting/upgrade
- **Console A/B/X/Y controls** — input feels native
- **UI navigation (Sprint 6 Pillar A)** — joystick + A/B works for all menus
- **Disabled button visibility** — focusable, just not activatable

## B. TUNE — numbers off, design right (lower priority)

- Bot stats — Miner/Striker/Backpack Bot search ranges may need tuning (Eddie flagged earlier)
- Floor difficulty curve B1-B5 — playable but can be sharpened later

## C. REDESIGN — design itself doesn't work

### C1. Bot building (HIGH PRIORITY — Sprint 7)
Current: bot = "10 plain T1 ore." Static, no choice.
New: **Build-your-own-bot crafting**
- Each ore tier = points: T1=1, T2=3, T3=9, T4=27
- Bot threshold: 10 points (uniform across all bots for now)
- Player allocates ANY mix of ores from inventory to reach threshold
- Mineral ores apply type-locked bonuses (Fire=+dmg, Ice=slow, etc.)
- Special **Void mineral** gives a random bonus per piece
- Fixed magnitude per mineral piece (each Fire = +1 dmg, each Earth = +5 HP, etc.)
- UI: recipe grid showing inventory + build slot + running total + bonuses preview
- "Auto-assign" button quick-fills cheapest valid combination
- Multiple instances of same bot type allowed (each with different mineral profile)

### C2. Mineral spawn rate ramp (HIGH PRIORITY — Sprint 7)
Current: 25% mineral chance on every floor — too much for beginners.
New: ramped curve
- B1-B3: 5%
- B4-B5: 15%
- B6+: 25%

### C3. Bot upgrade flow (Sprint 8)
Current: Lab "Upgrade Bots" view = HP +10 / damage +1 per level, ore + gold cost.
New: same crafting mechanic as building
- Spend ore points to level up an existing bot
- Each level = base stat increase
- Minerals applied at upgrade time = additional bonuses on top
- A single bot accumulates a layered mineral profile across upgrades
- Two players' Scouts can look identical but play very differently

## D. REMOVE — dead weight

(None flagged in playtest.)

## E. Future scope (not Sprint 7)

- Tetris-like backpack
- Storage tabs (multiple pages)
- Dual merge
- T2 content (B6F-B10F)
- More bot types (Guardian, Healer, Amplifier)
- Sound effects (negative SFX for disabled-button A press, hit feedback, etc.)
- Music
- Tutorial / first-run guidance
- Story / NPC dialogue

---

## Sprint 7 commit

Implement **C1 + C2** as Sprint 7's primary work. Bot upgrade rework (C3) deferred to Sprint 8 once the build crafting UI proves out the pattern.
