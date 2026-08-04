# M4 — the chopping game

Full build history and bugfix post-mortems behind the M4 line in CLAUDE.md's
status table. See [README.md](README.md) for how this folder is organized.

## M4 — the chopping game

`main.tscn`'s `3D_World_Root` instances
`res://scenes/3d_action/chopping_minigame.tscn` (root Node3D runs
`chopping_minigame.gd`). `chopping_minigame_harness.tscn` is an F6 feel-test
harness that instances the same scene inside a viewport. Enter it from the main
scene with the yard HUD's **"Go chopping"** button, which emits `minigame_entered`
and drives the A10 2D/3D toggle (the temp M key it replaced is gone).

- **The slicer is Amendment 6's runtime plane cut.** Each click cuts the log
  along a camera-inferred angle and caps the cut face; sliver cuts round up to
  a minimum piece size. `size_tier` is COMPUTED at slice time, and A3's single
  size test is unchanged.
- **Viewport** is 1280×720 + NEAREST (Amendment 8 — the pixel-art look was
  dropped), and since Amendment 16 the project base canvas matches, so that IS what renders.
- **Ground:** `res://assets/models/forest_floor/forest_floor_a.fbx` is instanced
  directly as a child node in `chopping_minigame.tscn` (scale 0.4, Sam-authored
  placement).
- **Inventory wired:** a fully-chopped log deposits its species' item into
  InventoryManager — one `resource_gathered` per finished firewood piece, at the
  batch-collect point (`_begin_stacking`). Wood type is data-driven: since
  2026-08-02 the table is `res://data/species_table.tres` (it was a `_LOG_SPECIES`
  const in `chopping_minigame.gd` until Sam's 25 woods landed — see the 25-wood
  ladder doc). A row maps log meshes → yield item, and scales to many woods
  (add a row) and many log SHAPES per wood (add a path). CURRENT ART: only
  `log_01/log_02.fbx` (oak) and `birch_log_01..06.fbx` (real birch art, six
  authored shapes) exist; the other 22 species wear tinted oak via `bark_tint`.
- **A row's `meshes` is a LIST on purpose.** Species is picked first, shape
  second, so log variety never changes how often a wood turns up — six birch
  meshes as six rows would have made three quarters of every yard birch.
  `debug_forced_species` (a LADDER INDEX) / `debug_forced_mesh` force either for
  tests and shots. A row may also carry `inside_tex`/`inside_normal`/`inside_tint`
  for its cut faces; empty falls back to oak.
  Cut materials are cached per species BY DESIGN, not just for speed:
  `MeshUtils.jag_cut` finds a piece's cut surface by comparing
  `material == _cut_mat` **by reference**, so a fresh instance per log would
  leave anything cut before the swap unroughenable.
- `log_2.fbx`, an unused duplicate that used to sit in `assets/models/logs_export/`,
  was deleted 2026-08-04. `maya_working/` still has unimported `log_03/04/05.fbx`
  (raw Maya exports, never referenced from the project — see ASSET PIPELINE in
  CLAUDE.md). CLAUDE.md previously claimed log_01…log_05 were live; they were
  not, and are not.
- **Acceptance:** `m4_acceptance.tscn` **55/55** — drives `debug_slice_world` to
  completion, checks inventory deposit == firewood count, per-species yield, one
  hit per slice, the A12 budget, and (since 2026-08-02) the axe viewmodel's contact
  key and its failsafe. It calls `get_tree().quit()` on finish, so run headless
  with a generous `--quit-after` backstop (e.g. 20000).
  **The click layer IS partly headless-verifiable now.** Test 7 calls `_on_click`
  for real, which is the suite's ONLY raycast — and it needs `await physics_frame`
  plus a settle wait first, because the query runs against the physics server and
  the log is still dropping in from `drop_height` a process frame after spawn. The
  FEEL of clicking is still Sam's eyeball test in F5/F6.
- KNOWN: firewood uses the mini-game's own `max_firewood` (40) soft cap for
  feel, not `fragment_physics_budget` (A12's nominal 24) — reconcile at tuning.
- **BUGFIX 2026-07-23 — sliced pieces shaded darker than the uncut log.**
  `MeshSlicer` carried only POSITION/NORMAL/UV across a cut, so
  `SurfaceTool.commit()` regenerated the tangent basis from the cut soup. Both log
  materials (`oak_bark`, `oak_top`) are normal-mapped, and the regenerated basis
  pointed ~90 deg off the FBX-authored one (import has `meshes/ensure_tangents=true`),
  so the normal map was read rotated. `mesh_slicer.gd` now carries ARRAY_TANGENT and
  ARRAY_COLOR through the slice, interpolating both at the cut (handedness/binormal
  sign is per-surface, never lerped); cut caps still use `generate_tangents()` because
  their UVs are built fresh there, and they emit white vertex colours so a
  `vertex_color_use_as_albedo` cut material can't multiply to black.
- **BUGFIX 2026-07-27 — cut-face UVs only ever worked BY ACCIDENT.**
  `MeshSlicer._build_caps` UV'd a cut face as the offset from its centroid **in
  metres**, which lands inside 0..1 only when the piece is about a metre across. The
  `cap_fit_round` argument fits the round to the cut face's OWN measured extent.
  **M4 deliberately keeps the metres mapping**, which is correct for its TILING cut
  material, and the slicer suite asserts exactly that.
- **BUGFIX 2026-07-29 — M4 stopped spawning logs.** `MeshUtils.mesh_from_scene`
  started BAKING the transform authored on an imported FBX's `MeshInstance3D`, and
  the M4 logs carry scales of their own (log_01 33.88x, log_02 31.59x) — so
  `log_scale = 13.0`, authored against the RAW 0.032 m mesh, produced a **14 m log**
  with the camera inside it. `log_scale` is REPLACED by **`log_height` (0.42 m, what
  13.0 gave before)** and the scale is derived per mesh in `_fit_scale()` from its own
  measured height. A bare multiplier means whatever units the artist exported in; a
  target height cannot drift that way again. **Why 16/16 stayed green through it:**
  every M4 check is relative, and a 14 m log slices into two plausible halves exactly
  like a 0.42 m one. It was caught by RENDERING it (`core/tools/shot_runner.tscn`).
- **Winding convention, pinned:** Godot's front face is the CLOCKWISE one — a
  triangle is seen from the side its right-hand-rule normal points AWAY from.
  `MeshUtils.winding_report()` plus checks in `test_slicer` assert the engine's own
  primitive first, so the convention itself is pinned rather than assumed. Getting
  this wrong makes geometry see-through under CULL_BACK, and it is invisible on any
  cut material (every one in the project is CULL_DISABLED).
- **`MeshUtils.plane_to_local` had always rotated the normal the wrong way** (fixed
  2026-07-27). A plane's normal transforms by the TRANSPOSE OF THE FORWARD basis;
  the code read `inv.basis.transposed()`, which for a rotation R evaluates to R, not
  Rᵀ. Identical to correct for any translation-only transform, which is why it
  survived — but M4 ROTATES pieces to their long axis before cutting them, so every
  slice of a turned billet was cutting on a plane rotated the wrong way round since
  M4 shipped. Guarded by 10 checks in `test_slicer` at five yaws including 310.8°.

## M4 — the axe became a CAMERA VIEWMODEL on an AnimationPlayer (2026-08-02)

**Creative Director call:** *"Currently the axe swing in the game looks bad, the
animation feels clunky and I want a little more create control over it. It should
look as if the axe is being over-head swung from where the camera."* Sam specified
the node tree and the four beats himself, and then, seeing the first pass:
*"the axe can just swing down from off screen, we dont need to see it rise in to
frame, it looks weird."*

- **`res://scenes/3d_action/axe_viewmodel.gd` (`class_name AxeViewmodel`) REPLACES
  `axe_rig.gd`, which is DELETED** (recoverable from git). The old rig was a
  world-space axe that flew from the impact point to the wood along a hand-built
  Bezier between two hardcoded euler poses. Nothing about it could be keyframed,
  which is exactly the "no creative control" Sam is describing. The rig is now
  authored in `chopping_minigame.tscn`, hanging off the camera:

  ```
  Camera3D
  └── AxeViewmodelAnchor      (axe_viewmodel.gd — fixed to the camera, aims the swing)
      ├── AxeAnimationRoot    (the ONLY node the animation moves)
      │   └── axe_basic.fbx   (scale 1.4 lives here)
      └── AnimationPlayer     (plays "swing" from res://data/axe_swing_lib.tres)
  ```

- **THE ANIMATION OWNS THE GAMEPLAY BEAT, and that is the point of the rebuild.**
  `swing` carries a METHOD TRACK whose key calls `AxeViewmodel._on_swing_contact()`
  at the frame the blade bites; that emits `contact`, and `chopping_minigame` runs
  `_resolve_pending()` there. Move the key in the editor and the wood breaks
  somewhere else. **This closed a real bug:** the scene carried `swing_time = 1.0`
  while the split fired off a separate `anticipation_sec = 0.1` timer, so the log
  came apart while the axe was still up in the air. Two owners for one moment.
- **The method key is DEFERRED** (AnimationMixer's default). The split adds and
  frees nodes; doing that from inside the mixer's own process is asking for it.
- **THE FAILSAFE IS LOAD-BEARING, and it is proven.** The mini-game does not trust
  the signal: `contact` comes from a key in an editable data file, and a `swing`
  re-keyed without one would leave a strike pending forever — which blocks every
  future click and stops the game dead. `_strike_timeout()` arms a deadline from
  `contact_time() * strike_timeout_slack`, and `_resolve_pending()` clears
  `_pending` FIRST so the key and the deadline can never spend the same strike.
  `m4_acceptance` strips the method track out of a copy of the animation and
  asserts the wood still splits.
- **`anticipation_sec` survives only as the no-viewmodel fallback.** A missing
  anchor is a warning, not an error — a scene stripped down for a test should not
  need a viewmodel to chop wood.
- **The swing IS the cooldown now.** A click is refused while `is_swinging()`, so
  `swing_cooldown` is a floor beneath the animation rather than the whole gate. The
  swing-speed skill therefore drives `AxeViewmodel.set_speed()` (the ratio
  `swing_cooldown / current_swing_cooldown()`), so "5% faster between swings"
  speeds up the SWING — an upgrade you can see beats one you can only measure.
- **THERE IS NO WINDUP IN FRAME.** The swing starts already raised and parked past
  the right edge; the first thing the player sees is the head coming down. Total
  0.46 s, contact at 0.18 s — deleting the raise took the dead time at the front of
  a click with it.
- **`res://core/tools/build_axe_swing.gd` authors the default swing**, because a
  `rotation_3d` track stores QUATERNIONS and nobody should be typing or reading
  those. A pose is written the way it is thought about — where the hand is, which
  way the handle points — and the quaternion falls out. **It is a default-builder,
  NOT a build step: running it again overwrites Sam's tuning.**
- **The roll is DERIVED, not authored** (`handle x swing_plane_normal`). Authoring
  "which way is the edge facing" per pose was tried first and produced a spin,
  because that sense flips as the handle passes vertical.
- **TWO FRAMING RULES, both learned from PNGs and invisible in every number:**
  (1) *the grip moves, the head is what swings* — the first pass drove the head
  from 0.27 m to 1.15 m from the lens in 0.09 s, and a 4x change in apparent size
  reads as the axe shrinking away from you, not as a chop; (2) *the handle butt is
  never on screen* — the second pass left the butt floating mid-frame and it read
  as a fence post. `build_axe_swing`'s report prints the grip's SCREEN position for
  every key and flags any that is inside the frame, so rule 2 is checked rather
  than hoped for.
- **`core/tools/axe_shot.tscn` shoots all seven beats — RUN NON-HEADLESS**, and run
  it on any change to the swing. Every problem above was found in its PNGs and none
  of them was visible anywhere else. It waits on ELAPSED TIME and writes the images
  after the run (the lesson `orb_shot` paid for), and it spaces the post-contact
  shots generously because A11's hit-pause fires there.
- **The aim lean** (`aim_yaw_deg` 6, `aim_pitch_deg` 4, PLACEHOLDERS) tips the whole
  anchor toward the click before the animation plays, so a swing does not land in
  the same pixel however far off-centre you clicked. Set both to 0 for a rigidly
  fixed viewmodel; the authored motion is never touched either way.
- **PLACEHOLDERS (Directive 3):** every pose, both timings and the axe's 1.4 scale.
  These are a starting point for Sam to re-key in the animation editor — which is
  the whole reason the motion moved into a data file.
