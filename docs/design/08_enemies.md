# Enemy Design

## Overview

Enemies come from two sources tied to the game's narrative: natural creatures that live in the mines, and mineral entities that emerge from portals. Both are connected to a rare mineral that is both the source of the player's bot-building power and the origin of the portal threat.

## Narrative Foundation

A rare mineral deep underground is the source of:
- The player's ability to build bots (through mineral-infused ore)
- The corrupted entities that pour through portals

The same material that empowers the player also creates the threat. Mining it draws attention. Using it makes you stronger but makes the danger worse. The deeper you go, the closer to the source, the more intense both sides become.

## Two Enemy Factions

### Natural Fauna (Cave Enemies)

Underground creatures that naturally inhabit the mines. Territorial, not malicious.

**Behavior:**
- Defensive — they guard their territory (caves)
- Don't chase far from their cave or patrol zone
- Not attracted to ore — they don't care what you're carrying
- Passive floor wanderers on some floors (non-aggressive until provoked)

**Feel:** Wildlife. You're the intruder. Lighter tone.

**Drops:** Normal ore, occasionally batteries

**Scaling:** Get stronger with depth due to long-term exposure to the rare mineral. Bigger, tougher, but same territorial behavior.

**Example Types (per tier):**

| Tier | Fauna | Notes |
|---|---|---|
| T1 (B1F-B5F) | Cave Beetles, Tunnel Rats | Small, weak, basic rushers |
| T2 (B6F-B10F) | Rock Crabs, Cave Bats | Tougher, some ranged (bat dive-bombs) |
| T3 (B11F-B15F) | Stone Golems, Tunnel Serpents | Tanks and area threats |
| T4 (B16F-B20F) | Crystal Beasts, Deep Wurms | Mini-boss level fauna |

### Mineral Entities (Portal Enemies)

Creatures born from or corrupted by the rare mineral. Aggressive, drawn to ore.

**Behavior:**
- Hostile — they actively hunt the player
- Attracted to ore in the player's backpack
- Relentless — they don't retreat
- Spawn from portals and immediately seek the player

**Feel:** Unnatural, wrong. Crystalline monsters, living ore, mineral growths with limbs. Unsettling.

**Drops:** Mineral cores (pure minerals ready for Lab infusion)

**Scaling:** Get stronger with depth AND react to how much ore (especially mineral ore) the player is carrying.

**Example Types (per tier):**

| Tier | Entity | Notes |
|---|---|---|
| T1 (B1F-B5F) | Ore Shards, Crystal Mites | Small swarmers, fragile |
| T2 (B6F-B10F) | Mineral Stalkers, Prism Crawlers | Rushers and ranged |
| T3 (B11F-B15F) | Corruption Golems, Shard Spitters | Tanks and ranged, mixed waves |
| T4 (B16F-B20F) | Abyssal Crystals, Vein Horrors | Heavy threats, exploders |

## Enemy Archetypes

Both factions share base archetypes, reskinned per faction:

| Archetype | Behavior | Threat | Fauna Example | Entity Example |
|---|---|---|---|---|
| Rusher | Runs at player, melee attack | Pressure, forces movement | Cave Beetle | Crystal Mite |
| Ranged | Keeps distance, shoots | Area denial | Cave Bat | Shard Spitter |
| Tank | Slow, high HP, hits hard | Resource drain on bots | Stone Golem | Corruption Golem |
| Swarm | Weak, spawns in groups | Overwhelms single-target | Tunnel Rats | Ore Shards |
| Exploder | Charges, detonates on death | AoE damage to bots/player | (T3+ fauna TBD) | Abyssal Crystal |

### Archetype vs Bot Interactions
- **Rushers** — countered by turrets (mowed down before reaching player)
- **Ranged** — outrange turrets, need combat drones to chase them down
- **Tanks** — drain bot attention, other enemies slip through while bots focus the tank
- **Swarms** — overwhelm single-target bots, need multiple turrets or AoE mineral bots
- **Exploders** — punish bot clustering, force spread-out bot placement

## Portal Spawn System

Portals have two trigger types that create layered tension.

### Timed Waves (Predictable — Insaniquarium Style)
- Portal waves come on a regular timer per floor
- Pacing: peaceful mining → warning → wave → peace → warning → wave (harder) → ...
- Warning phase: rumbling, necklace glow, screen edge pulse (several seconds to prepare)
- Each subsequent wave on the same floor is harder (more enemies, tougher mix)
- Timer between waves shortens on deeper floors
- Player can prepare: place turrets, position bots, find cover

### Rock-Triggered Portals (Unpredictable — Surprise Threat)
- Some rocks have a chance to trigger a portal when broken
- Warning is shorter than timed waves — more sudden, more panic
- Chance modifiers:
  - Time spent on floor (longer = higher chance)
  - Ore carried in backpack (more = higher chance)
  - Mineral ore carried (extra weight)
  - Depth (deeper = higher base chance)
- Creates gambling tension: every rock broken to find stairs might bring trouble

### Both Together
- Timed waves are the **predictable** threat — you can prepare
- Rock portals are the **unpredictable** threat — keeps tension between waves
- Early floors: long timer between waves, low rock trigger chance
- Deep floors: short timer, high rock trigger chance
- Combined: deeper floors become a constant pressure cooker

### Portal Behavior
1. Visual/audio warning (shorter for rock-triggered portals)
2. Portal opens at a location on the floor
3. Enemies spawn in a fixed number of waves from the portal
4. Portal closes after all waves are done
5. Spawned enemies remain until killed — they don't despawn
6. Multiple portals possible on deeper floors (timed + rock-triggered simultaneously)

## Mineral Core Drops

Mineral entities drop mineral cores on death:
- Pure mineral items (Fire, Ice, Thunder, etc.)
- Same as cave loot mineral cores — ready to infuse at Lab
- Drop rate is not 100% — killing entities is rewarding but not guaranteed
- Creates a secondary reward for surviving portal attacks
- Narrative tie-in: you're reclaiming the mineral from corrupted forms

## Enemy Damage

### Against Player
- Enemies deal physical damage (hits armor first, then HP)
- Exception: Venom/poison type enemies bypass armor (damage HP directly)
- Damage scales with depth tier

### Against Bots
- Enemies can attack and destroy bots
- Turrets can be destroyed (static, can't dodge)
- Follower bots can take damage and be destroyed
- Exploders deal AoE damage to all nearby bots
- Bot HP is determined by ore tier used to build them

## Open Design Questions

- [ ] Timed wave intervals per tier
- [ ] Rock portal trigger chance values and scaling
- [ ] Enemy HP, damage, and speed values per tier
- [ ] Portal wave composition (how many enemies per wave, what mix)
- [ ] Boss enemies at checkpoints — designs and mechanics
- [ ] Do mineral entities have elemental types matching mineral types?
- [ ] Fauna aggro range and leash distance
- [ ] Can enemies fight each other? (fauna vs entities)
- [ ] Enemy visual design language (natural vs crystalline/corrupted)
- [ ] Sound design for portal warnings
- [ ] Do portal enemies scale with story progression or just depth?
- [ ] Mini-boss variants in caves at higher tiers
