# Current project status

Last updated: 2026-08-09.

This is the short operational status. Historical suite growth and implementation
narrative belong in `docs/history/` or git history.

## Scope

The shipped game is the log-cutting and lumberyard progression game. Tree
felling and ore mining are removed. Villagers/staff are removed from the
automation design. Sam authorized the continuous playable campaign through M14
on 2026-08-06. The post-M14 procedural postgame remains out of scope.

## Milestones

| Area | State |
|---|---|
| M1 core contracts | Implemented; 19/19 |
| M2 scene shell/render pipeline | Implemented; 24/24 |
| M3 GameFeel/global config | Implemented; 18/18; Creative Director tuning remains separate |
| M4 chopping game | Integrated; 55/55; core feel has been positively reviewed |
| M7A progression/orders/shop | Implemented; 294/294 |
| M7C Strength, Technique, Speed slices | Signed off 2026-08-05; 221/221 with M8 completion regression |
| Runtime slicer | 34/34 |
| M8 Slice 1 mastery contracts/persistence | Signed off 2026-08-05; 29/29 |
| M8 Slice 2 mastery effects/UI | Implemented for review 2026-08-05; 45/45 |
| M8 Slice 3 certified splitter purchases/assignment | Approved by Sam 2026-08-05; covered by the verified M8 completion suite |
| M8 Slice 4 watched Mechanical Splitter runtime/progression | Approved by Sam 2026-08-05; 93/93 |
| M8 Slice 5 derived Purchased shop tab | Approved by Sam 2026-08-05; 104/104 with discovery regression |
| M8 Slice 6 Certified Yard Expansion | Approved by Sam 2026-08-05; M8 122/122, M7A 294/294 |
| M9 standing campaign commissions | Reworked 2026-08-09; 32/32; save v17; five long-term choices with automatic tracking/payout |
| M7B craftsmanship/customers/reputation | Implemented 2026-08-06; 16/16; save v7 |
| M7D derived visible yard progression | Implemented 2026-08-06; 12/12; four foundational states plus headquarters |
| M8 certified logistics/offline foundations | Implemented 2026-08-06; 19/19 focused plus 122/122 legacy; save v8 |
| M9 regional supply network | Implemented 2026-08-06; 15/15; save v9 |
| M10 continental company/build variety | Implemented 2026-08-06; 14/14; save v10 |
| M11 global wood mastery | Implemented 2026-08-06; 9/9 |
| M11B final terrestrial species | Implemented 2026-08-06; 11/11 |
| M12 launch programme | Implemented 2026-08-06; 12/12; save v11 |
| M13 first alien expedition | Implemented 2026-08-06; 13/13; save v12 |
| M14 interplanetary timber company | Implemented 2026-08-06; 10/10 |
| Four-hour campaign experience pass | Implemented 2026-08-09; campaign experience 12/12, M15 29/29, full campaign 10/10; values remain provisional |
| First-time tutorial and placeholder graphics | Implemented 2026-08-07; 31/31; all lessons use a two-second post-event delay |
| Fresh campaign through credits | Implemented 2026-08-09; accelerated public-API harness 10/10 |
| M8 Mechanical Splitter measured tuning | Approved by Sam 2026-08-05; 104/104 with discovery regression |
| Startup New Game / Load Game boundary | Approved by Sam 2026-08-05; 17/17 |
| Hidden-lock progression discovery | Approved by Sam 2026-08-05; M7A 285/285, M8 104/104 |
| Manual reward receipts and level-up feedback | Approved by Sam 2026-08-05; M4 55/55, M7A 285/285, M7C 221/221 |
| M9 Slice 2 through playable M14 minimum campaign | Complete 2026-08-06; post-M14 remains unauthorized |

The four-hour experience pass makes `3,040,000,000,000` Earth trees authoritative across manual,
watched, active-company and offline receipts. Final output is capped before
inventory, XP and cash; zero is the only launch authority and terrestrial
production then reports exhaustion. Lifetime earned cash is monotonic and
reveals finite, milestone-gated production upgrades without rebasing their fixed
prices. The maximum provisional planetary set reaches zero inside a 16.5–17
minute final production band. Four unique completed manual logs now
advance the Earth counter by exactly one tree; automation continues to report
explicit tree volume separately from recovered sellable output. The deterministic
grant-free policy now reaches watched automation at about 35 minutes, company
scale at about 70 minutes, Earth zero at about 159 minutes and modeled credits at
about 200 minutes including fifteen minutes of management/read time. It projects
159 terrestrial manual logs and a 54.4% tactile share. All pacing values remain
labelled placeholders until uninterrupted novice fresh-save playtests approve them.

The first-time guide is armed by New Game but remains completely absent until
the first skill point at level 2. Ada introduces Skills there; level 3 then
reveals Jobs. Rowan Pike teaches the four-logs-per-tree manual receipt,
automatic sale, the first completed job, Shop, Tree Catalog and Job Board; Ada
Gearhart introduces reinvestment, skills and automation; Nova Quill
appears only when Atlas or launch work is actionable. Each beat observes public
progression/HUD signals, persists through the v16 introduced-feature
ledger, can resume after load, can be closed without skipping, can be skipped
permanently, and grants nothing. A replay button remains available after the opening. Generated portraits and code-native
vector placeholders replace every explicit missing-art label in the live HUD
and early equipment presenter while remaining tagged for final-art replacement.
All five dock controls are absent on a fresh yard: Jobs appear at level 3, Shop
appears after any authored job is completed, Skills after the first earned point,
Catalog at its first usable species/equipment route, and Atlas after earned
regional progress. Cash cannot bypass the Jobs or Shop gates. Future rows,
regions and reward identities remain hidden until their own public gates are live.

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

Standing commissions are now a five-moment campaign system, not a repeatable
board chore. The player chooses one of three deterministic offers after Pine
Campsite, first company scale, terrestrial readiness, Earth zero and first alien
mastery. Only one commission can be active; progress and payout are automatic,
and fast completion cannot immediately trigger another choice. The retired board
tab stays hidden. The compact top-right chip shows every choice at once without a
modal or scroll, then collapses to the active long-term goal.

Each generated offer remains a persisted immutable snapshot. Rewards use the
labelled relevance ratio against the next meaningful species, launch project or
alien-line expense, with delivered work value as a floor. Save v17 preserves
offer moments, the active identity/progress, completion history and exact-once
reward sources; older multi-slot work is retained only as legacy compatibility.
Effort counts, premiums and cadence remain explicitly labelled placeholders.

Locked progression content no longer appears as disabled shelf rows or future
contract cards. The Shop lists unlocked/owned rows only, hides the entire
Mechanical Splitter tab until the machine gate is earned, and hides the runtime
card and Tree Catalog assignment controls until their underlying machine/profile
routes exist. Contracts, purchases, the first-haul milestone, level-ups and the
final mastery threshold now name the content they unlock as an explicit reward.
The skill window presents one readable branch at a time. Strength is available
at the first point, Speed at Working Yard, Mastery at Regional Company and
Frontier only in the Cosmic Finale. Locked paths stay readable inside the active
branch. The 36 core nodes cost exactly 84 points; terrestrial level rewards stop
at that entitlement and switch to cash. Three alien masteries grant exactly nine
additional points for the nine one-rank Frontier nodes, so the complete tree costs
93 without an early cap-out or postgame grind. A full respec refunds the existing
point entitlement and charges 20% of current cash.
Skill values are final: ranked cards calculate the current and 5/5 bonus from
live data, while chance-based skills state their chance, guaranteed-proc limit
and reward in player-facing language.

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
When a share crosses a level boundary, the prior level visibly reaches 100%
before the label, skill point, tutorial state and pooled celebration advance.
The celebration retains vertical rays, sparks and light without the former
ground halo rings. Tutorial cards then wait five seconds after their triggering
event so these rewards and unlocks can read before guidance enters.
Each sold firewood payout is attached to one pooled coin only after Market and
Orders settle it; the coin waits beside the log until that receipt exists, then
flies to the cash counter, increments it and contributes one capped bounce-grow
impulse before disappearing. A pooled procedural gold ring/ray/spark celebration
surrounds the block on level-up. The full XP, coin and level-up node pools are
built during initial scene load, and one covered startup render submission warms
their Compatibility-renderer material pipelines before gameplay. Final VFX art
and feel values remain explicitly replaceable stand-ins.

## Continuous campaign implementation (M7B–M14)

Craftsmanship now settles through `ManualPieceReceipt`, carrying species, item,
normalised size, grade, source-log identity and origin. Rough work always keeps
base value; clean and exceptional bands, customer families, reputation and
bounded customer history are typed and resource-backed. Automation-origin
receipts cannot enter any manual craftsmanship, signature, mastery, perfect-log
or Axeman XP path. The wood selector remains the authoritative owned-species
supply choice.

The yard derives stump, shed, working yard, depot and headquarters presentation
from purchases and completed infrastructure instead of persisting a cosmetic
tier. Native equipment, staging, trophies, vehicles, Mission Control, gantry,
vessel, specimen rig and fleet pad remain Compatibility-safe greybox geometry.

The watched splitter contract is unchanged. Six sequential logistics purchases
add bounded supplier queues, route priorities, blocked-output recovery and a
deterministic company simulator. Active and offline runs consume identical
persisted inputs and return unapplied receipts. Offline time is capped and may
not discover, certify, master, present a story beat or cross the Earth finale.

The Supplier Atlas owns seven authored Earth regions and one source for each of
the 25 existing species. Discovery, standing, depot and route are separate
repairable states. Road, rail and port routes, bounded dispatch capacity, three
freely adjustable doctrines, Hydraulic Split Banks and major projects keep old
species, customers and machinery relevant. The World Wood Catalogue reports
ownership, manual mastery, certification, supplier, contract and automation,
while manual and automated log-equivalents remain separate persisted totals.

Lignum Vitae is the gated 25th showcase after the other 24 masteries and all
three global projects. Only three valid manual finale receipts can award Earth
Master; the completed yard remains playable and points to launch. Mission
Control, Gantry, Orbital Test and Deep-Space Vessel consume existing cash,
processed output, mastery and explicit inventory contributions. The configurable
craft and expeditions use an injectable clock; output cannot shorten an active
flight.

Kepler Grove/Resonant Spiralwood, Tidal Moon/Tideglass Timber and Ember
World/Cinderheart Timber each follow survey → quarantine → identification →
specimen → manual certification → repeat cargo → mastery. Spiralwood reveals a
luminous assisted band, Tideglass bounds low-gravity fragments, and Cinderheart
consumes one scar-primed non-recursive assist. Certified/mastered destinations
support bounded cargo fleets, soft charters and alien-only orbital cutting
lines. Earth stays visible as completed headquarters, and new specimens always
start manually.

Save version 16 is the endpoint: v6 roles, v7 craftsmanship, v8 logistics, v9
regions, v10 company/global state, v11 launch, v12 alien/fleet state and v13's
approved 45-node overhaul. V14 refunds former one-rank selections so ranked
prerequisites cannot load in an impossible shape while preserving point
entitlement and cash. The accelerated full campaign harness reaches the repeatable
three-destination company from a reset yard only through public progression
paths and round-trips the resulting state.
V15 adds authoritative Earth depletion, lifetime earned cash, Earth receipt
identities and persisted feature introductions without granting spendable cash.
V16 adds the bounded manual-log remainder used by the four-logs-per-tree rule;
committed v15 Earth totals remain intact and older historical manual work is
converted conservatively.

Ten AI-generated production candidates are integrated under
`the-axeman/assets/generated/`, each after a separate generation, full-size
inspection. The original seven campaign candidates received targeted correction;
the three tutorial portraits passed their first-generation UI-readability review.
They remain replaceable and provenance tracked. Alien fresh/scarred/cut captures
confirm distinct surfaces and readable cut faces.

## Known, undecided gaps

- Follow-Up has no owned-modifier escape from the precision guard equivalent to
  Double Strike's Steady Continuation.
- `GameplayModifierDef.Kind.WINDUP_TIME` and `SWING_RECOVERY` remain declared
  but unused.
- Equipment proc odds/passives, auxiliary prices, placeholder tints and the new
  Mastery Echo/Express Handoff bounds remain labelled tuning placeholders.
  Existing approved skill proc chances were not changed.
- M4's `max_firewood` soft cap and the nominal fragment physics budget are still
  separate tuning concepts.
- Slice 6's 20-piece contract counts, scaled contract bonuses, scaled profile
  prices and splitter receipt timing remain visibly labelled placeholders.
  Level 9/49/96 structural probes pass, but a later live pacing review must
  decide whether any authored row should change.
- M9 effort-band quantities, rotation premium ratios and adaptive receipt timing
  remain labelled placeholders. The multi-generation level 3/49/96 probe pins
  mixed/frontier relevance at the approved 5% anchor target but is not final feel
  approval.
- All M7B–M14 economy, capacity, route, project, doctrine, launch, expedition,
  alien mastery, fleet and orbital values listed in `docs/TUNING_PLACEHOLDERS.md`
  remain provisional.
- Generated assets remain production candidates, not Sam-authored final art.
  Native machine/vehicle/space geometry is still an art-replacement target.
- The tutorial portrait cast and vector equipment/UI plates are complete
  placeholders, not final character sheets, animation rigs or final 3D props.
- The deterministic M15 policy report passes the two-to-four-hour gate at about
  200 modeled minutes. This is simulation evidence, not human feel approval.
- The uninterrupted fresh-save playthrough and real Windows-machine smoke test
  remain external alpha gates. The macOS Universal export has passed a local
  startup smoke; the Windows x86_64 archive has passed export and archive checks.

## Current test baseline

The authoritative tests are the live test files. The latest
verified baseline is M1 19, M2 24, M3 18, M4 55, M7A 294, M7B 16, M7C 27,
M7D 12, M8 122,
M8 logistics 19, M9 32, M9 regional 15, M10 14, M11 9, M11B 11, M12 12,
M13 13, M14 10, full campaign 10, campaign experience 12, M15 29, tutorial 31,
equipment 99 and startup 17. Skill overhaul is 280/280 and XP delivery is 9/9. The standalone slicer
baseline remains 34/34. The campaign visual tool captures atlas, catalogue,
the persistent goal, standing commission choice, phased skills, Earth finale,
launch, every alien fresh/scarred/cut treatment, orbital company and credits at
1280×720 under the Compatibility renderer. See `docs/TESTING.md`.

The proc-driven equipment slice adds a 99/99 focused acceptance suite. M4 55/55,
M7C 27/27, M8 logistics 19/19, M9 32/32, M13 13/13, M15 29/29, tutorial 31/31
and full campaign 10/10 pass after integration. All eight equipment-stage frames
rendered successfully in Godot 4.7.1 Compatibility and were visually inspected.
