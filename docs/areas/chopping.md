# Chopping area guide

Read this only for runtime chopping, slicing, fragments, the axe, the pile, or
their focused tools. The live scenes and tests remain authoritative.

## Entry and ownership

- `scenes/3d_action/chopping_minigame.tscn` and `.gd` own the live chopping
  loop. `chopping_minigame_harness.tscn` instances the same scene for feel tests.
- `scenes/2d_management/yard_hud.*` owns the yard-facing entry/exit flow.
- Chopping resolves species through `data/species_table.tres`, deposits finished
  firewood through `InventoryManager`, and awards XP once per completed log.
- Earth depletion counts four unique completed manual logs as one felled tree.
  Individual pieces never advance the Earth counter, and automation reports its
  own explicit tree volume separately from recovered output.
- A species owns a list of meshes. Select species first and mesh second so
  species frequency is independent of the amount of available shape art.
- All 25 terrestrial species belong exactly once to one of five handling
  families: Supple Softwood, Fibrous Conifer, Straight Grain, Interlocked
  Hardwood or Iron-Dense Timber. Their fresh-bite, scar and size-relief
  modifiers come from `data/wood_handling_profile_table.tres`; every numeric
  value remains a labelled feel-test placeholder.
- Every terrestrial species requires manual mastery. Per-species targets are
  short (5–7 logs) and total 155; the no-bonus unlock path projects 159 manual
  logs, avoiding a late mastery wall while preserving hands-on contact with all
  25 woods.

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
- Follow-Up is a visible automatic swing with synchronous strike resolution;
  Flurry permits one further bounded swing. Bonus swings cannot recursively
  create more bonus chains.
- Double/Triple/Quad Chop use one root proc roll and at most one/two/three valid
  geometry-safe continuation cuts. Work Rhythm turns held primary input into
  repeated legal swings; Unbroken Rhythm carries it across log handoff.
- Final manual XP is authoritative before its receipt orbs launch. Routine,
  Quick Study, Mastery, grain and alien rewards share the same logarithmic count
  and quotient/remainder distribution from `XPPacingConfig`. At a level
  boundary, the HUD holds the old level at a full bar before rolling over; only
  that rollover triggers the pooled level-up celebration. The celebration keeps
  its rising rays, sparks and light but has no ground-level halo rings.
- Reward presentation uses four bounded mixed tiers. XP progresses from green
  through blue and violet to a gold-white core; cash glints resolve into exact
  coin, green-note, blue-note and strapped-bundle shares only after settlement.
  Phase-1 chopping/reward sounds are original deterministic WAVs routed through
  pooled voices; all cue gains, pitch ranges and tier thresholds remain labelled
  placeholders pending the measured audition gate.

## Focused verification

- Logic: `core/tests/m4_acceptance.tscn`, `core/tools/test_slicer.gd`.
- Smoke: `core/tools/chopping_smoke.tscn`.
- Non-headless pile timing: `core/tools/pile_smoke.tscn`.
- Visual tools include `shot_runner`, `axe_shot`, `proc_shot`, `grain_shot`,
  `species_shot`, `m8_splitter_shot`, `inspect_materials`, and `inspect_fbx`
  under `core/tools/`.
- `orb_scale_shot.tscn` captures small, medium, large and capped/jackpot bursts
  after the complete authored stagger has released.
- Run `axe_shot` after changing the swing animation. Run `species_shot` after a
  species mesh or bark tint change. Use `inspect_materials` for imported material
  binding; material names alone are unreliable.
- The Mechanical Splitter uses one static representative log proxy for every
  assigned species/batch. It is a presentation stand-in, not runtime slice input.

Historical implementation and post-mortem detail is in
`docs/history/02_m4_chopping_game.md` and the older M4 handoffs. Do not load those
unless the current guide and code do not explain a relevant trap.
