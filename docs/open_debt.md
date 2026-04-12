# Open Debt Tracker

Carried forward each sprint. Items are added when deferred, removed when resolved.

---

## Active Debt

| ID | Debt | Origin | Priority | Notes |
|---|---|---|---|---|
| D1 | `_random_enemy()` aggro/leash gap at T2-T4 | Sprint 2 | Medium | T1 patched in `_make_enemy_data()`, T2-T4 still use defaults with no aggro/leash |
| D2 | Dead code `_spawn_loot()` in `cave_entrance.gd` | Sprint 2 | Low | Cleanup candidate, no functional impact |
| D3 | `Player._apply_upgrades()` armor sync vs GameManager restore | Sprint 2 | Watch | Harmless today, fragile if Smith upgrade logic forks |
| D4 | Design T2 balance values (B6F-B10F) | Sprint 1 | High | Only T1 is tuned; T2 ore/enemies/bots use placeholder values |
| D5 | Mineral effect multipliers per mineral type | Sprint 1 | Medium | Fire=damage, Ice=slow, etc. — designed but not implemented |
| D6 | Save system (3 manual + 1 auto) | Sprint 1 | High | Designed in doc 12, not implemented. Players lose all progress on page close |
| D7 | Permanent bots + merge system | Sprint 1 | High | Designed in doc 10, not implemented. Signature feature |
| D8 | Story/narrative wiring | Sprint 1 | Medium | Letters, NPC dialogue, story gates — designed in doc 11 |
| D9 | Enemy pathfinding around interior walls | Sprint 3 | Medium | Needed for Two Chambers and Cross Corridor templates — enemies may get stuck on walls |
| D10 | 2D juicing (normal maps, CanvasItem lights, shader fog) | Sprint 1 | Low | Visual polish, deferred repeatedly |

## Resolved

| ID | Debt | Resolved In | How |
|---|---|---|---|
| — | Floor templates (1400x1000 + 3 layouts) | Sprint 3 | Implemented per spec |
| — | Build menu not opening (touch + desktop) | Sprint 3 | Changed `_unhandled_input` to `_process` + `Input.is_action_just_pressed` |
| — | Mining Rig attack_speed = 0 (division by zero) | Sprint 3 | Set to 1.0 |
| — | Follower bots not respawning across floors | Sprint 3 | Added `_respawn_follower_bots()` in controller |
| — | Bot health storage using wrong property | Sprint 3 | Changed to `bot.get_scaled_health(ore_tier)` |
