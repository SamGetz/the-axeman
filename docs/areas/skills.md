# Run powers area guide

Read this for run XP, level offers, quality, six-slot ownership, rerolls, banishes,
Payday, boss bonus choices, or power effects.

## Current implementation

The permanent SkillTree and its proc runtime are retired and removed. `GameState`
has no permanent XP or skill state; bounded migration tables convert old value
without exposing legacy query or purchase surfaces.

The immutable `RunPowerTable` contract contains:

- fourteen Core powers owned by every fresh/migrated profile;
- thirteen Blueprint powers unlocked only through settled boss rolls;
- authored rank caps, typed effect ladders, and explicit `PLACEHOLDER` tuning
  on every row, with a hard catalogue ceiling of 32 powers.

Power identity, copy, pool, cap, and presentation live in
`data/run_power_catalogue_placeholder.tres`. All temporary power rank ladders
live in the single balance file `data/run_power_curves_placeholder.tres`. Its
arrays are cumulative totals: entry one is Rank 1, entry two is Rank 2, and so
on. Chance values use `0.0-1.0`, intervals use seconds, distances use metres,
and destructive payload counts are whole logs.

Slice 2 now runs from Level 1 with a fresh XP curve. Authoritative XP queues
levels immediately, while the choice pause waits until the matching orb fills
the displayed bar. Each normal event offers three distinct eligible cards;
Luck can add a fourth. Reroll replaces every remaining card without changing
event size, Banish removes a card from this and all future offers, and the last
card cannot be banished. Multiple levels resolve serially.

New identities can fill at most six stable slots. After that, only legal ranks
for those six appear. Active cards, bans, queued levels, utility charges,
per-rank quality multipliers, automatic-power cadence, and RNG state round-trip
through the attempt snapshot, so reload cannot reroll an offer or lose a live
power state. Active Grain Reader marks also restore their exact target, plane,
visual anchor, and reward source without advancing RNG. If no legal rank remains,
the resolver falls back to Payday.

Every eligible power identity has exactly the same selection weight. Luck can
add a fourth card but does not favor one power name over another. Every
non-Payday card then rolls a separate per-pick quality: Common, Rare, Epic, or
very rare Legendary. Quality does not bypass Core/Blueprint ownership. A
selection always advances the owned
power by exactly one rank; Rare, Epic, and Legendary only strengthen the value
of that one authored increment. The current explicitly provisional weights are
`1 / 0.20 / 0.05 / 0.005`, with provisional value multipliers
`1× / 2× / 3× / 4×`. Offers exclude an exact power/quality pair if its clamped
value would not change gameplay.

All 27 powers are live from their first owned rank:

- Core: Deep Bite, Quick Hands, Scar Wisdom, Double Chop, Follow-Up, Splinter
  Volley, Flying Wedge, Yard Magnet, Soft Landing, Ring Reinforcement, Quick
  Study, Keen Appraisal, Area Size, and Sawblade Halo.
- Blueprint: Grain Reader, Earthshaker, Powder Keg, Kindling Chain, Whirling
  Axe, Crosscut Sweep, Maul Drop, Splitter Rig, Cant Hook, Stump Pulse,
  Last-Ditch Rescue, Momentum, and Timber Burst.

Area Size is a shared multiplicative stat for power geometry. Its provisional
rank ladder is `1.1× / 1.2× / 1.3× / 1.4× / 1.5×`, with card quality scaling
the increment rather than adding ranks. It currently scales Earthshaker,
Powder Keg, Kindling Chain, Whirling Axe's orbit, Crosscut Sweep, Stump Pulse,
Sawblade Halo, and Timber Burst in both gameplay and their matching area
presentation. It does not resize the yard boundary itself. Sawblade Halo
periodically destroys every loose root inside its stump-centered circle. Timber
Burst destroys every loose root inside the circle released by a completed root.
Their cadence/radius ladders are provisional.

The off-block destructive set is intentionally high-impact: Earthshaker,
Whirling Axe contacts, Crosscut Sweep, Sawblade Halo, Timber Burst, Powder Keg,
Kindling Chain, Maul Drop, Flying Wedge, Splinter Volley, and spilled Double
Chop work all remove loose roots atomically. Crosscut Sweep also completes the
current stump root. Unaffected roots remain untouched, while Timber Burst
follow-on completions retain their chain reaction through an iterative queue
that is safe under dense late-run log volumes.

Their runtime includes block modifiers, real cuts, completion chains, loose-log
targeting and forces, boundary protection, XP/cash modifiers, rescue charges,
Momentum, and visible timed automatic tools. Loose-root power cuts happen
immediately; their fragment planes use deterministically randomized log-local
X/Z normals. Physics rotation cannot turn that canonical mesh-space plane into
a diagonal cut. New powers never leave partial descendant geometry to save,
restore, or hand to the block.

All off-block destructive count values now mean distinct logs destroyed. Every
successful primary manual strike fires visible Splinter Volley feedback and
immediately destroys its nearest ordered targets. Its explicitly provisional
rank ladder is `1 / 2 / 3 / 4 / 5 / 6 / 7 / 8` logs; card quality strengthens
that one selected rank's value and never grants extra ranks. Flying Wedge keeps
one fixed endangered-log payload, while rank and card quality improve only its
interval. Powder Keg, Kindling Chain, Maul Drop, and spilled Double Chop work use
their displayed count as the maximum distinct loose logs destroyed. Radius,
contact, and sweep powers immediately destroy every affected loose root.

The Splinter Volley projectile uses labelled placeholder size, height, colour
mix, glow, and shared travel-duration values in
`data/run_vfx_config_placeholder.tres`;
these remain inspector-tunable pending a measured feel pass.

Each destroyed loose root synchronously becomes a deterministic-random `2–6`
real-fragment batch using the provisional survival-tuning range. The descendants
fall apart independently, cash and XP burst at the root's position exactly once,
and settled pieces enter the normal immediate sink. Completion still fires
source-neutral root-completion powers without creating manual-only outcome
records or procs. No live power leaves partial off-block geometry or a deferred
cut journal.

The production HUD renders the three/four-card modal, visibly distinct quality
badges and effect deltas, input-transparent falling tree/log/leaf accents, the
six-slot strip, automatic cooldown/ready state, charges/stacks, and acquisition/
trigger feedback. All 27 powers have distinct vector emblems with a neutral,
equal-identity background; the same icon is used by Home, offers, and
the live loadout. The active strip is a `356×42` row centered at the top
immediately below the XP bar. Each active slot shows only its icon and `R#`—no
name or runtime-status copy—while full details stay on Home and level-up cards,
so the strip no longer blocks the lower chopping view. Flying Wedge, Crosscut
Sweep, and Maul Drop have distinct
code-native proc silhouettes; Whirling Axe renders its orbiting tools, and
Splitter Rig visibly claims and transfers its target. Other triggers use
power-colored burst feedback. Yard Magnet applies its deliberately gentler Rank
1 pull only while a loose root is in live contact with the yard floor. It fires
an immediate `0.5`-second pulse on acquisition, then repeats every `5` seconds at
Rank 1. Its explicitly provisional interval ladder is `5 / 4.5 / 4 / 3.5 / 3 /
2.5 / 2 / 1.5` seconds; rank force still uses the separate `0.1`–`0.8` ladder.
During a pulse, planar motion is updated on physics ticks toward one fixed,
reachable approach dock outside the actual block collider, immediately enters
the authored capped speed, and eases down before contact. The clearance includes
the landed root's current world-planar support, including sideways and split
geometry. Valid floor contact suppresses upward bounce and tumbling so each
pulse reads as a clean arcade ground glide. While engaged, its controller
temporarily removes floor friction and locks all rotation; the pulse ending,
leaving the floor, or entering delivery restores ordinary rigid-body physics.
Cycle and pulse timers pause, save, restore, reset, and report separately to the
HUD.

## Remaining boundaries

The quality odds, value multipliers, and all authored power numbers remain
labelled `PLACEHOLDER` until measured tuning approval. Release captures remain
separate work.

Do not revive permanent skill writes or proc dictionaries. Chopping and arena
effects read the typed permanent-plus-run modifier aggregation surface.
