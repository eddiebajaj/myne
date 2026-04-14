# Sprint 5 — Economy Rework + Minimal Art Pass

**Sprint goal:** Replace the battery/disposable bot system with Crystal Power + Lab bot hub. Validate the art pipeline with AI-generated pixel art sprites for key entities.

**Themes:** 2 paths, delivered in order:

1. **Path A (must-have):** Crystal Power economy rework — drop old systems, add new
2. **Path B (nice-to-have):** Minimal pixel art pass using AI-generated sprites

Lesson from Sprint 3: keep scope tight. Path A is non-negotiable; Path B ships if Path A is clean.

---

## Path A — Crystal Power Economy Rework

### A1. Remove old systems

**Delete / disable:**
- Battery system (`Inventory.batteries`, battery crafting at Lab, battery consumption on bot build/merge)
- Disposable bots (`turret`, `mining_rig`, `combat_drone`, `mining_drone` — remove from build menu, can leave the .gd files for now)
- Build menu in the mine (`_open_build_step1` and related in `mining_hud.gd`)
- Battery HUD display
- `BotPlacer` functionality (bot_placer.gd is no longer used in the mine — leave file, remove wiring)

**Keep:**
- `BotBase` (permanent bots still extend it)
- `PermanentBot` (Scout uses this)
- Bot follower arrays (permanent bots only)

### A2. Crystal Power system

Add to `Inventory`:
```gdscript
var crystal_power_capacity: int = 1   # Permanent capacity, upgraded via Lab
var run_party_cp_used: int = 0         # CP consumed by current run_party
```

**Rules:**
- Each permanent bot has a `cp_cost: int` in its data (Scout = 1)
- `run_party` can contain bots whose total `cp_cost` ≤ `crystal_power_capacity`
- If upgrading to 2 CP, player can bring 2 × 1-CP bots, or 1 × 2-CP bot
- Party selection happens at mine entrance (loadout screen)

### A3. Merge charges

Replace battery-costs-merge with charge system.

Add to `Inventory`:
```gdscript
var merge_charges_max: int = 1   # Charges available per run (upgraded)
var merge_charges: int = 1       # Current remaining this run
```

Update merge execution in `mining_hud.gd`:
- Check `Inventory.merge_charges > 0` instead of `Inventory.batteries > 0`
- Consume a charge (not a battery) on merge
- Reset `merge_charges = merge_charges_max` at run start (in `Inventory.begin_run()`)
- 30-second cooldown between merges (track in mining_hud, prevent merge button during cooldown)

### A4. Lab rework (bot hub)

Update `scripts/town/npc_lab.gd` to offer new services:

**Lab menu options:**
1. **Build Bot** — spend ore + gold to construct a companion from a blueprint
   - Blueprint list (Scout available from start)
   - Shows cost (ore + gold)
   - Adds to `Inventory.permanent_bots` on purchase
2. **Upgrade Bots** — per-bot stat upgrades (HP, damage, attack speed)
3. **Upgrade Necklace** — increase `crystal_power_capacity` by 1 (scaling cost)
4. **Upgrade Merge** — increase `merge_charges_max` by 1 (scaling cost)
5. **Close**

Each option opens a sub-menu. Keep the existing NPC menu pattern (pause game, focus first button, B to close).

### A5. Scout becomes buildable

Change Scout from "unlocked at B5F" to "blueprint available from start, build at Lab."

Scout blueprint:
- Cost: 20 ore (any T1) + 100 gold
- Builds 1 Scout, adds to `permanent_bots`

Remove the "first B5F checkpoint unlocks Scout" logic from `game_manager.gd`. Remove the unlock popup from `town.gd`.

The first run, player has no bots — they mine, sell ore, save up, then buy a Scout at the Lab.

### A6. Party selection UI

Add party selection to mine entrance panel (already exists from Sprint 2b):
- Show permanent_bots list with checkboxes
- Player selects up to `crystal_power_capacity` worth of bots
- Selection persists via `Inventory.run_party`
- "Enter Mine" button starts run with selected party

### A7. Balance values (initial guesses, expect tuning)

| Upgrade | Starting cost | Cost growth |
|---|---|---|
| Build Scout | 20 ore + 100 gold | (blueprint, one-time per bot) |
| Upgrade Scout HP +10 | 15 ore + 150 gold | 1.5x per level, max 5 levels |
| Upgrade Scout damage +1 | 15 ore + 150 gold | 1.5x per level, max 5 levels |
| Necklace CP +1 | 50 ore + 500 gold | 2x per level, max 4 levels (final CP = 5) |
| Merge Charges +1 | 50 ore + 500 gold | 2x per level, max 3 levels (final charges = 4) |

### A8. HUD updates

- Remove battery counter from mining HUD
- Add "Merge Charges: X/Y" to mining HUD
- Remove battery counter from town HUD
- Add CP capacity to town HUD or loadout screen

### Acceptance criteria (Path A)
- [ ] Batteries removed from inventory, HUD, build menu, merge
- [ ] Disposable bots removed from build menu (can't be built in mine)
- [ ] Build menu no longer opens in mine (B button does... something else, maybe nothing for now)
- [ ] Crystal Power capacity starts at 1, stored in Inventory
- [ ] Merge uses charges, consumes 1 per merge, resets on run start
- [ ] 30s cooldown between merges
- [ ] Lab offers: Build Bot, Upgrade Bots, Upgrade Necklace, Upgrade Merge
- [ ] Scout buildable at Lab for 20 ore + 100 gold
- [ ] Party selection at mine entrance, limited by CP
- [ ] First-run flow: no bot → mine → earn gold → buy Scout → come back with party

---

## Path B — Minimal Art Pass (if Path A ships clean)

### B1. Art pipeline setup

Create the infrastructure for sprite-based entities, designed for easy replacement when Eddie gets an asset pack from itch.

**Structure:**
```
resources/
└── sprites/
    ├── player/
    │   └── player.png (32x32)
    ├── enemies/
    │   ├── cave_beetle.png
    │   └── crystal_mite.png
    ├── bots/
    │   └── scout.png
    ├── ores/
    │   ├── iron.png
    │   └── copper.png
    └── environment/
        ├── wall.png
        └── floor.png
```

**Code pattern:**
Replace `ColorRect` with `Sprite2D` + a `@export var texture: Texture2D`. The code loads the texture from a path constant at the top of the file, making it easy to swap:

```gdscript
const TEXTURE_PATH := "res://resources/sprites/player/player.png"
```

When Eddie swaps in asset pack sprites, just change the path or drop in new files with the same names.

### B2. AI-generated sprites (Eddie's task)

PO provides prompts, Eddie generates the sprites using his AI tool of choice (Scenario, Retro Diffusion, Leonardo, etc.).

**Minimum sprite set:**
1. Player (Myne) — 32x32, miner girl with pickaxe, Binding of Isaac style, top-down view
2. Scout companion — 32x32, small crystalline robot, cyan color, floating
3. Cave Beetle enemy — 32x32, brown armored beetle, aggressive stance
4. Crystal Mite enemy — 32x32, glowing pink/blue crystal creature
5. Iron ore node — 32x32, gray metallic rock cluster
6. Copper ore node — 32x32, orange-brown metallic rock cluster

All sprites: pixel art, 32x32 resolution, top-down view, transparent background, Binding of Isaac reference for silhouette/readability.

### B3. Integration

Code agent tasks (after Eddie provides sprites):
- Replace `ColorRect` with `Sprite2D` in entity scene generators
- Wire up `TEXTURE_PATH` constants for each entity type
- Verify sprite scaling/centering matches old ColorRect hitboxes
- Keep health bars, labels, and UI elements — only the main visual changes

### Acceptance criteria (Path B)
- [ ] Sprite resource structure created under `resources/sprites/`
- [ ] All 6 minimum sprites generated and placed in correct paths
- [ ] Player, Scout, Cave Beetle, Crystal Mite, Iron, Copper display as sprites in-game
- [ ] ColorRect fallback preserved (if texture missing, show colored rect)
- [ ] Swap-in path documented in README or spec for future asset pack drop

---

## Out of Scope (Explicit)

- Save system (Eddie's call: fun first)
- Dual merge (Sprint 6+)
- Second permanent bot (Guardian, etc.) — Sprint 6
- T2 content (B6F-B10F balance) — Sprint 6
- Full art pass (all enemies, all bots, full environment tiles) — Sprint 6
- Story beats beyond Scout availability
- Sidequests
- Rare blueprints from progression (Sprint 6)

---

## Delivery Order

1. **Path A first** — clean implementation, playtest
2. **Path B prep** — PO writes sprite prompts, Eddie generates sprites
3. **Path B integration** — code agent swaps ColorRect → Sprite2D
4. **Sprint review**

Playtest checkpoints after Path A completes AND after Path B integrates.

---

## Risk Notes

- **Scope creep is the Sprint 3 failure mode.** If Path A drags on with bugs, Path B drops. Don't chain them tightly.
- **Lab UI complexity.** Four sub-menus (build, upgrade bot, upgrade necklace, upgrade merge) is a lot. Keep each sub-menu simple.
- **Party selection is new UI.** Test it on mobile — can't have the same input issues as the backpack saga.
- **Art replacement.** Document the swap-in path clearly so Eddie can drop in asset pack files without code changes.
