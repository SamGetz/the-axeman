# Current project status

Last updated: 2026-08-17.

## Live game

Campfire Survivors is a 15-minute log-cutting survival run with an explicit
Endless/cash-out decision. Home owns banked Cash, thirteen permanent upgrades,
yard/frequency selection, Blueprint unlocks, and records. A run owns session
Cash, run XP, level choices, six temporary-power slots, boss state, pressure,
and results. Failure and **Bank & Go Home** settle the purse exactly once;
Abandon forfeits it.

Yard One supplies whole physical logs through resource-backed interval and
amount curves. Three scheduled bosses use five-root top-down stump stacks. XP
and Cash commit authoritatively at root completion while pooled orbs and coins
stage only their display. Finished billets become collisionless, remain opaque
for five active seconds, then sink through the floor and despawn.

## Powers and tuning

The run-power catalogue has fourteen Core and thirteen Blueprint identities.
Identity, copy, pool, icon, and shader references live in
`data/run_power_catalogue_placeholder.tres`. Run powers are announced with real
3D geometry rather than particles: every power owns a distinct prop in
`scenes/3d_action/run_power_prop_library.gd`, destroyed-log counts become that
many real billets, and effective radii size both the true ground ring and the
emblem. See `docs/areas/skills.md`. Every gameplay rank ladder and its
rank cap live in the single editable `data/run_power_curves_placeholder.tres`
resource: the longest effect array for a power defines its cap, and shorter
companion arrays hold their final value. Values are cumulative by rank and
remain explicitly `PLACEHOLDER` pending balance approval.

Every power that hits a loose root now destroys that entire root immediately.
Count values mean distinct logs destroyed; chance values use `0.0–1.0`. Each
destroyed root breaks into a deterministic-random two-to-six real-fragment
batch on log-local X/Z planes, pays its exact XP and Cash once, then uses the
normal fragment fall and floor-sink lifecycle. Area and contact powers remove
every eligible root in their geometry. Crosscut Sweep also completes the stump
root, and Timber Burst chains through an iterative completion queue.

## Persistence

`InventoryManager` is the only inventory writer. `GameState` owns permanent
profile mutation; `RunDirector` owns disposable attempt state; `SaveSystem`
serializes them. A suspended attempt locks permanent controls. Current v19
saves use separate profile and optional-attempt sections with protected atomic
replacement.

Power-curve validation is diagnostic and is isolated from profile authority.
Editing a ladder can neither make a valid save unreadable nor disable permanent
upgrades, banking, Blueprint unlocks, or save writes.

Migration keeps only value-bearing compatibility: old Cash/entitlement
conversion, inventory and lifetime records, retired paid-upgrade refunds, and
one-time reconstruction of old partial power cuts. The five removed meta rows
are refunded from their exact saved paid ledgers. Retired campaign, company,
equipment, permanent SkillTree, tutorial, splitter-shop, alien, and production
implementations are no longer present.

## Repository audit

The 2026-08-17 audit removed disconnected gameplay modules, schemas, resources,
scenes, milestone tests, probes, review tools, historical briefs, obsolete
shaders, and unused audio cues/assets. Shared live authorities were
consolidated: `SpeciesTable` is the wood catalogue, `RunVfxConfig` is the
presentation tuning surface, and `GameConfig` contains only consumed
subresources. Source art, generated runtime art, current visual-review tools,
and bounded migration fixtures are retained intentionally.

## Remaining boundaries

All unapproved costs, rewards, odds, multipliers, intervals, radii, counts,
camera values, and power curves remain labelled `PLACEHOLDER`. Measured balance
tuning and the release capture matrix are separate work. Tree felling, mining,
explorable forests, villagers, staff rosters, and the retired long-horizon
campaign are out of scope unless Sam restores them explicitly.

## Latest verified logic gate

- Profile/progression/migration and tuning isolation: 103/103.
- Home: 26/26; run XP: 21/21; offers: 42/42; icons: 2/2.
- Run-power runtime: 57/57; boss stack: 18/18; stage: 25/25.
- Survival lifecycle: 45/45; production Main smoke: 22/22.
- Chopping: 60/60; cut journal: 6/6; slicer: 34/34.
- Reward/audio: 39/39; performance stress: 6/6.
- Material catalogue: 25 species, 21 placeholder rows, 41 textures.
- Godot 4.7.1 editor import and script parse: PASS.

Commands and interpretation live in `docs/TESTING.md`.
