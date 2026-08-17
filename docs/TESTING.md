# Testing and verification

Run Godot commands from the inner `the-axeman/` directory. On Sam's Mac:

```bash
GODOT=/Users/sgetz/Downloads/Godot.app/Contents/MacOS/Godot
```

## Survivors pivot and run-power gate

```bash
"$GODOT" --headless --path . res://core/tests/survivors_progression_slice1_acceptance.tscn
"$GODOT" --headless --path . res://core/tests/survivors_home_ui_acceptance.tscn
"$GODOT" --headless --path . res://core/tests/xp_delivery_acceptance.tscn
"$GODOT" --headless --path . res://core/tests/run_power_offer_acceptance.tscn
"$GODOT" --headless --path . res://core/tests/run_power_icon_acceptance.tscn
"$GODOT" --headless --path . res://core/tests/run_power_runtime_acceptance.tscn
"$GODOT" --headless --path . res://core/tests/boss_stack_acceptance.tscn
"$GODOT" --headless --path . res://core/tests/survivors_stage_ui_acceptance.tscn
"$GODOT" --headless --path . res://core/tests/survival_run_acceptance.tscn
"$GODOT" --headless --path . res://core/tests/survival_main_smoke.tscn
"$GODOT" --headless --path . res://core/tests/survival_cut_journal_acceptance.tscn
"$GODOT" --headless --path . res://core/tests/m4_acceptance.tscn
"$GODOT" --headless --path . -s res://core/tools/test_slicer.gd
"$GODOT" --headless --path . --editor --quit
```

Current result (2026-08-17):

| Gate | Result |
|---|---:|
| Slice 1 standalone level resources, delivery curves, catalogues/profile/banking/save/migration | 108/108 |
| Landing, Level Select, four-column Power Up UI, Home persistence, suspended locks, and rendered layout | 26/26 headless; 27/27 rendered |
| Run XP and reward-flight authority | 21/21 headless; 24/24 rendered |
| Run-power choices, vertical focus flow, utilities, save determinism, compact top-center six slots, offer rain | 42/42 headless; 45/45 rendered |
| All 27 distinct vector icons and full-frame gallery | 2/2 headless; 3/3 rendered |
| All 27 run powers at owned rank one, uniform identity sampling, quality, Area Size/AoE scaling, targeting, off-block slicing/completion, pulsed magnet cadence, delivery handoff, save/restore, and feedback | 60/60 headless; 62/62 rendered |
| Scheduled five-root boss stack, exact rewards, top-down order, save/restore, counter, and top-root camera tracking | 18/18 headless; 20/20 rendered |
| Timed stage, focused pause, explicit endless/cash-out, and results UI | 25/25 headless; 27/27 rendered |
| Survival ownership, per-level curve control, and lifecycle regression | 46/46 |
| Production Main branded startup/Level Select/Home/arena/HUD/death/handoff/final-minute flood smoke | 19/19 headless and rendered |
| Runtime chopping, unlocked held input, finished-piece settlement, and floor-sink lifecycle | 66/66 |
| Real active-cut journal restore | 6/6 |
| Runtime slicer | 34/34 |
| Editor import and script parse | PASS |

The acceptance suites use isolated `user://` paths and clean them afterward.
Slice 1 covers atomic purchase/refund/banking, exact signal counts, disk retry,
Blueprint conversion, malformed data, required legacy backup failure,
interrupted replacement recovery, v18/v17/v16/v14/v1 fixtures, and typed root
identity/reward validation. The expected forced-backup error line is part of a
passing negative-path test.

The production suites cover Home navigation and locks, the 15-minute stage clock,
cash-out/failure/exact-once banking, explicit Endless continuation, run XP and
serial choices, three/four-card offer sizing, reroll/banish, the six-slot rule,
saved cards/RNG, all four per-card quality tiers, persistent tree/log/leaf offer
rain, equal-width vertical card flow, primary-action focus, and the two
reward-flight destinations. Rendered menu checkpoints are written at 1280×720
to `/private/tmp/axeman_home_menu.png`, `/private/tmp/axeman_pause_menu.png`,
`/private/tmp/axeman_results_menu.png`, and
`/private/tmp/axeman_run_power_offer.png`; the startup smoke also writes
`/private/tmp/axeman_startup_menu.png` and
`/private/tmp/axeman_final_minute_flood.png`. The icon gate writes
`/private/tmp/axeman_run_power_icons.png`, and the offer gate writes
`/private/tmp/axeman_run_six_slots.png` after filling the compact active strip.
The run-power runtime suite exercises all 27 powers from owned
rank one, loose-root target selection, multi-cut attribution, automatic cadence,
completion authority, runtime status, the `0.5`-second/`5`-second Rank 1 Yard
Magnet pulse and its saved phase, actual magnetized-body delivery, split-mesh
handoff continuity, compound-rotated loose-root cuts remaining aligned to the
mesh's true top/bottom frame, five-hit completion after canonical firewood-sized
descendants, deterministic nearest-target Splinter Volley count payloads, Flying Wedge's
fixed six-cut/single-root removal and exact payout, the 0.5-second autosave race,
uniform identity sampling independent of quality, Area Size scaling for both
gameplay reach and visible area geometry, Sawblade Halo, Timber Burst,
stale-tween cancellation, and
suspended-attempt restoration.
Earthshaker, Whirling Axe, Crosscut Sweep, Sawblade Halo, and Timber Burst are
also covered as full-completion powers: they apply only a target's remaining
real cuts, preserve unaffected roots, complete Crosscut's active stump root, and
drain Timber Burst chain reactions iteratively.
Rendered checkpoints include `/private/tmp/axeman_area_sawblade.png` and the
mid-flight `/private/tmp/axeman_splinter_volley.png`.

Disposable run XP uses the provisional `1.30×` global gain authored in
`survival_run_tuning_placeholder.tres`. The lifecycle suite verifies ordinary
root snapshots, the power runtime suite verifies composition with Quick Study
and Grain Reader, and the boss suite verifies exact five-way division of the
boosted jackpot.

The native startup review tool writes the CAMPFIRE SURVIVORS fresh-profile,
returning-profile, Level Select, Power Up, suspended-run, and
replacement-confirmation checkpoints to
`/private/tmp/campfire_survivors_startup_new_camp.png`,
`/private/tmp/campfire_survivors_startup_profile_menu.png`,
`/private/tmp/campfire_survivors_startup_level_select.png`,
`/private/tmp/campfire_survivors_startup_power_up.png`,
`/private/tmp/campfire_survivors_startup_suspended_attempt.png`, and
`/private/tmp/campfire_survivors_startup_confirmation.png`.
Rendered runs also capture the visible flight/arrival states, quality layouts,
six-slot icon/rank presentation, action feedback, and the scaled Sawblade Halo
ring at 1280×720. The AoE checkpoint is
`/private/tmp/axeman_area_size_aoe.png`.

The boss-stack suite crosses the real first schedule while an ordinary root is
active, proves that the encounter queues without deleting work, then clears all
five real roots from top to bottom. It covers ordinary level hardness, exact
five-way Cash/XP jackpot division, one Blueprint roll only at zero, active-stack
restore, the `5 → 0` HUD, ordinary distance/FOV, complete exposed-root framing
at every layer, and exact post-stack return to the normal camera.
Rendered checkpoints are `/private/tmp/axeman_boss_stack.png` and
`/private/tmp/axeman_boss_stack_one.png`.

## Later gates

Do not use the old mature-Earth pacing probe as evidence for the new stage. Its
Harvest Capacity/splitter model is historical. Later gates still need measured
pacing/tuning, performance stress, fresh-import validation, and the remaining
release capture matrix.

## Historical suites

Older M7B–M15, company, logistics, contracts, mastery, launch, alien, Frontier,
skill-tree, and equipment-proc suites describe retired progression. Keep them as
history/migration evidence; do not add compatibility behavior to make their old
purchase or permanent-XP expectations live again.
