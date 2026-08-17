# Chopping area guide

Read this for the active block, slicing, loose logs, arena physics, destructive
run powers, or cut-journal suspension.

## Live owners

- `chopping_minigame.tscn`: active block, axe, runtime slicing, finished pieces,
  XP/Cash presentation, and floor sink.
- `loose_log_arena.gd`: waiting rigid bodies, boundary exposure, warnings,
  block claims, Splitter Rig claims, loose-root power destruction, and fragments.
- `run_director.gd`: delivery cadence, attempt phase, rewards, stage pressure,
  powers, and settlement.
- `survival_run_tuning_placeholder.tres`: shared provisional survival values.

## Delivery and boundary rules

Deliveries are whole physical logs with species, mesh, rewards, and hardness
snapshotted at creation. Each `YardDef` owns linked native interval and amount
curves. Yard One uses a provisional 512-root guard, above two full five-second
breach windows at its maximum authored 50 roots per second.

Crossing the red ring starts one continuous five-second exposure timer; re-entry
resets it. An outside log has block-claim priority by elapsed exposure. With no
outside root, a landed root is selected randomly. If the block is waiting and
no arena root is claimable, the next due delivery drops over the block.

Manual completion pauses boundary exposure only until its replacement visibly
lands. Run time, deliveries, and physics continue. Menus and mandatory choices
pause the run clock, deliveries, arena, chopping, and power hazards together.

## Block and boss behavior

The manual axe is block-only. Hold-to-Chop and Continuous Handoff query live
meta capabilities. Claimed logs use a generation-guarded vertical lift, hidden
X/Z reposition, and eased drop; save preparation canonicalizes an active handoff.

A scheduled boss waits behind the current root, then drops five roots as one
stump stack. Only the top layer collides and accepts cuts. Each completion
promotes the next root and advances the visible `5 → 0` counter. Camera framing
tracks the complete exposed layer and returns to the normal stump pose at zero.

## Off-block destruction

Every destructive power hit against a loose root destroys the whole root
immediately. Count values mean distinct logs, not accumulated cuts. Area/contact
powers destroy every eligible root in their geometry; ordered/count powers stop
after their displayed maximum.

Destruction flashes the root, synchronously builds a deterministic-random two-
to-six real-fragment batch, and awards its snapshotted XP and Cash exactly once.
Fragment planes use randomized log-local X or Z normals, so a rotating rigid body
cannot turn a canonical cut diagonal through its authored ends. Fragments fall
apart locally, settle, become collisionless, and enter the existing sink.

The provisional fragment minimum/maximum live in
`data/survival_run_tuning_placeholder.tres`. Power count, chance, radius, force,
and interval ladders live in `data/run_power_curves_placeholder.tres`.

Only whole waiting logs are boundary hazards. Active descendants and finished
billets do not participate. The Splitter Rig visibly claims one endangered
non-boss root through its dedicated transfer path; the retired permanent
splitter and temporary Blaster no longer exist.

## Rewards and finished pieces

Root completion owns exact-once session Cash and run XP. Finished-piece
inventory settlement still validates through `InventoryManager`, but its coin
or orb is presentation only. Finished billets become collisionless where they
land, remain opaque for five active-play seconds from the final chop, then sink
through the floor and despawn only when fully below it.

## Suspension journal

`LogDescriptor` is the stable root identity. Every successful block cut records
the parent stable piece id and parent-local plane; descendants use stable `/a`
and `/b` paths. Restore rebuilds the original descriptor, replays cuts, and then
reapplies transforms and scars. Do not serialize generated meshes.

New off-block destruction is atomic and never saves partial geometry. Retired
`pending_power_cuts` fields remain read-only migration input for old suspended
attempts.

## Verification

```bash
"$GODOT" --headless --path . res://core/tests/run_power_runtime_acceptance.tscn
"$GODOT" --headless --path . res://core/tests/survival_run_acceptance.tscn
"$GODOT" --headless --path . res://core/tests/survival_cut_journal_acceptance.tscn
"$GODOT" --headless --path . res://core/tests/boss_stack_acceptance.tscn
"$GODOT" --headless --path . res://core/tests/chopping_acceptance.tscn
"$GODOT" --headless --path . -s res://core/tools/test_slicer.gd
```

Geometry or presentation changes also require a rendered checkpoint or editor
inspection; logic tests alone do not validate visual composition.
