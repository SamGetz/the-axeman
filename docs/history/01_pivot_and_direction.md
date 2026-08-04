# The pivot and approved direction

Full narrative behind the one-paragraph pivot summary in `CLAUDE.md`. See
[README.md](README.md) for how this folder is organized.

## THE PIVOT (2026-08-01)

Sam's direction: *"Time for a big pivot. I want to just focus on the 'chopping
game'. We can remove anything relating to the tree felling game. I want the new
scope of the game to just be a 'number go up' game, where you are a log cutter.
Since the core gameplay of the log cutting already feels awesome, lets clean up
the game and keep the scope around the log cutting game."*

**The tree-felling game (M5) is GONE.** Every file belonging to it — the voxel
wood volume, the hinge fall, the FPS forest player, the stand of trees, the
bucking, the 22 forest/seam dev tools, `m5_acceptance`, `TreeDef`,
`pine_tree.tres` and 53 MB of tree art — was deleted on 2026-08-01. It is all
recoverable from git (see below); it is not coming back unless Sam says so.

**What the game is now:** a cozy "number go up" lumberyard game built around
M4's tactile chopping — a log on a block, click to slice it into firewood, then
turn that satisfying work into stock, fulfilled orders, cash, reputation and a
steadily growing yard. Manual chopping remains the central and most valuable
interaction for the entire game.

**THE PROJECT IS NOW UNDER GIT.** The repo root is
`C:\Users\Sam\Documents\the_axeman\` (the whole thing, not just the Godot
project). Two commits exist:

| Commit | What |
|---|---|
| `29bcd6f` | The full working state *before* the pivot — M1–M5, the forest, all tree art. |
| `38b4425` | The pivot: everything tree-related removed. |

`.godot/` and `*.log` are gitignored. **Commit as you work now** — the safety
net exists, use it. **UPDATED 2026-08-04: a remote now exists** —
`origin` → `https://github.com/SamGetz/the-axeman.git`, tracking `master`.
This line originally said there was no remote; it was stale. See Operational
Rule 7 in CLAUDE.md — sync with `origin/master` at the start of every session
before starting new work.

### APPROVED POST-PIVOT DIRECTION (2026-08-01)

Sam approved the full cozy-lumberyard recommendation and the roadmap in
`handoff/08_COZY_LUMBERYARD_ROADMAP.md`:

1. **M6 ore mining is fully removed, not archival.** Retired from the roadmap
   2026-08-01; on 2026-08-04 Sam asked directly to strip it out ("this is logs
   only") and its spec, data class (`OreVeinDef`) and registry items were
   deleted outright. `ItemCategory.MINERAL`/`GEM`, `ToolType.PICKAXE` and the
   `MOSSY_QUARRY`/`VOLCANIC_CAVERN` biomes are gone from the frozen A6 enums —
   see the amendment log. Mining must not be reintroduced as a second action
   loop unless Sam separately reverses this.
2. **M7 is re-scoped to lightweight lumberyard progression and orders.** Cash,
   firewood stock, reputation and lifetime wood chopped are the progression
   spine. The yard grows visibly alongside the counters.
3. **M8 is reinterpreted as certified automation, with no yard-staff layer.**
   Sam removed the villagers/yard-staff concept 2026-08-04 — unlocking and
   purchasing stay driven entirely by the existing shop (the same Items/Trees
   tabs M7A already built), not by a hired roster. M8's scope is the first
   certified Mechanical Splitter: once a species is mastered, its cutting
   profile is bought directly through the shop like every other purchase, and
   the machinery then replaces routine manual commodity chopping for that
   solved wood while the player moves to the next unknown species.
4. **Biomes may return only as wood-supply regions**, not explorable FPS forest
   levels. They unlock species, customers and contracts.
5. **Tone is cozy lumberyard first**, with restrained absurd escalation only
   after the grounded chopping-and-yard fantasy is established.

### EXPANDED ENDGAME DIRECTION (2026-08-01)

Sam has now defined the long-horizon goal: build from the cozy yard into the
company that **masters and chops every kind of log on Earth**, then spend the
resulting wealth and materials on space expeditions that return alien logs. The
extensive design and module sequence are in
`handoff/10_EARTH_TO_ALIEN_TIMBER_ROADMAP.md`.

This does **not** restore M5 or create a replacement tree-felling management
layer. There are no standing-tree counts, forest-depletion maps, felling crews,
skidders or Last Tree sequence. Regions are log suppliers only: every unknown
species first arrives at the existing chopping block for its manual learning
and certification phase. The grounded yard must be established before the
global and space scale is revealed. The roadmap is not permission to skip
module sign-off or invent tuning values.

**Certified auto-cutting IS in scope, begins with the first Mechanical Splitter
in M8 and is required for trillion-scale timber throughput.** This automates log
processing, never tree felling. The progression loop is: manually chop and learn
a new species a small authored number of times, certify it, buy/install its
cutting profile, then let machinery replace manual commodity production for
that solved wood while the player moves to the next unknown species. Machines
cannot award Axeman XP, discover, master or certify a new species. Exact rates,
requirements and value differences remain tuning calls.

### SKILL TREE AND STORE DIRECTION (2026-08-02)

Sam approved three player-skill branches: **Strength**, **Speed** and
**Technique**. Skills must do more than make the same loop faster. Their defining
rewards are named random bonus mechanics such as double/triple/quadruple strikes,
free follow-ups, hot streaks, golden-grain opportunities and multiplied manual
XP. Proc chains require bad-luck protection, valid slicer geometry, visible
announcements and protection for precision work. Final odds and magnitudes are
tuning calls.

Cash belongs to the physical store: axes/tools, workstation/environment,
automated production, yard/logistics and optional session supplies. Skills
define what the Axeman can do; equipment weights how often, how strongly or how
safely those mechanics occur. Every meaningful purchase must be felt or seen in
the yard. Full framework: `handoff/10_EARTH_TO_ALIEN_TIMBER_ROADMAP.md`.

Exact prices, payout multipliers, timing values and upgrade magnitudes are still
tuning decisions. Do not invent them in code: present them to Sam as resource
values/placeholders and tune with Creative Director sign-off.

### CLEANUP — resolved 2026-08-04

Both items formerly tracked here as open Creative Director calls were resolved
by Sam's direct request to strip deprecated/unused elements from the repo:

1. `slice_poc.tscn` (the pre-Amendment-8 960×540 harness, superseded by
   `chopping_minigame_harness.tscn`) — **deleted**. Recoverable from git.
2. The stale root-level `core/` and `data/` duplicates of the M1 drop —
   **deleted**. The canonical copies are the only copies now: `the-axeman/core/`
   and `the-axeman/data/`. `handoff/00_OVERVIEW.md` is stale on this point (it
   still describes the old "don't delete" stance, preserved there as history).

Also removed in the same pass: the stale, drifted `AGENTS.md` (a duplicate of
this file that had fallen out of sync — CLAUDE.md is the sole source of truth),
`assets/models/logs_export/log_2.fbx` (the unused duplicate noted in the asset
pipeline section), a stray unrelated `java_script_working_example.js` bundle at
the repo root, and a tracked `.DS_Store`.
