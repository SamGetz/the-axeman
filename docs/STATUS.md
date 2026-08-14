# Current project status

Last updated: 2026-08-14.

## Survivors progression pivot

Implementation is stopped at the **Slice 2 approval gate**. The permanent and
persistence authorities from Slice 1 remain in place, and the Home hub, timed
yard-one loop, run XP/offers, staged reward presentation, and settlement/results
flow are now live.

`GameState` now owns Home Cash, the exact paid-rank ledger for the 18 permanent
upgrade lines, unlocked run powers, selected yard/frequency, per-yard records,
one-time migration notice, monotonic run identities, and exact-once settlement
ids. A full refund returns only recorded spend, preserves Blueprint unlocks and
records, and clamps delivery-frequency selection.

`RunDirector` owns the current session purse, Level 1 run XP, queued level
choices, six run-power slots, utility charges, stage time/pressure, and results.
Session cash cannot be spent in play. Failure and **Bank & Go Home** transfer the
whole purse exactly once; a rejected bank leaves the attempt paused, locked, and
resumable. Explicit Abandon forfeits it. The old Shop, SkillTree, and equipment
proc surfaces are behaviorally inert and remain only for migration or temporary
visual lookup.

## Slice 2 live loop

Startup now opens a dedicated Home hub with all 18 permanent upgrades, four
yard-one starting-frequency choices, the 24-power catalogue, records, and
Start/Resume/Abandon controls. Permanent controls are locked while an attempt is
suspended, and exact-ledger full refunds persist through reload.

Yard one runs for 20 gameplay minutes. Its countdown and delivery-pressure
timers pause with menus and power choices. Reaching the boundary opens an
explicit **Continue Endless** or **Bank & Go Home** decision; generic Resume
cannot choose Endless. Failure and cash-out show a result before routing Home.

Run XP is authoritative when earned, while the visible XP value and level-choice
pause wait for the corresponding orb to reach the live edge of the XP bar.
Choices offer three distinct cards, with Luck able to add a fourth, and support
reroll, banish, serial queued levels, a hard six-slot limit, and deterministic
save/restore of cards and RNG. Quick Study and Keen Appraisal already feed the
typed modifier aggregation surface; the remaining power behaviors are Slice 4.

Root cash is committed once at completion, independently of whether presentation
tokens survive. Each landed firewood receipt validates through
`InventoryManager` and releases only its visible share. Coins fly to the
prominent session-cash counter, while the permanent Home bank stays visible as a
smaller locked counter. Displayed cash never leads the authoritative purse.

## New content contracts

- `MetaUpgradeTable`: exactly 18 visible, bounded permanent lines.
- `RunPowerTable`: 12 Core and 12 Blueprint powers with fixed rarity and caps.
- `YardTable`: one 1,200-second yard row, six species, four starting frequency
  tiers, 35 level-pressure rows, and three scheduled boss definitions.
- Typed run/root schemas capture yard, run, boss, hardness, rewards, original
  mass, descendant paths, and one completion receipt per root.

Every unapproved cost, effect, interval, reward, hardness, boss, and conversion
value remains explicitly labelled `PLACEHOLDER` in its resource.

## Save v19

The v19 profile and optional attempt are separate sections. Current-version
loads require their complete top-level shape and reject malformed scalar types.
Atomic writes protect the previous file through `.tmp` and `.replacing`, and
startup restores an interrupted replacement before proceeding.

V18 and earlier files receive a byte-identical timestamped backup before any
replacement. Migration transfers the v18 attempt purse, converts only pinned
legacy ownership/entitlement rows, seeds the three safe capability equivalents,
preserves inventory/pile/lifetime records, and discards incompatible geometry.
The bounded historical derivations that affect value are covered for v1 skill
aliases, pre-v15 Earth/lifetime records, and v16 alien-mastery entitlement.

## Remaining implementation boundaries

The live milestone is still block-only. Shared loose-root slicing, descendant
hazards, piece budgets, and temporary Blaster behavior are Slice 3. Boss runtime,
Blueprint banking, cascades, and the complete behavior/VFX pass for all 24 powers
are Slice 4. Generated asset completion, tuning, and release captures are Slice
5. Retired Earth, Slow Time, ammunition, Woods, Harvest Capacity, and in-run
spending no longer appear in the live Slice 2 UI.

## Verification

- Survivors Slice 1 authority/catalogue/migration acceptance: **106/106**.
- Home hub production acceptance: **23/23**.
- Run XP/reward-flight acceptance: **21/21 headless**, **24/24 rendered**.
- Run-power offer production acceptance: **27/27 headless**, **30/30 rendered**.
- Timed stage/results production acceptance: **25/25**.
- Survival ownership/lifecycle regression: **40/40**.
- Production Main smoke: **11/11**.
- Active cut-journal restore: **6/6**.
- Runtime slicer: **34/34**.
- Godot 4.7.1 headless editor import/parse: **PASS**.

Reviewed 1280×720 captures cover Home sections, XP flight/arrival, coin flight,
normal three-card choices, and the six-slot HUD. No later implementation slice
should begin until Sam approves this gate.
