# Sprint 9 — Procgen Caves + Art Pack Integration

**Sprint goal:** Replace fixed template floors with organically-generated cave layouts that feel mine-like. Replace ColorRect placeholder sprites for the most visible entities with Kenney Roguelike assets.

**Pillars:**
1. **A:** Procgen cave generation (cellular automata)
2. **B:** Kenney asset pack integration (player + ores + tiles)

Pillar A is the bigger design shift. Pillar B depends on Eddie downloading the pack first but is mostly wiring once textures are in place.

---

## Pillar A — Procgen Cave Generation

### A1. Algorithm

Cellular automata (CA) is the canonical choice for organic caves. Deterministic per floor via seeded RNG so the same floor number always yields the same layout.

**Generation pipeline:**
1. **Seed**: `seed = GameManager.current_floor + save_run_seed` (floor consistent across re-entries during a run; varies across runs).
2. **Initialize grid**: `WIDTH × HEIGHT` cells. Each cell starts as wall with probability `WALL_CHANCE` (≈0.45). Border cells always walls.
3. **Iterate (CA smoothing)**: for `ITERATIONS = 4-5` passes, each cell becomes a wall if ≥5 of its 8 neighbors are walls (or if <3 neighbors are walls, to thin isolated floor pockets). Classic "4-5 rule" for caves.
4. **Flood-fill connectivity**: find the largest connected floor component. Any smaller floor pockets get converted to walls (prevents unreachable caves).
5. **Pick spawn / exit**: player spawn = random floor cell in the first quadrant. Exit = random floor cell at max BFS distance from spawn (guarantees a journey).
6. **Ore / enemy spawn zones**: use `floor_generator._spawn_ore_nodes` + `_spawn_enemies`, but restrict placements to floor cells (not walls). Reuse existing density / mineral-ramp logic from Sprint 7 Pillar B.

### A2. Depth-based progression

Tune CA parameters per depth band so floors feel different:

| Depth | WALL_CHANCE | ITERATIONS | Feel |
|---|---|---|---|
| B1-B3 | 0.40 | 4 | Open, easy navigation — starter-friendly |
| B4-B5 | 0.45 | 4 | Standard caves |
| B6+ | 0.50 | 5 | Tighter corridors, more chambers |

Higher WALL_CHANCE + more iterations → tighter walls and more connected chambers. Values are starting points; tune after playtest.

### A3. Floor dimensions

Keep current 1400×1000 world size. CA grid = 70 wide × 50 tall (20px tiles). Wall tiles are 20×20 `StaticBody2D` with `RectangleShape2D`. Floor tiles are pure visual (no collision) — for Pillar A floor is a tinted `ColorRect` background; Pillar B replaces with textured TileMap.

### A4. Template fallback

Keep the 3 existing templates (`Open Arena`, `Two Chambers`, `Cross Corridor`) as ONE option in a new floor-type roll:
- 80% procgen cave
- 20% template floor (set-piece variety)

Set-piece floors break up the organic feel occasionally — keeps player's memory from flattening into "every floor is a blob".

### A5. Performance

CA is cheap. 70×50 grid × 5 iterations = ~17,500 cell evaluations per generation. Under 100ms even on web. Spawning ~3500 wall tile nodes is the real cost — monitor frame hitches. If too slow:
- Merge adjacent wall tiles into larger `StaticBody2D`s (greedy meshing)
- Use one big `TileMap` with collision layer (much faster, recommended if we adopt the Kenney tileset in Pillar B anyway)

Lean toward TileMap from the start if Pillar B lands in the same sprint — it's the right answer architecturally.

### A6. File changes

- `scripts/dungeon/floor_generator.gd` — add `_generate_procgen_cave()` path, restructure `generate()` to dispatch procgen vs template based on roll
- New helper `scripts/util/cave_gen.gd` — pure CA logic, returns a 2D array of booleans (true = wall)
- `scripts/dungeon/mining_floor_controller.gd` — ensure ore/enemy/player spawn points only land on floor cells (use the generated grid as a mask)

---

## Pillar B — Kenney Asset Pack Integration

### B1. Pack to use

[Kenney Roguelike Caves & Dungeons](https://kenney.nl/assets/roguelike-caves-dungeons) (free, CC0) + [Kenney Roguelike RPG Pack](https://kenney.nl/assets/roguelike-rpg-pack) for characters/enemies.

Eddie downloads both, extracts to `c:\Users\MP Crew\mining-game\assets\sprites\kenney\`.

### B2. Pack layout expected

Godot auto-imports PNGs. After extraction, expect a structure like:
```
assets/sprites/kenney/
  roguelike-caves/
    tileset.png  (spritesheet)
    individual/  (optional per-sprite PNGs)
  roguelike-rpg/
    characters/
    enemies/
```

If the pack ships as one big spritesheet, Pillar B gains a small task: define `Rect2` regions to sub-slice the sheet. If individual sprites, we skip that.

### B3. Entities to convert first

Order by visibility:

| Entity | Current | Target |
|---|---|---|
| Player | ColorRect (green 28×28) | Kenney character sprite |
| Walls | ColorRect (grey 20×20) | Kenney cave wall tile |
| Floor | ColorRect (dark background) | Kenney cave floor tile |
| Ores (4 tiers × plain) | ColorRect with tier-tinted colors | Kenney ore sprites (different per tier) |
| Enemies (slime / bat / spider / whatever exists) | ColorRect | Kenney enemy sprites matching our 3 T1 enemies |

**Deferred to Sprint 10+:**
- Bot types (4 + mineralized variants — no clean Kenney match exists)
- Projectiles
- Mineralized ore variants (stay tinted for now)
- HUD icons

### B4. TileMap for walls + floors

Given Pillar A may spawn ~3500 wall tiles, using a Godot `TileMap` node is the right architecture anyway. The tileset resource references the Kenney tile spritesheet with per-tile physics layers for wall collision.

Steps:
1. Create `scenes/dungeon/cave_tileset.tres` pointing to the Kenney tilemap sprite
2. Configure wall tiles with collision shape in the TileSet editor (one-time)
3. `mining_floor_controller` places tiles via `tilemap.set_cell(...)` instead of spawning per-tile nodes

### B5. SpriteUtil update

Existing `scripts/util/sprite_util.gd` supports texture-or-fallback. Extend:
- Add `try_load_texture(path: String) -> Texture2D` helper returning null if missing
- Per-entity paths defined in a central `scripts/util/asset_paths.gd` const map: `{"player": "res://assets/sprites/kenney/.../wizard.png", ...}`
- Each entity's `_ready` / `setup` checks its path in the map, falls back to ColorRect if load fails

This means the game runs even before the pack is installed — paths fail gracefully, ColorRect stays. Safe to ship incrementally.

### B6. Sprite size matching

Kenney tiles are typically 16×16 or 32×32. Current entity sizes are 28×28. Either:
- Scale sprites 2× to approximate current sizes
- Adjust collision shapes to match the new sprite size

Pick "scale 2×" as default — simpler and keeps tile math predictable. Kenney art holds up at 2× integer scaling.

---

## Acceptance Criteria

### Pillar A
- [ ] `cave_gen.gd` generates deterministic cave layouts given a seed
- [ ] Flood-fill ensures single connected floor region (no isolated caves)
- [ ] CA parameters change per depth band (B1-3, B4-5, B6+)
- [ ] Ore and enemy spawns land only on floor cells, not walls
- [ ] Player spawn and exit are on floor, exit placed far from spawn
- [ ] Template floors still appear ~20% of the time as set-pieces
- [ ] Generation completes in <200ms on web

### Pillar B
- [ ] Player sprite uses Kenney character (not ColorRect)
- [ ] Cave walls and floor use Kenney tileset via TileMap
- [ ] At least one ore tier has a textured sprite (rest can fall back)
- [ ] At least one enemy type is textured
- [ ] Game runs cleanly even if the asset folder is missing (ColorRect fallback)
- [ ] No visible "mixed" look — any entity that's still ColorRect should feel intentional, not broken

---

## Out of Scope (Explicit)

- Destructible walls (future sprint — big scope, player mines through tiles)
- Bot sprites (no clean Kenney match; stays ColorRect this sprint)
- Ice/Thunder/Venom on-hit mechanics (D28 — future)
- Merge effect redesign (D18 — future)
- Void mineral drops (D27 — future)
- HUD / button textures (still programmatic)
- Sound effects, music (still deferred)

---

## Risks

- **Pack layout surprise** — Kenney packs are reasonably consistent but the structure after unzip can vary. Pillar B timeline depends on this landing cleanly. If the pack is one atlas that needs slicing, that's 4-6 extra hours for a sub-task.
- **TileMap migration during Pillar A** — if we go TileMap-first, Pillar A depends on Pillar B's tileset being ready. Order matters. **Decision**: Pillar A ships with per-tile `StaticBody2D` (works today), then Pillar B migrates to TileMap. Two passes, but each is independently testable.
- **Enemy pathfinding through caves** — current enemies use simple steering (D9 — flagged as debt). Organic walls may expose the pathfinding gap more than templates did. If enemies get stuck often, playtest will flag it and we budget a mini-fix within the sprint. Worst case, defer enemies off-floor or give them wall ignore.
- **Procgen seeds & save interaction** — if a save system ever lands (D6 deferred), seed storage matters. For now: seed = floor number + session RNG, resets per run. Document this contract in `cave_gen.gd`.
- **Art style mismatch** — ColorRect bots + Kenney walls/player might look weird until bots also get sprites. Mitigate: pick bot ColorRect colors that complement Kenney's palette (muted, not neon).

---

## Delivery Order

1. **Pillar A.1**: `cave_gen.gd` CA helper — pure function, testable in isolation
2. **Pillar A.2**: `floor_generator.gd` integration, procgen-vs-template roll, floor cell masking for spawns
3. **Playtest checkpoint** — confirm caves feel mine-like and connectivity holds
4. **Pillar B.1**: Eddie downloads Kenney packs, extracts to `assets/sprites/kenney/`
5. **Pillar B.2**: `asset_paths.gd` constants + `SpriteUtil` fallback wiring
6. **Pillar B.3**: Player sprite conversion (canary entity — if this works, the pattern holds)
7. **Pillar B.4**: TileMap migration for walls/floor (also supersedes Pillar A's per-tile StaticBody2D)
8. **Pillar B.5**: Ore + enemy sprite wiring
9. **Playtest checkpoint** — visual pass, confirm mixed ColorRect+sprite look is tolerable
10. **Sprint review**

Commit per step per Sprint 7/8 discipline. Version bumps: `v0.9.0a` after Pillar A lands, `v0.9.0b` after Pillar B.
