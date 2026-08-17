# The Axeman — agent instructions

Keep this file lean: it is loaded into every Claude session. Do not add build
diaries, bug post-mortems, full test output, tuning discussions, or retired
designs here. Put current task-specific guidance under `docs/areas/` and current
status in `docs/STATUS.md`.

## Project

Campfire Survivors is a cozy Godot log-cutting survival/progression game. Manual
chopping is the central interaction: timed log deliveries pressure the yard,
temporary run powers create controlled chaos, and completed roots pay run XP
and session cash that can be banked into permanent Home upgrades.

- Engine: Godot 4.7 stable.
- Renderer: Compatibility (`gl_compatibility`).
- Runtime language: GDScript and native Godot nodes.
- Godot project root: `the-axeman/` inside this repository.
- `addons/godot_mcp` is editor/inspection tooling. Do not treat it as gameplay
  code or edit it unless the task is specifically about that tooling.

Tree felling, ore mining, explorable forests, villagers, and staff rosters are
retired. Do not restore or replace them without Sam's explicit direction.

## Authority and context loading

Use this precedence when sources disagree:

1. Sam's instruction in the current conversation.
2. The live code, resources, and tests.
3. Current summaries in `docs/STATUS.md` and `docs/areas/`.
4. Git history when an old decision is directly relevant.

Load only the task-specific document named in the routing table below. Inspect
the relevant code and tests before trusting prose that duplicates them.

For ordinary code searches, start in `the-axeman/core/`, `the-axeman/data/`,
and `the-axeman/scenes/`. Exclude `.godot/`, `*.import`, binary assets,
`maya_working/`, and `the-axeman/addons/godot_mcp/` unless the task concerns
imports, art, Maya sources, or MCP tooling.

## Working rules

1. Preserve user work. Before editing, run `git status --short` and inspect any
   overlapping diff. Never discard or overwrite unrelated changes.
2. Do not fetch or pull merely to answer, explain, inspect, or diagnose. Before
   substantial implementation, check branch state and fetch only when remote
   freshness matters. Never pull, switch branches, commit, or push unless the
   task calls for it and the worktree is safe.
3. Work on one approved module or slice at a time. Do not start the next module
   because the current one appears complete.
4. Sam owns final artistic and mathematical tuning values. Use clearly labelled
   placeholders in `.tres` resources when implementation must proceed; do not
   hardcode invented final values.
5. Verify uncertain APIs against Godot 4.7 Compatibility before using them.
   Unsupported or banned for gameplay: real DOF/CameraAttributes, volumetric
   fog, SDFGI, DirectionalLight projectors, and runtime CSG/mesh booleans.
   Runtime plane slicing in the chopping game is the approved exception.
6. Inventory mutations belong in `InventoryManager`. Progression mutations
   belong in `GameState`, through its public methods or EventBus flow. Other
   systems query them read-only.
7. Keep scripts and scenes consistent with the project's existing path/node
   header conventions. Do not duplicate canonical files outside
   `the-axeman/`.
8. Add regression coverage proportionate to the change. A new regression guard
   should be shown to fail without its fix when practical. Visual changes also
   require a render or non-headless inspection; numeric tests alone are not
   enough for geometry, animation, materials, or composition.

## Frozen implementation invariants

- Main hierarchy: `Main(Node)` -> `UI_Canvas(CanvasLayer)` ->
  `SubViewportContainer` -> `Action_Viewport(SubViewport 1280x720)` ->
  `3D_World_Root(Node3D)`. Gameplay UI belongs in sibling
  `UI_Overlay(CanvasLayer, layer 2)`.
- The viewport, base canvas, and window are 1280x720. The viewport uses 4x MSAA,
  anisotropic filtering level 3, and nearest canvas filtering.
- `Enums` is a `class_name`, never an autoload. Its live scope is
  `ChopDirection { LEFT, RIGHT, UP, DOWN }`.
- EventBus's existing cross-boundary signal contract is frozen. Prefer local
  signals or current public APIs over adding global signals. If a genuine
  contract change is required, stop and propose it to Sam before editing.
- In 2D mode, disable the action viewport's updates and the 3D world's
  processing; restore them on `minigame_entered`.
- Hit pause uses an ignore-time-scale timer and must guard overlapping pauses.
- Settled fragments freeze, and active rigid-body counts remain bounded.
- Species selection is data-driven through `data/species_table.tres`. A species
  may own multiple meshes; pick species first and shape second so art variety
  does not distort species probability.
- Logs are not inventory items. Root completion owns exact-once session Cash
  and run-XP rewards; finished billets retain the inventory validation seam.
- Session Cash cannot be spent in a run. Banked Home Cash buys permanent
  upgrades, while temporary powers come only from run level-up choices.

## Current status

The live loop is the survivors progression pivot documented in
`docs/STATUS.md`: Home, yard selection, timed/endless runs, run XP/offers, 27
temporary powers, boss stacks, settlement, and save migration. Retired campaign,
company, equipment, SkillTree, and tutorial implementations have been removed;
only bounded save-migration data remains.

Latest verified suite counts and commands live in `docs/STATUS.md` and
`docs/TESTING.md`; do not copy growing test histories back into this file.

## Read only when relevant

| Task | Read |
|---|---|
| Current milestone, known gaps, latest suite counts | `docs/STATUS.md` |
| Running tests or setting up another machine | `docs/TESTING.md`, then `SETUP.md` if needed |
| Runtime slicing, chopping, fragments, axe, finished-piece sink, or visual test tools | `docs/areas/chopping.md` |
| Cash, saves, inventory, orders, species ownership, or the yard HUD | `docs/areas/progression.md` |
| Run XP, power curves, run powers, quality, grain cues, or Follow-Up | `docs/areas/skills.md` |
| FBX, materials, textures, Maya, or art imports | `docs/areas/assets.md` |
| Why an old decision was made | git history |

## Test discipline

Run Godot commands from the inner `the-axeman/` directory, which contains
`project.godot`. Running `godot --path .` from the repository root can open the
project manager and exit successfully without running the requested scene.

After adding a new `class_name`, run a Godot import pass so the global class
cache is refreshed. `--check-only` may report missing autoload identifiers;
use the relevant scene suite for integration confidence. Rendered layout and
geometry checkpoints require a non-headless run.
