# M8 — Villager Overlays (portraits · morale · production multiplier)

Status at handoff: direction only. Final module; smallest system surface,
highest art dependence (Sam's hi-res portraits).

## Scope fence

IN: villager roster from VillagerDef `.tres` data; hi-res portrait overlays
on UI_Overlay; runtime morale mirrored in GameState; morale/role production
multiplier plugged into M7's single `effective_seconds` call site;
role assignment to buildings (blueprint detail — confirm).
OUT: pathfinding/walking villagers, dialogue, needs simulation — none of
that exists anywhere in the blueprint summary; do not invent scope. If Sam
asks for it, that's a post-M8 conversation.

## Binding contracts

- **A9:** portraits are gameplay UI → **UI_Overlay (layer 2) only.**
- **The formula (CLAUDE.md, frozen):**
  `effective_seconds = base_seconds / (role_bonus * morale_factor)`.
  M7 was built with both factors defaulted 1.0 behind ONE function — M8
  ONLY changes that function's inputs. If M7 wasn't built that way, fix M7
  first (inside M8 scope, disclosed in delivery).
- **VillagerDef frozen** (`data/villager_def.gd`): `id, display_name,
  portrait (Texture2D), role, morale (authored DEFAULT — runtime morale is
  mirrored in GameState per the A8 note)`. Runtime morale therefore:
  - lives in GameState (new private dict + public getter, seeded from
    VillagerDef defaults on first sight);
  - is WRITTEN only inside GameState. **A7 has no villager/morale signal
    and A7 is frozen** — so morale changes enter GameState via a public
    GameState method (allowed: "their own public methods", Operational
    Rule 6), or via an EventBus amendment if Sam prefers signal purity.
    Previous agent's lean: public method `GameState.set_villager_morale()`
    with clamping — no amendment needed. Decide with Sam and record it.
- What CHANGES morale (chopping output? upgrades? time?) is 100% blueprint/
  Sam territory — get the rule before implementing any mutation.
- `role_bonus` mapping (role StringName → bonus float): data, not code.
  There is no RoleDef resource in the frozen set — simplest compliant home:
  a Dictionary on the building/config `.tres` side or matching by
  `role == building id` convention. Ask Sam; a new resource type would be
  an A8 amendment.

## Design direction

- `res://data/villagers/*.tres` — VillagerDef instances (ids, names, roles;
  portraits null-safe placeholders until Sam's art lands).
- `res://scenes/2d_management/villager_overlay.tscn` on UI_Overlay:
  portrait cards (TextureRect + name + morale readout). **Hi-res warning:**
  the canvas is 640×360 logical under `canvas_items` stretch — hi-res
  portraits will be downsampled unless the overlay opts out of canvas
  scaling. Options (verify in 4.7 before promising): CanvasLayer
  `follow_viewport_enabled` tricks or a separate high-res approach. This is
  the module's one genuine technical risk — prototype it FIRST, show Sam,
  then build the rest. If crisp hi-res under the current stretch config
  proves impossible without violating A1, halt and bring options to Sam.
- Assignment UI: villager → building (if blueprint says assignment exists);
  assignment state lives in GameState (progression-adjacent, single writer).
- Production hook: assigned villager's `role_bonus` × their
  `morale_factor` feed M7's function. Morale factor derivation from raw
  morale (clamp? curve?) = tuning → ask, keep in a `.tres`.

## Acceptance test — `m8_acceptance` (+ ALL suites green — final full pass)

1. VillagerDefs load; ids unique; morale defaults within valid range.
2. GameState mirrors runtime morale: getter returns authored default before
   any change; after the sanctioned mutation path, new value (clamped).
3. Formula: base_seconds 10, role_bonus 2.0, morale_factor 1.25 →
   effective 4.0 (exact); factors 1.0 → M7 behavior byte-identical.
4. Morale change mid-job does not retroactively change a running job's
   timer (or does, if Sam specifies — test whichever rule Sam picks).
5. Overlay lives under UI_Overlay; nothing added under UI_Canvas.
6. Null portrait renders placeholder without errors.
7. Full-project regression: M1–M7 suites re-run green. This is the
   ship-candidate gate.

## Ask-Sam list for M8

1. Blueprint text on villagers: roster size, roles list, assignment rules,
   what moves morale up/down.
2. Morale mutation path decision (GameState public method vs EventBus
   amendment).
3. role_bonus values + morale_factor curve (data/tuning).
4. Portrait art: dimensions, aspect, delivery format (PNG? aseprite?), and
   the hi-res-over-640×360 presentation decision after seeing the
   prototype.
5. Running-job recalculation rule (item 4 above).

## After M8

All eight modules delivered ≠ project over — expect a polish/tuning pass
(the deferred art-direction items: gobo replacement under Compatibility,
overall softness, real DOF-fake dressing), the deferred data flags, and
possibly save/load if it never landed. Compile the parked list from
CLAUDE.md + memory + these docs and hand Sam a single prioritized menu.
