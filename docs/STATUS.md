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
| M8 Slice 2 mastery effects/UI | Implemented for review 2026-08-05; 45/45 |
| M8 Slice 3 certified splitter purchases/assignment | Approved by Sam 2026-08-05; covered by the verified M8 completion suite |
| M8 Slice 4 watched Mechanical Splitter runtime/progression | Approved by Sam 2026-08-05; 93/93 |
| M8 Slice 5 derived Purchased shop tab | Approved by Sam 2026-08-05; 101/101 |
| M8 Mechanical Splitter measured tuning | Approved by Sam 2026-08-05; 101/101 |
| M8 Slice 6 and later | Not authorized to start |

M7C Slice 7 made Follow-Up an automatic bonus swing after a landed root swing,
with its own real split roll and a recursion guard. Ready Stance accelerates the
axe wind-up only; contact restores the ordinary follow-through rate.

M8 Slice 1 records one bounded mastery counter per species from the existing
de-duplicated manual log root. Shared 1 / 5 / 10 reward thresholds carry labelled
cash, XP and reliability placeholders. Save version 3 introduced the counters
and migrated versions 1 and 2 without inventing historical mastery.

M8 Slice 2 sums every reached threshold across species. Cash modifies ordinary
Market baskets but not fixed order premiums; manual XP applies after existing
proc calculation; split reliability adds before the existing cap. Owned rows in
the standalone Tree Catalog shows live progress, the next authored reward, and
mastered state.

M8 Slice 3 adds an inert Mechanical Splitter purchase and three early-species
cutting profiles. The shop derives certification gates from mastery, purchases
remain atomic, and ownership persists through existing building tiers. The
shop now separates ordinary Items from a dedicated Mechanical Splitter tab. The
frequently checked Tree Catalog has its own bottom-right icon/window and owns the
single validated splitter assignment, persisted by save version 4. The splitter
service does not yet run a timer, write inventory, award XP/mastery or simulate
offline progress. Once mastery certifies a supported tree, its Tree Catalog row
now provides an active route to the required machine/profile purchase instead
of presenting disabled shop prompts.

M8 Slice 4 makes that first machine visible as a native-node greybox with its
missing authored art labelled in-world. An always-on card reports locked,
unassigned, missing profile, ready, processing or output blocked. The player
loads the one input slot from the sole persisted Tree Catalog assignment; only
active yard time advances the watched cycle. One completed receipt deposits the
assigned `SpeciesDef.yield_item` through `InventoryManager`, sells it through an
automation-specific `Market` path, pays cash through `GameState`, and awards 20%
of the assigned species' XP through `GameState`. It does not advance orders,
lifetime chopped, mastery or certification and cannot trigger manual skill
procs. One static representative log appears on the bed during processing; it
disappears on completion without runtime slicing or multiple species geometry.
Queue/progress/output receipts are deliberately ephemeral, so restore grants
nothing.

Sam's five splitter upgrade identities are Speed, Auto Loading, Logs per Split,
Experience Gain and Money Gain. They reveal in that order, each after the first
rank/purchase of the previous line. Only Auto Loading is one-time; the other
four are bounded tiered rows. The identities/order and starting 20% XP rate are
approved direction. Sam approved the complete measured band on 2026-08-05: a
5-second base cycle, one firewood per represented log, a 50% Speed floor, 1,000
machine / 250 profile prices, 2,500 Auto Loading, five 10% Speed ranks, seven
Logs ranks from 5 to 12, four 20-point XP ranks from 20% to 100%, and five 10%
Money ranks. Typed resources carry the approved price-growth values.

Sam approved a 4x firewood-value injection on 2026-08-05. Every entry in the
single `data/price_table.tres` market ladder is multiplied by four; relative wood
ordering and every sale ownership boundary remain unchanged.

M8 Slice 5 adds a third Purchased shop tab without adding purchase-history
state. Completed one-time purchases and fully maxed tiered rows are derived from
the existing persisted building tiers, leave their functional tab, and appear
in authored order as read-only Owned or Maxed entries. A tiered row stays in
Items or Mechanical Splitter while another rank remains available. Items and
Mechanical Splitter remain separate tabs; Tree Catalog remains its standalone
bottom-right window. Save version remains 4 because the on-disk shape is
unchanged.

## Known, undecided gaps

- Follow-Up has no owned-modifier escape from the precision guard equivalent to
  Double Strike's Steady Continuation.
- `GameplayModifierDef.Kind.WINDUP_TIME` and `SWING_RECOVERY` remain declared
  but unused.
- Final proc odds, caps, bad-luck bounds, node costs, wind-up cap, mastery
  thresholds and mastery reward magnitudes remain labelled tuning placeholders.
- M4's `max_firewood` soft cap and the nominal fragment physics budget are still
  separate tuning concepts.

## Current test baseline

The authoritative tests are the live test files. The latest verified human
baseline is M1 19, M2 24, M3 16, M4 55, M7A 285, M7C 221, M8 Slice 5 and
measured splitter tuning 101, slicer 34. See `docs/TESTING.md` for commands and
non-headless requirements.
