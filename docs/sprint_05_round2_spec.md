# Sprint 5 Round 2 — Starter Bots, Blueprints, Storage, Merge Gating

**Context:** Path A (Crystal Power economy rework) shipped. Playtesting revealed friction — 20 ore Scout cost + 16 slot backpack = can't buy Scout on first run. Also, only one bot (Scout) = no variety. This round addresses both.

---

## 1. Starter bots (buildable from start, no blueprint needed)

All starter bots: **10 ore only (no gold), 1 CP cost.**

### Miner
| Stat | Value |
|---|---|
| HP | 20 |
| Damage | 0 (non-combat) |
| Mining range | 80 px |
| Mining rate | 1.5s per hit |
| Move speed | 100 |
| Follow distance | 50 |
| Role | Auto-mines nearby ore nodes while following player |

AI: Follows player. Every 1.5s, finds nearest ore node within 80px and hits it once (same effect as pickaxe on ore).

### Striker
| Stat | Value |
|---|---|
| HP | 25 (fragile) |
| Damage | 8 (high) |
| Attack range | 45 px (melee) |
| Attack speed | 0.8/s |
| Move speed | 110 |
| Follow distance | 50 |
| Role | High-damage glass cannon |

AI: Follows player when idle. Targets nearest enemy within 45px. Moves to melee range and attacks. No projectile — damage applied on contact (same pattern as current Combat Drone but at melee range).

### Backpack Bot
| Stat | Value |
|---|---|
| HP | 15 |
| Damage | 0 |
| Move speed | 100 |
| Follow distance | 50 |
| Passive | +8 backpack slots while in run_party (and alive/not knocked out) |
| Role | Capacity boost for bigger hauls |

Passive implementation: `Inventory.get_max_capacity()` checks if Backpack bot is in run_party AND not knocked out. Adds 8 to the base capacity. When knocked out mid-run, capacity reverts mid-run (this might cause ore to overflow — see section 1.1).

**1.1. Overflow handling when Backpack bot knocked out:**
If player has more ore than new capacity (bot died mid-run), excess ore stays in inventory but `is_full()` returns true until excess is dropped/sold/used. Same as the existing "full backpack" handling.

---

## 2. Blueprint system

### Data
- `Inventory.blueprints: Array[String]` — already exists, use it
- Each blueprint = bot id. If bot id is in blueprints OR is a starter, Lab offers it.

### Starter bots
`const STARTER_BOTS = ["miner", "striker", "backpack_bot"]` — always available regardless of blueprints.

### Blueprint drop
- **Scout blueprint** drops at B4 (first time). Floor 4 triggers a guaranteed blueprint spawn.
- Drop is a visible item on the floor (purple glowing ColorRect, 16x16, bounces gently).
- Walking over it auto-pickups, adds "scout" to Inventory.blueprints, plays pickup popup: "Scout Blueprint!"
- Only drops if blueprint not already owned.

### Lab integration
- Build Bot view lists all available bots:
  - Always: Miner, Striker, Backpack Bot
  - Conditional: Scout (if "scout" in blueprints)
- Hide bots the player already owns in permanent_bots (or show "owned" greyed out).

### Cost uniformity
All bots cost **10 ore**. No gold. Same as Eddie's decision: "no special treatment for now, since every bot can merge anyway."

---

## 3. Merge gating at B5F

### Unlock
- Add `Inventory.merge_unlocked: bool = false`
- On first B5F reach: set true, emit unlock popup "Merge Unlocked! Press X to transform with your bot."
- GameManager tracks `merge_unlock_notified` flag so popup only shows once.

### Enforcement
- In mining_hud `_on_touch_x`: if `not Inventory.merge_unlocked`, show "Merge locked until B5F" warning, return.
- Same check in `_process` X keyboard fallback.
- X button panel simply doesn't open.

### Lab merge upgrades
- Keep the "Upgrade Merge" option in Lab regardless of unlock state (let player invest early).
- But only useful after unlock.

---

## 4. Storage Shed

### Town integration
- New interactable in the town scene — a "Storage Shed" building near the other NPCs.
- Use same pattern as existing NPCs: proximity detection, action_a / interact to open menu.
- Panel design: scrollable grid of stored ore types with quantities.

### Storage data
Add to `Inventory`:
```gdscript
var storage: Array[Dictionary] = []  # Same format as carried_ore
const STORAGE_CAPACITY: int = 48  # slots (3x backpack for now)
```

### Storage UI
Two-column layout:
- Left: Backpack contents (ore + quantities, readonly here)
- Right: Storage contents (ore + quantities)
- Middle buttons:
  - **Deposit All** → moves everything from backpack to storage (respects storage capacity)
  - **Withdraw One (per ore type)** → small button next to each stored ore type, moves 1 to backpack if backpack has space
  - **Close**

### Capacity
- Storage holds 48 total ore pieces across all ore types.
- Persistent across runs (not cleared on return/death).
- If deposit would exceed capacity, deposit fills what fits and leaves excess in backpack.

### Lab combined check
When Lab checks "can afford X ore":
- Count = `Inventory.count_plain_t1_ore()` (backpack) + equivalent function for storage
- When spending: spend from storage first, then backpack (preserves backpack for active use)
- New method: `Inventory.spend_plain_t1_ore_from_any(amount) -> bool`

---

## 5. Balance summary

| Item | Cost | Notes |
|---|---|---|
| Miner | 10 ore | Starter, mining support |
| Striker | 10 ore | Starter, glass cannon melee |
| Backpack Bot | 10 ore | Starter, +8 slots passive |
| Scout | 10 ore (after B4 blueprint) | Ranged combat support |
| Necklace upgrade | 50 ore + 500 gold, 2x per level | Max 4 levels (CP=5) |
| Merge upgrade | 50 ore + 500 gold, 2x per level | Max 3 levels (charges=4) |
| Bot HP upgrade | 15 ore + 150 gold, 1.5x per level | Max 5 levels |
| Bot damage upgrade | 15 ore + 150 gold, 1.5x per level | Max 5 levels |

---

## 6. Acceptance criteria

### Starter bots
- [ ] Miner, Striker, Backpack Bot visible in Lab Build Bot view from game start
- [ ] Each builds for 10 ore, no gold
- [ ] Miner auto-mines nearby ore nodes while following
- [ ] Striker melee-attacks enemies with 8 damage
- [ ] Backpack Bot grants +8 slots while in run_party

### Blueprint system
- [ ] Scout blueprint drops at B4 on first visit
- [ ] Blueprint pickup adds "scout" to Inventory.blueprints
- [ ] Scout appears in Lab Build Bot view only after blueprint pickup
- [ ] Scout costs 10 ore once unlocked

### Merge gating
- [ ] X button does nothing until first B5F reach
- [ ] Unlock popup shows on first B5F reach
- [ ] After unlock, merge works as before

### Storage Shed
- [ ] New interactable in town (visible building)
- [ ] Panel shows backpack + storage side by side
- [ ] Deposit All, Withdraw (per type), Close buttons work
- [ ] 48-slot capacity enforced
- [ ] Storage persists across runs
- [ ] Lab purchases spend from storage first, then backpack

---

## 7. Out of scope (explicit)

- Storage tabs / tab upgrades (Sprint 6+)
- Tetris-like backpack shapes (Sprint 6+)
- Rare bot blueprints beyond Scout (Sprint 6+)
- Bot upgrade details UI polish (Lab views are functional, visual polish later)
- Storage grid UI with tetris shapes (plain list for now)

---

## 8. Risks

- **Scope:** 4 new bot types + blueprint system + storage + merge gating in one round. Tight but doable given Path A landed clean.
- **Blueprint drop placement:** Spec says "guaranteed on B4." Need to ensure floor_generator places it somewhere reachable.
- **Backpack bot knockout capacity:** handle cleanly — don't crash if player's carrying more than new cap.
- **Storage UI on mobile:** follow the backpack panel pattern (in-scene, not autoload).
