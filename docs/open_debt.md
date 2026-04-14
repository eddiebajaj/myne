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
| D6 | Save system (3 manual + 1 auto) | Sprint 1 | Medium | Deferred — fun first, persistence later (Eddie's call) |
| D7 | Permanent bots + merge system | Sprint 1 | **Partial** | Scout + solo merge done (Sprint 4). Dual merge, roster, Crystal Power rework = Sprint 5 |
| D8 | Story/narrative wiring | Sprint 1 | Medium | Letters, NPC dialogue, story gates |
| D9 | Enemy pathfinding around interior walls | Sprint 3 | Medium | Enemies may get stuck on template walls |
| D10 | 2D juicing (normal maps, lights, shaders) | Sprint 1 | Low | Combat readability done (Sprint 4). Pixel art pass = Sprint 5 |
| D11 | BackpackPanel autoload is dead code in mine | Sprint 3 | Low | Still registered, may be used in town |
| D12 | Town scene input/UI overhaul | Sprint 3 | Medium | Town still uses old input patterns |
| D13 | Economy rework: Crystal Power, remove batteries/disposable bots | Sprint 4 | **High** | Full design locked, implementation = Sprint 5 |
| D14 | Lab rework: bot hub (build, upgrade, necklace, merge) | Sprint 4 | **High** | Design locked, implementation = Sprint 5 |
| D15 | Blueprint progression system | Sprint 4 | High | Common + rare blueprints, story unlocks |
| D16 | Pixel art pass (32x32, Binding of Isaac ref) | Sprint 4 | High | Style locked, production = Sprint 5 |

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
