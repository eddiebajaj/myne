# Save System & Camera

## Save System

### Save Slots
- **3 manual save slots** — player-controlled, town only
- **1 autosave slot** — system-controlled, automatic

### Manual Save
- Available only in town
- Player chooses which of 3 slots to save to
- Allows multiple playthroughs or branching save strategies

### Autosave
- Triggers on:
  - Returning to town (every time)
  - Reaching a checkpoint in the mine
- Overwrites the single autosave slot each time
- Separate from manual saves — cannot overwrite manual slots

### Mid-Floor Quit
- If the player quits mid-floor (close game, crash, etc.):
  - Lose current floor's progress (ore mined, bots built on that floor)
  - Respawn in town on next load
  - Equivalent to death penalty BUT checkpoint-saved bots are kept
  - Not punishing — just resets to last safe state

### What Gets Saved
- Player stats (HP, armor, equipment)
- Gold amount
- Inventory/backpack contents (ore, batteries, consumables)
- Town state (upgrades purchased, NPC states, quest progress)
- Mine progress (checkpoints unlocked, story flags)
- Permanent bot roster and upgrade states
- Lab mineral storage
- Story progression flags

---

## Camera

### Floor Camera
- Fixed top-down perspective
- Shows most or all of the floor room at once
- If the room is larger than the viewport, camera follows the player with slight lag
- Zoom level is fixed — no player-controlled zoom
- Camera stays within room bounds (no showing void/outside edges)

### Town Camera
- Top-down, follows the player as they walk around
- Similar behavior to floor camera but town areas may be larger

### Merge Transformation
- Camera may zoom in briefly during transformation sequence (TBD)
- Returns to normal after merge completes

## Open Design Questions

- [ ] Exact camera zoom level / viewport size
- [ ] Camera shake intensity settings (accessibility option?)
- [ ] Save file data format
- [ ] Save slot UI design
- [ ] Does autosave show a visual indicator? (saving icon)
- [ ] Cloud save support? (future feature)
