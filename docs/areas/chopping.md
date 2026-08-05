# Chopping area guide

Read this only for runtime chopping, slicing, fragments, the axe, the pile, or
their focused tools. The live scenes and tests remain authoritative.

## Entry and ownership

- `scenes/3d_action/chopping_minigame.tscn` and `.gd` own the live chopping
  loop. `chopping_minigame_harness.tscn` instances the same scene for feel tests.
- `scenes/2d_management/yard_hud.*` owns the yard-facing entry/exit flow.
- Chopping resolves species through `data/species_table.tres`, deposits finished
  firewood through `InventoryManager`, and awards XP once per completed log.
- A species owns a list of meshes. Select species first and mesh second so
  species frequency is independent of the amount of available shape art.

## Load-bearing behavior

- Runtime plane slicing is intentional. `size_tier` is computed at slice time;
  the frozen size test is
  `piece.size_tier > GameFeelConfig.size_threshold`.
- Cut materials are cached per species by reference. `MeshUtils.jag_cut` uses
  material identity to find generated cut surfaces; replacing the material with
  a fresh instance per log breaks later roughening behavior.
- The slicer carries positions, normals, UVs, tangents, and vertex colors across
  a cut. Cut caps generate their own tangents and white vertex colors.
- Cap UVs are projected in the cut plane's local basis. Preserve winding when
  reversing triangles; do not reverse a flat vertex list.
- `MeshUtils.mesh_from_scene` bakes imported node transforms. Size logs by the
  target height, not a blind multiplier.
- Axe contact is keyed by `AnimationPlayer`. Swing-speed and Ready Stance may
  change the lead-in, but the authored contact/follow-through relationship must
  remain visible and testable.
- Follow-Up is a second visible automatic swing with synchronous strike
  resolution. Bonus swings cannot recursively create more bonus chains.

## Focused verification

- Logic: `core/tests/m4_acceptance.tscn`, `core/tools/test_slicer.gd`.
- Smoke: `core/tools/chopping_smoke.tscn`.
- Non-headless pile timing: `core/tools/pile_smoke.tscn`.
- Visual tools include `shot_runner`, `axe_shot`, `proc_shot`, `grain_shot`,
  `species_shot`, `m8_splitter_shot`, `inspect_materials`, and `inspect_fbx`
  under `core/tools/`.
- Run `axe_shot` after changing the swing animation. Run `species_shot` after a
  species mesh or bark tint change. Use `inspect_materials` for imported material
  binding; material names alone are unreliable.
- The Mechanical Splitter uses one static representative log proxy for every
  assigned species/batch. It is a presentation stand-in, not runtime slice input.

Historical implementation and post-mortem detail is in
`docs/history/02_m4_chopping_game.md` and the older M4 handoffs. Do not load those
unless the current guide and code do not explain a relevant trap.
