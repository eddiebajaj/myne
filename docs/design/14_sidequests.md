# Sidequest Design

## Overview

Sidequests serve two purposes: give players specific reasons to mine and build the world beyond the main story. Every sidequest should reveal character, build the world, or connect to the crystal mystery. No filler fetch quests.

Sidequests are available in every town and unlock as the player progresses through regions.

## Sidequest Types

### 1. NPC Personal Quests (Character-Driven)

Each NPC has a personal story. Their quests reveal who they are and deepen the player's connection to the world.

#### Home Village Examples

| NPC | Quest | Reward | Narrative Purpose |
|---|---|---|---|
| Lab NPC | "I need Crystal ore from B8F. I'm building something... for your father. Don't ask yet." | Bot upgrade | Foreshadows his connection to dad's mission |
| Smith | "My grandfather's pickaxe is somewhere in the B6F caves. He lost it decades ago." | Unique pickaxe cosmetic / minor stat boost | Establishes miners have gone deep for generations |
| Market Merchant | "Mountain pass miners used to trade a silver ore I've never seen. Find some, I'll pay double." | Premium gold payout | Introduces Region 2 ore before player gets there |
| Mom | "Your father left a locked box in the attic. He said the key is 'where he first heard the hum.'" | Family photo (codex entry). No mechanical reward. | Sends player to the cave from dad's mine letter about the crystal humming. Pure emotion. |

#### Later Town Examples (TBD)
- Each new town has 3-5 NPC personal quests
- Quests reflect the town's culture and relationship to mining
- Some NPCs have multi-part quest chains that span the player's time in that region

### 2. Defense Quests (Mechanic-Driven)

Player deploys turrets and bots to protect locations from portal waves. Uses core bot mechanics in a new context — defending something other than yourself.

#### How It Works
- Player is given a location to defend (village entrance, mine shaft, NPC camp, town square)
- Portal waves spawn on a timer, targeting the location
- Player pre-places turrets and bots using their own ore and batteries
- The player doesn't mine during defense — pure defense challenge
- Survive X waves to complete the quest

#### Narrative Escalation

| Phase | Quest | Implication |
|---|---|---|
| Region 1 | "A portal opened near the village mine entrance. Set up some turrets." | Portals are a nuisance |
| Region 2 | "Portals are appearing on the mountain pass. The road needs defenses." | Portals are spreading |
| Region 3 | "Portal activity is spiking near the settlement. Help us hold." | The crystal is reaching further |
| Region 4 | "A portal opened inside the village. Protect the town square." | The threat is at home. Mom is there. Personal stakes. |

#### Design Intent
- Tests bot placement skill in a focused scenario
- Creates demand for batteries and ore (economy sink)
- Makes portals feel like a world-level threat, not just a mine problem
- Ties into narrative: the crystal is growing, portals are reaching the surface
- Could become a recurring activity — portals keep appearing, defend again for escalating rewards

#### Potential Rewards
- Gold
- Unique bot sidegrades ("the engineer studied how your turrets performed and improved the design")
- Rare minerals
- Codex entries (portal behavior data)

### 3. Repeatable Resource Quests (Economy-Driven)

Simple "bring me X" quests with flavor text that builds the world. These are the grind quests — functional, but not soulless.

#### Examples

| Quest | Flavor | Reward |
|---|---|---|
| "The village needs 10 Iron for repairs." | Mine entrance is cracking — world-building about mine instability | Gold |
| "I'm experimenting with Fire minerals. Bring me 3." | Lab NPC research | Unique bot sidegrade |
| "The Smith needs Obsidian to forge a new tool." | Introduces deeper ore requirements | Pickaxe upgrade material |
| "Merchants in the next town want Crystal samples." | Trade route flavor | Premium gold + reputation |

#### Design Rules for Repeatable Quests
- Always have a reason beyond "I need stuff"
- Reward should match the effort (deep ore = better reward)
- Some repeatables should mention the crystal/portal situation to maintain narrative tension
- Limit active repeatables to avoid quest log bloat (3-5 at a time)

### 4. Mystery Quests (Lore-Driven)

Found through codex entries, cave discoveries, or NPC hints. These build the crystal civilization's story for lore-hunters.

#### Examples

| Quest | Trigger | Reward |
|---|---|---|
| Find 3 crystallized relics across regions | Cave discoveries | Lab NPC assembles them → vision of the civilization before crystallization (codex entry) |
| A miner in Region 2 is "hearing things" from the veins | NPC dialogue | Investigate → discover crystal communicates with certain people → foreshadows necklace connection |
| Decipher markings found on cave walls | Multiple cave finds | Reveals the crystal civilization's name, culture, what they valued |
| A crystallized animal in a deep cave seems... alive? | Cave discovery B20F+ | Investigate → learn that the crystal preserves consciousness, not just form |

#### Design Intent
- Optional but deeply rewarding for invested players
- Build toward the B25F ruins reveal — players who did mystery quests will have context others don't
- Codex entries from these quests make the final act more emotionally resonant
- Some mystery quests span multiple regions (find pieces in Region 1, 2, and 3)

### 5. Story Gate Quests (Progression-Driven)

These unlock the next region. They should feel meaningful and tied to the crystal theme, not arbitrary roadblocks.

| Gate | Quest | Tie-In |
|---|---|---|
| Region 1 → 2 | "The mountain pass is blocked by a crystal growth. Lab NPC needs specific ore to build a device to clear it." | Crystal is physically blocking progress — it's growing |
| Region 2 → 3 | "A cave-in sealed the deep route. The Region 2 Smith can forge supports, but needs rare ore from B18F." | Uses the Smith upgrade progression |
| Region 3 → 4 | "The road to the capital requires a royal permit. The local governor needs proof of what's down there." | Bring codex evidence — ties to the narrative |

#### Design Rules for Story Gates
- Always involve mining (the player should need to go into the mine to progress)
- Should feel like a natural obstacle, not an arbitrary wall
- Completing the gate should feel like an achievement, not a chore
- 1-2 hours of play per gate (mining + town + quest completion)

## Quest System Design

### Quest Log
- Accessible from pause menu
- Categories: Active, Completed, Region-specific
- Shows objectives, rewards, and quest-giver location
- Max active quests: 8-10 (prevents overwhelm)

### Quest Rewards
- Gold (most common)
- Bot upgrades/sidegrades (from Lab-related quests)
- Equipment (from Smith-related quests)
- Codex entries (from mystery quests)
- Unique items (from NPC personal quests)
- Story progression (from gate quests)

### Quest Availability
- New quests unlock as the player reaches new floors/regions
- Some quests have prerequisites (complete quest A before quest B appears)
- Town NPCs have new dialogue and quests after major story beats
- Defense quests appear periodically as portals escalate

## Open Design Questions

- [ ] Exact quest counts per town/region
- [ ] Quest reward balancing (gold amounts, upgrade values)
- [ ] Multi-part quest chain details
- [ ] Defense quest wave composition and difficulty
- [ ] Defense quest map/location designs
- [ ] Quest UI/UX design (quest log, tracking, notifications)
- [ ] Do quests have time limits or deadlines?
- [ ] Can quests fail? What happens?
- [ ] NPC relationship/reputation system tied to quest completion?
- [ ] Recurring defense quest scaling and leaderboard design
