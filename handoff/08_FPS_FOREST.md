# 08 — FIRST-PERSON FOREST

**Status: §0, §1, §2 and §6 are BUILT (2026-07-26, CLAUDE.md Amendment 14) and
awaiting Creative Director sign-off. §3, §4 and §5 are NOT built and must not be
started without it — that is the whole point of §7's stop point.** Read
`00_OVERVIEW.md` and the CLAUDE.md M5 passes first.

## What changed against this plan when it was built

- **§0 decisions, all answered by Sam before any code:** forest is the 3D biome you
  walk into (so this is an M5 re-scope, contracts intact); A1 fix via the Settings
  UI; stop after step 2; felled trunks persist until bucked.
- **§2's fear was justified and §2's optimism was not.** The screen-space aim really
  would have collapsed at a crosshair, and it was replaced exactly as recommended.
  But the `cut_span` re-measure came out the OTHER way: 0.50 m still cannot fell
  tree_01 even walking right round it, because cutting a narrow channel from every
  side hollows the trunk into a shell that still carries the tree. Numbers are in
  CLAUDE.md and in `_warn_cut_span`'s own comment. **Do not repeat the plan's claim
  that 0.50 "may become perfectly playable".**
- **§6 was cheaper than feared.** `debug_blow(side, y, edge)` needed NO change —
  `side` and `edge` were always camera-relative, not screen-relative. All 154
  existing checks passed untouched; the suite is now 182 with `_test_14` (the
  first-person aim) and `_test_15` (persist until bucked) added.
- **§1's coupling was solved by keeping the orbit camera as a DEV camera**
  (`player_controlled = false` poses the player as a puppet) rather than by giving
  the tools a new way to place a camera. All the `cam_*` exports still mean what
  they meant and every shot tool still works.
- **One bug found that this plan did not anticipate**, and it is the kind §3b is
  about: a cut site remembers its world direction, but `_site_at` matched on
  CAMERA-RELATIVE side, so walking round a tree folded a blow into the notch on the
  face now behind the player. Fixed with `cut_face_arc_deg`.

Creative Director direction, 2026-07-26: *"I want this to be an fps game now,
where you walk through a forest and chop down trees."*

The chopping simulation itself needs **no change**. Everything in `WoodVolume`,
`TreeTrunk`, `HingeFall` and the load model is camera-agnostic — it takes world
planes and reports measured wood. What changes is everything *around* it: who
holds the camera, how a blow is aimed, and the fact that there is now more than
one tree.

---

## 0. DECISIONS NEEDED BEFORE ANY CODE (Directive 1 and 2)

This is not an M5 tweak. It re-scopes the project, so it needs Sam's answers and
an amendment before implementation, not after.

1. **Is M5 signed off, and is this a new module or a re-scope of M5?** Directive 1
   is one module at a time with explicit sign-off, and M6 (ore mining) is
   currently next. This needs a decision or the module order stops meaning
   anything.
2. **Does the 2D village survive?** A9/A10/A7 all still work if the forest is
   simply "the 3D biome you enter" — `minigame_entered(Biome)` fires when you
   walk in, `minigame_exited()` when you leave. That keeps every frozen contract
   intact and is the cheapest answer. If instead the whole game becomes
   first-person, M7/M8 and much of the blueprint need rewriting. **Recommend the
   first.**
3. **A12 needs restating.** "24 active rigid bodies *per mini-game*" was written
   for one tree on one stump. A walkable forest is a world, not a mini-game.
   Amendment required — see §5.
4. **Felled trunks: persist until bucked, or keep fading?** Today a felled trunk
   fades after `fade_delay` (Sam's live value 0.5 s) and deposits its yields. In
   an FPS you would expect to walk away and come back to it. This changes the
   reward loop, so it is Sam's call, not a technical one.
5. **Aim model** — confirm §2's "cut where you look". It is the one genuine
   design question in this plan.
6. **Forest size and tree count** target, so §3 and §4 can be sized.

### Fix the A1 finding FIRST

The OPEN A1 FINDING in CLAUDE.md — `Action_Viewport` is authored 1280x720 but is
**960x540 at runtime**, because `SubViewportContainer.stretch` resizes it to the
960x540 base canvas — is currently a static-camera annoyance ("still kinda
pixelated"). Under mouse look, with the whole frame moving every frame, an
upscaled render reads as smear and shimmer and it will be blamed on the FPS
controller. Fix it before building anything on top.

It is a `project.godot` edit (base canvas to 1280x720) and **project.godot is a
clobber trap** — walk Sam through the Settings UI rather than editing the file.
It touches A1, so it needs an amendment either way.

---

## 1. PLAYER CONTROLLER AND CAMERA

New: `res://scenes/3d_action/forest_player.tscn` (CharacterBody3D + Camera3D at
eye height) and `res://scenes/3d_action/forest_player.gd`. WASD, mouse look,
gravity, `move_and_slide`, `Input.MOUSE_MODE_CAPTURED`.

Collision, using the layers already defined on `TreeTrunk`:
- Player mask = `GROUND_LAYER | TIMBER_LAYER` — you cannot walk through the
  stump, a standing trunk or a felled log.
- **Deliberately NOT `DEBRIS_LAYER`.** Splinters already pass through timber by
  Sam's own call; having a hundred of them shove the player about is all cost.

### The coupling that will bite

`tree_felling.gd::_apply_camera()` runs in `_process` **every frame** and
rewrites the camera's position and `look_at`. It must go, along with `_orbit()`,
`_yaw_steps`, `_orbit_tween`, the A/D and arrow keybinds, and the
`cam_distance` / `cam_height` / `cam_focus_y` / `camera_step_deg` / `orbit_time`
exports.

**Those exports are how all four dev tools frame their shots** —
`core/tools/tree_shot.gd`, `seam_shot.gd`, `seam_layers.gd` drive them directly,
at roughly a dozen call sites. Removing them silently breaks the entire
render-to-PNG verification workflow, which is the only way this project has ever
caught a rendering bug. Give the tools a way to place the player/camera
explicitly *in the same change*, or they stop working and nobody notices until
the next visual regression ships.

**GameFeel**: it writes `h_offset`/`v_offset` on the camera, and `_apply_camera`
re-applying the transform every frame is why they never fought. Those are
frustum shifts, not transforms, so they should compose with mouse look
unchanged — but verify the shake still reads before moving on, because A11's
hit-pause plus trauma shake is most of what the chop feels like.

---

## 2. AIM FROM THE CROSSHAIR — AND WHY IT IS A DESIGN CHANGE

Every aiming function currently takes a `screen_pos`: `_on_click`, `_aim_point`,
`_side_from_screen`, `_entry_edge`, `_buck_click`. The naive port is to pass the
viewport centre. **It does not work**, and the reason matters:

`_side_from_screen` compares `screen_pos.x` against the trunk's unprojected x,
and ties inside 2 px fall back to the side already being cut. At a crosshair
pointed at a trunk those two values are always within a pixel or two, so **side
selection and `entry_angle_deg` both collapse** — the player loses the angle of
entry, which PASS 5 exists entirely to give them.

**Recommended (Option A): cut where you look.** Raycast from the camera to the
trunk's surface and derive everything from the 3D hit point:
- side and entry azimuth = the hit point's horizontal offset from the trunk axis
  (this is strictly better than the current screen-space arithmetic, and it is
  the natural first-person mapping — you aim at the wood, not at the screen);
- `_blow_angle`'s height comparison works unchanged from the hit point's y;
- `_entry_edge`'s unproject-the-radius trick is deleted outright.

**Consequence to re-measure, and it is good news:** PASS 5 warns that
`cut_span` below ~0.80 m "cannot be felled from one viewpoint at all". Sam's
live value is **0.50**. An FPS player can *walk around the trunk*, so that
premise no longer holds and 0.50 may become perfectly playable — possibly the
better feel, since it makes working round a tree a real activity. Re-measure it
with `core/tools/felling_spam.gd` before changing it, and update
`_warn_cut_span()`'s message, which will otherwise be actively misleading.

---

## 3. MANY TREES — THE PART THAT IS ACTUALLY HARD

`tree_felling.gd` assumes exactly one tree (`_trunk`, `_has_tree()`,
`_spawn_tree()`, `_clear_board()`).

### 3a. Build the voxels lazily. This is the whole ballgame.

A tree's voxel field is ~26,875 samples plus the profile build. Doing that for a
forest at load is the thing that will make this unshippable. `TreeTrunk.build()`
is already a single discrete call, so this is a **scheduling change, not a
rewrite**:

- a tree is a cheap imported `MeshInstance3D` + its pick `Area3D` until the
  player's first blow lands on it;
- that first blow calls `TreeTrunk.build()`, then the blow;
- when the player walks away from a part-chopped tree, collapse its six chunk
  `MeshInstance3D`s back to one mesh (`band_mesh()` already rebuilds the whole
  band) so idle trees cost one draw, not six.

### 3b. Per-tree state must move off the game node

These are currently globals on `tree_felling.gd` and are **per-tree**:
`_sites`, `_site`, `_face_side`, `_face_dir`, `_last_stress`, `_last_thickness`,
`_next_crack`, `_lean`, `_lean_tween`.

Left as they are, chopping tree B inherits tree A's notch, fall direction and
crack progression. This is the single most error-prone item in the plan. Move
them onto `TreeTrunk` (or a per-tree state dictionary keyed by the trunk).

### 3c. Picking

Each `TreeTrunk` already builds a pick `Area3D` on `_PICK_LAYER` (1<<1) with a
cylinder collider — it was built for exactly this and is currently unused,
because `_aim_point` shortcuts to the single trunk's axis segment. Replace that
with a real ray query against `_PICK_LAYER` and use whichever tree it hits.

### 3d. One tree falls at a time

`_felling`, `_falling`, `_hinge`, `_fallen`, `_landed`, `_impact_speed` and the
whole `_watch_fallen` path are single-instance. **Recommend keeping it that
way** — reject blows on other trees while one is going over. Making the fall
re-entrant is a large job for very little.

---

## 4. GROUND AND FOREST

`forest_floor_a.fbx` is one patch (Sam's live scale 0.8) with a 60x2x60 box
backstop under it. For walking you need either a larger ground asset or
`forest_floor_a` tiled in a grid. `_fit_ground_collider()` already builds a
`ConcavePolygonShape3D` from the floor mesh at load, so tiling means N trimesh
colliders — fine, but **keep the box backstop**, it is what stops debris falling
out of the world.

Trees placed by a seeded scatter with a minimum spacing and a clear radius round
the player spawn.

---

## 5. BUDGET ACROSS A WORLD (the A12 amendment)

- **Debris.** `max_debris` (120, added in PASS 7) retires the oldest *settled*
  piece globally. In a forest that means piles quietly vanish behind you. Either
  raise the cap and consolidate settled piles into a MultiMesh per felling site —
  which A12's own text already anticipates ("long-term piles may consolidate to
  MultiMesh") — or accept the vanishing. Sam's call.
- **Draw calls.** Standing trees are cheap; *engaged* trees are six chunks plus a
  crown. §3a's collapse-on-walk-away is what keeps this bounded.
- **Shadows.** One `DirectionalLight3D` with `shadow_enabled` across a whole
  forest is a different proposition from one tree in a clearing. Expect to need a
  shadow distance limit.

---

## 6. VERIFICATION — BUDGET FOR THIS, IT IS NOT OPTIONAL

`core/tests/m5_acceptance.gd` is 154 checks and it is the regression net for all
of PASS 7's seam and performance work. It drives `debug_blow(side, y, edge)`,
whose `edge` argument is a screen-space concept that §2 deletes. **A meaningful
number of those checks will need reworking onto the new aim seam.** Do it as part
of §2, not afterwards, or the forest gets built on top of an unverified simulation.

Also: `core/tools/felling_spam.gd` should grow a walk phase (walk, chop, walk on)
so the "does it stay flat" measurement covers the thing that is actually shipping.

---

## 7. SUGGESTED ORDER — AND WHERE TO STOP

Given limited budget, **do not attempt this in one session.**

1. ✅ §0 decisions + the A1 viewport fix. *(Decisions taken 2026-07-26. The A1 fix is
   Sam's to do in the Project Settings UI — base canvas 960x540 → 1280x720 — and is
   the reason `m2_acceptance` is still 22/23.)*
2. ✅ §1 + §2 against the **existing single tree**, with the dev tools kept working
   and m5_acceptance moved onto the new aim seam. *(Built. 182/182.)*
3. ✅ **Stop and play it.** *(Sam, 2026-07-26: "that works pretty well".)*
4. ✅ §3 many trees. *(Built, with the A12 amendment first — CLAUDE.md Amendment 15.)*
5. ✅ §4 / §5 forest and budget. *(Built: tiled ground, seeded scatter, shadow distance
   limit, and settled debris consolidated to MultiMesh.)*
6. ⬅ **YOU ARE HERE. A 25-tree stand, awaiting a live look.**

### What §3–§5 cost against this plan's estimates

- **§3b was as dangerous as advertised, and the plan under-called ONE thing:** the lean
  tween. Moving state onto the tree is not enough for state that is *live* — a tween keeps
  writing while the player walks off, so it has to be bound to its own trunk.
- **§3a is confirmed as the whole ballgame, and it needed one exception to be a rule:** the
  tree the player starts next to is built at LOAD. Deferring it only guarantees the first
  swing of the session pays for it. Measured: 25 trees up in ~1.18 s, one voxelised.
- **§5's debris question was the real A12 content.** The 24-active cap needed no change,
  because one tree falls at a time. What needed changing was `max_debris` deleting piles.
- **§4 was cheaper than feared.** Tiling the authored patch on its own measured footprint,
  and building the trimesh collider off every tile, is about 40 lines.

Step 2 is a complete, playable, verifiable milestone on its own, and it answers
the only question that actually matters — *does chopping feel good in first
person?* — before paying for a forest. If the answer is no, everything from §3
onward was wasted. If it is yes, the rest is ordinary work.
