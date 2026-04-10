# Permanent Bots & Merge System

## Overview

Permanent bots are crystal-powered companions that form Myne's party. Unlike disposable bots (ore + battery, lost each run), permanent bots persist forever, are earned through story and quests, and can merge with Myne to create an armored combat form.

## Permanent Bot Basics

| Aspect | Detail |
|---|---|
| Power source | Crystal necklace (not batteries) |
| Lifespan | Permanent — survive across all runs |
| Party size | 2 bots max per run (+ Myne = 3 party members) |
| Combat capable | Yes — they fight alongside Myne |
| Earned from | Story, checkpoints, sidequests, cave discoveries |
| Upgraded at | Lab (ore + gold) |

## Role in Combat

Permanent bots are the core party. Disposable bots are tactical supplements.

| | Permanent Bots | Disposable Bots |
|---|---|---|
| Count per run | 2 | As many as batteries allow |
| Combat ability | Strong, upgradeable | Weaker, determined by ore tier |
| Survive runs | Yes | No |
| Cost to deploy | Free (crystal powered) | Ore + battery |
| Role | Core party, always fighting | Turrets, rigs, extra drones for coverage |

### Why Both Matter
- Permanent bots can't cover an entire floor alone — too few
- Disposable turrets hold chokepoints, mining rigs farm ore, extra drones handle overflow
- Permanent bots handle the main fight, disposable bots handle everything else
- Without disposable bots: permanent bots are spread too thin
- Without permanent bots: pure ore drain, no reliable baseline

## Permanent Bot Roster

Players collect many permanent bots over the course of the game but only bring 2 per run. Choosing which 2 to bring is a pre-run decision that affects:
- What combat support you have on each floor
- What merge forms are available
- What utility/passive abilities you have access to

### Example Permanent Bots (TBD — to be designed with narrative)

| Bot | Combat Style | Upper Merge | Lower Merge |
|---|---|---|---|
| Scout | Fast attacks, low damage | Rapid-fire crystal shots | Dash movement, high speed |
| Guardian | Tanky, draws aggro | Heavy melee, shield | Armored legs, knockback stomp |
| Amplifier | Buffs nearby bots, ranged | AoE crystal blast, beam attacks | Float/hover, area pulse |
| Striker | High damage, fragile | Dual crystal blades | Lunge movement, gap closer |
| Engineer | Repairs/buffs disposable bots | Drone swarm launcher | Deployable platform/barrier |
| Healer | Restores Myne's HP/armor | Regen aura, cleanse | Damage absorption field |

*Bot roster is not final — will be expanded with narrative design.*

## On Death (In a Run)

Permanent bots cannot be permanently lost. When "killed" in a run:
- Knocked out for the rest of the run
- Cannot merge with a knocked-out bot
- Returned to full health when Myne returns to town
- If severely damaged, may need Lab repair (gold cost)

## Merge System

Myne absorbs her permanent bots to form an armored combat suit. Robot anime transformation sequence.

### How It Works

1. Myne's crystal necklace resonates with her permanent bots
2. Bots physically attach to Myne — one as upper body (arms/weapons), one as lower body (legs/mobility)
3. Myne becomes a combat-capable armored form
4. Duration is limited by battery quality used to fuel the merge
5. When duration expires, bots detach and return to normal companion mode

### Merge Configurations

**Dual merge (2 bots):**
- One bot assigned to upper body → determines attack type, weapon, range
- One bot assigned to lower body → determines movement type, speed, dodge
- Assignment is chosen at merge time, not pre-set
- Same two bots can create two different forms depending on assignment

**Solo merge (1 bot):**
- One bot assigned to either upper OR lower
- Upper = Myne gets arms/weapons, keeps normal movement
- Lower = Myne gets legs/mobility, keeps pickaxe for attacking
- Half-suit — cheaper, less powerful, but still useful
- Costs less battery energy than dual merge

### Merge Combinations

With 2 bots and 2 positions, each pair creates 2 forms:

| Upper | Lower | Result |
|---|---|---|
| Scout | Guardian | Ranged attacks + armored movement |
| Guardian | Scout | Heavy melee + fast dashing |
| Scout | Amplifier | Rapid fire + hovering AoE |
| Amplifier | Scout | Crystal beam + high speed |
| Guardian | Amplifier | Shield bash + area pulse |
| Amplifier | Guardian | AoE blast + heavy stomp |

*With 6 bots: 6 x 5 = 30 dual combos + 6 solo upper + 6 solo lower = 42 total forms.*

### Merge UI Flow

**Dual merge:**
```
[Merge Button] → Select Upper Bot → Select Lower Bot → [Confirm] → TRANSFORMATION SEQUENCE → Combat
```

**Solo merge:**
```
[Merge Button] → Select Bot → [Upper / Lower] → [Confirm] → TRANSFORMATION SEQUENCE → Combat
```

### Merge Assignment is Done Mid-Run
- Player decides in the moment based on the situation
- Facing a swarm? Maybe ranged upper + fast lower to kite
- Facing a tank? Maybe heavy melee upper + armored lower to brawl
- Flexibility is the point — same party, different answers to different threats

## Battery as Merge Fuel

Merging consumes a battery. Battery tier (determined by the ore used to craft it) determines merge duration.

| Battery Tier | Crafted From | Merge Duration |
|---|---|---|
| Basic Battery | T1 ore (Iron/Copper) | Short (~15 sec) |
| Improved Battery | T2 ore (Crystal/Silver) | Medium (~30 sec) |
| Advanced Battery | T3 ore (Gold/Obsidian) | Long (~45 sec) |
| Superior Battery | T4 ore (Diamond/Mythril) | Extended (~60 sec) |

*Duration values are placeholder — to be balanced.*

### Battery Dual Purpose
The same batteries fuel both disposable bots and merges:
- Build a turret = 1 battery consumed
- Merge = 1 battery consumed
- "Do I save this Advanced Battery for a long merge, or build a strong turret?"
- Pre-run planning: how many batteries, what tier, for what purpose

### Battery Crafting
- Crafted at the Lab
- Cost: ore (determines tier) + gold (crafting fee)
- Higher tier batteries require higher tier ore
- Ore is consumed in crafting — another pull on the ore economy

## Ore Economy (Updated — Four Uses)

```
ORE ──┬── Sell for gold
      ├── Lab: bot upgrades/research
      ├── Lab: craft batteries
      └── Mine: build disposable bots (ore + battery)
```

## Progression Arc

| Phase | Floors | Permanent Bots | Merge | Feel |
|---|---|---|---|---|
| Early | B1F-B5F | 0 | No | Pure mining, disposable bots only, learning the basics |
| First companion | ~B5F | 1 | Solo only | First real partner, solo merge tutorial |
| Mid game | B6F-B10F | 2 | Dual unlock | Full party, merge combos open up |
| Late game | B11F+ | 2 (from growing roster) | Full system | Party comp matters, merge form matches the threat |

## Open Design Questions

- [ ] Full permanent bot roster (how many total, earned where)
- [ ] Permanent bot individual ability design
- [ ] All merge form designs (per combination)
- [ ] Merge transformation animation/sequence details
- [ ] Solo merge duration vs dual merge duration (same battery cost?)
- [ ] Can you merge multiple times per floor with multiple batteries?
- [ ] Do permanent bots gain XP or level up?
- [ ] Permanent bot AI behavior (aggro, positioning, priorities)
- [ ] Can knocked-out permanent bots be revived mid-run? (consumable?)
- [ ] Merge form stat scaling (based on permanent bot level? ore tier of battery? both?)
- [ ] Party selection UI on loadout screen
- [ ] Does merging have an invulnerability window during transformation?
