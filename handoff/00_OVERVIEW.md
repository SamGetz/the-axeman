# HANDOFF — The Axeman · Read this first

You are taking over as Lead Gameplay Programmer / Technical Engine Architect
on **The Axeman**, a hybrid 2D/3D cozy village builder. The previous agent
(Claude Fable 5) delivered M1 and M2; both are signed off. You deliver M3–M8,
one module at a time, in order, with Creative Director sign-off between each.

**`CLAUDE.md` at the repo root is your constitution.** Read it in full before
touching anything. This handoff pack does not replace it; it adds working
knowledge that isn't written down anywhere else. If this pack ever appears to
contradict CLAUDE.md, CLAUDE.md wins — and tell Sam you found a discrepancy.

The full Master Project Blueprint document is **NOT in the repo**. CLAUDE.md
carries the operative summary of its contracts. If a module decision needs
blueprint text you don't have, **ask Sam to paste the relevant section —
never invent it.**

---

## The people

- **Sam** (they/them pronouns unconfirmed — use "Sam") is the Creative
  Director and the only human. Sam is an artist (Maya) and is *learning* the
  Godot editor: when you need them to do something in the editor, spell out
  every click ("FileSystem dock, bottom-left, double-click the file with the
  clapperboard icon"), and expect questions like "where do I press F6".
  Sam authors all art and owns all tuning numbers.
- You own code, scene structure, and tests. You never pick final tuning
  values — placeholders go in `.tres` files, and you list every placeholder
  you introduced when you deliver a module.

## Hard process rules (these have teeth)

1. **Never start the next module without Sam's explicit go-ahead.** "Looks
   good" about the current module is not a go-ahead for the next.
2. **Part A contracts are frozen.** Changes require: halt → written proposal
   to Sam → approval → add to CLAUDE.md's APPROVED AMENDMENT LOG → resume.
   Four amendments exist already (see CLAUDE.md); follow their format.
3. Artistic/mathematical tuning values: halt and ask for exact numbers, or
   ship clearly-labelled placeholders in `.tres` files. **Never hardcode.**
4. Verify uncertain APIs exist in Godot 4.7 / Compatibility renderer before
   using them. See "Renderer traps" below for known casualties.
5. Every script header states its `res://` path and the node it attaches to.
   Every delivered scene gets its full node tree written out in your delivery
   message. (Look at `core/*.gd` headers for the house style.)
6. Inventory writes ONLY inside InventoryManager; progression writes ONLY
   inside GameState. Everything else is read-only + EventBus emissions.

## Layout on disk (Windows machine)

| Path | What |
|---|---|
| `C:\Users\Sam\Documents\the_axeman\` | Repo root. **A git repo since the 2026-08-01 pivot** — commit as you work. CLAUDE.md, this pack, source images, Maya files. |
| `...\the_axeman\the-axeman\` | **The actual Godot project.** Everything you ship goes here. |
| `...\the_axeman\core\`, `...\data\` | **Stale duplicates** of the M1 drop. Canonical copies are inside `the-axeman\`. Sam hasn't approved deleting these — don't. (`data/tree_def.gd` went in the 2026-08-01 pivot; the rest stands.) |
| `...\the_axeman\maya_working\models\` | Sam's Maya sources + FBX exports (`chopping_stump_a.fbx`, `log_a.fbx` exist today). Copy FBX into `res://assets/models/` when a module needs them; never reference `maya_working` from the project. |
| `C:\Users\Sam\Desktop\Godot_v4.7.1-stable_win64.exe` | The engine binary. |

Project folders (A4, frozen): `res://core/`, `res://data/`,
`res://scenes/2d_management/`, `res://scenes/3d_action/`, `res://assets/`.
Tests live in `res://core/tests/` as `mN_acceptance.gd/.tscn` pairs.

## Running the project headless (memorize this)

The Desktop exe is a **non-console Windows build**: piping stdout mostly
works from Git Bash, but the reliable capture is `--log-file`.

```bash
cd "C:/Users/Sam/Documents/the_axeman/the-axeman"

# 1. Import pass — run after adding ANY new asset/scene, before running scenes:
"/c/Users/Sam/Desktop/Godot_v4.7.1-stable_win64.exe" --headless --path . --import --quit

# 2. Run an acceptance scene (they have no quit() — --quit-after is mandatory
#    or the process hangs forever; tests run synchronously in _ready):
"/c/Users/Sam/Desktop/Godot_v4.7.1-stable_win64.exe" --headless --path . \
  --quit-after 5 --log-file /path/to/run.log res://core/tests/m3_acceptance.tscn
```

- `ERROR: 1 resources still in use at exit` after `--import` is benign.
- If your module's test needs frames to elapse (physics, timers), `await`
  inside the test and raise `--quit-after` accordingly.

## ⚠ The project.godot clobber trap (this bit us twice)

Sam usually has the Godot editor **open** while you work. The editor holds
`project.godot` in memory and **rewrites the whole file from memory** any
time Sam touches any project setting — silently destroying edits you made on
disk. Protocol:

- New files/scenes/scripts on disk: always safe; editor rescans.
- `project.godot` edits: make them, then **immediately tell Sam to run
  Project → Reload Current Project before touching anything else.** Put this
  warning first in your message, bold, not buried.
- If a setting change is small and Sam is active in the editor, the safer
  path is walking Sam through the Settings UI instead (as was done for the
  autoloads — they're registered as `uid://` strings in project.godot;
  that's normal, leave them).

## Current engine/project facts

- **Godot 4.7.1 stable**, Compatibility renderer (`gl_compatibility`),
  GDScript only, native nodes only, no third-party plugins *for gameplay*.
  (`addons/godot_mcp` exists for editor tooling/inspection — leave it alone,
  its 3 MCP autoloads stay after ours.)
- Autoload order (frozen): `EventBus`, `InventoryManager`, `GameState`,
  then the MCP ones. `core/enums.gd` is `class_name Enums` — NEVER autoload.
- project.godot also sets: main scene `res://scenes/main.tscn`, base
  viewport 640×360, window override 1280×720, stretch `canvas_items`/`keep`,
  Jolt physics. Physics engine is **Jolt** — remember for M4/M5 fragment
  behavior (sleeping thresholds may differ from GodotPhysics).
- Item registry ids (locked): `pine_log, oak_log, mahogany_log, stone,
  copper_ore, iron_ore, amethyst, ruby, sapphire, wood_board, copper_ingot,
  iron_nail`.

## Renderer traps (Compatibility) — confirmed & suspected

- **SpotLight3D `light_projector` does not visibly render** under
  gl_compatibility (confirmed by Sam's eyeball test of M2: no gobo pattern,
  just a plain cone). A1 *mandated* the projector approach; **Sam raised it
  2026-07-22** (supplied `images/lightmaps/leaves_gobo_tilable.jpg`) and it
  was replaced, scoped to the M4 `chopping_minigame.tscn` scene only, with an
  animated shadow-casting alpha-scissor cutout quad (`CanopyGobo` node +
  `res://scenes/3d_action/canopy_gobo.gd` +
  `res://assets/shaders/canopy_gobo.gdshader`) — see CLAUDE.md Amendment 9.
  **Still needs Sam's F6 eyeball-check** (not headless-verifiable, same as
  the original gobo finding) before it counts as confirmed working. The M2
  placeholder scene's own gobo (if any survives there) is untouched — this
  amendment only covers the live M4 scene.
- Banned outright by CLAUDE.md: real DOF (CameraAttributes), volumetric fog,
  SDFGI, DirectionalLight projectors, runtime mesh booleans/CSG, runtime
  volume computation.
- Sam also reported M2 renders "soft" overall. Untriaged; likely the blurred
  BG dominating + placeholder lighting. Art pass later — don't chase it now.

## State of delivered work

> **PICK UP HERE (2026-08-01): read CLAUDE.md's "THE PIVOT" block first.**
> **This pack is older than the pivot and parts of it are now wrong.** Sam has
> cut the scope to the log-chopping game alone: the whole tree-felling game (M5)
> and the FPS forest were deleted, along with `03_M5_TREE_FELLING.md`,
> `08_FPS_FOREST.md` and `09_TRUNK_SEAMS_AND_ROOTS.md` from this pack. Anything
> below about trees, the forest, felling, bucking or the voxel wood describes
> code that no longer exists — it is preserved in git at commit `29bcd6f`.
>
> The new scope is a **cozy "number go up" lumberyard game** built on the M4
> chopping mini-game, which Sam says already feels awesome. The approved
> grounded progression direction is captured in
> `08_COZY_LUMBERYARD_ROADMAP.md`; the expanded finite-Earth and alien-timber
> endgame is in `10_EARTH_TO_ALIEN_TIMBER_ROADMAP.md`.
>
> `02_M4_CHOPPING_BLOCK.md` and `07_M4_SLICING_POC.md` describe live chopping
> code. `08_COZY_LUMBERYARD_ROADMAP.md` plus its long-horizon extension
> `10_EARTH_TO_ALIEN_TIMBER_ROADMAP.md` are the binding roadmap. `04`/`05`/`06`
> describe the retired pre-pivot plan and are retained only as history.
>
> **What is waiting is Sam, not code.** M4 is integrated and 16/16 but has never
> been signed off, and the click-to-chop input layer has never been
> headless-verifiable — it wants a live look in F5/F6.

- **M1 (core contracts): DONE, signed off.** 21/21 acceptance. Note tests
  2/5/7/8 *deliberately* trigger red errors — only `FAIL:` lines matter.
- **M2 (shell + pipeline): DONE, functionality accepted.** 21/21 acceptance
  (`core/tests/m2_acceptance.tscn`). Art direction explicitly deferred.
  - `scenes/main.tscn` + `main.gd`: A9 hierarchy, A10 mode switch.
  - `scenes/3d_action/placeholder_action_scene.tscn`: placeholder stump/
    ground/blurred-BG-quad/sun-gobo-spotlight/stepped AnimationPlayer.
  - **Temp debug:** M key in `main.gd` toggles 2D↔3D via real EventBus
    signals. Marked "M2 TEMPORARY DEBUG". Keep until M7A provides the real
    entry flow for the chopping game, then delete.
  - `assets/textures/background_blurred.jpg` was converted from
    `images/background_blurred.jfif` at repo root (Godot won't import .jfif;
    it's a plain JPEG — rename-copy was enough).
- The game boots to an **empty screen by design** (2D mode, A10, M7 UI
  doesn't exist yet). Press M. Remind Sam of this every time — it reads as
  "broken" otherwise.

## Delivery ritual per module (what "done" means)

1. Code + scenes + an `mN_acceptance` test scene in the M1/M2 style
   (`PASS:`/`FAIL:` lines, `=== ALL MN ACCEPTANCE CRITERIA PASS ===`,
   same `_check()` pattern — copy it).
2. Headless: import pass, new suite green, **re-run every older suite**
   (M1, M2, …) to prove no regression.
3. Delivery message to Sam: what was built, full node trees, every
   placeholder tuning value introduced, exact editor steps for Sam's own
   acceptance run, open questions.
4. Update CLAUDE.md's CURRENT PROJECT STATUS block (module ✅, what's next).
5. Wait for sign-off. Do not touch the next module meanwhile.

## Persistent memory

Agent memory lives at
`C:\Users\Sam\.claude\projects\C--Users-Sam-Documents-the-axeman\memory\`
(`MEMORY.md` is the index). Keep `axeman-project-state.md` current after
every module — it's how a fresh session recovers state fast.

## Module queue

| Doc | Module | One-liner |
|---|---|---|
| `01_M3_GAMEFEEL.md` | M3 | Hit-pause, noise camera shake, `register_impact` |
| `02_M4_CHOPPING_BLOCK.md` | M4 | Firewood chopping mini-game — **this is the game now** |
| `07_M4_SLICING_POC.md` | M4 | Slicer state, render-to-PNG debug workflow, Compatibility material traps |
| `08_COZY_LUMBERYARD_ROADMAP.md` | M7+ | **Binding:** cozy orders, progression, upgrades, later logistics staff |
| `10_EARTH_TO_ALIEN_TIMBER_ROADMAP.md` | M7–M14+ | **Binding extension:** skills, finite Earth campaign, Last Tree, launch programme and alien logs |
| `04_M6_ORE_MINING.md` | M6 | **Retired:** historical ore-mining direction; do not build |
| `05_M7_MANAGEMENT.md` | old M7 | **Superseded:** historical village-management direction; do not build |
| `06_M8_VILLAGERS.md` | old M8 | **Superseded:** historical villager/morale direction; do not build |

`03_M5_TREE_FELLING.md`, `08_FPS_FOREST.md` and `09_TRUNK_SEAMS_AND_ROOTS.md`
were deleted in the 2026-08-01 pivot along with the code they specified.

Each doc has: scope fence, binding contracts, the design I would have built
(follow it unless Sam redirects), acceptance criteria, and the exact
questions to ask Sam before/while building. **M3's doc is the most
prescriptive because it was fully designed at handoff time — start there.**
