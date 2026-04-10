# Town & Progression Design

## Overview

Towns are fully explorable JRPG-style spaces with NPCs, shops, and sidequests. The player walks around, talks to people, and manages their progression between mining runs.

## Town Structure

### Home Town (Permanent)
- The player's base of operations throughout the game
- Contains the Lab — the only place for bot research and upgrades
- Always accessible regardless of story progression

### Story Towns (Unlocked via Story)
- New towns appear as the player reaches new regions/story acts
- Each has its own Smith tier, Market stock, and quest NPCs
- Player travels between towns (fast travel TBD)

## Key NPCs

### Lab Researcher
- **Location:** Home town only
- **Function:** Bot research, upgrades, sidegrades, battery crafting, mineral services
- **Currency:** Ore (as crafting material) + Gold
- **Close relationship with Myne** — uncle/grandpa figure, knew her father
- **Progression:**
  - Bot stat upgrades (HP, damage, range, build cost reduction)
  - Bot sidegrades from sidequests (alternate behaviors — e.g., slowing turret, tank drone)
  - Blueprint research (unlocked via story, built at lab)
  - Permanent bot upgrades and maintenance
  - Battery crafting (ore determines tier/quality)
  - Mineral extraction and infusion

### Smith
- **Location:** Each town has one (better tiers in later towns)
- **Function:** Pickaxe upgrades
- **Currency:** Gold
- **Progression:**
  - Mining speed
  - Damage (still low, but less terrible)
  - Durability / special properties (TBD)

### Market
- **Location:** Each town
- **Function:** Consumables, supplies, ore selling
- **Currency:** Gold
- **Consumables:** Healing items, utility items (TBD)

## Resource Flow

```
ORE ──┬── Sell at Market ──→ GOLD ──┬── Smith (pickaxe, armor, backpack)
      │                             ├── Market (consumables)
      ├── Lab (bot upgrades) ◄──────┘   (lab also costs gold)
      ├── Lab (craft batteries — ore tier = battery tier)
      │
      └── Spend in Mine (build disposable bots OR fuel merge)
```

### Ore Has Four Competing Uses
1. **Sell for gold** — fund pickaxe, armor, consumables
2. **Spend at Lab (upgrades)** — upgrade/sidegrade bots (long-term investment)
3. **Spend at Lab (batteries)** — craft batteries, ore tier determines battery quality
4. **Spend in the mine** — build disposable bots or fuel merge (immediate survival)

This four-way pull is the core economic tension. A rare ore is always worth something no matter what you do with it, and there's always a reason to want more.

## Progression Sources

### From Story / Checkpoints (Earned)
- Bot blueprints ("found Mining Drone schematics on B10F")
- New ore types (exist in deeper floors, story introduces them)
- New mine access
- New town access

### From Shops (Purchased)
- Pickaxe stat upgrades
- Bot stat upgrades (at Lab)
- Batteries and consumables
- Better gear in later towns

### From Sidequests (Effort)
- Bot sidegrades — alternate bot behaviors
- Unique bot mods ("bring me 5 crystals from B15F for a faster combat drone")
- Gives players specific goals for mine runs beyond "get more gold"

## Consumables

### Batteries (Crafted at Lab)
- **Crafted from ore** — ore tier determines battery tier (quality/duration)
- 1 battery = 1 disposable bot build OR 1 merge fuel
- Limits how many bots/merges the player can use per run
- Creates pre-run planning: "How many batteries, what tier, for what purpose?"
- Better batteries = longer merge duration

| Battery Tier | Crafted From | Merge Duration |
|---|---|---|
| Basic | T1 ore (Iron/Copper) | Short (~15 sec) |
| Improved | T2 ore (Crystal/Silver) | Medium (~30 sec) |
| Advanced | T3 ore (Gold/Obsidian) | Long (~45 sec) |
| Superior | T4 ore (Diamond/Mythril) | Extended (~60 sec) |

### Other Consumables (TBD)
- Healing items
- Utility items (flares, escape tools, etc.)
- Specific ideas to be designed later

## Bot Build Cost

Building a disposable bot requires BOTH:
1. **Ore** — mined during the run (type and amount varies per bot)
2. **Battery** — crafted at Lab before the run (1 per bot)

Merging requires:
1. **Battery** — consumed to fuel the merge (tier determines duration)

This means:
- Batteries are shared between disposable bots and merging
- "Do I use this Advanced Battery for a turret or save it for a 45-second merge?"
- Running out of batteries = no more bots AND no more merges

## Open Design Questions

- [ ] Battery crafting costs (gold fee per tier)
- [ ] Do batteries take backpack space?
- [ ] Specific pickaxe upgrade tiers and costs
- [ ] Lab research tree structure
- [ ] Sidequest reward design
- [ ] Consumable types beyond batteries
- [ ] Town fast travel system
- [ ] Home base customization (house, workshop, display)
- [ ] Market stock changes per story town
- [ ] NPC relationship / reputation system?
