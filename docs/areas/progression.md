# Progression area guide

Read this for Home Cash, permanent upgrades, run settlement, power ownership,
records, saves, migration, or suspended-attempt locking.

## Authority

- `InventoryManager` is the only inventory writer.
- `GameState` owns the v19 permanent profile.
- `RunDirector` owns disposable attempt state and session Cash.
- `SaveSystem` serializes those owners without becoming an authority.
- `SurvivorsContent` exposes validated immutable catalogues.

Permanent XP, skill points/ranks, species purchasing, equipment, Harvest
Capacity, Woods, and in-run spending are retired and removed. Live capability
checks use `GameState.has_meta_capability()`.

## Permanent economy

Each attempt starts with zero session Cash. Failure and **Bank & Go Home** send
the full purse through `GameState.bank_run()` with a stable settlement id, so an
attempt cannot pay twice. Endless defers settlement. Failed validation leaves
the attempt resumable; Abandon explicitly forfeits it.

The thirteen live upgrade rows store a rank and the exact amount paid for each
rank. Purchase validates cost, cap, prerequisite, Cash, and attempt lock before
mutation. Full refund sums the ledger; free migrated ranks carry zero-cost
entries. Five removed rows—Ready Stance, Block Control, Boss Handling, Blaster
Duration, and Off-Block Cutting—are recognized only during load and refunded
from their historical paid ledgers.

Purchase, refund, direct unlock, yard, and frequency controls are read-only
while a live or suspended attempt exists.

## Run ownership and lifecycle

Fresh profiles own fourteen Core powers and no Blueprint powers. Settled boss
rolls unlock still-locked Blueprints without duplicates; exhaustion converts
through the labelled placeholder Cash row. Offers respect ownership, select
eligible identities uniformly, and roll quality separately. Quality strengthens
one selected rank's increment; it never unlocks a Blueprint or grants extra
ranks.

Home exposes the thirteen upgrades, Yard One frequency choices, the 27-power
catalogue, records, and Start/Resume/Abandon. `RunDirector` starts at Level 1
with zero XP, Cash, and selected powers. It owns the 15-minute clock, deliveries,
queued choices, and result state. Stage clear requires an explicit Endless or
bank decision.

Yard One is `data/yards/yard_one_placeholder.tres`. Its linked native curves
own seconds and whole logs per falling wave. The interval curve's three authored
anchors are Level 1 at `2.166667` seconds, approximately Level 15.2 at
`0.8145385`, and Level 35 at `0.2`; frequency-tier scales multiply the sampled
interval. The amount curve stays at one root through Level 19, reaches two at
Level 20, and climbs to ten at Level 28. Final-minute and Endless pressure use
the rightmost `0.2`-second/ten-root points.

Each scheduled boss is a five-root stack. Ordinary level hardness applies to
each layer, while the authored jackpot divides exactly across the five roots.
Only clearing the fifth records the boss and produces one Blueprint roll.
Schedule, active stack, descriptors, exact rewards, and pending roll all survive
suspend/restore.

Cash and globally scaled XP commit immediately. Coins and XP orbs are display
receipts only; cancellation settles them so saving or shutdown cannot lose
value or block a level choice.

## Save and migration

The v19 ConfigFile has `meta`, `profile`, `inventory`, and optional `attempt`
sections. Profile-only saves preserve an attempt. Atomic replacement uses a
temporary file and protected predecessor, and startup can recover an interrupted
replacement.

Before replacing v18 or older, `SaveSystem` creates a byte-identical backup.
Invalid content or backup failure aborts migration without modifying the source.
Migration retains only value-bearing records: eligible old Cash, inventory,
lifetime work, safe capability equivalents, Blueprint entitlement, and exact
refunds for retired paid meta rows. Incompatible attempt geometry is discarded;
old partial off-block cuts have one bounded reconstruction path.

All migration tables remain labelled placeholders where conversion values have
not received final approval.
