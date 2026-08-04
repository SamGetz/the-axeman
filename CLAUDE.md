# The Axeman — agent instructions

Keep this file lean: it is loaded into every Claude session. Do not add build
diaries, bug post-mortems, full test output, tuning discussions, or retired
designs here. Put current task-specific guidance under `docs/areas/`, current
status in `docs/STATUS.md`, and historical narrative in `docs/history/`.

## Project

The Axeman is a cozy Godot log-cutting and lumberyard progression game. Manual
chopping is the central interaction: logs arrive on the block, the player cuts
them into firewood, and that work becomes stock, orders, cash, reputation,
skills, and a visibly growing yard.

- Engine: Godot 4.7 stable.
- Renderer: Compatibility (`gl_compatibility`).
- Runtime language: GDScript and native Godot nodes.
- Godot project root: `the-axeman/` inside this repository.
- `addons/godot_mcp` is editor/inspection tooling. Do not treat it as gameplay
  code or edit it unless the task is specifically about that tooling.

Tree felling, ore mining, explorable forests, villagers, and staff rosters are
retired. Do not restore or replace them without Sam's explicit direction.
Regions may supply logs; automation may process already-known species.

## Authority and context loading

Use this precedence when sources disagree:

1. Sam's instruction in the current conversation.
2. The live code, resources, and tests.
3. Current summaries in `docs/STATUS.md` and `docs/areas/`.
4. Approved roadmap material when the task is roadmap or scope planning.
5. `handoff/`, `docs/history/`, old test counts, and git history are background
   only. They are not current implementation authority.

Do not read the handoff pack or roadmap files by default. Load only the one
task-specific document named in the routing table below. Inspect the relevant
code and tests before trusting prose that duplicates them.

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
- `Enums` is a `class_name`, never an autoload. Current enum scope is wood-only:
  `ItemCategory { RAW_WOOD, REFINED }`, `ToolType { AXE }`, and wood-supply
  biomes only.
- EventBus's existing cross-boundary signal contract is frozen. Prefer local
  signals or current public APIs over adding global signals. If a genuine
  contract change is required, stop and propose it to Sam before editing.
- The only size-tier test is
  `piece.size_tier > GameFeelConfig.size_threshold`.
- In 2D mode, disable the action viewport's updates and the 3D world's
  processing; restore them on `minigame_entered`.
- Hit pause uses an ignore-time-scale timer and must guard overlapping pauses.
- Settled fragments freeze, and active rigid-body counts remain bounded.
- Species selection is data-driven through `data/species_table.tres`. A species
  may own multiple meshes; pick species first and shape second so art variety
  does not distort species probability.
- Logs are not inventory items. Chopping yields registered `*_firewood` items.
- Cash buys world objects and supplies; skill points buy player capability.
- Machines may process a mastered/certified species but may not discover,
  master, certify, or award Axeman XP for a species.

## Current status

M1, M2, M3, M4, M7A, and the M7C Strength, Technique, and Speed vertical slices
are implemented. M7C Slice 7 (automatic Follow-Up plus Ready Stance wind-up
speed) was signed off on 2026-08-05. Do not infer permission to begin the next
slice or M8.

Latest verified suite counts and commands live in `docs/STATUS.md` and
`docs/TESTING.md`; do not copy growing test histories back into this file.

## Read only when relevant

| Task | Read |
|---|---|
| Current milestone, known gaps, latest suite counts | `docs/STATUS.md` |
| Running tests or setting up another machine | `docs/TESTING.md`, then `SETUP.md` if needed |
| Runtime slicing, chopping, fragments, axe, pile, or visual test tools | `docs/areas/chopping.md` |
| Cash, saves, inventory, orders, species ownership, or the yard HUD | `docs/areas/progression.md` |
| XP, skill tree, procs, grain cues, Follow-Up, or Ready Stance | `docs/areas/skills.md` |
| FBX, materials, textures, Maya, or art imports | `docs/areas/assets.md` |
| Near-term module planning | `handoff/08_COZY_LUMBERYARD_ROADMAP.md` |
| Earth-to-space long-horizon planning | `handoff/10_EARTH_TO_ALIEN_TIMBER_ROADMAP.md` |
| Why an old decision was made | the specific file in `docs/history/` or git history |

The roadmap files are planning references, not prerequisites for implementation
tasks. The old `handoff/00_OVERVIEW.md` and numbered implementation briefs are
historical unless a current area document explicitly points to one.

## Test discipline

Run Godot commands from the inner `the-axeman/` directory, which contains
`project.godot`. Running `godot --path .` from the repository root can open the
project manager and exit successfully without running the requested scene.

After adding a new `class_name`, run a Godot import pass so the global class
cache is refreshed. `--check-only` may report missing autoload identifiers;
use the relevant scene suite for integration confidence. Some physics and pile
checks require non-headless execution because their correctness depends on the
real animation/render clock.
