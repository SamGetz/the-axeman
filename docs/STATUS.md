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
| M8 Slice 5 derived Purchased shop tab | Approved by Sam 2026-08-05; 104/104 with discovery regression |
| M8 Slice 6 Certified Yard Expansion | Implemented for Sam's review 2026-08-05; M8 121/121, M7A 289/289 |
| M8 Mechanical Splitter measured tuning | Approved by Sam 2026-08-05; 104/104 with discovery regression |
| Startup New Game / Load Game boundary | Approved by Sam 2026-08-05; 17/17 |
| Hidden-lock progression discovery | Approved by Sam 2026-08-05; M7A 285/285, M8 104/104 |
| Manual reward receipts and level-up feedback | Approved by Sam 2026-08-05; M4 55/55, M7A 285/285, M7C 221/221 |
| M8 Slice 7 and later | Not authorized to start |

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
offline progress.

M8 Slice 4 makes that first machine visible as a native-node greybox with its
missing authored art labelled in-world. Once the machine is installed, its card
reports unassigned, missing profile, ready, processing or output blocked. The player
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

M8 Slice 6 extends the one-time contract ladder to all 25 species and gives
every species one certified Mechanical Splitter profile. The first three
contracts/profiles and approved splitter upgrade band remain unchanged. The 23
later contracts and 22 later profiles use explicitly labelled placeholder
counts, bonuses and prices pending measured post-M8 tuning. Later profiles
require their matching contract, their own species certification and the
installed machine. The contract board separates revealed incomplete work into
Open and compact read-only history into Completed; unrevealed contracts remain
absent.

Watched splitter settlement now emits presentation-only start/cancel signals
around the existing authoritative completion receipt. A separate prewarmed
pool stages one unpaid splitter coin, exact cash and XP receipts, and procedural
wood chips without sharing manual reward nodes. The representative greybox log
uses the assigned species' bark and inside treatments, the machine has a short
completion impulse, and the required authored-art marker is subordinate to a
larger operational state. Queue and receipt presentation remain ephemeral;
save version stays 4.

Locked progression content no longer appears as disabled shelf rows or future
contract cards. The Shop lists unlocked/owned rows only, hides the entire
Mechanical Splitter tab until the machine gate is earned, and hides the runtime
card and Tree Catalog assignment controls until their underlying machine/profile
routes exist. Contracts, purchases, the first-haul milestone, level-ups and the
final mastery threshold now name the content they unlock as an explicit reward.
The skill tree remains a visible prerequisite map rather than a storefront.

Startup no longer auto-loads or silently starts fresh. The native stand-in menu
keeps the yard's rendering and processing disabled until the player explicitly
chooses New Game or Load Game. Load is disabled when no save exists. Replacing
an existing autosave requires confirmation, and the fresh state is written via
SaveSystem's atomic temp-file route before gameplay begins. Missing, corrupt or
newer-version loads remain at the menu with a player-facing error; autosave and
save-on-quit cannot write until a session has successfully started.

Manual completion feedback now keeps progression authoritative while presenting
it one receipt at a time. XP is banked immediately, then pooled green orbs fly to
the live fill edge and advance the displayed XP strip by their exact shares.
Each sold firewood payout is attached to one pooled coin only after Market and
Orders settle it; the coin waits beside the log until that receipt exists, then
flies to the cash counter, increments it and contributes one capped bounce-grow
impulse before disappearing. A pooled procedural gold ring/ray/spark celebration
surrounds the block on level-up. The full XP, coin and level-up node pools are
built during initial scene load, and one covered startup render submission warms
their Compatibility-renderer material pipelines before gameplay. Final VFX art
and feel values remain explicitly replaceable stand-ins.

## Known, undecided gaps

- Follow-Up has no owned-modifier escape from the precision guard equivalent to
  Double Strike's Steady Continuation.
- `GameplayModifierDef.Kind.WINDUP_TIME` and `SWING_RECOVERY` remain declared
  but unused.
- Final proc odds, caps, bad-luck bounds, node costs, wind-up cap, mastery
  thresholds and mastery reward magnitudes remain labelled tuning placeholders.
- M4's `max_firewood` soft cap and the nominal fragment physics budget are still
  separate tuning concepts.
- Slice 6's 20-piece contract counts, scaled contract bonuses, scaled profile
  prices and splitter receipt timing remain visibly labelled placeholders.
  Level 9/49/96 structural probes pass, but a later live pacing review must
  decide whether any authored row should change.

## Current test baseline

The authoritative tests are the live test files. The latest verified baseline
is M1 19, M2 24, M3 16, M4 55, M7A 289, M7C 221, M8 Slice 6 121, startup 17,
slicer 34. The Slice 6 pacing probe passes at levels 9, 49 and 96, and the
expanded non-headless tool captures the full 1280x720 contract/profile/runtime
matrix. See `docs/TESTING.md` for commands and non-headless requirements.
