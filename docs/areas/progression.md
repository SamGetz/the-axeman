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

A fresh profile owns all twelve Core run powers and no Blueprint powers. Each
settled Blueprint roll deterministically selects a still-locked Blueprint
without duplicates. Once exhausted, the roll converts through its explicit
placeholder Home Cash row.

Only yard one is selectable in this milestone. Fall Frequency Control unlocks
three choices beyond the default; it does not add a separate reward multiplier.

## Home and run lifecycle

The startup overlay is the Home hub for an existing profile. It exposes all 18
upgrade lines, the yard/frequency selector, the 24-power catalogue, records, and
Start/Resume/Abandon. Purchase, refund, yard, and frequency controls are disabled
whenever a live or suspended attempt exists. Home changes save through the
`GameState.profile_changed` flow without erasing an attempt section.

`RunDirector` starts every attempt at Level 1 with zero XP, cash, and selected
powers. It owns the 20-minute yard clock, level-driven delivery pressure, queued
power choices, and the result state. Stage clear pauses on an explicit Endless
or bank decision; a generic resume never makes that choice for the player.

Cash and XP rewards are authoritative immediately. Their displayed totals are
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

This guide describes the live Slice 2 authority and UI boundary. Shared loose
slicing and Blaster are Slice 3. Boss runtime, Blueprint reward delivery,
cascades, and the full 24-power behavior implementation remain Slice 4.
