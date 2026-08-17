# Testing and verification

Run every command from the inner `the-axeman/` project directory. On Sam's Mac:

```bash
GODOT=/Users/sgetz/Downloads/Godot.app/Contents/MacOS/Godot
```

Use `--rendering-method gl_compatibility` for the project renderer.

## Current logic matrix

```bash
"$GODOT" --headless --path . --rendering-method gl_compatibility res://core/tests/survivors_progression_slice1_acceptance.tscn
"$GODOT" --headless --path . --rendering-method gl_compatibility res://core/tests/survivors_home_ui_acceptance.tscn
"$GODOT" --headless --path . --rendering-method gl_compatibility res://core/tests/xp_delivery_acceptance.tscn
"$GODOT" --headless --path . --rendering-method gl_compatibility res://core/tests/run_power_offer_acceptance.tscn
"$GODOT" --headless --path . --rendering-method gl_compatibility res://core/tests/run_power_icon_acceptance.tscn
"$GODOT" --headless --path . --rendering-method gl_compatibility res://core/tests/run_power_runtime_acceptance.tscn
"$GODOT" --headless --path . --rendering-method gl_compatibility res://core/tests/boss_stack_acceptance.tscn
"$GODOT" --headless --path . --rendering-method gl_compatibility res://core/tests/survivors_stage_ui_acceptance.tscn
"$GODOT" --headless --path . --rendering-method gl_compatibility res://core/tests/survival_run_acceptance.tscn
"$GODOT" --headless --path . --rendering-method gl_compatibility res://core/tests/survival_main_smoke.tscn
"$GODOT" --headless --path . --rendering-method gl_compatibility res://core/tests/survival_cut_journal_acceptance.tscn
"$GODOT" --headless --path . --rendering-method gl_compatibility res://core/tests/chopping_acceptance.tscn
"$GODOT" --headless --path . --rendering-method gl_compatibility res://core/tests/log_material_acceptance.tscn
"$GODOT" --headless --path . --rendering-method gl_compatibility res://core/tests/reward_audio_acceptance.tscn
"$GODOT" --headless --path . --rendering-method gl_compatibility res://core/tests/survival_performance_stress.tscn
"$GODOT" --headless --path . --rendering-method gl_compatibility -s res://core/tools/test_slicer.gd
"$GODOT" --headless --path . --rendering-method gl_compatibility --editor --quit
python3 tools/audio/validate_sfx.py
```

## Verified baseline — 2026-08-17

| Gate | Result |
|---|---:|
| Profile, catalogues, banking, saves, migration, and retired-row refunds | 102/102 |
| Home, Level Select, Power Up grid, persistence, and attempt locks | 26/26 |
| Run XP and reward-flight authority | 21/21 |
| Power offers, utility actions, quality, slots, and deterministic restore | 42/42 |
| Distinct 27-power icon catalogue | 2/2 |
| All powers, whole-log destruction, fragments, magnet, handoff, and restore | 57/57 |
| Five-root boss stack, rewards, order, counter, camera, and restore | 18/18 |
| Stage pause, Endless/cash-out, and results | 25/25 |
| Survival ownership, curve sampling, and lifecycle | 45/45 |
| Production Main startup/Home/arena/HUD/death/handoff smoke | 22/22 |
| Active-cut journal restore | 6/6 |
| Runtime chopping and finished-piece sink | 60/60 |
| Species/material catalogue | 25 species; 21 placeholder rows; 41 textures |
| Reward plans and exactly 23 live audio cues | 39/39; 34 WAV assets valid |
| Dense-run bounded-resource stress | 6/6 |
| Runtime slicer | 34/34 |
| Editor import and script parse | PASS |

The progression suite intentionally prints one forced-backup failure while
testing the negative path; it still must finish 102/102. Godot may report
engine RID/ObjectDB residue at process exit in several headless scenes; use the
explicit pass/fail totals as the suite result.

## Coverage focus

The power runtime gate covers all 27 identities from Rank 1, uniform identity
sampling, quality-adjusted values, Area Size, atomic loose-root destruction,
two-to-six fragments, exact reward attribution, Crosscut stump completion,
Timber Burst chaining, Yard Magnet pulse state, Splitter Rig transfer, and
suspend/restore. Compound-rotated roots verify that fragment planes remain in
the mesh-local X/Z frame.

The profile gate owns current-version validation plus v18/v17/v16/v14/v1
migration fixtures. These are the only retained historical fixtures because
they protect value-bearing compatibility. Retired milestone acceptance suites
must not be restored to make removed gameplay behavior live again.

## Visual verification

Headless logic is insufficient for geometry, materials, animation, camera
composition, or menu layout. Use the current review tools under `core/tools/`
and inspect their `/private/tmp/axeman_*.png` outputs at 1280×720. Relevant
checkpoints include startup/Home, level offers, the six-slot HUD, boss stack,
Sawblade/Area Size, Splinter Volley, final-minute pressure, and finished billet
hold/sink/gone states.
