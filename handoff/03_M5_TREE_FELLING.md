# M5 — Tree Felling (quadrant cuts · gear gating · hinge fall)

> **STATUS (2026-07-23): M5 IS BUILT, but NOT to the design below.** Sam
> redirected it on the day: the tree is felled by cutting a WEDGE with the M4
> runtime slicer, not by swapping authored quadrant meshes. That supersedes the
> "Binding contracts" and "Design direction" sections of this document and A2
> for trees — see **Amendment 10** and the M5 block in `CLAUDE.md`, which are
> the current source of truth. What survived from this doc verbatim: gear gating
> off `hardness_level`, TreeDef staying frozen and data-driven, the scripted
> (non-physics) hinge fall, the felled trunk feeding the M4 fragment pipeline,
> reuse of `fragment_piece` + `fragment_physics_budget`, and every acceptance
> criterion except #2/#3 (quadrant mesh swaps, which no longer exist — the
> equivalent geometric checks are in `core/tests/m5_acceptance.gd`).
> The "Ask-Sam list" at the bottom is still live; answers 1–4 shipped as
> clearly-labelled placeholders rather than blocking.

Status at handoff: direction only. Design within these fences and reuse M4's
machinery — M5 should be substantially smaller than M4 if M4 was built right.

## Scope fence

IN: standing trees in the 3D action scene; directional cuts against 4
quadrants × N depth stages (default N=3, data-driven); structural integrity;
gear gating by tool tier vs tree hardness; the fall (hinge rotation at the
base); felled trunk feeds the M4 fragment pipeline; TreeDef-driven data for
Pine first.
OUT: new biomes/species beyond what Sam asks for (data comes later), mining
(M6), any UI beyond what M4 already established.

## Binding contracts

- **A2 (verbatim for trees):** pre-authored fracture states only. Trees:
  **4 quadrants × N cut depths (default 3), mesh swap +
  `structural_integrity` decrement.** No runtime cutting.
- **TreeDef is frozen** (`data/tree_def.gd`): `biome, hardness_level,
  quadrant_stage_meshes (Array of per-quadrant Arrays of Mesh),
  integrity_per_cut, yields (Array[FragmentDef])`. All tunables live in
  TreeDef instances, never code. If the design genuinely needs another
  field → amendment proposal to Sam first.
- **A7:** same two signals as M4 (`action_hit_registered`,
  `resource_gathered` via the fragment pipeline). Nothing new on EventBus.
- Gear gating reads `GameState.get_tool_tier(Enums.ToolType.AXE)` —
  progression stays read-only; upgrades arrive only via `gear_upgraded`
  (M7's job to emit).
- Banned list applies: the fall is NOT physics simulation of a tree mesh
  hierarchy — see hinge note below.

## Design direction

- `ChopDirection` maps to quadrant selection (LEFT/RIGHT/UP/DOWN → which
  quadrant face you're cutting; camera-relative mapping needs Sam's
  confirmation).
- Each quadrant tracks its cut depth 0..N; a successful cut increments depth,
  swaps that quadrant's mesh from `quadrant_stage_meshes[quadrant][depth]`,
  and decrements the tree's `structural_integrity` by `integrity_per_cut`.
  Starting integrity = derived from data (e.g. quadrants × N ×
  integrity_per_cut) — confirm the fell condition with Sam: all quadrants
  fully cut? integrity ≤ 0? (Blueprint detail not in CLAUDE.md.)
- **Gear gating:** if `axe_tier < tree.hardness_level`, the hit registers as
  a bounce: no cut, no integrity change — but still emits
  `action_hit_registered` (GameFeel thunk) unless Sam wants a distinct
  denied-feel. Ask.
- **Hinge fall:** stop-motion friendly and cheap — animate the felled trunk
  rotating around a hinge point at the stump edge (AnimationPlayer with
  discrete/stepped keys per A1's stop-motion rule, or a scripted stepped
  rotation). Do NOT use a physics joint for the fall itself; on landing,
  swap the trunk for M4 fragment pieces (the trunk's `yields` chain) which
  ARE rigid bodies under the A12 budget. Fall direction: away from the most-
  cut quadrant or fixed per camera? Ask Sam.
- After the fall, the stump remains (art: does Sam want a felled-stump mesh
  per species? ask — `chopping_stump_a` may be reusable placeholder).
- Reuse `fragment_piece.tscn` + `FragmentPhysicsBudget` from M4 untouched.
  If M4's code needs modification to be reusable, that's a refactor INSIDE
  M5's sign-off scope — say so in the delivery.

## Acceptance test — `m5_acceptance` (+ all older suites re-run green)

1. TreeDef for pine loads; 4 quadrant arrays; N stages each.
2. Cut on quadrant Q at depth d swaps to `quadrant_stage_meshes[Q][d+1]`
   and decrements integrity by exactly `integrity_per_cut`.
3. Cuts beyond depth N on a quadrant are rejected (no swap, no decrement).
4. Gear gate: axe tier below `hardness_level` → zero state change on the
   tree (emit `gear_upgraded` to raise the tier via the real path, then the
   same cut succeeds).
5. Fell condition triggers exactly once; trunk converts to fragments; full
   collection of a pine tree's yields lands the right registry ids/amounts
   in InventoryManager.
6. A12 cap still holds during the post-fall fragment burst.

## Ask-Sam list for M5

1. Fell condition (all quadrants cut vs integrity zero) and fall direction
   rule — blueprint text if it exists.
2. Camera-relative vs world-relative quadrant mapping for ChopDirection.
3. Denied-hit feel for under-tier axes (bounce anim? different shake?).
4. N (cut depths) and integrity numbers for Pine — placeholders in the
   TreeDef `.tres` until given.
5. Art status: quadrant stage meshes are 4×N per species (12 for pine at
   N=3) — are these authored? If not, placeholder wedge primitives with the
   same `.tres` shape.
6. Does felling also grant wood directly, or is ALL yield via the fragment
   chop chain? (Registry has `oak_log` but no approved oak chain — flag it.)
