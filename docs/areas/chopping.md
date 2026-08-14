# Chopping area guide

Read this for the active block, slicing, loose logs, arena physics, powerups, or
cut-journal suspension.

## Live entry points

- `scenes/3d_action/chopping_minigame.tscn` owns the active block, axe, runtime
  slicing, firewood, XP/cash presentation, and visible yard pile.
- `scenes/3d_action/loose_log_arena.gd` owns waiting rigid bodies, the red ring,
  per-log outside exposure, warnings, block claims, splitter claims, and blaster
  ray hits.
- `core/run_director.gd` owns arrival cadence, random selection, attempt phase,
  run XP/session cash, stage pressure, choices, and settlement.
- `data/survival_run_tuning_placeholder.tres` is the only survival tuning source.

## Required behavior

- Deliveries are whole physical logs spawned above a sampled clear position.
  Loose bodies collide with the floor and one another.
- Any out-of-bounds loose log takes block-claim priority, ordered by elapsed
  exposure even if it is still settling. When none are outside, one landed log
  is chosen randomly. Species and mesh were captured at delivery; a later
  catalogue change never reskins them.
- The boundary test uses the body's horizontal centre. Crossing outside starts
  one continuous five-second proposed timer. Re-entry resets it to zero.
- Completing a manual log freezes only boundary exposure until the replacement
  log visibly lands. The run clock, deliveries, and arena physics continue.
- Block handoff animation follows a data-tuned horizontal clearance arc around
  the current camera rather than cutting through the viewer.
- Only whole waiting logs are hazards. Active-log descendants and finished
  firewood never participate in the boundary timer, splitter, or blaster.
- Menus pause the run clock, deliveries, arena bodies, chopping scene, powerup
  hazards, and splitter together.

## Current interaction boundary

The live Slice 2 interaction remains axe-on-block. Retired Slow Time,
right-click ammunition, Earth batches, and disposable in-run splitter purchases
have no live HUD/economy path. Off-block slicing, shared descendants, and the
temporary Blaster arrive together in Slice 3; do not emulate them with the old
impulse or splitter paths.

## Suspension journal

`LogDescriptor` supplies the stable root identity. Its v19 extension also has
strict run/yard/boss, hardness, reward, and original-mass snapshots. Typed
`LogRootState`, descendant, and completion-receipt schemas are present, but
shared arena slicing does not begin until Slice 3. Every successful block cut
appends the parent stable piece id and parent-local plane. Descendants use stable
`/a` and `/b` paths. A snapshot also stores each live descendant transform,
projection offset, and scar records.

Restore stages the original descriptor, replays cuts in order, then reapplies
saved transforms and scars. Do not replace this with saved meshes or a fresh-log
reroll. `prepare_for_suspend()` first cancels an uncontacted swing, completes
authoritative settlement boundaries, and normalises active animation state.

## Reward boundary

The delivered descriptor snapshots its fixed yard cash and XP values. A final
manual split completes the root once: `RunDirector` immediately commits the full
cash snapshot and exact root-XP receipt, independent of visible token survival.
Chopping divides cash only into presentation shares. Each finished-piece landing
performs its validated add/remove through `InventoryManager`, then releases one
share to a coin that targets the prominent session counter; it cannot mint cash
again. XP orbs target the live fill edge of the HUD bar, and the corresponding
level-choice pause waits for arrival. Cancelling either VFX path settles its
display receipt immediately.

Slice 3 moves block and loose descendants onto the full shared-root completion
transaction. Craft grades, contracts, species mastery, alien behaviors, and
automated campaign XP/cash do not run.

## Verification

```bash
"$GODOT" --headless --path . res://core/tests/survival_run_acceptance.tscn
"$GODOT" --headless --path . res://core/tests/survival_cut_journal_acceptance.tscn
"$GODOT" --headless --path . -s res://core/tools/test_slicer.gd
"$GODOT" --path . res://core/tools/survival_visual_shot.tscn
```

Inspect `/private/tmp/axeman_survival_active.png` for boundary/log readability
and ensure the active block remains unobstructed.
