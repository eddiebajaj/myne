# Sprint 6 — UI Input Parity + Direction Lock

**Sprint goal:** Make every UI navigable with A/B/X/Y/joystick — no tapping required. Then playtest end-to-end and lock game direction before further design changes.

**Pillars:**
1. **A (stable):** Engine-level input mapping — works regardless of future UI redesigns
2. **C (decision):** Full playtest, document what stays / what changes
3. **B (scoped):** Per-panel focus polish — only on panels that won't be redesigned

Deliver A first, then C, then scope B based on C's findings.

---

## Pillar A — Global UI Input Mapping

### A1. Input action mappings (project.godot)

Map existing actions to Godot's built-in UI actions:

```
ui_accept — triggers focused button (mapped to: action_a + Enter + Space)
ui_cancel — closes/backs out (mapped to: action_b + Escape)
ui_up/down/left/right — directional focus movement
```

Godot has built-in `ui_accept`, `ui_cancel`, `ui_up/down/left/right` actions already. We need to:
- Add `action_a` as an additional event for `ui_accept`
- Add `action_b` as an additional event for `ui_cancel`
- Add virtual joystick → `ui_up/down/left/right` (thresholded)
- Keyboard arrows stay as default

### A2. Joystick threshold for UI

When a panel is focused/open, the virtual joystick should emit discrete `ui_up/down/left/right` events instead of continuous movement. Thresholding:

- Deflection > 0.5 in a direction triggers the action (once per "press")
- Release (back below 0.3) arms the next trigger
- Treat each axis independently

When no UI panel is open, joystick continues to drive player movement (current behavior).

Detection: TouchControls can track "is any modal panel open" via a boolean flag set by the HUD/panels. Or simpler: every frame, if joystick deflection crosses the threshold AND a panel is open, emit an InputEventAction for the appropriate direction.

### A3. Focus defaults

All Godot Button nodes have `focus_mode = FOCUS_ALL` by default — verify nothing in the codebase has overridden this.

For panels that open and grab focus, they already call `grab_focus()` on the first button (added in previous sprints). Verify this works for all panels.

### A4. Focus visual

Godot's default focus outline is a dotted blue rectangle — subtle and easy to miss on mobile. Add a custom theme override:

- Brighter border (2px solid cyan or yellow, alpha 0.9)
- Applied globally via a Project theme

Create/update `resources/ui_theme.tres` (or inline override in mining_hud) that sets:
- `Button/styles/focus` — bright bordered StyleBoxFlat

### A5. Focus wrap-around

By default, Godot's focus navigation goes to the first/last button based on layout position. For vertical button lists, pressing down past the last button goes nowhere (no wrap). Add wrap-around behavior:

- When a panel builds its button list, set `focus_next` / `focus_previous` / `focus_neighbor_bottom` / `focus_neighbor_top` on each button to create a cycle
- Last button's `focus_neighbor_bottom` = first button
- First button's `focus_neighbor_top` = last button

This is a per-panel tweak but low-effort if done systematically.

### A6. Panels to wire up

- Lab main menu + all sub-views
- Smith menu
- Market menu
- Mine entrance panel (including party checkboxes + Enter button)
- Build menu (already focus-aware)
- Backpack (requires grid navigation, defer to Pillar B)
- Merge panel
- Storage Shed panel

For each: verify first button grabs focus on open, focus wraps correctly, A triggers focused button, B closes panel.

### Acceptance criteria
- [ ] `action_a` activates focused Button (triggers its `pressed` signal)
- [ ] `action_b` closes any open panel
- [ ] Joystick / arrow keys move focus within a panel
- [ ] Joystick threshold prevents continuous rapid-fire when held
- [ ] All panels auto-focus first button on open
- [ ] Focus indicator is clearly visible (not just dotted outline)
- [ ] Focus wraps around (last → first, first → last)
- [ ] Player movement still works when no panel is open (joystick drives player, not UI)

---

## Pillar C — Playtest + Direction Lock

### C1. Full end-to-end playthrough

User plays a complete session start to finish:
- Fresh start, no bots
- Mine first run solo
- Buy first bot
- Progress through B1-B5+
- Find Scout blueprint
- Unlock merge at B5F
- Test all bot types
- Test all Lab upgrade paths
- Test storage shed, backpack, inspect popups

### C2. Direction lock document

PO writes `docs/direction_lock_sprint_6.md` capturing:

- **Keep as-is:** mechanics/UI that feel right
- **Tune:** numbers that need adjustment (bot stats, drop rates, costs)
- **Redesign:** UI/flows that need rework (crafting UI, etc.)
- **Remove:** anything that's dead weight or confusing

This becomes the input for subsequent sprint planning.

### C3. Issue list

Any bugs found during playtest go into a quick-fix list. Tech agent fixes critical ones; minor issues queue for future sprint.

### Acceptance criteria
- [ ] Full playthrough completed by user
- [ ] Direction lock document written and committed
- [ ] Issue list created with priorities

---

## Pillar B — Per-Panel Focus Polish (scoped after C)

After C identifies which panels will be redesigned, Pillar B polishes only the panels that are staying:

### B1. Backpack grid navigation
- 4x4 cell grid
- Directional navigation moves focus between cells
- A on a cell opens inspect popup (not drop directly — existing behavior)
- Inspect popup has its own focus (Drop/Close buttons)

### B2. Party selection in mine entrance
- Checkboxes navigable with directions
- A toggles focused checkbox
- Tab to "Enter Mine" button

### B3. Storage Shed
- Two-column layout (backpack | storage)
- Directional navigation between columns
- Special handling for the "Deposit All" and "Close" buttons vs per-ore "Withdraw" buttons

### B4. (Conditional on C)
- Polish any other staying panels identified in direction lock

### Acceptance criteria (Pillar B)
- [ ] Backpack grid fully navigable without touch
- [ ] Inspect popup Drop/Close buttons reachable
- [ ] Party checkboxes toggleable with A button
- [ ] Storage Shed withdraw buttons reachable

---

## Out of Scope (Explicit)

- Redesigning the Lab/crafting UI (wait for C to decide)
- Art/sprite swap (Sprint 5 Path B deferred)
- Tetris-like backpack
- Dual merge
- T2 content
- Save system
- New bots

---

## Delivery Order

1. **Pillar A** first — global mapping, works across all panels
2. **Pillar C** — user playtests with navigable UI, writes direction lock
3. **Pillar B** — polish panels C marked as "keeping"
4. **Sprint review**

---

## Risks

- **Godot focus quirks on web** — focus behavior can differ between editor and web export. Test on the actual deployed build.
- **Joystick threshold tuning** — too sensitive = rapid-fire scroll, too loose = feels unresponsive. May need iteration.
- **Focus wrapping with disabled buttons** — need to skip disabled buttons or focus dead-ends.
