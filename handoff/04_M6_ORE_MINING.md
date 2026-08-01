# M6 — Ore Mining (pickaxe · fracture layers · gem drops)

Status at handoff: direction only — the thinnest spec in the pack because
most blueprint detail for M6 was never surfaced into CLAUDE.md. Expect to
lean on Sam for mechanics; do NOT guess them into existence.

## Scope fence

IN: mining mini-game in quarry/cavern biomes; pickaxe hits against
OreVeinDef-driven veins; pre-authored fracture layers activated radially
around hit points; weighted-random gem drops; yields through the M4
fragment/collection pipeline into InventoryManager.
OUT: new EventBus signals (A7 covers it: `minigame_entered(biome)`,
`action_hit_registered`, `resource_gathered`), biome unlock logic (GameState
already owns it), refining (M7).

## Binding contracts

- **A2:** pre-authored fracture states only — `fracture_layers` are authored
  meshes revealed/removed layer by layer. No runtime booleans (banned list),
  no runtime volume computation.
- **OreVeinDef is frozen** (`data/ore_vein_def.gd`): `biome, hardness_level,
  fracture_layers (untyped Array), yields (Array[FragmentDef])`. Layer
  entry *internal structure* is not pinned by the schema comment — decide it
  with Sam and document it in the `.tres`, don't extend the .gd (that would
  be an amendment).
- Gem drops: "weighted-random entries within these yields" (schema comment).
  The weight representation isn't pinned — if it needs data FragmentDef
  doesn't carry, that's an **amendment proposal**, not a quiet field.
  (Previous agent's lean: encode weights positionally via duplicate entries
  in `yields` — zero schema change; check whether Sam finds authoring that
  acceptable before proposing an amendment instead.)
- Tool: `Enums.ToolType.PICKAXE` tier from GameState gates hardness exactly
  like M5's axe gate — same pattern, same test shape.
- Valid gem/mineral ids (registry, locked): `stone, copper_ore, iron_ore,
  amethyst, ruby, sapphire`.
- RNG: seed through a single RandomNumberGenerator owned by the mini-game
  scene, injectable for tests (deterministic acceptance runs — pass a fixed
  seed in the test).

## Design direction

- `res://scenes/3d_action/mining_vein.tscn` mirroring M4/M5 structure;
  biome entry via `minigame_entered(Enums.Biome.MOSSY_QUARRY /
  VOLCANIC_CAVERN)` — remember GameState gates biome unlocks;
  MOSSY_QUARRY/VOLCANIC_CAVERN start LOCKED, so tests unlock via
  `environment_unlocked` (the real path).
- "Activated radially around hit points": interpret as — each fracture layer
  entry carries a position; a hit activates (detaches/spawns) layer pieces
  within some radius of `hit_position`. Radius = tuning value → `.tres`
  placeholder, ask Sam. Confirm interpretation against blueprint text
  BEFORE building.
- Reuse `fragment_piece.tscn` + `FragmentPhysicsBudget` (A12 cap applies to
  rock debris identically).
- GameFeel: hits emit `action_hit_registered`; nothing new.

## Acceptance test — `m6_acceptance` (+ all older suites green)

1. OreVeinDef loads; layers non-empty; every yield leaf's `yield_item` is a
   valid registry id.
2. Locked-biome entry produces no mini-game state change; after
   `environment_unlocked` it does (drive via EventBus, assert via
   GameState).
3. Pickaxe gate: under-tier → no fracture state change; at/above tier →
   layer activation near hit point only (place two hits far apart, assert
   radial selectivity).
4. Seeded RNG: fixed seed → deterministic gem drop sequence; distribution
   sanity over many draws (weights roughly respected, loose tolerance).
5. Full vein clear → expected total minerals in InventoryManager; gem count
   within authored min/max.
6. A12 cap during layer bursts.

## Ask-Sam list for M6

1. Blueprint text for mining mechanics — radial activation, layer counts,
   what a "vein cleared" state is. Highest-priority ask; don't build on the
   radial interpretation without confirmation.
2. Gem drop rates per vein type (data), and whether the duplicate-entry
   weighting authoring style is acceptable vs. wanting a weight field
   (= amendment decision made consciously).
3. Which biome ships first for M6 acceptance (MOSSY_QUARRY presumably).
4. Art status for vein/fracture-layer meshes; placeholder rock primitives
   otherwise (same drop-in `.tres` discipline as M4/M5).
5. Denied-hit feel for under-tier pickaxe (reuse M5's answer?).
