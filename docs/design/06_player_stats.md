# Player Stats & Equipment

## Overview

The player has no character level. All stat progression comes from equipment and upgrades purchased or found. The player is always "just a miner" — gear makes them better, not experience points.

## Stat Sources

| Stat | Source | Upgradeable At |
|---|---|---|
| HP | Fixed baseline | Not upgradeable (armor absorbs damage instead) |
| Armor | Equipment (Smith / cave loot) | Smith, cave loot |
| Mining Power | Pickaxe | Smith |
| Pickaxe Damage | Pickaxe | Smith |
| Move Speed | Fixed | Not upgradeable (for now) |
| Carry Capacity | Backpack (grid) | Smith or shop (TBD) |

## Health

- **Baseline:** ~8-10 hits from enemies before death
- **Fixed** — does not increase through upgrades
- **Healing:** Consumables only (purchased from Market)
- **On death:** Respawn in town, lose carried ore and bots since last checkpoint

## Armor (Shield Layer)

Armor is a separate damage layer that sits in front of HP.

### How It Works
- Armor has its own value (e.g., Armor: 5)
- Physical damage hits armor first, reducing armor value
- When armor reaches 0, damage goes to HP
- **Bypass:** Certain damage types skip armor entirely (poison, venom, possibly other elemental effects)
- Armor does NOT regenerate — once it's gone, it's gone until repaired or replaced

### Armor Progression
- **Bought at Smith** — tiered armor sets, better armor in later towns
- **Found in caves** — can find armor you can't buy yet
- **Repair at Smith** — restore damaged armor between runs (gold cost)
- Armor is purely defensive — no perks, no special effects. It's just a damage buffer.

## Pickaxe

The player's only tool/weapon. Upgraded at the Smith.

### Mining Power (Hits to Break)

Ore nodes require multiple hits to break. Pickaxe tier determines how many.

| Pickaxe | T1 Node | T2 Node | T3 Node | T4 Node |
|---|---|---|---|---|
| Starter | 3 hits | 6 hits | 12 hits | 20+ hits |
| Tier 2 | 2 hits | 4 hits | 8 hits | 14 hits |
| Tier 3 | 1 hit | 3 hits | 5 hits | 9 hits |
| Tier 4 | 1 hit | 2 hits | 3 hits | 5 hits |

*Values are placeholder — to be balanced.*

### Soft Gating
- No hard locks — any pickaxe can break any node
- Higher tier nodes just take significantly more hits with a weak pickaxe
- More time swinging = more exposure to portals and enemies
- Upgrading the pickaxe doesn't unlock content, it makes content survivable

### Pickaxe Damage (Combat)
- Pickaxe can hit enemies for low damage
- Upgrades improve this slightly but it's never a real combat strategy
- Exists so the player isn't completely helpless, not as a viable playstyle

## Backpack (Grid-Based Inventory)

### Structure
- Grid of cells (e.g., 4x4 starting size)
- Ore pieces occupy grid space (shapes TBD — 1x1? Tetris-style?)
- Player must fit ore into available grid space
- When grid is full, can't mine more — must go home or discard

### Upgrades
- Expand the grid (add rows/columns)
- Purchased at Smith or shop (TBD)
- Key upgrade axis — directly increases how much ore you can risk per run

### Design Intent
- Grid creates a "how full am I?" visual that drives the push/bank decision
- Fitting ore is a light mini-puzzle, not a major time sink
- Backpack pressure increases with depth — better ore might take more space? (TBD)

## Smith Services

The Smith handles all equipment:

| Service | What | Cost |
|---|---|---|
| Pickaxe Upgrade | Better mining power, slight damage increase | Gold |
| Armor Purchase | New armor tiers | Gold |
| Armor Repair | Restore damaged armor to full | Gold |
| Backpack Upgrade | Expand inventory grid | Gold |

## Equipment Summary

```
PLAYER
├── HP: Fixed (~8-10 hits)
├── Armor: Absorbs damage before HP (Smith / cave loot)
├── Pickaxe: Mining speed + minor combat (Smith upgrades)
├── Backpack: Grid inventory for ore (upgradeable size)
└── Move Speed: Fixed
```

## Open Design Questions

- [ ] Exact HP value
- [ ] Armor tier values and pricing
- [ ] Pickaxe tier costs and exact hit values per node tier
- [ ] Backpack starting size and upgrade increments
- [ ] Ore grid shapes (1x1 uniform? or Tetris-style per ore type?)
- [ ] Armor repair pricing
- [ ] Can armor be found as cave loot at any depth?
- [ ] Does poison/venom damage bypass armor partially or fully?
- [ ] Are there different armor types or just one linear upgrade path?
