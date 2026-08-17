# Progression area guide

Read this for Home Cash, permanent upgrades, run settlement, power ownership,
records, saves, migration, or suspended-attempt locking.

## Authority

- `InventoryManager` is the only inventory writer.
- `GameState` is the v19 permanent-profile authority.
- `RunDirector` owns disposable attempt state, including session cash.
- `SaveSystem` serializes those owners without becoming an authority itself.
- `SurvivorsContent` exposes the validated immutable meta, power, yard, and
  migration-refund catalogues.

Permanent XP, skill points/ranks, species purchasing, old equipment ownership,
Harvest Capacity, Woods, and the in-run shop are retired. `Shop`, `SkillTree`,
and `ProgressionProcs` are neutral migration/presentation facades only.
Live permanent-capability consumers, including Hold-to-Chop and Continuous
Handoff, query `GameState.has_meta_capability()` rather than the retired
`SkillTree` modifier facade.

## Permanent economy

Every attempt starts with zero session cash. Session cash cannot be spent in
play. Failure and **Bank & Go Home** send the whole purse to Home Cash through
`GameState.bank_run()` and record its stable run id so the same attempt cannot
pay twice. Continuing Endless defers that transfer. If validation or capacity
rejects settlement, the attempt remains paused and resumable; Abandon explicitly
forfeits the purse.

The 18 upgrade lines store a rank and one exact amount-paid ledger entry per
rank. Purchase validates cost, cap, prerequisite, cash, and lock state before
committing. Full refund sums that historical ledger; free migrated capability
ranks carry zero entries. Blueprint ownership and yard records are unaffected.

Permanent purchase, refund, direct unlock, yard, and frequency controls are
read-only while a suspended/live attempt lock exists.

## Content ownership

A fresh profile owns all fourteen Core run powers and no Blueprint powers. Each
settled Blueprint roll deterministically selects a still-locked Blueprint
without duplicates. Once exhausted, the roll converts through its explicit
placeholder Home Cash row.

Run offers respect that ownership boundary. Card quality is rolled only after a
legal unlocked power identity is selected, so Epic or Legendary quality never
unlocks a Blueprint. Every accepted power card grants exactly one owned rank;
Rare, Epic, and Legendary modify only that rank's effect increment. Per-rank
quality multipliers persist with the suspended attempt. Every eligible power
identity is sampled uniformly; Luck affects card count and Rare/Epic quality
weights, not the identity selected.

Only yard one is selectable in this milestone. Fall Frequency Control unlocks
three choices beyond the default; it does not add a separate reward multiplier.

## Home and run lifecycle

The startup overlay is the Home hub for an existing profile. It exposes all 18
upgrade lines, the yard/frequency selector, the 27-power catalogue, records, and
Start/Resume/Abandon. Purchase, refund, yard, and frequency controls are disabled
whenever a live or suspended attempt exists. Home changes save through the
`GameState.profile_changed` flow without erasing an attempt section.

`RunDirector` starts every attempt at Level 1 with zero XP, cash, and selected
powers. It owns the 15-minute yard clock, level-driven delivery pressure, queued
power choices, and the result state. Stage clear pauses on an explicit Endless
or bank decision; a generic resume never makes that choice for the player.

Each selectable level is one standalone `YardDef` resource under
`the-axeman/data/yards/`. Open `yard_one_placeholder.tres` for Yard One's
identity, duration, species windows and weights, rewards, frequency-tier scales,
XP/hardness rows, bosses, and unlock metadata. Its linked native Godot curves
`yard_one_delivery_interval_curve.tres` and
`yard_one_delivery_amount_curve.tres` own falling-wave seconds and log count by
run level. The catalogue only lists these level resources; runtime contains no
hardcoded batch ramp.

Yard One's migrated provisional interval curve begins at
`2.166667 / 1.7333335 / 1.3666665 / 1.0666665` seconds across the four tier
scales and reaches its `0.2`-second safety floor at Level 20 on the default tier.
The separate amount curve authors one root through Level 19, two at Level 20,
then one more per level through ten at Level 28. The final minute and Endless
read the curves' rightmost `0.2`-second/ten-root endpoints. Ordinary and
boss reward rows use nearest-whole `25%` of prior Cash and `50%` of prior XP.
Every disposable XP source then receives the user-directed provisional `1.30×`
global gain multiplier; run-power multipliers compose with it once. Species
windows and the three boss schedules remain compressed proportionally into the
900-second run.

Each scheduled boss is a five-root top-down stump stack. Its authored Cash/XP
jackpot is divided exactly across those roots, while every layer uses ordinary
current-level hardness instead of the retired single-root boss multipliers.
Only clearing the fifth layer increments the boss record and creates one pending
Blueprint roll for settlement. Schedule progress, the queued/active encounter,
remaining root descriptors, exact rewards, boss count, and pending roll survive
attempt save/restore.

Cash and globally scaled XP rewards are authoritative immediately. Root and boss
XP snapshots include the `1.30×` gain at delivery time, while event bonuses use
the same scaling helper immediately before commitment. Their displayed totals are
staged by presentation receipts: coins target the session-cash label and XP
orbs target the current fill edge of the XP bar. Missing/cancelled VFX settle
their receipts immediately, so suspension or shutdown cannot lose value or
leave a level choice blocked.

## Save v19 and migration

The ConfigFile has `meta`, `profile`, `inventory`, and `attempt` sections.
Profile-only saves preserve an existing attempt; clearing an attempt is an
explicit API. Atomic replacement uses a temporary file and protected predecessor
and can recover from interruption between the two renames.

Before replacing v18 or earlier, `SaveSystem` must create a collision-safe,
byte-identical backup. Invalid content, missing sections, wrong authority types,
or backup failure abort migration and leave the source untouched.

V18 migration transfers only `attempt.cash`; stale `profile.cash`, gross earned
cash, and spent-run counters are not currency. Pinned placeholder tables convert
recognized equipment, species ownership, XP/skill entitlement, and safe
capabilities. Inventory, pile, lifetime work, and old Earth/overflow values are
preserved as current or read-only records. Incompatible attempt geometry is
discarded with a one-time notice.

Earlier migration also preserves old unspent cash, applies baseline-one tier
rules, de-duplicates species ownership, avoids XP/skill double counting, and
replays only value-relevant historical derivations for v1, pre-v15, and v16.

## Gate boundary

The authority and UI rules above remain the live boundary. Shared loose-root
slicing and the complete 27-power behavior/VFX set now consume these public
surfaces without moving inventory or permanent progression writes out of their
owners. The boss encounter/reward path is live; measured balance tuning remains
separate work.
