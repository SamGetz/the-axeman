# Testing and verification

Run all Godot commands from the inner `the-axeman/` directory. The repository
root has no `project.godot`; running there can open the project manager and exit
without executing the requested suite.

Set `GODOT` to the Godot 4.7.1 executable for the current machine, then run:

```bash
"$GODOT" --headless --path . --quit-after 900 res://core/tests/m1_acceptance.tscn
"$GODOT" --headless --path . --quit-after 900 res://core/tests/m2_acceptance.tscn
"$GODOT" --headless --path . --quit-after 900 res://core/tests/m3_acceptance.tscn
"$GODOT" --headless --path . --quit-after 20000 res://core/tests/m4_acceptance.tscn
"$GODOT" --headless --path . --quit-after 20000 res://core/tests/m7a_acceptance.tscn
"$GODOT" --headless --path . --quit-after 20000 res://core/tests/m7c_acceptance.tscn
"$GODOT" --headless --path . --quit-after 20000 res://core/tests/m8_acceptance.tscn
"$GODOT" --headless --path . --quit-after 20000 res://core/tests/startup_acceptance.tscn
"$GODOT" --headless --path . -s res://core/tools/test_slicer.gd
```

Latest verified baseline on 2026-08-05:

| Suite | Expected |
|---|---:|
| M1 | 19/19 |
| M2 | 24/24 |
| M3 | 16/16 |
| M4 | 55/55 |
| M7A | 285/285 |
| M7C | 221/221 |
| M8 Slice 5 + measured splitter tuning + discovery | 104/104 |
| Startup New Game / Load Game | 17/17 |
| Slicer | 34/34 |

The focused startup suite drives the production main scene and real save
service. It verifies the dormant/no-autosave menu boundary, disabled Load state,
fresh-game atomic write, explicit progression-and-inventory restore, existing
save confirmation and non-destructive corrupt-save failure. Like M7A, M7C and
M8, it moves any existing player save aside for the run and restores it before
quitting.

`m8_acceptance.tscn` includes the approved 68-check Slice 3 foundation and 25
focused Slice 4 checks for typed cycle data, all six runtime states, one-slot
admission, active-yard timing, exact-once cash/20%-XP settlement, restore safety,
the representative log, five upgrade identities/effects, paced introduction,
greybox presence and HUD presentation.

Slice 5 adds six focused checks for the three-tab shop structure, pre-purchase
functional placement, completed one-time Items and splitter movement, partial
and maxed tiered placement, read-only owned/maxed rows, and restoration derived
from existing building tiers without a purchase-history field.

Focused discovery checks verify that locked splitter shelves and profiles stay
absent, mastery names its certification reward, earning the machine gate reveals
the tab, and installing the machine leaves the earned profile-purchase route
actionable.

The verified 104-check completion run also pins Sam's complete measured splitter
band: machine/profile gates and prices, five-second cycle, one output per
represented log, 50% Speed floor, five Speed ranks, one-time Auto Loading,
5-to-12 Logs per Split, 20-to-100% automation XP and five Money Gain ranks.

M1 deliberately exercises error paths; expected red engine messages are not
failures. Treat lines beginning with `FAIL:` as failures.

`pile_smoke.tscn` and render/shot tools must run non-headless. The pile check
depends on the real animation clock, while shot tools require a renderer. Visual
or geometry changes should run their focused shot tool and be inspected, not
only asserted numerically.

M8's focused non-headless render tool captures fresh shop placement, the
mastery unlock-reward copy, the partially ranked Mechanical Splitter shelf,
the populated Purchased tab, ready, processing and completed cash/XP machine/HUD states to
`/private/tmp/axeman_m8_splitter_*.png`:

```bash
"$GODOT" --path . res://core/tools/m8_splitter_shot.tscn
```

The startup stand-in has a focused non-headless render check which captures the
saved-yard menu and its New Game replacement confirmation without touching the
real save:

```bash
"$GODOT" --path . res://core/tools/startup_shot.tscn
```

The approved reward-feedback checkpoint was also inspected in the production
1280x720 yard: XP orbs advance the live bar edge per receipt, coins remain in the
yard until their exact payout exists and disappear on counter impact, stacked
coin impacts grow the cash counter, and the prewarmed level-up effect surrounds
the workpiece without a first-trigger hitch. These animated checks require a
live play session; the static HUD/startup/M8 tools remain the layout regression
captures.

On a fresh clone, run the import pass twice before trusting test results:

```bash
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . --import
```

Also import after adding a new `class_name`, because headless suite runs do not
refresh the global script class cache. See `SETUP.md` only for full machine
bootstrap and engine-install details.
