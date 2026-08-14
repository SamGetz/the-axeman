# Testing and verification

Run Godot commands from the inner `the-axeman/` directory. On Sam's Mac:

```bash
GODOT=/Users/sgetz/Downloads/Godot.app/Contents/MacOS/Godot
```

## Survivors pivot — Slice 2 gate

```bash
"$GODOT" --headless --path . res://core/tests/survivors_progression_slice1_acceptance.tscn
"$GODOT" --headless --path . res://core/tests/survivors_home_ui_acceptance.tscn
"$GODOT" --headless --path . res://core/tests/xp_delivery_acceptance.tscn
"$GODOT" --headless --path . res://core/tests/run_power_offer_acceptance.tscn
"$GODOT" --headless --path . res://core/tests/survivors_stage_ui_acceptance.tscn
"$GODOT" --headless --path . res://core/tests/survival_run_acceptance.tscn
"$GODOT" --headless --path . res://core/tests/survival_main_smoke.tscn
"$GODOT" --headless --path . res://core/tests/survival_cut_journal_acceptance.tscn
"$GODOT" --headless --path . -s res://core/tools/test_slicer.gd
"$GODOT" --headless --path . --editor --quit
```

Current result (2026-08-14):

| Gate | Result |
|---|---:|
| Slice 1 catalogues/profile/banking/save/migration | 106/106 |
| Home hub production UI, persistence, and suspended locks | 23/23 |
| Run XP and reward-flight authority | 21/21 headless; 24/24 rendered |
| Run-power choices, utilities, save determinism, six slots | 27/27 headless; 30/30 rendered |
| Timed stage, explicit endless/cash-out, and results UI | 25/25 |
| Survival ownership and lifecycle regression | 40/40 |
| Production Main startup/Home/arena/HUD/death smoke | 11/11 |
| Real active-cut journal restore | 6/6 |
| Runtime slicer | 34/34 |
| Editor import and script parse | PASS |

The acceptance suites use isolated `user://` paths and clean them afterward.
Slice 1 covers atomic purchase/refund/banking, exact signal counts, disk retry,
Blueprint conversion, malformed data, required legacy backup failure,
interrupted replacement recovery, v18/v17/v16/v14/v1 fixtures, and typed root
identity/reward validation. The expected forced-backup error line is part of a
passing negative-path test.

Slice 2 covers production Home navigation and locks, the 20-minute stage clock,
cash-out/failure/exact-once banking, explicit Endless continuation, run XP and
serial choices, three/four-card offer sizing, reroll/banish, the six-slot rule,
saved cards/RNG, and the two reward-flight destinations. Rendered runs also
capture the visible flight/arrival states and verify 1280×720 outputs.

## Later gates

Do not use the old mature-Earth pacing probe as evidence for the new stage. Its
Harvest Capacity/splitter model is historical. Slices 3–5 add shared-root
geometry stress, boss/power acceptance, pacing probes, performance stress,
fresh-import validation, and the remaining release capture matrix described in
the approved pivot plan.

## Historical suites

Older M7B–M15, company, logistics, contracts, mastery, launch, alien, Frontier,
skill-tree, and equipment-proc suites describe retired progression. Keep them as
history/migration evidence; do not add compatibility behavior to make their old
purchase or permanent-XP expectations live again.
