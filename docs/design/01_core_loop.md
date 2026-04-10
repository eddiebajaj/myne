# Core Game Loop

## High-Level Loop

```
TOWN → ENTER MINE → MINE/BUILD/SURVIVE → RETURN TO TOWN → SELL/UPGRADE → REPEAT
```

## Detailed Flow

### 1. Town Phase
- Sell ore for gold
- Buy upgrades (pickaxe, backpack, bot blueprints — TBD)
- Choose which mine to enter
- Select starting floor (any unlocked checkpoint)

### 2. Mining Phase (Per Floor)
- Arrive on floor — single open room with ore nodes scattered around
- Mine ore nodes with pickaxe
- Encounter threats (caves, portals)
- Build bots from ore to defend/assist
- Find stairs down to next floor
- **Decision: go deeper or take stairs up to bank ore?**

### 3. Return
- Take stairs/ladder up from any floor to return instantly to town
- All carried ore is banked safely upon return
- Follower bots are lost (run is over)

## The Core Tension

Every floor presents the same question: **push or bank?**

- Pushing deeper means better ore but more danger, and your unhauled ore is at risk
- Banking means safety but you lose your bot army and start the next run from scratch (at your checkpoint)
- The deeper you are with more bots, the harder it is to leave — your momentum is your investment

## Death

- **Respawn in town**
- **Lose:** All ore currently carried (entire run's haul, not just current floor)
- **Lose:** All bots built since last checkpoint
- **Keep:** Checkpoint progress, town upgrades, unlocked floors

## Run Pacing

- Each floor: ~30-60 seconds
- Each tier (5 floors between checkpoints): ~5-8 minutes
- Full deep run: variable based on how far the player pushes
