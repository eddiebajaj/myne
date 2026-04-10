# Ore & Mineral System

## Overview

Ore is the game's central resource with three competing uses: sell for gold, spend at Lab for upgrades, or build bots mid-run. Each ore has a base type (determines tier/power) and may carry a mineral modifier (determines special effects).

## Ore Formula

```
ORE = Base Type (tier) + Mineral (optional, random)
```

- **Base type** — fixed by depth, determines sell value and bot power
- **Mineral** — random modifier on ~20-30% of nodes, adds special effects to bots built from it

## Base Ore Types

Two ores per depth tier: one common, one specialist (rarer, better for Lab research or specific uses).

| Tier | Common Ore | Specialist Ore | Depth | Sell Value | Bot Quality |
|---|---|---|---|---|---|
| T1 | Iron | Copper | B1F - B5F | Low | Basic |
| T2 | Crystal | Silver | B6F - B10F | Medium | Improved |
| T3 | Gold | Obsidian | B11F - B15F | High | Strong |
| T4 | Diamond | Mythril | B16F - B20F | Very High | Top Tier |

### Tier Rules
- Higher tier ore produces stronger bots (more HP, damage, range)
- Higher tier ore sells for more gold
- Specialist ore is rarer but may have better Lab research value (TBD)
- Ore types do not appear outside their depth range — incentive to push deeper

## Minerals (Modifiers)

Random modifiers that appear on some ore nodes. Visible on the node before mining (visual tell: glow, particle effect, color). When mined, the mineral is attached to the ore in inventory.

### Mineral Spawn Rules
- ~20-30% of ore nodes have a mineral
- Mineral type is random
- Any mineral can appear on any ore tier
- Deeper floors may have higher mineral spawn rates (TBD)

### Mineral Types

| Mineral | Bot Effect | Visual Tell (TBD) |
|---|---|---|
| Fire | Damage over time / burn | Orange glow |
| Ice | Slows enemies | Blue glow |
| Thunder | Chain damage to nearby enemies | Yellow sparks |
| Earth | Increased bot HP / durability | Green glow |
| Wind | Increased attack speed or range | White swirl |
| Venom | Poison, damage ramps over time | Purple glow |

### Mineral + Tier Interaction
- Mineral effect is the same regardless of tier
- Tier determines the strength of the effect
- Example: Iron (Fire) turret = weak burn. Diamond (Fire) turret = devastating burn.
- Same effect, different power level

## Inventory Tracking

- Ore with different minerals are tracked as separate inventory slots
- Example inventory: `3x Crystal, 2x Crystal (Fire), 1x Crystal (Ice)`
- Plain ore and mineral ore do not stack together

## Sell Value

- Base sell price determined by ore tier
- Mineral ore sells for bonus gold on top of base price
- Creates tension: sell the special ore for premium gold, or use it to build a special bot

## Tiered Bot Recipes

Building a bot costs X ore of **one type** (no mixing). The ore tier and mineral determine the bot's stats and effects.

| Bot | Ore Cost | Battery Cost |
|---|---|---|
| Turret | 5 ore (single type) | 1 |
| Mining Rig | 4 ore (single type) | 1 |
| Combat Drone | 8 ore (single type) | 1 |
| Mining Drone | 6 ore (single type) | 1 |

*Ore costs are placeholder — to be balanced.*

### Build Examples
- 5x Iron → Iron Turret (basic damage, basic range)
- 5x Crystal (Fire) → Crystal Fire Turret (improved damage, improved range, burn effect)
- 8x Diamond (Thunder) → Diamond Thunder Combat Drone (top tier stats, chain lightning)

### No Mixing Rule
- Must use one ore type per build
- Forces commitment: you need enough of one type, not a random pile
- Makes inventory management matter: "I have 3 Crystal and 3 Iron — not enough for either bot"

## Lab Mineral Services

The Lab researcher can manipulate minerals for a gold cost:

### Extract
- Strip a mineral from mineral ore
- Result: plain ore + mineral item (stored separately)
- Use case: save a good mineral for later, sell the plain ore now

### Infuse
- Attach a stored mineral to plain ore
- Result: mineral ore
- Use case: apply a stockpiled Fire mineral to high-tier Diamond ore
- Allows players to control RNG — farm minerals, apply to best ore

### Lab Mineral Storage
- Extracted minerals are stored at the Lab
- Player builds a collection of minerals over time
- Strategic: "I have a Thunder mineral saved, waiting for Diamond ore to infuse it"

## Open Design Questions

- [ ] Exact ore costs per bot type (balancing)
- [ ] Specialist ore unique properties (what makes Copper different from Iron beyond rarity?)
- [ ] Mineral spawn rate scaling with depth
- [ ] Mineral rarity tiers (are some minerals rarer than others?)
- [ ] Lab extraction/infusion gold costs
- [ ] Can minerals appear on specialist ores?
- [ ] Maximum inventory size and how ore slots work
- [ ] Are there "super minerals" or combined mineral effects?
- [ ] Do minerals affect Mining Rig / Mining Drone behavior? (e.g., Fire mining rig mines faster?)
