# Dungeon & Mining Design

## Floor Structure

Each floor is a single open room (Harvest Moon mine style) viewed from top-down (Chocobo's Dungeon aesthetic) with free movement (not grid-based).

### Floor Contents
- **Ore nodes** — visually distinct, broken with pickaxe to collect ore
- **Rocks/ground tiles** — breakable with pickaxe, may hide stairs down, treasure, or trigger portals
- **Stairs up** — always visible from the start, returns player instantly to town (escape route)
- **Stairs down** — hidden under a rock, must be discovered by mining rocks
- **Caves** (some floors) — visible entrance, optional dangerous sub-area with loot
- **Open space** — room to maneuver, place bots, kite enemies

### Floor Layout Principles
- Small enough to see most of the room at once
- Large enough for meaningful bot placement and movement
- Clear visual distinction between ore nodes, rocks, and ground
- Stairs up always near the entry point (safe corner)

## Mining Flow Per Floor

1. **Arrive** — see ore nodes, rocks, cave entrance (if any), stairs up
2. **Mine ore** — hit ore nodes for resources, fills backpack
3. **Search for stairs** — hit rocks to break them, one hides the stairs down
4. **Deal with threats** — caves (opt-in) and portals (forced via timer + rock triggers)
5. **Build bots** — spend ore + battery for disposable bots, permanent bots fight automatically
6. **Merge** — if needed, spend battery to transform with permanent bots
7. **Floor "done"** — player-defined, no completion condition. Leave when you want.
8. **Choose:** Stairs down (deeper) or stairs up (bank ore, end run)

### "Floor Done" is Player Choice
There is no clear condition for finishing a floor. The player decides when to leave:
- Mined everything valuable? Go down.
- Backpack getting full? Go home.
- Portal wave just ended? Quick, move before the next one.
- Found stairs early? Stay to mine more or descend immediately.
- Found a cave? Risk it for loot or skip it.

## Stairs Discovery

### Stairs Down (Hidden)
- Hidden under one of the rock/ground tiles on the floor
- Player must break rocks with pickaxe to find it
- Most rocks are empty — one reveals the stairs
- Once found, stairs remain visible — player can use them whenever
- Finding stairs does NOT force the player to descend — it's a choice

### Stairs Up (Always Visible)
- Always present and visible from the moment you arrive
- Instant return to town — entire run ends
- All carried ore is banked safely
- All bots are lost (run ends)
- Escape route is never hidden — the player can always leave

### Scout Bot Detection
- Scout permanent bot (if in party) beeps when near something underground
- Detects: stairs down, hidden treasure, portal rocks
- Does NOT tell you which one — just "something's here"
- Range-based: beeps faster/louder when closer
- Creates tension: every beep is "is this good or bad?"
- Gives Scout bot a clear utility role outside of combat

## Dungeon Types

### Story Mines (Fixed Layout)
- Hand-crafted floors with intentional design
- Specific cave placements, enemy encounters, teaching moments
- Boss encounters at checkpoints
- Player progresses through these to unlock deeper tiers
- **Primary progression path**

### Grinding Mines (Procedural) — Future Feature
- Unlocked after clearing story checkpoints
- Randomized layouts, node density, cave/portal frequency
- For farming ore and resources between story pushes
- Could support modifiers (dense portals + double ore, etc.)

## Checkpoint System

Every 5 floors is a checkpoint (B5F, B10F, B15F, etc.)

### Checkpoint Functions
1. **Story beat** — lore, NPC encounters, narrative progression
2. **Difficulty gate** — new enemy types, ore types, mechanics introduced
3. **Bot save point** — follower bots (disposable) and permanent bots are "safe"
4. **Warp destination** — player can start future runs from any unlocked checkpoint
5. **Safe room** — no threats, moment to breathe and decide

### Checkpoint Flow
```
Arrive at checkpoint floor → Story/event plays → Safe moment (no threats) → Decision: push deeper or return to town
```

## Portal System

Portals are the primary combat threat. Two trigger types create layered tension.

### Timed Waves (Insaniquarium Style)
- Portal waves come on a predictable timer
- Warning phase: rumbling, necklace glow, screen edge pulse (a few seconds to prepare)
- Wave arrives: portal opens, enemies spawn in waves
- Wave ends: portal closes, peace returns
- Each subsequent wave on the same floor is harder
- Timer between waves shortens on deeper floors

### Pacing Per Floor
```
ARRIVE → peaceful mining → WARNING → WAVE 1 → peace → WARNING → WAVE 2 (harder) → peace → ...
```

### Rock-Triggered Portals (Surprise Threat)
- Some rocks have a chance to trigger a portal when broken
- Chance modifiers:
  - Time spent on floor (longer = higher chance)
  - Ore carried in backpack (more = higher chance)
  - Mineral ore carried (extra weight on chance)
  - Depth (deeper floors = higher base chance)
- Creates "gambling" tension: every rock you break to find stairs might bring trouble
- Warning is shorter than timed waves — more sudden, more panic

### Both Together
- Timed waves are the **predictable** threat — you can prepare for them
- Rock portals are the **unpredictable** threat — keeps you tense between waves
- Early floors: long timer, low rock trigger chance
- Deep floors: short timer, high rock trigger chance
- Combined effect: deeper floors are a constant pressure cooker

### Portal Behavior
1. Visual/audio warning (shorter for rock-triggered)
2. Portal opens at a location on the floor
3. Enemies spawn in a fixed number of waves
4. Portal closes after all waves are done
5. Enemies that spawned remain until killed (they don't despawn)

## Threat Sources

### Caves (Opt-In Danger)
- Visible entrance on the floor — player chooses to enter
- Contains enemies guarding loot (mineral cores, equipment, blueprints, artifacts, batteries)
- Higher risk, higher reward
- **Role in pacing:** rewards exploration and bravery
- Scout bot beeps near cave entrances too (detects treasure inside)

### Portals (Forced Danger)
- Timed waves + rock triggers (see Portal System above)
- Mineral entities pour out — drawn to Myne's ore
- Escalate with time, depth, and ore volume
- **Role in pacing:** punishes lingering, creates urgency, provides mineral core drops

## Depth Incentives

Why push deeper instead of banking?

1. **Better ore** — deeper floors have ore types that don't exist on upper floors
2. **Bot momentum** — permanent bots are still healthy, disposable followers persist, going home resets everything
3. **Skip to checkpoint** — future runs can warp to checkpoints, but start with zero disposable bots and zero ore
4. **Deep caves** — best cave loot is deeper, and you're strongest right after a checkpoint
5. **Merge investment** — high-tier batteries fuel longer merges, worth using deep where threats match the power

## Player Actions on Each Floor

### Pickaxe
- **Mine ore nodes** — primary use, hit to break and collect ore
- **Break rocks** — search for stairs, may find treasure or trigger portals
- **Attack enemies** — low damage, panic option, not a real combat strategy
- **Break environment** — cracked walls, destructible objects (TBD)

### Movement
- Free movement (not grid-based, not 8-directional)
- WASD / analog stick
- No dash/dodge (TBD — might be needed for portal encounters)

### Building
- Open build menu (hotkey) — game pauses
- Select bot type
- Place on floor (static) or confirm spawn (follower)
- Costs ore + battery from inventory

### Merging
- Open merge menu (hotkey) — game pauses
- Select upper bot, lower bot (or solo merge)
- Confirm — transformation sequence plays
- Costs 1 battery, duration based on battery tier

## Open Design Questions

- [ ] Exact floor dimensions and camera behavior
- [ ] Ore node density per floor and scaling with depth
- [ ] Rock density per floor (how many rocks to search through)
- [ ] Timed wave intervals per tier (how long between waves)
- [ ] Rock portal trigger chance values
- [ ] Cave frequency and placement rules
- [ ] Backpack/inventory grid starting size
- [ ] Floor generation rules for procedural mines
- [ ] Environmental hazards beyond enemies (lava, gas, collapse?)
- [ ] Can the player see how many rocks are left unbroken?
- [ ] Are there floors with no stairs down (dead ends with bonus loot)?
