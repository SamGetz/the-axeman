# Current project status

Last updated: 2026-08-05.

This is the short operational status. Historical suite growth and implementation
narrative belong in `docs/history/` or git history.

## Scope

The shipped game is the log-cutting and lumberyard progression game. Tree
felling and ore mining are removed. Villagers/staff are removed from the
automation design. Do not begin a new module or slice without Sam's approval.

## Milestones

| Area | State |
|---|---|
| M1 core contracts | Implemented; 19/19 |
| M2 scene shell/render pipeline | Implemented; 24/24 |
| M3 GameFeel | Implemented; 16/16; Creative Director tuning remains separate |
| M4 chopping game | Integrated; 55/55; core feel has been positively reviewed |
| M7A progression/orders/shop | Implemented; 285/285 |
| M7C Strength, Technique, Speed slices | Signed off 2026-08-05; 221/221 with M8 completion regression |
| Runtime slicer | 34/34 |
| M8 Slice 1 mastery contracts/persistence | Signed off 2026-08-05; 29/29 |
| M8 Slice 2 mastery effects/UI | Authorized 2026-08-05; implementation pending |
| M8 Slice 3 and later | Not authorized to start |

M7C Slice 7 made Follow-Up an automatic bonus swing after a landed root swing,
with its own real split roll and a recursion guard. Ready Stance accelerates the
axe wind-up only; contact restores the ordinary follow-through rate.

M8 Slice 1 records one bounded mastery counter per species from the existing
de-duplicated manual log root. Shared 1 / 5 / 10 reward thresholds carry labelled
cash, XP and reliability placeholders, but do not affect gameplay until Slice 2.
Save version 3 persists the counters and migrates versions 1 and 2 without
inventing historical mastery.

## Known, undecided gaps

- Follow-Up has no owned-modifier escape from the precision guard equivalent to
  Double Strike's Steady Continuation.
- `GameplayModifierDef.Kind.WINDUP_TIME` and `SWING_RECOVERY` remain declared
  but unused.
- Final proc odds, caps, bad-luck bounds, node costs, wind-up cap, mastery
  thresholds, and mastery reward magnitudes remain labelled tuning placeholders.
- M4's `max_firewood` soft cap and the nominal fragment physics budget are still
  separate tuning concepts.

## Current test baseline

The authoritative tests are the live test files. The latest verified human
baseline is M1 19, M2 24, M3 16, M4 55, M7A 285, M7C 221, M8 Slice 1 29,
slicer 34. See `docs/TESTING.md` for commands and non-headless requirements.
