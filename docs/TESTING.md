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
| M8 Slice 2 | 45/45 |
| Slicer | 34/34 |

M1 deliberately exercises error paths; expected red engine messages are not
failures. Treat lines beginning with `FAIL:` as failures.

`pile_smoke.tscn` and render/shot tools must run non-headless. The pile check
depends on the real animation clock, while shot tools require a renderer. Visual
or geometry changes should run their focused shot tool and be inspected, not
only asserted numerically.

On a fresh clone, run the import pass twice before trusting test results:

```bash
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . --import
```

Also import after adding a new `class_name`, because headless suite runs do not
refresh the global script class cache. See `SETUP.md` only for full machine
bootstrap and engine-install details.
