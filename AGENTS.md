# The Axeman — Codex instructions

The Godot project is in `the-axeman/`. It uses Godot 4.7 Compatibility and
GDScript/native nodes. The game is a cozy log-cutting and lumberyard progression
game. Tree felling, mining, explorable forests, villagers, and staff rosters are
retired unless Sam explicitly restores them.

- Preserve existing work; inspect `git status --short` and overlapping diffs
  before editing.
- Do not fetch or pull for read-only requests. Never pull, switch branches,
  commit, or push unless the task calls for it and the worktree is safe.
- Do not invent final tuning values. Put labelled placeholders in `.tres`
  resources and surface them to Sam.
- Inventory writes belong in `InventoryManager`; progression writes belong in
  `GameState` or its public signal flow.
- Work on only the requested module or slice. Do not begin the next milestone
  without approval.
- Search `the-axeman/core`, `the-axeman/data`, and `the-axeman/scenes` first.
  Ignore `.godot`, `*.import`, binary art, Maya sources, and
  `addons/godot_mcp` unless relevant.
- Run Godot commands from the inner `the-axeman/` directory.
- On Sam's Mac, use the Godot executable at
  `/Users/sgetz/Downloads/Godot.app/Contents/MacOS/Godot`.
- Test logic changes and render/inspect visual or geometry changes.

Read only the relevant route:

- Status: `docs/STATUS.md`
- Tests/setup: `docs/TESTING.md`
- Chopping: `docs/areas/chopping.md`
- Progression: `docs/areas/progression.md`
- Skills/procs: `docs/areas/skills.md`
- Art imports: `docs/areas/assets.md`

Live code, resources, and tests outrank prose.
