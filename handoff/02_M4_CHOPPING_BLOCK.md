# M4 — Firewood Chopping Block (first playable mini-game)

Status at handoff: not designed in detail — this doc is direction + fences.
M4 is the vertical slice: input → hit → fragment chain → physics → pickup →
inventory. Expect the most Sam-iteration of any module so far.

## Scope fence

IN: chopping mini-game on the stump in the 3D action scene. A log on the
block; directional chops; FragmentDef chain traversal (mesh swap on split);
A12 rigid-body fragments; collecting leaf pieces → `resource_gathered` →
InventoryManager; GameFeel wired to every hit; Sam's real FBX art for
stump/log/axe if the meshes are ready.
OUT: tree felling (M5), mining (M6), any 2D UI (M7), sounds unless Sam asks,
gear *gating* (M5 introduces it — M4 just reads
`GameState.get_tool_tier(Enums.ToolType.AXE)` and passes it through).

## Binding contracts

- **A2:** pre-authored fracture states ONLY. A hit = mesh/scene swap per
  FragmentDef. No runtime geometry ops.
- **A3:** the ONLY size test anywhere:
  `piece.size_tier > GameFeel.config.size_threshold`. One call site if
  possible. (Blueprint intent: pieces above threshold need more chopping /
  can't be collected yet; confirm exact gameplay meaning with Sam — see
  Ask-Sam list.)
- **A7:** hits emit
  `action_hit_registered(hit_position: Vector3, tool_tier: int, direction: Enums.ChopDirection)`.
  Yields emit `resource_gathered(id, amount)` — ids must be registry ids or
  InventoryManager errors them (that's the contract working).
- **A12:** fragments are RigidBody3D; on sleep OR settle-timeout → freeze
  (`freeze = true`, FREEZE_MODE_STATIC). Hard cap **24 active rigid bodies**
  per mini-game; over cap → freeze oldest settled first. Long-term piles may
  consolidate to MultiMesh (defer until it's actually needed — likely M7-era
  polish, not M4).
- **Amendment 1 (FragmentDef.sub_fragments):** empty = leaf = collectible
  (`yield_item`/`yield_amount` read only then). Non-empty = a successful hit
  swaps the piece for its sub_fragments. Splits are 2-way for now.
- Physics engine is **Jolt** — verify sleeping detection triggers your
  freeze path in practice (test with a settle timeout as the backstop, not
  just `sleeping_state_changed`).

## Approved data: the Pine chain (from CLAUDE.md, Sam signed off)

4 hits, 5 leaf pieces, 9 meshes, all leaves yield `pine_log`:

```
pine_log_full (t5)
├─ half_a (t4)            ├─ half_b (t1, leaf)
   ├─ qtr_a (t3)             ├─ qtr_b (t1, leaf)
      ├─ 8th_a (t2)             ├─ 8th_b (t1, leaf)
         ├─ 16th_a (t1, leaf)   ├─ 16th_b (t1, leaf)
```

Author this as `res://data/fragments/pine_chain.tres` (nested FragmentDef
resources; folder name is your choice inside `res://data/`). Mesh fields
reference Sam's FBX-imported meshes; if the 9 fragment meshes aren't
exported yet, build the whole chain with placeholder primitive meshes
(scaled boxes) so the *system* can be accepted, and structure the `.tres`
so Sam's meshes drop in without touching code. Fragment pivots are at the
landing/contact point (Sam's export rule) — placeholder primitives should
mimic that (origin at bottom).

## Asset pipeline notes (first module that consumes Sam's art)

- Copy FBX from `maya_working\models\...` into `res://assets/models/<name>/`,
  run the headless import pass, then LOOK at the result (open in editor or
  instance it) before building on it. Known first-time risks: cm→m scale
  (fix once in the FBX import dock or ask Sam to export at 0.01), Y-up,
  frozen transforms. `chopping_stump_a.fbx` and `log_a.fbx` exist today.
- Any import-dock setting you change: write it down in your delivery so it's
  reproducible.

## Design direction (previous agent's intent, coarser than M3)

- New scene `res://scenes/3d_action/chopping_block.tscn` (+ script on root)
  — grows out of a copy of the placeholder scene (camera + gobo light +
  environment + BG stay); `main.tscn` swaps the placeholder instance for it
  under `3D_World_Root`.
- A `fragment_piece.tscn` (RigidBody3D + MeshInstance3D + CollisionShape3D)
  driven entirely by a `FragmentDef`; script exposes
  `setup(def: FragmentDef)`. The chop swap: on successful hit on a
  non-leaf piece, despawn it, spawn its `sub_fragments` (2 pieces) at
  authored offsets with a small impulse (`log_hop_force` placeholder from
  GameFeelConfig; `perfect_cut_throw_force` if the hit was "perfect" —
  mechanic def needed from Sam, see below).
- A single `FragmentPhysicsBudget` (plain Node, child of the mini-game
  scene) owns the A12 cap/freeze bookkeeping. Keep it separate and testable:
  `track(body)`, `active_count()`, freeze policy inside.
- Input: keyboard first (e.g. arrow keys = ChopDirection.LEFT/RIGHT/UP/DOWN)
  via InputMap actions (`chop_left` etc.) so bindings are data. **Ask Sam
  for the intended control scheme before wiring** — blueprint may specify
  mouse swipes.
- Collection: leaf pieces auto-collect after settling? Walk-over? Click?
  **Blueprint detail not in CLAUDE.md — ask Sam.** Whatever the answer:
  collection is the ONLY place `resource_gathered` is emitted, and the
  emitted id comes from `yield_item`.
- Every registered hit → EventBus `action_hit_registered` → GameFeel reacts
  (already wired in M3). The mini-game does NOT call
  `GameFeel.hit_pause()` directly — the signal is the one path.
- Remove/retire the M3 H-key debug once real hits exist (M-key stays until
  M7).

## Acceptance test — `m4_acceptance` (+ keep all older suites green)

System-level, headless-friendly (drive logic APIs directly, not input):

1. Pine chain resource loads; depth/leaf-count/yields match the approved
   chain (4 hits deep, 5 leaves, every leaf yields `pine_log`).
2. Simulated full chop-down of one log yields exactly 5 `pine_log` into
   InventoryManager (count 0 → 5).
3. A hit on a leaf piece does NOT split further; a hit on non-leaf swaps to
   exactly 2 children (Amendment 1 semantics).
4. `action_hit_registered` emitted once per registered hit with the acting
   tool tier from GameState.
5. A12: spawn > 24 bodies via repeated chops → active (non-frozen) count
   never exceeds 24; settle-timeout freezes bodies even if Jolt never
   reports sleep (await physics frames; budget generous `--quit-after`).
6. A3: exactly one size-threshold call site behaves as specified once Sam
   defines the gameplay meaning.

## Ask-Sam list for M4 (get these BEFORE building the interaction layer)

1. Control scheme for chops (keys? mouse swipe direction?).
2. What "perfect cut" means mechanically (timing window? aim point?) — it
   has a reserved force value in GameFeelConfig, so it's a real mechanic.
3. Collection interaction for leaf pieces.
4. Gameplay meaning of the A3 size threshold in the chopping game.
5. Are the 9 pine fragment meshes exported yet, or build on placeholders?
6. Settle-timeout seconds + spawn impulse feel values (placeholders in
   `.tres` until tuned; `game_feel_config.tres` already holds the two
   forces).
