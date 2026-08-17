# Chopping area guide

Read this for the active block, slicing, loose logs, arena physics, powerups, or
cut-journal suspension.

## Live entry points

- `scenes/3d_action/chopping_minigame.tscn` owns the active block, axe, runtime
  slicing, firewood, XP/cash presentation, and finished-piece floor sink.
- `scenes/3d_action/loose_log_arena.gd` owns waiting rigid bodies, the red ring,
  per-log outside exposure, warnings, block claims, splitter claims, and blaster
  ray hits.
- `core/run_director.gd` owns arrival cadence, random selection, attempt phase,
  run XP/session cash, stage pressure, choices, and settlement.
- `data/survival_run_tuning_placeholder.tres` is the only survival tuning source.

## Required behavior

- Deliveries are whole physical logs spawned above a sampled clear position.
  Loose bodies collide with the floor and one another.
- Each selectable level is a standalone `data/yards/*.tres` resource. Its native
  interval curve maps run level to seconds between falling waves; its amount
  curve maps run level to whole logs per wave. Yard One begins at
  `2.166667 / 1.7333335 / 1.3666665 / 1.0666665` seconds across its four tier
  scales, reaches two logs at Level 20 and ten at Level 28, and lets the final
  minute/Endless read the curves' `0.2`-second/ten-log rightmost points. The
  provisional physical-root guard is `512`, above two full five-second breach
  windows at the 50-roots/second peak.
- Any out-of-bounds loose log takes block-claim priority, ordered by elapsed
  exposure even if it is still settling. When none are outside, one landed log
  is chosen randomly. Species and mesh were captured at delivery; a later
  catalogue change never reskins them.
- The boundary test uses the body's horizontal centre. Crossing outside starts
  one continuous five-second proposed timer. Re-entry resets it to zero.
- Completing a manual log freezes only boundary exposure until the replacement
  log visibly lands. The run clock, deliveries, and arena physics continue.
- Hold-to-Chop repeats the next legal swing after the authored cooldown while
  the primary button remains held. It reads the permanent capability directly
  from `GameState`; Continuous Handoff independently decides whether that hold
  survives the completed-root transition.
- If the block is waiting and no loose log can be claimed, the next due delivery
  drops directly above the block instead of landing in the yard first.
- A due scheduled boss waits behind the current active root and replaces the old
  single damage-sponge root with five boss-species roots dropped together on the
  stump. Only the top layer owns an active collider or accepts cuts. Completing
  it promotes the next lower root in place until the visible `5 → 0` count is
  exhausted. Ordinary loose deliveries may continue while the stack owns the
  block. The run camera keeps its ordinary distance and FOV, centres the actual
  exposed top-root geometry so the complete root remains in frame, and eases
  downward as each layer is cleared. Finishing the stack returns the camera
  exactly to its normal stump framing.
- Block handoff animation rises vertically at a user-directed provisional 1.75x
  lift duration from the claimed log's ground pose. The arena source is hidden
  synchronously and a snapshot of its actual whole-or-split meshes owns the
  flight. Every mesh corner must clear the top of frame before a brief hidden
  reposition directly over the chopping block, followed by a separate eased
  vertical drop. Handoffs are generation-checked and cancelled on replacement;
  ordinary autosave snapshots the hidden authoritative landing state without
  mutating the live flight, restore canonicalizes it once, and explicit suspend
  lands an active flight before saving.
- Only whole waiting logs are hazards. Active-log descendants and finished
  firewood never participate in the boundary timer, splitter, or blaster.
- Finished firewood settles its authoritative reward immediately, becomes
  collisionless where it landed, remains fully visible for five active-play
  seconds from the final chop, then sinks slowly through the floor while staying
  opaque. It despawns only once fully below the floor. There is no persistent
  chopped stack or haul-away in the live yard; legacy pile/save counters are
  migration-only.
- Menus pause the run clock, deliveries, arena bodies, chopping scene, powerup
  hazards, and splitter together.

## Current interaction boundary

The manual axe interaction remains block-only. Run powers can now slice loose
roots immediately: one physics owner carries real descendant meshes and compound
colliders, each hit flashes white, and its plane uses a deterministically
randomized log-local X or Z normal. A loose root's world tumble cannot rotate
that plane into a diagonal: it always traverses the mesh's true authored top and
bottom. Loose cuts reuse the block's square-
footprint bias, cloven cut-face treatment, fresh-half spacing, and normal
bark/end/cut materials. The fifth successful off-block
slice completes the root, releases its six descendants as individual falling
physics pieces, and bursts its exact-once cash/XP presentation at that world
position. Settled pieces immediately begin the normal collisionless floor sink.
New loose deliveries fall at exactly twice their prior speed. Retired Slow
Time, right-click ammunition, Earth batches, disposable
in-run splitter purchases, and the temporary Blaster still have no live path.

## Suspension journal

`LogDescriptor` supplies the stable root identity. Its v19 extension also has
strict run/yard/boss, hardness, reward, and original-mass snapshots. Typed
`LogRootState`, descendant, and completion-receipt schemas are present, but
the focused run-power arena slice is now live. Successful loose cuts retain
their ordered source receipts; restore deterministically rebuilds their real
X/Z descendant geometry, and a later block claim consumes the same progress.
Every successful block cut appends the parent stable piece id and parent-local
plane. Descendants use stable `/a` and `/b` paths.

Restore stages the original descriptor, replays cuts in order, then reapplies
saved transforms and scars. Do not replace this with saved meshes or a fresh-log
reroll. `prepare_for_suspend()` first cancels an uncontacted swing, completes
authoritative settlement boundaries, and normalises active animation state.

## Reward boundary

The delivered descriptor snapshots its fixed yard cash and XP values. A final
manual split completes the root once: `RunDirector` immediately commits the full
cash snapshot and exact root-XP receipt, independent of visible token survival.
The current user-directed provisional yard table uses nearest-whole `25%` of the
previous Cash rewards and `50%` of the previous XP rewards, including boss
jackpots before their exact five-way division.
Chopping divides cash only into presentation shares. Each finished-piece
settlement performs its validated add/remove through `InventoryManager`, then
releases one share to a coin that targets the prominent session counter; the
subsequent immediate sink is presentation only and cannot mint cash
again. XP orbs target the live fill edge of the HUD bar, and the corresponding
level-choice pause waits for arrival. Cancelling either VFX path settles its
display receipt immediately.

The full generalized shared-root state remains broader than this focused
run-power slice. Craft grades, contracts, species mastery, alien behaviors, and
automated campaign XP/cash do not run.

## Verification

```bash
"$GODOT" --headless --path . res://core/tests/survival_run_acceptance.tscn
"$GODOT" --headless --path . res://core/tests/survival_cut_journal_acceptance.tscn
"$GODOT" --headless --path . res://core/tests/boss_stack_acceptance.tscn
"$GODOT" --headless --path . res://core/tests/m4_acceptance.tscn
"$GODOT" --headless --path . -s res://core/tools/test_slicer.gd
"$GODOT" --path . res://core/tools/survival_visual_shot.tscn
"$GODOT" --path . res://core/tools/finished_firewood_shot.tscn
```

Inspect `/private/tmp/axeman_survival_active.png` for boundary/log readability
and ensure the active block remains unobstructed. Inspect the
`/private/tmp/axeman_finished_firewood_{hold,sink,gone}.png` sequence for the
opaque hold, opaque floor sink, and complete below-floor removal.
Inspect `/private/tmp/axeman_boss_stack.png` for the opening top-root lock and
`/private/tmp/axeman_boss_stack_one.png` for the camera following the final
layer downward. `/private/tmp/axeman_final_minute_flood.png` records the physical
final-minute delivery pressure without changing camera framing.
