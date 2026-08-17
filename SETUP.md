# Setup

Campfire Survivors is a native Godot 4.7 Compatibility project. It has no
package-manager step and no external runtime dependency.

## Requirements

- Godot 4.7.1 stable, standard GDScript build (not .NET/Mono).
- A checkout of this repository.
- A Compatibility-capable graphics driver for rendered review.

The Godot project is the inner `the-axeman/` directory. All engine commands
must run there.

On Sam's Mac:

```bash
export GODOT="/Users/sgetz/Downloads/Godot.app/Contents/MacOS/Godot"
cd the-axeman
```

On another machine, point `GODOT` at that machine's Godot 4.7.1 executable.

## First import

The `.godot/` import cache is generated and gitignored. Build it after a fresh
checkout, and refresh it after adding or renaming a global `class_name`:

```bash
"$GODOT" --headless --path . --rendering-method gl_compatibility --editor --quit
```

The command must complete without parse or resource-load errors. Editor-setting
or local MCP connection messages do not affect gameplay parsing.

## Verify

Run the current command matrix and compare its exact counts with
`docs/TESTING.md`. A quick integration check is:

```bash
"$GODOT" --headless --path . --rendering-method gl_compatibility \
  res://core/tests/survival_main_smoke.tscn
```

Open the project for manual input and rendered-layout review:

```bash
"$GODOT" --path . --rendering-method gl_compatibility --editor
```

## Local state

Player progress lives outside the repository at
`user://the_axeman_save.cfg`. Copy that file separately if progress must move
between machines. The `.godot/` directory is also machine-local and should
never be committed.

The source art under `maya_working/` and the imported runtime art under
`the-axeman/assets/` are both intentional. Git LFS is not currently configured.

## Current documentation

- `AGENTS.md` and `CLAUDE.md`: repository working rules.
- `docs/STATUS.md`: current implementation and retained boundaries.
- `docs/TESTING.md`: current verification commands and counts.
- `docs/areas/`: focused guides for chopping, progression, powers, and assets.

Retired milestone briefs, build diaries, and obsolete acceptance suites are not
kept in the working tree; use git history only when their context is necessary.
