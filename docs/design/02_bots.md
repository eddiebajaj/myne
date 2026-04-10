# Bot System Design

## Overview

Bots are the player's primary means of combat and mining efficiency. Built from mined ore mid-run, they represent the core spending decision: every bot built is ore not taken home as profit.

## Bot Categories

### Static Bots (Floor-Scoped)
Placed on a floor. Do not move between floors. Lost when the player leaves the floor.

### Follower Bots (Run-Scoped)
Follow the player floor to floor. Saved at checkpoints. Lost on death (since last checkpoint) or when returning to town.

## Bot Types

| Bot | Category | Role | Cost | Description |
|---|---|---|---|---|
| Turret | Static | Defense | Cheap | Placed on the ground, shoots at nearby enemies. Covers an area while the player mines. |
| Mining Rig | Static | Mining | Cheap | Placed near ore nodes, mines them automatically. Speeds up floor clearing. |
| Combat Drone | Follower | Defense | Expensive | Follows the player, attacks enemies. The core long-term defense investment. |
| Mining Drone | Follower | Mining | Expensive | Follows the player, mines nearby nodes alongside them. Long-term mining efficiency. |

## Design Intent Per Bot

### Turret
- **When to build:** Cave entrance nearby, need to hold a position while mining
- **Feel:** "I'll set up here and mine safely behind my turret"
- **Disposable** — player should feel OK leaving these behind

### Mining Rig
- **When to build:** Ore-rich floor, want to farm it fast
- **Feel:** "This floor is loaded, let me get a rig going while I mine the other side"
- **Investment play** — spend ore to get more ore, but only on this floor

### Combat Drone
- **When to build:** Mid-run, preparing for deeper floors
- **Feel:** "This is my bodyguard for the long haul"
- **The big decision** — expensive, but persists through floors and checkpoints

### Mining Drone
- **When to build:** Planning a long run, want sustained mining speed
- **Feel:** "My little mining buddy that pays for itself over several floors"
- **Efficiency investment** — spend ore now, mine faster on every subsequent floor

## Bot Lifecycle

```
BUILD (spend ore) → ACTIVE (on floor / following) → CHECKPOINT (followers saved) → LOST (death / return to town)
```

### Static Bots
1. Player opens build menu, selects turret or mining rig
2. Places it on the current floor
3. Bot operates until player leaves the floor
4. Bot is gone — no recovery

### Follower Bots
1. Player opens build menu, selects combat or mining drone
2. Drone spawns and follows the player
3. Drone follows to next floor via stairs down
4. At checkpoint: drone state is "saved"
5. On death: drones built after last checkpoint are lost; checkpoint-saved drones persist
6. On return to town: all drones are lost (run ends)

## Building

- **How:** Open build menu (hotkey/button), select bot type, place/confirm
- **Where:** Anywhere on the current floor
- **When:** Anytime during mining phase (not during transitions)
- **Cost:** Ore (from inventory) + 1 Battery (purchased from Market before run)

## Build Cost

Every bot requires two resources:
1. **Ore** — mined during the run, amount/type varies per bot
2. **Battery** — 1 per bot, any type. Bought at Market in town before the run.

Batteries cap how many bots you can build per run. Running out of batteries = no more bots, regardless of ore supply. This creates a pre-run planning decision: how many batteries to bring.

## Upgrades & Sidegrades (Town — Lab)

- **Upgrades:** Improve bot stats (HP, damage, range, build cost reduction). Cost: gold + ore at Lab.
- **Sidegrades:** Alternate bot behaviors unlocked via sidequests. Examples: slowing turret, tank drone, AoE mining rig.
- **Blueprints:** New bot types unlocked through story/checkpoint progression, then built at Lab.

## Open Design Questions

- [ ] Specific ore costs per bot type
- [ ] Ore type requirements (any ore? specific ores?)
- [ ] Bot limit per floor / per player?
- [ ] Bot health and damage values
- [ ] Can the player repair/heal bots?
- [ ] Visual/audio feedback for bot placement
- [ ] Bot AI behavior details (aggro range, targeting priority)
- [ ] Do batteries take backpack space?
- [ ] Battery pricing and scaling
