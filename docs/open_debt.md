# Open Debt Tracker

Carried forward each sprint. Items are added when deferred, removed when resolved.

---

## Active Debt

| ID | Debt | Origin | Priority | Notes |
|---|---|---|---|---|
| D1 | `_random_enemy()` aggro/leash gap at T2-T4 | Sprint 2 | Medium | T1 patched, T2-T4 still use defaults |
| D2 | Dead code `_spawn_loot()` in `cave_entrance.gd` | Sprint 2 | Low | Cleanup candidate |
| D3 | `Player._apply_upgrades()` armor sync fragility | Sprint 2 | Watch | Harmless today, fragile if Smith logic forks |
| D4 | Design T2 balance values (B6F-B10F) | Sprint 1 | High | Only T1 is tuned |
| D5 | Mineral effect multipliers per type | Sprint 1 | Medium | Fire=damage, Ice=slow, etc. — designed not implemented |
| D6 | Save system (3 manual + 1 auto) | Sprint 1 | Low | Deferred — fun first, persistence later (Eddie's call) |
| D7 | Dual merge system (2 bots upper+lower) | Sprint 1 | Medium | Solo merge done (Sprint 4). Dual merge = Sprint 6+ |
| D8 | Story/narrative wiring | Sprint 1 | Medium | Letters, NPC dialogue, story gates |
| D9 | Enemy pathfinding around interior walls | Sprint 3 | Medium | Enemies may get stuck on template walls |
| D10 | Pixel art production | Sprint 4 | Medium | Infrastructure ready (Sprint 5). Sprites deferred — needs paid tool or asset pack |
| D11 | BackpackPanel autoload is dead code in mine | Sprint 3 | Low | Still registered, may be used in town |
| D12 | Town scene input/UI overhaul | Sprint 3 | Medium | Town still uses old input patterns |
| D17 | Bot balance tuning | Sprint 5 | Medium | Ranges, HP, damage — Eddie noted but deferred ("keep B as is") |
| D18 | Merge effect redesign per-bot | Sprint 5 | Medium | Eddie flagged "merge effect will be different than what you listed" |
| D19 | Tetris-like backpack shapes | Sprint 5 | Medium | Eddie mentioned as upcoming |
| D20 | Storage tabs / upgrade path | Sprint 5 | Low | Once base 48 slots fill up |
| D21 | Rare bot blueprints (Guardian, Healer, Amplifier) | Sprint 5 | Medium | Need progression gates |
| D23 | Backpack grid navigation | Sprint 6 | Low | Deferred until tetris-like rework |
| D24 | Bot rename UI | Sprint 7 | Low | Auto-numbering for now ("Scout #1") |
| D25 | Sound effects (negative SFX, hit feedback) | Sprint 6 | Low | Future polish |
| D26 | Hard material recipe balance | Sprint 7 | Medium | Values feel right at B1-B3, untested at depth or with multiple builds/run |
| D27 | Void mineral never drops | Sprint 7 | Low | Not in `MineralData.get_all_minerals()`. Build-time data flow ready; activates when drops wired |
| D28 | Ice/Thunder/Venom on-hit mechanics | Sprint 7 | Medium | Counts stored as bot meta; no runtime hit code consumes them yet |
| D29 | Market tab conversion | Sprint 8 | Low | Deferred — no Buy flow exists yet. Revisit when Trader NPC or Buy content designed |
| D30 | Legacy upgraded-bot stat drift | Sprint 8 | Low | Migration collapses `hp_upgrade_level`/`damage_upgrade_level` into `upgrade_level` via max-of-the-two. Stats may shift slightly for bots upgraded in Sprint 5-6 |
| D31 | TileMap migration for walls/floor | Sprint 9 | Medium | Sprint 9 pragmatic path kept per-tile `StaticBody2D` + Sprite2D. TileMapLayer would batch ~3500 bodies into one physics body + aggregated collision. ~3-4 hours: create TileSet .tres, rewrite `_spawn_procgen_walls`, verify collision behavior |
| D32 | Backpack UI ore sprites | Sprint 9 | Low | Backpack grid cells still use StyleBoxFlat.bg_color from ore.color. World ore nodes converted to Kenney sprites in Pillar B.4; UI cells need TextureRect replacement |

## Resolved (Sprint 8)

| ID | Debt | Resolved In | How |
|---|---|---|---|
| D22 | Bot upgrades via crafting mechanic (C3) | Sprint 8 | Upgrade tab with recipe grid, escalating thresholds, 1x hard materials |
| — | Lab UI finalization (tabbed layout) | Sprint 8 | 5-tab horizontal TabBar with shoulder-button nav |
| — | Scrap owned bots | Sprint 8 | Scrap tab with 50% point refund, greedy hard-material packing |
| — | Backpack panel UX pass | Sprint 8 | Ores/Bots/Artifacts tabs |
| — | Town Storage UX pass | Sprint 8 | Deposit/Withdraw tabs, per-row focus preservation |
| — | Version visibility | Sprint 8 | `v0.8.0a` label bottom-right via `GameVersion` autoload |
| — | CI auto-build on push | Sprint 8 | Restored `push: main` trigger alongside `workflow_dispatch` |
| — | Stat compounding bug | Sprint 8 | Added immutable `base_max_health`/`base_damage` fields |
| — | Focus loss on add/remove (post-Sprint-8 regression) | Sprint 8 | `await get_tree().process_frame` before `grab_focus` — fixes `queue_free` tree-exit race |
| — | Tab nav via joystick accidents | Sprint 8 | Moved to dedicated `tab_prev`/`tab_next` (Q/E + LB/RB) |

## Resolved (Sprint 7)

| ID | Debt | Resolved In | How |
|---|---|---|---|
| — | Build-your-own-bot crafting (C1) | Sprint 7 | Point system + recipe UI + multi-instance bots |
| — | Mineral spawn rate ramp (C2) | Sprint 7 | 5/15/25% by floor depth |
| — | Multi-instance permanent bots | Sprint 7 | Auto-numbered (Scout #1, Scout #2) |
| — | Market sell-from-storage | Sprint 7 | Two-column manual selection UI |
| — | Sub-menu focus loss on view transition | Sprint 7 | `is_queued_for_deletion()` filter |
| — | Focus loss on add/remove in crafting | Sprint 7 | Index save/restore across rebuild |
| — | Hard material per-bot identity | Sprint 7 | Iron/Copper/Crystal requirements per bot |

## Resolved (Sprint 5)

| ID | Debt | Resolved In | How |
|---|---|---|---|
| D13 | Economy rework (Crystal Power, remove batteries) | Sprint 5 | Path A |
| D14 | Lab rework as bot hub | Sprint 5 | Path A |
| D15 | Blueprint progression system | Sprint 5 | Round 2 (Scout via B4 drop) |
| — | Town storage for cross-run ore | Sprint 5 | Storage Shed (48 slots) |
| — | Starter bot variety | Sprint 5 | Miner + Striker + Backpack Bot |
| — | Merge unlock as progression beat | Sprint 5 | B5F unlock + popup |
| — | Art pipeline infrastructure | Sprint 5 | SpriteUtil + ColorRect fallback |

## Resolved (Sprint 3)

| ID | Debt | Resolved In | How |
|---|---|---|---|
| — | Floor templates (1400×1000 + 3 layouts) | Sprint 3 | Implemented per spec |
| — | Build menu not opening | Sprint 3 | Fixed input handling |
| — | Mining Rig attack_speed=0 | Sprint 3 | Set to 1.0 |
| — | Follower bots not respawning across floors | Sprint 3 | Added `_respawn_follower_bots()` |
| — | Bot health storage wrong property | Sprint 3 | `get_scaled_health(ore_tier)` |
| — | selected_bot null from closure capture | Sprint 3 | Captured by value before close |
| — | Touch input unreliable (Input.action_press) | Sprint 3 | InputEventAction via parse_input_event |
| — | D-pad replaced with virtual joystick | Sprint 3 | Console A/B/Y layout |
| — | Backpack autoload broken on web | Sprint 3 | Rebuilt UI in-scene inside MiningHUD |
