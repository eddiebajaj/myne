# Research: 2D -> 3D Migration Feasibility (Godot 4.2, Web + Mobile Web)

**Author:** Tech Agent (research only, no code changes)
**Date:** 2026-04-11
**Status:** Decision input for Eddie

---

## Executive Summary

Migrating Mining Game from 2D to 3D in Godot 4.2 is **technically possible but strategically a trap** for this project's targets (HTML5 + mobile web). Godot 4's web export is locked to the GL Compatibility renderer (WebGL 2.0), which supports 3D but with a known history of mobile-browser performance and correctness issues — especially on mobile Safari. Recommendation: **stay 2D, invest the equivalent effort in art, shaders, and fake-depth techniques** that deliver 80% of the "3D feel" at 10% of the cost and zero platform risk.

---

## 1. Godot 4.2 3D Web Export — Reality Check

| Aspect | Status |
|---|---|
| Renderer on web | GL Compatibility only (WebGL 2.0). Forward+ and Mobile renderers require Vulkan/Metal and are **not available on web**. |
| WebGPU support | Not in 4.2. Being discussed for Godot 5 / future. Not a near-term bail-out. |
| 3D in GL Compatibility | Works, but is "least advanced" path. Several 3D features are missing or buggy vs Forward+ (shadows, GI, decals, some post-fx). |
| Mobile Safari (iOS) | WebGL 2.0 support exists but has **well-documented correctness issues** other browsers don't have. Docs explicitly recommend Chromium/Firefox for dev. |
| Mobile Chrome (Android) | Generally OK for 2D, variable for 3D. Post-4.4 regressions reported on Android (60 -> ~45 fps on unchanged 3D scenes). |
| itch.io HTML5 hosting | Unchanged — same deploy pipeline works for 2D or 3D builds. |

**Bottom line:** You can ship a 3D Godot game to HTML5, but you are on the engine's least-supported rendering path on its least-supported deploy target, with an iOS Safari wildcard you cannot fully control.

---

## 2. Mobile Web Performance For Our Entity Count

Target scene budget (per current design): player + ~10 enemies + ~10 ore nodes + ~5 bots + particles + walls = **~30–50 dynamic nodes** per floor. That is small.

What the research says:

- Simple 3D Godot scenes on low-end Android phones report **20–40 fps in-browser**, not 60.
- Tonemapping alone has been measured eating enough GPU budget to cap scenes below 55 fps even with resolution scaling.
- Godot's Compatibility renderer is explicitly the low-end path — it **can** handle our entity count, but every 3D feature you add (real shadows, dynamic lights, post-fx) burns into a narrow budget.
- Mobile Safari has periodic WebGL 2.0 issues that can cause correctness (not just perf) problems. No fix path except "wait for Apple".

Verdict: **our entity count is not the problem.** The problem is that 3D on mobile-browser-Safari is a coin flip regardless of how many entities you have, and the margin for error is thin. In 2D, the same scene runs at 60 fps on a potato.

---

## 3. Migration Cost — What's Reusable vs. Rewrite

Current codebase snapshot:
- **30** `.gd` files, **~22** of them touch 2D-specific APIs (Vector2, Node2D/Body2D/Area2D, CollisionShape2D, ColorRect, Sprite2D).
- **262** individual references to 2D nodes/types across those files.
- **4** `.tscn` scenes (most scene-building is done programmatically in `floor_generator.gd` — which is actually good for migration).

### Reusability breakdown

| Layer | Reusable as-is | Needs rewrite | Notes |
|---|---|---|---|
| Game design / balance data (ore tables, enemy stats, upgrade values) | 100% | 0% | Pure data. |
| `GameManager`, `Inventory` autoloads | ~95% | 5% | Only spatial assumptions leak in. |
| UI (HUD, menus, touch controls) | ~90% | 10% | `Control` nodes are 2D in both worlds; touch controls keep working. |
| Resource definitions (`OreData`, `EnemyData`, `MineralData`) | ~90% | 10% | Add a mesh/material hook. |
| Gameplay logic (damage, pickaxe swing, wave spawning, rock loot tables) | ~70% | 30% | Logic survives; the *hooks* into transforms change. |
| Scene/physics layer (player, enemies, bots, ore nodes, rocks, stairs, walls, floor_generator) | ~10% | 90% | Every `Vector2`, `StaticBody2D`, `Area2D`, `CharacterBody2D`, `ColorRect`, `position`, `move_and_slide`, collision layer, area overlap query, mouse/tap hit-testing, camera. |
| Art (ColorRect placeholders) | 0% | 100% | By definition — no 2D placeholder art translates. |

**Rough aggregate:** **~40–50% of the code survives logically, ~50–60% needs rewrite or heavy edit.** Every gameplay script that does movement, spawning, hit-testing, or camera work has to be re-plumbed. Plus: Y-axis flip (2D Y-down vs 3D Y-up), camera-relative input math, collision layers re-declared for 3D physics server.

### Sprint-count estimate

- **Time to hit current 2D parity in 3D, placeholder art:** ~3–5 sprints (get player walking, mine ore, spawn enemies, bots working, one floor, portal, rocks, stairs). Optimistic because the scene-building is programmatic.
- **Time to hit shippable 3D quality (real meshes, materials, lighting, mobile-web-verified):** **+4–8 more sprints.** Art pipeline is the long tail.
- **Total: 7–13 sprints** to be roughly where we already are today, minus polish.
- **Opportunity cost:** that same 7–13 sprints in 2D gets us a full art pass, 2–3 new mine biomes, expanded bot roster, the full mineral system, and probably a second tier of content.

---

## 4. Art Pipeline — The Real Cost

We're currently shipping `ColorRect` placeholders. The *minimum* that makes 3D feel like an upgrade over 2D placeholders:

1. **Primitive-only (boxes + spheres with materials):** free, looks like a grey-box prototype, arguably *worse* than colored 2D rectangles because depth cues highlight the lack of detail. **Not viable as a visual selling point** — defeats the purpose of the migration.
2. **Kenney / free asset packs (Mini Dungeon, Mini Characters, Prototype Textures):** free, CC0, usable, gets to "early-access indie" look with maybe 1–2 sprints of integration. Realistic minimum.
3. **Custom low-poly (Blender) + PBR materials:** 3–6 sprints for a consistent style across player, enemies, bots, ores, environment. This is the real "3D looks great" scenario.
4. **Rigged/animated characters:** add another 2–4 sprints. Without animation, 3D characters look worse than 2D ones because the eye expects movement.

Our current 2D art pipeline is: "pick a Color, set a ColorRect." Moving to 3D means we need an *actual art pipeline*, an *actual artist workflow*, and an *actual asset review loop*. That is a category change, not a parameter change.

---

## 5. Touch / Input — Translating gui_input To 3D

Current setup (per `touch_controls.gd` and project memory):
- Touch joystick is a `Control` with `gui_input` — fully 2D overlay.
- `mine` is now a keyboard/`Space` action.
- Player reads `Input.get_axis("move_left","move_right")` etc. and pipes straight into `Vector2` velocity.

In 3D:
- The `Control`-based touch UI **keeps working unchanged** — Godot UI is always 2D overlay. Win.
- The input axis -> movement bridge needs camera-relative math: `direction = (camera.basis.x * input.x + camera.basis.z * input.y)` projected to XZ plane. Easy but has to be done everywhere the player/bots/enemies read input.
- **Tap-to-interact** (e.g. "tap this ore node") moves from `Area2D._input_event` to `Camera3D.project_ray_normal` + physics raycast. More code, more edge cases, but standard.
- Top-down fixed camera keeps the interaction model mostly the same — nobody needs to rotate a 3D camera with their thumb.

Input layer cost: **low-to-medium**. This is not where the migration dies.

---

## 6. Top 5 Risks Specific To This Project

1. **Mobile Safari iOS correctness bugs in WebGL 2.0.** We cannot test-fix our way out of Apple's rendering stack. A correctness bug on iOS Safari could silently brick the primary deploy target mid-development, and our only remedy is "wait for Apple" or "tell players to use a different browser" (which they won't).
2. **Performance cliff on mid-tier Android phones in-browser.** Our entity count is fine on paper, but Godot 4 post-compat-renderer optimizations have been **regressing**, not improving, on Android. We'd be betting on the engine getting better, not worse, and the trendline is ambiguous.
3. **Art pipeline shock.** The team currently ships features in hours using ColorRect. Moving to even Kenney asset integration is a culture shift — every new feature now has an art dependency. Sprint throughput drops by a factor we haven't measured.
4. **Top-down 3D often looks worse than top-down 2D.** Diablo/Spelunky/Chocobo's Dungeon vibe is mostly about readable silhouettes and clear ground-plane feedback. A 3D top-down with placeholder meshes and no shadows reads as muddy and less legible than strong 2D sprites. We'd be trading known-good readability for hypothetical future polish.
5. **Scope creep from "now that it's 3D...".** Once in 3D, the team will want dynamic lights (no — breaks compat renderer budget), real shadows (expensive on mobile web), particles (GPU particles are partly broken on GL Compatibility), physics-driven ore (expensive). Every "cool 3D thing" has a footnote. The list of "we can't do that because compat renderer" is long and demoralizing.

---

## 7. Alternatives — "3D-ish Feel" With 2D Techniques

Fully stays in our working pipeline, zero platform risk:

| Technique | Cost | Payoff |
|---|---|---|
| **Normal-mapped 2D sprites + CanvasItem lights** | Low | Sprites react to torch light on the player; huge atmosphere boost. Works on compat renderer. |
| **Parallax ground layers + drop shadows** | Low | Reads as "depth" without being 3D. Spelunky does this. |
| **Shader-based fake volumetrics** (cave fog, god rays) | Medium | Big "wow" per line of shader code. |
| **Isometric / oblique projection 2D tiles** | Medium | If Eddie wants a more spatial look without leaving 2D, this is the ~50% option. |
| **Screen shake, chromatic aberration, bloom on 2D** | Low | "Juicy 2D" beats "flat 3D" every single time on web. |
| **Real art pass on ColorRects** (pixel art or vector) | Medium-High | The actual highest-ROI upgrade. Nothing about "better visuals" requires 3D. |

Every one of these can ship in the current pipeline today. Combined, they produce a game that looks *better* on mobile web than a placeholder 3D port would, at a fraction of the sprint cost.

---

## Pros & Cons Table

| | 2D (stay) | 3D (migrate) |
|---|---|---|
| Renderer risk on web | None (2D is Godot's strongest web path) | GL Compatibility only; Safari wildcard |
| Mobile web perf headroom | Massive | Thin, trendline uncertain |
| Code reuse | 100% | ~40–50% |
| Art pipeline | ColorRect -> pixel/vector (known path) | Needs full 3D asset pipeline + artist workflow |
| Time to parity | 0 sprints (we're there) | 7–13 sprints |
| Depth perception in caves | Faked via shaders/lighting | Real but expensive on our target |
| Future polish ceiling | Medium-high with effort | Theoretically higher, practically capped by compat renderer |
| Top-down readability | Strong (sprites have clear silhouettes) | Risky (grey-box meshes muddy) |
| Team velocity impact | Unchanged | Significant drop during + after migration |
| Differentiation | Juicy 2D is a valid style in 2026 | "3D indie mining game" is a crowded space |

---

## Cost Estimate Summary

| Path | Sprints to current-parity | Sprints to shipping quality |
|---|---|---|
| Stay 2D + juice it (shaders, lights, art pass) | 0 | 3–6 |
| Migrate to 3D, Kenney assets | 5–7 | 9–13 |
| Migrate to 3D, custom art | 5–7 | 14–20+ |

---

## Recommendation

**Stay in 2D. Invest the equivalent effort in a real art pass, 2D lighting, shader atmosphere, and fake-depth techniques.** Revisit 3D only when (a) Godot ships WebGPU in stable and (b) we have a dedicated 3D artist on the team.

**Confidence: High (~85%).** The main uncertainty is Eddie's vision — if "3D" is a non-negotiable identity-of-the-game pillar, none of the above matters. But if 3D is being considered as a *polish/visual upgrade path*, the research is unambiguous: the cheaper, lower-risk, better-looking path on our target platforms is "juice the 2D."

The single biggest reason: **our target is mobile web.** Godot's 3D web export is its weakest supported configuration, specifically on the device class most of our players will use. We'd be fighting the engine on every sprint.

---

## Open Questions For Eddie

1. **Is 3D a vision requirement, or a polish wish?** (If vision: ignore this doc; if polish: don't do it.)
2. **Is mobile web still the primary target in 6 months?** If desktop/Steam becomes primary, the calculus flips — Forward+ on desktop makes 3D much more viable.
3. **What's the visual reference?** "Diablo top-down" can absolutely be shipped as 2D with lighting. "Deep Rock Galactic" cannot. Which end of the spectrum?
4. **Do we have budget for a 3D artist, or is the team doing it?** Programmer-art 3D looks worse than programmer-art 2D. Almost always.
5. **How much are we willing to bet on WebGPU landing in Godot within our dev window?** If we plan a 2-year dev cycle, WebGPU might arrive and rescue the mobile-web 3D story. If we plan to ship in 6 months, no.
6. **Would an isometric 2D projection (Chocobo's Dungeon / classic Diablo feel) satisfy the "depth perception in caves" pain point without leaving 2D?**

---

## Sources

- [Exporting for the Web — Godot Engine docs](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)
- [Overview of renderers — Godot](https://trinovantes.github.io/godot-docs/tutorials/rendering/renderers.html)
- [\[TRACKER\] 4.x OpenGL Compatibility renderer issues (godot #66458)](https://github.com/godotengine/godot/issues/66458)
- [Add WebGPU support (godot-proposals #6646)](https://github.com/godotengine/godot-proposals/issues/6646)
- [Looking to the future: WebGPU Renderer Backend for Godot (discussion #4806)](https://github.com/godotengine/godot-proposals/discussions/4806)
- [About Godot 4, Vulkan, GLES3 and GLES2](https://godotengine.org/article/about-godot4-vulkan-gles3-and-gles2/)
- [Poor mobile performance on HTML5 export (godot #58836)](https://github.com/godotengine/godot/issues/58836)
- [Performance on Android devices has decreased significantly (godot #109251)](https://github.com/godotengine/godot/issues/109251)
- [Mobile rendering limitations — Godot docs](https://docs.godotengine.org/en/3.5/tutorials/platform/mobile_rendering_limitations.html)
- [Using CharacterBody2D/3D — Godot docs](https://docs.godotengine.org/en/stable/tutorials/physics/using_character_body_2d.html)
- [Can't convert Vector2 to Vector3 due to y axis differences (godot-proposals #1720)](https://github.com/godotengine/godot-proposals/issues/1720)
