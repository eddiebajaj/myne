# Cave Loot System

## Overview

Caves are opt-in danger zones on mine floors. They contain enemies guarding loot that can't be obtained through normal mining. Cave loot is the primary reason to take risks beyond just mining ore.

## Loot Categories

### Mineral Cores
- Pure mineral items (Fire, Ice, Thunder, etc.) without ore attached
- Ready to infuse at the Lab — skips the extraction step
- Saves gold and gives immediate crafting flexibility
- **Why it's worth the risk:** Minerals are random on ore nodes, but cave cores are guaranteed specific minerals

### Equipment
- Armor pieces and pickaxe parts
- Can be items not yet available at the current Smith tier
- Finding gear in caves lets you "skip ahead" in progression
- **Why it's worth the risk:** Free upgrades that would otherwise cost gold, or gear you can't buy yet

### Blueprints
- Bot variant schematics — unique bot modifications only found in caves
- Taken to the Lab to unlock new bot sidegrades
- Examples: spread-shot turret, shield drone, area mining rig
- **Why it's worth the risk:** Exclusive content, can't be obtained any other way

### Batteries
- Free batteries found in the cave
- Directly enables more bot building this run without spending gold
- **Why it's worth the risk:** Immediate tactical advantage, extends your run capacity

### Artifacts (Run-Only Buffs)
- Passive items that provide a buff for the current run only
- Lost when the player returns to town
- Encourage pushing deeper — "I just found a great artifact, I should keep going"
- **Why it's worth the risk:** Temporary power spike that makes the next few floors easier

## Artifact Examples

| Artifact | Effect |
|---|---|
| Miner's Lantern | Reveals mineral types from further away |
| Ore Magnet | Auto-collects ore drops in a radius |
| Bot Overclock | Bots attack 30% faster this run |
| Deep Pockets | Temporary extra backpack row |
| Thick Boots | Immune to floor hazards (TBD) |
| Lucky Strike | Increased mineral spawn chance on nodes |
| Scrap Recycler | Recover partial ore when bots are destroyed |
| Emergency Battery | First bot built each floor costs no battery |

*Artifact list is not final — to be expanded.*

## Cave Design

### Structure
- Sub-area within a mine floor
- Visible entrance — player can see it and choose to enter
- Contains enemies (type/amount scales with depth)
- Loot is inside — might be in a chest, dropped by a mini-boss, or scattered around
- Player can leave the cave and return to the main floor

### Loot Rules
- Each cave has 1-3 loot items
- Loot table scales with depth (deeper caves = better loot categories)
- Not every cave has every loot type — randomized per cave
- Some loot may require clearing all enemies, some might be grabbable and runnable (TBD)

### Cave Frequency
- Not every floor has a cave
- Frequency may increase with depth (TBD)
- Story mines have hand-placed caves at specific floors
- Grinding mines randomize cave placement

## Loot Interaction with Core Loop

Cave loot reinforces the "push deeper" incentive:
- **Artifacts** are wasted if you go home (lost on return) — push deeper to use them
- **Batteries** enable more bots — push deeper while you have build capacity
- **Equipment** makes you tougher right now — push deeper while you're strong
- **Blueprints** and **Mineral Cores** are permanent value — safe to bank

This creates two loot emotions:
1. "I should push deeper to use this" (artifacts, batteries)
2. "I should go home to bank this" (blueprints, equipment, mineral cores)

Both are valid, both create tension.

## Open Design Questions

- [ ] Cave size and layout (one room? multi-room?)
- [ ] Cave enemy composition per depth tier
- [ ] Mini-bosses in caves? At what depth?
- [ ] Loot table specifics and drop rates
- [ ] Can you grab loot without clearing enemies?
- [ ] Artifact stacking (can you hold multiple artifacts?)
- [ ] Artifact rarity tiers
- [ ] Are some caves locked (require key item or story progress)?
- [ ] Visual distinction between cave tiers
