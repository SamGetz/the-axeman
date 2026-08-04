# M4 — Runtime Slicing POC (continuation handoff)

Historical POC continuation. For current firewood-chopping work, read
`docs/areas/chopping.md` and the live code first. Use this file only when the
current guide points to a POC-era renderer or slicing detail.

**STATUS (2026-07-22): the POC described below is DONE and folded into the live
M4 mini-game** — `chopping_minigame.tscn` / `chopping_minigame.gd` (renamed
from `slice_poc.tscn`/`.gd` once feel-approved; the F6 harness is now
`chopping_minigame_harness.tscn`, and the smoke test is
`core/tools/chopping_smoke.*`). This doc is kept for the render-to-PNG
workflow and the Compatibility-renderer traps below, both still current — but
any file path it mentions by the old `slice_poc`/`poc_smoke` names has moved;
see CLAUDE.md's M4 section for the current names.

## Where we are (historical — POC phase)

Sam rejected the authored-fracture M4 (the tier-swap `chopping_block`) and chose
**Path B: runtime mesh slicing** (Amendment 6, logged in CLAUDE.md). We iterated
a **standalone POC** — `res://scenes/3d_action/slice_poc.tscn` at the time
(run with F6) — to nail the *feel* before folding it into full M4
(collection→inventory, size-tier quantization, budget, acceptance test,
repoint `main.tscn`). That folding-in is now done; see the STATUS note above.

**The reference game** (`C:\Users\Sam\Downloads\example.js.txt`, a three.js +
cannon-es firewood chopper) is the source of truth for feel. Its decoded rules:
- Each slice makes two pieces. Each piece is judged **independently**:
  - volume ≤ floor (reference: 250 in³) → **firewood** (falls to pile)
  - **aspect ratio > 3** (long/thin stick) → **firewood** (falls)
  - otherwise (chunky) → **RESCUED, stays on the stump**, keep chopping
- Pieces are **real rigid bodies** → they collide with ground, stump, and each
  other → they pile. (We use Godot/Jolt RigidBody3D for this.)
- Three wood textures: bark (sides), end-grain (log ends), inside-grain (cut
  faces). An animated axe swings down. `drop.mp3` on landing.

## ⭐ The single most important workflow: render to PNG and LOOK

Do NOT iterate on visuals blind. Godot renders headlessly-ish to an image:
```bash
cd "C:/Users/Sam/Documents/the_axeman/the-axeman"
timeout 70 "/c/Users/Sam/Desktop/Godot_v4.7.1-stable_win64.exe" --path . \
  --rendering-driver opengl3 --resolution 480x480 --position 3000,3000 \
  --log-file <scratch>/shot.log res://core/tools/shot_runner.tscn
```
- Output PNGs: `%APPDATA%/Godot/app_userdata/the-axeman/poc_shot_*.png`
  (i.e. `C:\Users\Sam\AppData\Roaming\Godot\app_userdata\the-axeman\`). **Read
  them with the Read tool** — you can see the actual render.
- `--position 3000,3000` shoves the window off-screen so it doesn't annoy Sam.
- `core/tools/shot_runner.gd` instances the POC, waits, drives
  `debug_slice_world(Plane)` a few times, saves `_1_fresh` / `_2_cut` /
  `_3_axe`. Edit it to reproduce whatever you need to see.
- This is also how you diagnose material bugs (paint a surface solid magenta,
  render, confirm which faces it is).

## ⚠ Compatibility-renderer traps we already hit (do not repeat)

1. **Two `source_color` samplers in one shader → the 2nd renders WHITE** in the
   OpenGL/Compatibility backend, even though `set_shader_parameter` binds it
   correctly (verified via `get_shader_parameter`). Don't put multiple texture
   samplers in one gameplay shader.
2. **StandardMaterial3D triplanar renders WHITE on horizontal (Y-projection)
   faces** in Compatibility. Triplanar is fine on vertical faces only.
   → **Fix we shipped:** the log is split into surfaces — sides use triplanar
   bark; **end caps use PLANAR UVs** (generated in `_build_split_log`) with a
   plain material; cut faces use the slicer's generated cap UVs. `MeshSlicer`
   now **preserves per-surface materials AND UVs** through a cut.
3. **Highlight clipping**: a bright spotlight on light wood clips to white with
   no tonemap. The POC env uses `tonemap_mode = 3` (ACES) + sun energy 1.2.
4. **Infinite-plane floor (`WorldBoundaryShape3D`) causes tunneling + jitter.**
   Use a thick `BoxShape3D` floor instead (POC floor is a 60×2×60 box, top at
   y=0). Give falling bodies `continuous_cd = true`.

## POC file map (paths as of the POC phase — see STATUS note above for current names)

- `scenes/3d_action/slice_poc.tscn/.gd` (now `chopping_minigame_harness.tscn` /
  `chopping_minigame.gd`) — the mini-game. Camera orbits in 30° steps
  (A/D or arrows), left-click chops, R = fresh log. Key logic:
  - `_build_split_log()` — scales log_a ×20, splits into side (bark triplanar)
    + cap (end-grain, planar UV) surfaces.
  - `_try_slice` / `debug_slice_world` → `_slice_piece(body, world_plane)`.
  - `_place_piece` classifies by `min_vol` / `aspect_limit` (the reference
    rule) → `_spawn_piece`.
  - `_spawn_piece` — every piece is a recentred RigidBody3D with a convex
    collider; `separation_speed` nudge on every cut (so cuts aren't
    "atom-thin"); firewood gets `firewood_speed` extra push to leave the block.
    **Physics pass (2026-07-19):** mass now scales with AABB volume
    (`wood_density`, floored by `min_mass`) so a heavy log and a light sliver no
    longer fling each other; damping is exported (`piece_linear_damp`,
    `piece_angular_damp`); the spawn gap between fresh halves is exported
    (`spawn_gap`, up from a hardcoded 0.012) to stop coincident cut faces being
    ejected. **Tumble is now only applied to pieces meant to move** —
    `firewood_tumble` for firewood, `stay_tumble` (default 0) for stay/fresh
    pieces. This killed the old bug where the fresh log and chunky halves
    spawned spinning (the main source of "jumping").
  - `_physics_process` — **subtle slide-off assist.** A chunky piece that comes
    to rest with its centre past `slide_off_edge_frac` of the stump radius gets
    a small rate-limited outward+down nudge (`slide_off_impulse`,
    `slide_off_cooldown`, gated by `slide_off_settle_speed`) so it eases off the
    rim into the pile instead of balancing on the edge. Centred pieces (fresh
    log, halves near the middle) are never touched. This is Sam's "rolls to the
    side → slides off subtly" request; tune the fraction/impulse live. The
    threshold is a FRACTION of the measured stump radius, so it auto-scales if
    you change `stump_scale`.
  - `_build_stump()` — **the cutting stump is now the authored
    `chopping_stump_a.fbx`** (2026-07-19), no longer a placeholder cylinder.
    The FBX mesh is run through `_split_bark_cap` (bark triplanar sides +
    planar end-grain top, same treatment as the log — the raw FBX shipped no
    usable material and rendered solid WHITE) and shown as a `StumpMesh`
    MeshInstance3D. A cylinder collider is DERIVED from the scaled footprint
    (base on the ground, footprint centred on origin). `_stump_top_y` and
    `_stump_radius` are measured here and drive the log spawn height and the
    slide-off edge, so the whole rig tracks `stump_scale`.
  - `_split_bark_cap(mesh)` — generalised out of `_build_split_log`; splits any
    roughly-cylindrical wood mesh into bark-side + planar-cap surfaces. Shared
    by log and stump.
  - `_is_cuttable(body)` — a piece is choppable only while its centre is above
    `cuttable_min_y` (on the block); fallen pieces can't be cut.
  - Axe: hidden by default, `_swing_axe()` drops it in and retracts it.
- `scenes/3d_action/mesh_slicer.gd` — `class_name MeshSlicer`. Convex plane
  slice + cap generation, per-surface material/UV preserving. `test_slicer.gd`
  covers it (10/10). Assumes roughly-convex input (a log round).
- `scenes/3d_action/slice_piece.gd` — an EARLIER lightweight custom-physics
  piece, unused (we went back to real RigidBody). DELETED per Amendment 6.
- `core/tools/` dev tools (not shipped): `shot_runner.*` (render to PNG),
  `chopping_smoke.*` (headless logic check, 4/4; was `poc_smoke.*`),
  `test_slicer.gd`, `probe_log.gd`,
  `inspect_log.gd`, `inspect_stump.gd` (stump mesh stats — used to size the
  block), `build_pine_chain.gd` (retired chain builder).
- Assets: `assets/models/log_a/log_a.fbx` (solid log, imports ~2cm → ×20),
  `assets/models/chopping_stump_a/chopping_stump_a.fbx` (the cutting stump;
  copied in from `maya_working/`; mesh AABB 2.59×1.33×2.69 native, base at y=0,
  512 tris; scaled by `stump_scale` ≈0.376 so its top lands at ~0.5m),
  `assets/models/axe_basic/axe_basic.fbx` (untextured, ~0.5m, length along Y),
  `assets/textures/wood_oak/{outside,inside,top}_*.jpg`.

## Verify before handing back

`chopping_smoke` (4/4) + `test_slicer` (10/10) headless, and re-render a shot and
LOOK. Also re-run M1–M4 acceptance (they're independent but cheap insurance).

## Open tuning / next steps (Sam-facing, inspector on `Chopping_Minigame`)

- **Axe placement is a guess** — `axe_scale`, `axe_hidden_pos`,
  `axe_struck_pos`, `axe_hidden_euler`, `axe_struck_euler`, `swing_time`. Sam
  must eyeball. (axe_basic has no animation; we tween a swing.)
- **`stump_scale` (≈0.376)** — scales `chopping_stump_a`; its top is measured
  and the log spawn + slide-off edge follow it, so you can rescale freely and
  the log will still rest on top. The authored block is WIDER than the old 0.4r
  placeholder cylinder (scaled footprint radius ≈0.5m), so more chunky halves
  now stay on the block (a centre-cut render showed cuttable=3). If that feels
  too forgiving, lower `slide_off_edge_frac` or `separation_speed`.
- `separation_speed` (now 0.35, was 0.5 — lowered so chunky halves stay more
  centred), `cuttable_min_y` (0.4 — NOTE: still absolute; if you scale the
  stump taller, raise this to ~stump_top − 0.1), `min_vol` (0.004 m³ —
  reference used 250 in³; ours is unit-guessed), `aspect_limit` (3, from
  reference), `firewood_speed`, `wood_tile`.
- **Physics knobs (Piece physics / Slide-off inspector groups):**
  `wood_density` (700), `min_mass` (0.2), `piece_linear_damp` (0.35),
  `piece_angular_damp` (1.2), `spawn_gap` (0.02), `firewood_tumble` (3.0),
  `stay_tumble` (0.0), `slide_off_edge_frac` (0.7 — piece eases off once its
  centre passes 70% of the stump radius; auto-scales with `stump_scale`),
  `slide_off_impulse` (0.35), `slide_off_settle_speed` (0.25),
  `slide_off_cooldown` (0.4). All PLACEHOLDERS — Sam tunes live. If pieces
  still jitter on the rim, first try nudging `piece_angular_damp` up and/or
  `slide_off_impulse` up a touch.
- Physics jitter/jumping was addressed this pass (mass-by-volume, no
  spin-on-spawn for resting pieces, bigger anti-interpenetration gap, higher
  angular damp). The render-to-PNG stills confirm a clean fresh log and a tidy
  settled pile (not scattered). **Dynamic feel — live jitter and how "subtle"
  the slide-off reads — is NOT headless-verifiable; Sam must eyeball in F6.**
  A straight centre-cut still nudges both chunky halves; if both topple, lower
  `separation_speed` further or raise `slide_off_start`.
- Not yet done: drop/chop SFX, axe animation, real end-grain-vs-bark on the
  BOTTOM cap, folding into full M4 (inventory/collection/size-tier/budget/test).

## Amendment status

Amendment 6 (runtime slicing for M4 only) is logged in CLAUDE.md. A3 stays
intact: a sliced piece's `size_tier` will be COMPUTED (quantized) at slice time
when this folds into M4; the sole size test remains
`piece.size_tier > GameFeelConfig.size_threshold`. The POC currently uses raw
volume/aspect for the fall decision — reconcile to size_tier at M4 integration.
