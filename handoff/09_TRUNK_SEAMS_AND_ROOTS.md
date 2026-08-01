# 09 — TRUNK SEAMS, CUT FACES, AND THE ROOT VOXELISER

**Status: everything in this file is SHIPPED and green, including `voxel_roots`,
which is ON.** Read `00_OVERVIEW.md` and the CLAUDE.md entries for 2026-07-30 and
2026-07-31 first — this file is the working state, not a substitute for the log.

> **UPDATE 2026-07-31: §2 was BUILT AND THEN SWITCHED BACK OFF the same day.** The
> feature works — see §2 for what the analysis below got wrong, and note that both
> "blockers" it names were the CHECKS rather than the feature, while the real one
> (the stump collider) is not mentioned at all. But Sam played it and reported that
> the voxel parts "look awful" and the game "lags on every hit", and **the root
> flare is the cause of both**: its bark is the only part of the trunk that is not
> the artist's, and it takes the voxel grid from 68,600 to 234,423 samples. A blow
> went 84-350 ms. `voxel_roots` is OFF; a blow is now 32-50 ms with no spikes.
> Full write-up in CLAUDE.md, "THE HIT NO LONGER STUTTERS".
>
> **Nothing in this file is outstanding work.** What is left is Sam's live look,
> Sam's tuning numbers (§6), and — if root-cutting is still wanted — ART: a trunk
> whose flare is part of the stem silhouette rather than separate buttresses.

> **UPDATE 2026-07-30 (later the same day): §1 IS FIXED AND GUARDED.** It was
> **neither** of the two candidate causes below. The collider was one cylinder on
> the body's local Y axis and the timber is not a straight column on that axis —
> 74% of tree_02's timber sat outside it, worst by 2.72 m, so the woody crown
> came to rest 2.65 m under the dirt. It now follows the wood's own measured
> centre line (`TreeTrunk.timber_slices`). M5 **197/203**. Full write-up in
> CLAUDE.md, "FIXED 2026-07-30 (third round)".
>
> **AND §2 DID NOT GO WITH IT.** The expectation below that both were the same
> broken measurement is **disproven** — see the revised §2.

Everything here came out of one thread of Sam's reports: *"the texture looks
different and is stretching"* → *"it's actually not a hairline, we cannot ship
unless it is resolved"* → *"the texture of the tree rotates"* → *"worth doing to
remove those seams"* → *"this shelf looks really bad and just feels like a
removal of player agency"*.

---

## 0. State of the tree, right now

Suites, all verified at the end of the session:

| suite | result |
| --- | --- |
| `core/tests/m5_acceptance.tscn` (`--quit-after 600000`) | **198 / 203** |
| `core/tools/tree_species_smoke.tscn` | 53 / 53 |
| `core/tools/forest_smoke.tscn` | 46 / 46 |
| `core/tools/fps_smoke.tscn` | 14 / 14 |
| `core/tools/felling_smoke.tscn` | 11 / 11 |
| `core/tools/test_slicer.gd` (`-s`) | 34 / 34 |
| `core/tests/m4_acceptance.tscn` | 16 / 16 |

M5's 6 failures are the documented pre-existing ones (hinge/plank, "it broke at
the cut", `lean_start_stress`, the lean readout, the crown-base check and the
blow-count baseline). **M5 is not deterministic — ±1 is noise, not a
regression.** No contract was touched anywhere in this work.

### Shipped and working

- **A felled trunk's collider follows the wood** (`TreeTrunk.timber_slices`,
  `_fit_trunk_collider`, `_fit_log_collider`) — §1, fixed 2026-07-30. No tuning
  number; measured off the same cross-section scan the standing collider already
  used.
- **Cut faces wear the grain the axe exposed.** `WoodVolume.side_mat` is a second
  cut surface for near-vertical faces, mapped by the axis-aligned planar path;
  cross-cut faces keep the growth rings. This was Sam's original "stretching".
- **`cut_wood_tint`** — fresh wood was clipping 29% of its pixels to pure white.
  Now 0%. **Placeholder, Sam's number, wants tuning live.**
- **`prebuild_stand`** — every tree is voxelised at spawn, so no tree changes
  under the player on its first blow. Costs ~4.5 s and ~58 MB on a 25-tree stand
  (`core/tools/eager_build_probe.tscn`).
- **`cut_height_above_eye` (0.5 m)** — a blow may not land more than that above
  the player's eyes. Measured against the PLAYER, not the tree.

### `voxel_roots` — **ON since 2026-07-31**

Fills the field BELOW the flare top from the trunk's own triangles instead of
from the radial profile, so the band starts at the ground and there is no
imported roots piece at all. The axe reaches the dirt; the lowest a blow may land
drops from 0.60/0.80 m to 0.20 m. See §2.

---

## 1. ~~THE THING TO FIX FIRST~~ — a felled trunk sinks through the floor — **DONE**

**FIXED 2026-07-30. Kept below because the reasoning was WRONG in an instructive
way: both candidate causes were plausible, both were checkable, and neither was
it.** What the diagnostic actually showed is in CLAUDE.md; the short version is
that `_fallen_length` and the frame were both CORRECT — the collider spanned the
timber exactly, 0.000 m past the top — and it still missed the wood, because a
cylinder on the body's local Y axis can span a trunk and sit beside it. Length was
never the variable. **Ask "does the collider CONTAIN the wood", not "does it span
it".**

Sam, live: *"when a tree falls, the top half penetrates through the floor."*
**This is in the SHIPPING config (`voxel_roots` off) and is not caused by any
change in this session.** ~~It is almost certainly the same broken measurement as
the `voxel_roots` bucking regression in §2, so do this one first and expect both
to go together.~~ **It was not — see §2.**

The falling trunk gets ONE cylinder in `tree_felling.gd` (~line 2785):

```
cyl.radius = _trunk.radius
cyl.height = _fallen_length
cs.position = Vector3(0.0, _fallen_length * 0.5, 0.0)   # meshes re-origined on the hinge
```

Two candidate causes, and they are distinguishable by ONE measurement:

1. **`_fallen_length` is the TIMBER only.** It was changed on 2026-07-29 to
   measure the union of the meshes actually coming down, deliberately excluding
   leaf cards — tree_01's authored trunk is 8.82 m of a 13.59 m tree. If the
   collider covers only the wood, everything above it has nothing holding it up.
2. **Frame mismatch.** `_fallen_length` may be measured in the trunk's own frame
   while the collider is positioned from the HINGE, which would leave the
   cylinder short by the break height.

**The diagnostic:** at the moment of detach, print `_fallen_length` against the
AABB of the falling node's meshes *in the body's own frame*. If the AABB's height
matches `_fallen_length` but starts at a non-zero Y, it is (2). If the AABB is
much taller, it is (1).

**If it is (1), do NOT simply lengthen the cylinder to the canopy.** Leaves must
not hold a trunk up. Separate the two ideas: keep `_fallen_length` as the timber
length (bucking, `_min_log`, the A3 size tier, tip speed and the landing debris
line all read it and are correct) and give the collider its own span covering the
WOODY crown but not the leaf cards.

---

## 2. ~~FINISHING~~ `voxel_roots` — **DONE, AND IT IS ON** (2026-07-31)

> Sam: *"I want to be able to cut all the way down to the roots on the trunk, get
> that working."* It is on, and M5 is **198/203** with it — better than the 197 it
> scored with the switch off. Full write-up in CLAUDE.md, "THE AXE REACHES THE
> ROOTS". The short version of what the sections below got wrong:
>
> - The real blocker was **the STUMP collider**, which is not mentioned below at
>   all: a stump cut low is shorter than the old fixed neck band, so the neck
>   became the whole stump and the base collider was never built. It is a stack of
>   measured slabs now.
> - **Neither named failure below was a roots bug.** Bucking is provably identical
>   with the switch on and off; the test was halving a log, which cannot reach the
>   target by construction. "Solid timber" was a ray at one height, which stopped
>   meaning anything once the notch could remove wood at ankle height.
> - The roots' **bark** (triplanar) was already fine. What was actually broken was
>   the **end-grain round on cut faces in the flare** — the third overflow of that
>   same mapping. It is fitted PER LEVEL now.
> - One real behaviour change, and it is Sam's to accept: **cutting into the flare
>   gives an uncontrolled fall**, because a buttressed section is strong enough
>   that the player severs it before the load model fails it. Cutting at the
>   lowest allowed height fells both species with an intact hinge.

### The original analysis, kept because most of it was wrong in a useful way

**Re-measured 2026-07-30 with §1 fixed. Turning it on gives M5 194/203, and its
two named failures are still there:**

- `a trunk bucks out into about buck_target_logs logs (1 cuts for a target of 5)`
- `...and it is solid timber, not scenery you can walk through`

...plus `there was still holding wood when it went — the cut did not go clean
through` and a hinge measuring **0.000 m** of a 1.02 m trunk.

~~Both are length/collider measurements, i.e. §1.~~ **They are not.** With the
switch on, `trunk_collider_probe` (set `VOXEL_ROOTS := true`) reports the falling
trunk's collider containing the wood to 2.0% / worst 0.139 m on tree_02 and 0.3% /
0.075 m on tree_01, with the lowest wood vertex ABOVE the dirt in both cases. The
collider is fine. So:

- **A hinge of 0.000 m means the tree is being cut CLEAN THROUGH rather than
  hinged over.** With the flare inside the field, `band_lo` is the ground and the
  bottom levels are far wider — the load model's per-level areas, `_base_area`
  baselines and `_void_height` gating are all measured over a band whose shape has
  changed a lot. That is where to look, not at any length.
- **"solid timber, not scenery"** is a ray at ANKLE HEIGHT (y = 0.2) across the
  STUMP, on the timber layer — so it is `_build_stump_body` under a band that now
  starts at `ground_y`, and it is probably downstream of the break height the
  point above produces.
- The **bucking** failure follows the same trail: one cut means
  `_is_cuttable`/`_min_log` are being fed a trunk that broke somewhere unexpected.

Its own original blocker is untouched and still the reason the switch ships OFF:
**the roots' bark mapping** (`WoodVolume.root_mat`, triplanar) is built but not
verified, and the band's cylindrical wrap degenerates into contour banding on a
buttress.

### What is already done (do not redo it)

- `WoodVolume._fill_from_mesh` + `_sweep` — three axis sweeps, each line bucketed
  by grid footprint, taking the minimum distance and the majority sign. Three
  axes because one is not enough for either half: a vertical sweep finds the
  daylight under an arch but leaves a buttress's SIDES stair-stepped.
- `TreeTrunk` starts the band at `ground_y`, emits no Roots piece, skips the
  bottom rim inset (nothing laps over the band's foot any more) and widens
  `band_max_radius` to the flare via `_flare_max_radius` — **the one measurement
  that must not be clamped to the stem, or the buttresses fall off the grid.**
- `WoodVolume.root_mat` — TRIPLANAR bark for the flare, built per tree from the
  trunk's own bark material at its own fitted density, so the roots match the
  stem's bark scale with no number supplied. The band's cylindrical wrap
  degenerates into contour banding on a root (it swings through a huge range of
  bearings at almost no change of height); triplanar has no axis and no such
  failure.
- `_build_profile(..., skip_below)` — the bark fit ignores the flare. Extending
  the band to the ground made it measure the ROOTS again and fed the artist's
  root-island UVs into the wrap, which is the identical failure the leaf cards
  caused on 2026-07-29.

### A REAL BUG this exposed, worth keeping in mind

A blow probed for the wood's face starting at **2.5× the STEM's radius**. The
flare reaches 2.8×, so the probe began INSIDE the wood, `first_solid` reported a
face out where it started, the slab was built entirely outside the trunk, and the
blow removed nothing — tree_01 became unchoppable while tree_02 was fine.
`_cut_slab` now sizes its probe, its back plane and its scan box off
`band_max_radius`. **Any future widening of the band must check this.**

### Still unexplained

A thin banded ring at the flare shoulder. It is **not** the bark wrap — three
separate routing changes (height rule, normal rule, straddling-quad rule) did not
move it at all. Do not assume it is a UV problem; find out what surface those
pixels belong to first, by flagging surfaces with a flat unshaded material the
way `bark_ab_shot` already does for the roots and the cut cap.

---

## 3. The seam that is NOT worth another ramp

`_root_top` / `crown_base` hand-overs. **Five arrangements were measured on
2026-07-30 and every one traded one visible edge for another:**

1. inset the band under the imported piece (shipping)
2. pin the band's radius to the profile the field was built from — moved the line
3. pin it to the imported piece's own rim vertices — killed the line, tore the
   surface for two cells around it
4. invert the bottom ramp — killed the crack, gave the roots' rim a dark overhang
5. **interpenetration** (band outside the rim, inside deeper, so they cross) —
   structurally the only sound one, and it MEASURED WORSE: +0.0110 against the
   shipping +0.0080, because the outset needed to bury a rim is itself a ridge

**Why none can work:** surface nets is a DUAL method — its vertices sit inside
cells, never on the isosurface — so the band cannot be made to pass through the
imported mesh's rim by construction. Two independently generated surfaces must
hand over somewhere and whichever is outermost shows its rim. `voxel_roots` is
the answer at the bottom because it removes the hand-over entirely. The CROWN
join is left alone deliberately: it sits at 3.46 m, well above the 1.65 m
eyeline, and **that is why `band_height_max` must not be shortened** — at 1.5 m
it drops to 1.96 m, straight into view.

---

## 4. Measurement traps that cost real time here

Every one of these produced a confident wrong answer. They are the reusable part.

- **Reproduce the VERB in the report.** Sam said "after it is cut"; the tool
  rendered a tree that had been built but never struck. Different picture.
- **Frame it the way the player sees it.** A 5 cm strip shot from 2.6 m looking
  down reads as a hairline. Level with a horizontal ring you see an edge; from
  above you see its whole width.
- **Dev tools that pin their own tuning must pin the SHIPPING values** when the
  question is "what does the player see". Testing with a 6.5 cm gouge hid a bug
  that only appears with `tree_felling.tscn`'s own 3 cm bite.
- **`TreeTrunk._remesh()` only rebuilds chunks a BLOW marked dirty.** Changing a
  rendering knob and calling it re-meshes NOTHING, and the A/B comes out as two
  identical pictures. Use `bark_ab_shot._force_remesh`. This silently invalidated
  two comparisons.
- **Measure art against its VERTICES, not against rays.** A ray-cast probe
  reported the trunk's UV unwrap repeating twice per turn — coherent, plausible,
  and wrong. A whole sector-aware unwrap was built on it before the mesh's own
  vertices showed it wraps once. Reverted in full.
- **26 samples is not a measurement.** These trunks are lofted prisms with rings a
  metre apart, so a whole band holds only a few dozen vertices. Sample triangle
  CENTROIDS.
- **Never measure a fallen trunk with `xform * mesh.get_aabb()`** (added
  2026-07-30). Transforming an AABB gives the box bounding the ROTATED BOX, not the
  rotated mesh, so a horizontal trunk reads as metres deeper than it is — it
  invented 0.37 m of sinking that was not there, twice. Sample VERTICES.
- **Ask whether a collider CONTAINS the wood, not whether it SPANS it.** The whole
  of §1 hid behind a span that was exactly right. A check that only proves a
  collider exists (`_has_shape`) passes for one sitting beside the timber.
- **A collider is a COMPOUND now.** Anything reading one `CollisionShape3D` out of a
  body is asking the wrong question — that broke `_log_length`, `_log_span` and
  `debug_buck`'s default cut point, and it was the only regression the §1 fix
  produced.
- **A dev tool can go stale and still produce pictures.** `tree_shot` had been
  rendering a STANDING tree for five days (it drove a back cut PASS 6 deleted), and
  its fall frames were byte-identical. If two shots that should differ don't, check
  the tool before believing the result.
- **Before blaming a feature for a failing check, run the check's own operation
  with the feature OFF** (added 2026-07-31). Two of `voxel_roots`' three named
  blockers were the checks: bucking behaved identically either way, and "solid
  timber" was a single-height ray asking a question a 1.8 m capsule answers
  differently. `roots_probe` exists to run exactly that A/B.
- **A test whose STRATEGY cannot reach its own target is not measuring the
  target.** The bucking check halved a log repeatedly, which caps out at four
  pieces against a target of five; it passed on a floating-point hair. Drive the
  operation the way the spec describes it.
- **When one global constant has to serve a range, render BOTH ends.** Fitting the
  end-grain round to the stem clamped flare cuts to white; fitting it to the flare
  left stem cuts dark and ringless. Only the pictures showed the second one.
- **Profile the blow before believing a cost claim** (2026-07-31). CLAUDE.md said a
  blow was "~26-40 ms, invisible inside the A11 hit-pause". It was 84-350 ms by the
  time Sam played it, and nothing had re-measured since the claim was written.
  `core/tools/felling_profile.tscn` takes one minute.
- **A per-item call inside a per-burst loop is where the spikes live.**
  `_retire_old_debris` is a whole-list pass that can rewrite a MultiMesh, and it was
  called once per chip — twelve times a blow for one blow's worth of debris. Once a
  frame instead, and every 300 ms spike disappeared.
- **`bark_ab_shot` is currently producing byte-identical before/after pairs** and
  cannot be trusted for the imported-vs-voxel comparison; `butt_shot`'s
  `_1_preview_imported` / `_2_built_lowcut` does work. Same stale-tool family as
  `tree_shot` above — if two shots that should differ don't, suspect the tool.

---

## 5. Tools

New this session, all following the `core/tools/` pattern:

- **`bark_ab_shot.gd/.tscn`** — the same tree from the same camera before and
  after the band replaces its trunk; a `join` and a `down` framing at the
  hand-over; a chop with the SHIPPING cut settings; and one-run A/Bs of the grain
  routing. Sets `prebuild_stand = false`, because the game ships it on precisely
  so there is no "before" to shoot.
- **`bark_uv_probe.gd/.tscn`** — the band's bark mapping against the source's own
  vertices, and the radial step at the join. Reports the MEAN signed u error as
  degrees round the trunk, because a systematic offset is a rotation and reads
  completely differently from noise.
- **`eager_build_probe.gd/.tscn`** — what voxelising the whole stand costs.
- **`roots_probe.gd/.tscn`** (2026-07-31) — each species with `voxel_roots` off and
  then on, side by side: band, grid, aim range, the per-level areas and reaches the
  load model reads, a per-blow trace tagged HINGE or COLLAPSE, the break, the whole
  bucking sequence, and the stump's collider with rays through it. `AIM_AT` at the
  top picks between "as low as the game allows" and a fixed height. **This is the
  tool for any question of the form "is X caused by the roots?"**
- **`trunk_collider_probe.gd/.tscn`** (2026-07-30) — fells each species and asks
  whether the falling trunk's collider CONTAINS its wood in the body's own frame,
  then where the lowest wood vertex settles. Swaps the legacy single cylinder back
  in mid-fall, so the A/B is one run and one asset. `VOXEL_ROOTS` at the top
  measures §2's config.

Existing and still the right tools: `butt_shot` (the foot of a tree),
`seam_layers` (band and crown separately), `probe_tree` (the field as ASCII).

---

## 6. Open, and Sam's to decide

- `cut_wood_tint` is a placeholder that stops the clipping; it is not tuned.
- `pine_tree.tres` yields 4 `pine_log` against a `buck_target_logs` of 5, so the
  fifth log books nothing. Deliberate and invariant-safe, but the two numbers
  visibly disagree.
- `tree_felling.tscn` still has `cut_span = 0.50`, which cannot fell either trunk
  (`_warn_cut_span` says so at spawn).
- The five standing M5 failures want a deliberate rebaseline against current art
  and current tuning, not silent edits.
- **Cutting into the root FLARE gives an uncontrolled fall** (2026-07-31). A
  buttressed section is strong enough that the player severs it before the load
  model fails it — measured on tree_01 at 0.5 m: 0.20 m² left at stress 0.35, then
  clean through three blows later. Realistic, and the manual's own reason for
  notching above the flare, but Sam may want it softer. Levers are
  `crush_strength_kpa`, `bend_strength_kpa`, `fail_stress`, `bite_depth`. Cutting
  at the LOWEST allowed height fells both species with an intact hinge, so it is
  the flare's shoulder specifically.
