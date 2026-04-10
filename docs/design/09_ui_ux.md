# UI/UX Design

## Design Philosophy

- Clean and readable during mining, chaotic VFX during combat
- HUD is minimal — the world communicates state through VFX and audio
- Adaptive elements appear contextually, not permanently
- Chocobo's Dungeon cozy feel as baseline, intensity ramps with combat
- Town UIs are straightforward JRPG shop/menu interfaces

---

## Mining HUD

The primary gameplay screen. Minimal persistent elements, contextual pop-ins.

### Layout

```
┌─────────────────────────────────────────────────┐
│ [B7F]                          [Backpack ████░░] │
│                                                  │
│ [HP ██████████]                                  │
│ [AR ████████░░]                                  │
│                                                  │
│                                                  │
│                                                  │
│                    PLAYER                         │
│                                                  │
│                                                  │
│                                                  │
│                                                  │
│                                                  │
│ [🔋 x3]  [Bot: ⚔️x1 ⛏️x1]        [Build Menu] │
└─────────────────────────────────────────────────┘
```

### Persistent Elements
- **Top-left:** Floor number (B7F)
- **Top-right:** Backpack fill bar (tap to open full grid inventory)
- **Left side:** HP bar and Armor bar (stacked, armor on top)
- **Bottom-left:** Battery count, active follower bot icons with count
- **Bottom-right:** Build menu button
- **Center:** Clean play space — player, floor, nodes, enemies only

### Contextual Elements (Appear on Trigger)

| Trigger | Element |
|---|---|
| Mine a node | Ore icon + amount floats up, backpack bar pulses |
| Portal warning | Screen edge pulses red/purple, directional warning icon |
| Portal active | Portal location marked, enemy count indicator |
| Bot takes damage | Health pip flashes above bot (in-world) |
| Bot destroyed | Death VFX, follower count decreases |
| Backpack nearly full | Bar turns yellow → red when full |
| Low HP | Screen edges vignette red, heartbeat audio |

---

## Calm-to-Chaos Transition

The HUD stays consistent. The world changes around it.

### Mining State (Calm)
- Soft ambient audio
- Gentle pickaxe SFX
- Ore sparkle particles on nodes
- Minimal HUD, cozy Chocobo's Dungeon feel

### Portal Warning (Tension)
- Music shifts to urgent
- Screen edge glow (red/purple)
- HUD elements sharpen/brighten
- Audio cue (rumble, crystal cracking)

### Combat State (Chaos)
- Bot weapon VFX (lasers, projectiles, explosions)
- Enemy attack particles
- Screen shake on big hits/explosions
- Damage numbers floating
- Same clean room, now a light show

### Combat Ends (Return to Calm)
- VFX fade out
- Music softens back to ambient
- Calm returns over a few seconds

---

## Build Menu (Overlay)

Opened via bottom-right button or hotkey. Shows available builds based on current inventory.

```
┌──────────────────────────┐
│      BUILD BOT           │
│                          │
│  [Turret]     5x Iron    │
│  [Mining Rig] 4x Iron    │
│  [Combat ▶]   8x Crystal │
│  [Mining ▶]   6x Crystal │
│                          │
│  Battery: 3 remaining    │
│                          │
│  [Cancel]                │
└──────────────────────────┘
```

### Behavior
- Shows buildable bots based on current ore and batteries
- Greyed out if materials insufficient
- Ore type shown is highest available single-type stack
- Multiple ore options shown if player has different types (select which ore to use)
- Mineral ore marked with mineral icon — player can see what effect the bot will get
- **Game pauses while menu is open** — fits the cozy baseline, reduces panic
- After selecting: place mode for static bots (tap location), instant spawn for followers

---

## Backpack Grid (Overlay)

Opened by tapping the backpack bar. Full grid inventory view.

```
┌──────────────────────────┐
│     BACKPACK (12/16)     │
│  ┌──┬──┬──┬──┐           │
│  │Fe│Fe│Cr│  │           │
│  ├──┼──┼──┼──┤           │
│  │Cr│Cr│Ag│  │           │
│  │🔥│🔥│  │  │           │
│  ├──┼──┼──┼──┤           │
│  │Au│Au│Au│Ob│           │
│  ├──┼──┼──┼──┤           │
│  │Ob│Ob│Ob│  │           │
│  │⚡│⚡│⚡│  │           │
│  └──┴──┴──┴──┘           │
│                          │
│  [Discard]    [Close]    │
│                          │
│  Total Value: 340g       │
└──────────────────────────┘
```

### Behavior
- Grid shows ore with mineral icons overlaid
- Tap ore to select, then discard to make room
- Shows total sell value of all carried ore
- Game pauses while open
- Quick glance and back to mining

---

## Town UI — Smith

```
┌──────────────────────────────────────┐
│            SMITH                     │
│                                      │
│  PICKAXE                             │
│  ┌────────────────────────────┐      │
│  │ Iron Pickaxe → Steel Pickaxe │    │
│  │ Mining: 3 hits → 2 hits (T1) │    │
│  │ Damage: 5 → 8                │    │
│  │ Cost: 500g              [BUY]│    │
│  └────────────────────────────┘      │
│                                      │
│  ARMOR                               │
│  ┌────────────────────────────┐      │
│  │ Leather → Chain             │     │
│  │ Armor: 3 → 6               │     │
│  │ Cost: 400g              [BUY]│    │
│  └────────────────────────────┘      │
│                                      │
│  REPAIR ARMOR  (2/6)  200g  [REPAIR]│
│                                      │
│  BACKPACK                            │
│  ┌────────────────────────────┐      │
│  │ 4x4 grid → 4x5 grid        │     │
│  │ Cost: 600g              [BUY]│    │
│  └────────────────────────────┘      │
│                                      │
│  Gold: 1,240                         │
└──────────────────────────────────────┘
```

---

## Town UI — Lab

```
┌──────────────────────────────────────┐
│            LAB                       │
│                                      │
│  [Research]  [Upgrade]  [Minerals]   │
│                                      │
│  ── RESEARCH (Blueprints) ────────── │
│  ┌────────────────────────────┐      │
│  │ Combat Drone MkII          │      │
│  │ Requires: 5x Obsidian + 800g│     │
│  │ Status: Ready          [BUILD]│   │
│  └────────────────────────────┘      │
│  ┌────────────────────────────┐      │
│  │ Spread Turret (Blueprint)   │     │
│  │ Requires: 3x Crystal + 400g │     │
│  │ Status: Ready          [BUILD]│   │
│  └────────────────────────────┘      │
│                                      │
│  ── MINERALS ─────────────────────── │
│  │ Stored: 🔥x3  ❄️x1  ⚡x2      │  │
│  │ [Extract from ore]              │  │
│  │ [Infuse into ore]              │   │
│                                      │
│  Gold: 1,240  Ore: [inventory]       │
└──────────────────────────────────────┘
```

---

## Town UI — Market

```
┌──────────────────────────────────────┐
│           MARKET                     │
│                                      │
│  ── SELL ORE ─────────────────────── │
│  │ Iron x12        → 120g    [SELL] │
│  │ Crystal x5      → 250g    [SELL] │
│  │ Crystal 🔥 x2   → 340g    [SELL] │
│  │ [SELL ALL]           Total: 710g │
│                                      │
│  ── BUY ──────────────────────────── │
│  │ Battery x1          50g   [BUY] │
│  │ Battery x5         225g   [BUY] │
│  │ Health Potion       100g   [BUY] │
│  │ Repair Kit          150g   [BUY] │
│                                      │
│  Gold: 1,240                        │
└──────────────────────────────────────┘
```

---

## Mine Entrance (Pre-Run)

Shown when entering a mine. Last chance to check loadout.

```
┌──────────────────────────────────────┐
│        ENTER MINE                    │
│                                      │
│  Story Mine: Crystal Depths          │
│                                      │
│  Start from:                         │
│  ○ B1F                               │
│  ○ B5F  (Checkpoint)                 │
│  ● B10F (Checkpoint) ← selected     │
│  ○ B15F (Locked)                     │
│                                      │
│  ── LOADOUT ──────────────────────── │
│  Pickaxe: Steel Pickaxe              │
│  Armor: Chain (6/6)                  │
│  Batteries: 5                        │
│  Backpack: Empty (0/20)              │
│  Consumables: Health Potion x2       │
│                                      │
│  [DESCEND]              [BACK]       │
└──────────────────────────────────────┘
```

### Notes
- Loadout screen to be expanded in future design pass
- Serves as final gear check before committing to a run
- Shows all relevant stats at a glance

---

## Screen List (Complete)

| Screen | When | Pauses Game |
|---|---|---|
| Mining HUD | During mining runs | No |
| Build Menu | Player opens mid-run | Yes |
| Backpack Grid | Player opens mid-run | Yes |
| Smith | Town, talk to Smith NPC | N/A (town) |
| Lab | Town, talk to Lab NPC | N/A (town) |
| Market | Town, talk to Market NPC | N/A (town) |
| Mine Entrance | Entering a mine | N/A (town) |
| Pause Menu | Player pauses | Yes |

## Open Design Questions

- [ ] Exact HUD element sizes and positions
- [ ] Minimap needed? Or floors small enough to not need one?
- [ ] Dialogue UI for NPC conversations
- [ ] Notification/toast system for pickups, achievements
- [ ] Settings menu layout
- [ ] Controller vs keyboard vs touch input layouts
- [ ] Loadout screen expansion (equipment swapping, consumable management)
- [ ] Ore grid shapes for backpack (1x1? Tetris-style?)
- [ ] How build menu shows multiple ore type options for one bot
- [ ] Tutorial/onboarding UI elements
