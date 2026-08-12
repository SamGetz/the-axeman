# Testing and verification

Run all Godot commands from the inner `the-axeman/` directory. The repository
root has no `project.godot`; running there can open the project manager and exit
without executing the requested suite.

Set `GODOT` to the Godot 4.7.1 executable for the current machine, then run:

```bash
"$GODOT" --headless --path . --quit-after 900 res://core/tests/m1_acceptance.tscn
"$GODOT" --headless --path . --quit-after 900 res://core/tests/m2_acceptance.tscn
"$GODOT" --headless --path . --quit-after 900 res://core/tests/m3_acceptance.tscn
"$GODOT" --headless --path . --quit-after 20000 res://core/tests/m4_acceptance.tscn
"$GODOT" --headless --path . --quit-after 20000 res://core/tests/m7a_acceptance.tscn
"$GODOT" --headless --path . res://core/tests/m7b_acceptance.tscn
"$GODOT" --headless --path . --quit-after 20000 res://core/tests/m7c_acceptance.tscn
"$GODOT" --headless --path . res://core/tests/skill_overhaul_acceptance.tscn
"$GODOT" --headless --path . res://core/tests/xp_pacing_balance_acceptance.tscn
"$GODOT" --headless --path . res://core/tests/xp_delivery_acceptance.tscn
"$GODOT" --headless --path . res://core/tests/reward_audio_acceptance.tscn
"$GODOT" --headless --path . res://core/tests/m7d_acceptance.tscn
"$GODOT" --headless --path . --quit-after 20000 res://core/tests/m8_acceptance.tscn
"$GODOT" --headless --path . res://core/tests/m8_logistics_acceptance.tscn
"$GODOT" --headless --path . res://core/tests/m9_acceptance.tscn
"$GODOT" --headless --path . res://core/tests/m9_regional_acceptance.tscn
"$GODOT" --headless --path . res://core/tests/m10_acceptance.tscn
"$GODOT" --headless --path . res://core/tests/m11_acceptance.tscn
"$GODOT" --headless --path . res://core/tests/m11b_acceptance.tscn
"$GODOT" --headless --path . res://core/tests/m12_acceptance.tscn
"$GODOT" --headless --path . res://core/tests/m13_acceptance.tscn
"$GODOT" --headless --path . res://core/tests/m14_acceptance.tscn
"$GODOT" --headless --path . res://core/tests/full_campaign_acceptance.tscn
"$GODOT" --headless --path . res://core/tests/campaign_experience_acceptance.tscn
"$GODOT" --headless --path . res://core/tests/m15_pacing_foundation_acceptance.tscn
"$GODOT" --headless --path . res://core/tests/tutorial_acceptance.tscn
"$GODOT" --headless --path . res://core/tests/equipment_proc_progression_acceptance.tscn
"$GODOT" --headless --path . --quit-after 20000 res://core/tests/startup_acceptance.tscn
"$GODOT" --headless --path . -s res://core/tools/test_slicer.gd
"$GODOT" --headless --path . res://core/tools/m15_grant_free_pacing_probe.tscn
```

Latest verified four-hour-loop baseline on 2026-08-09:

| Suite | Expected |
|---|---:|
| M1 | 19/19 |
| M2 | 24/24 |
| M3 + consolidated global config | 18/18 |
| M4 | 55/55 |
| M7A | 294/294 |
| M7B craftsmanship/customers/reputation | 16/16 |
| M7C revised graph/content | 27/27 |
| Skill overhaul | 280/280 |
| XP pacing balance | 13/13 |
| XP full-bar delivery and ring-free level effect | 9/9 |
| M7D visible yard progression | 12/12 |
| M8 Slice 6 Certified Yard Expansion | 122/122 |
| M8 logistics/offline | 19/19 |
| M9 standing campaign commissions | 32/32 |
| M9 regional network | 15/15 |
| M10 continental company | 14/14 |
| M11 World Wood Catalogue | 9/9 |
| M11B Earth finale | 11/11 |
| M12 launch programme | 12/12 |
| M13 first alien expedition | 13/13 |
| M14 interplanetary company | 10/10 |
| Fresh campaign through credits | 10/10 |
| Four-hour campaign experience | 12/12 |
| M15 depletion/reinvestment foundation | 29/29 |
| Disabled tutorial presentation and placeholder art | 8/8 |
| Proc-driven equipment progression | 99/99 |
| Startup New Game / Load Game | 17/17 |
| Slicer | 34/34 |

The focused startup suite drives the production main scene and real save
service. It verifies the dormant/no-autosave menu boundary, disabled Load state,
fresh-game atomic write, explicit progression-and-inventory restore, existing
save confirmation and non-destructive corrupt-save failure. Like M7A, M7C and
M8, it moves any existing player save aside for the run and restores it before
quitting.

`tutorial_acceptance.tscn` keeps the authored mentor/content and placeholder-art
validation, then verifies that the tutorial director presents no card, focus or
replay help, writes no completion/skip state, and cannot let old staged-tutorial
flags hide an otherwise actionable Catalog. The retained non-headless tutorial
capture tool is intentionally inert while `TutorialDirector.ENABLED` is false.

`m8_acceptance.tscn` includes the approved 68-check Slice 3 foundation and 25
focused Slice 4 checks for typed cycle data, all seven runtime states, one-slot
admission, active-yard timing, exact-once cash/time-budgeted XP settlement, restore safety,
the representative log, five upgrade identities/effects, paced introduction,
greybox presence and HUD presentation.

Slice 5 adds six focused checks for the three-tab shop structure, pre-purchase
functional placement, completed one-time Items and splitter movement, partial
and maxed tiered placement, read-only owned/maxed rows, and restoration derived
from existing building tiers without a purchase-history field.

Focused discovery checks verify that locked splitter shelves and profiles stay
absent, mastery names its certification reward, earning the machine gate reveals
the tab, and installing the machine leaves the earned profile-purchase route
actionable.

The verified 104-check completion run also pins Sam's complete measured splitter
band: machine/profile gates and prices, five-second cycle, one output per
represented log, 50% Speed floor, five Speed ranks, one-time Auto Loading,
5-to-12 Logs per Split, 20-to-100% equivalent-manual-time automation XP and five
Money Gain ranks. Speed and represented output do not multiply XP per minute.

Slice 6 expands M7A to 289 checks; the current M8 suite has 122 checks after the
version-5 migration assertion. Loop-based checks cover all 26
contracts and 25 profiles; focused checks cover the three later-profile gates,
atomic purchase/save/assignment, early/middle/final watched cycles, settlement
start/cancel ordering, retry identity, separate bounded reward pools, exact
counter reconciliation, species bark/end treatment, and reduced missing-art
marker hierarchy.

M9 now has 32 focused checks for the hidden Pine gate, typed placeholder
catalogue, deterministic three-offer generation, owned-species filtering, the
sole selected standing goal, exact automatic payout, automation eligibility,
save-v17 persistence and legacy multi-slot migration. The five cadence moments
are covered separately by `campaign_experience_acceptance.tscn` so fast
completion cannot reopen the chooser.

The focused M7B–M14 suites cover typed catalogue validation, ownership
boundaries, additive migrations, derived yard landmarks, deterministic active
and offline simulation, regional delays, doctrine switching, the complete
25-species catalogue, the manual Earth finale, staged launch construction,
injected-clock expeditions, bounded alien cutting behaviors, fleet/orbital
receipts and persistence. Automation exclusion is asserted separately for
craftsmanship, certification, mastery, story presentation and first contact.

M15 covers exact Earth totals, four-logs-per-tree manual accounting, typed exactly-once receipts, manual and offline
zero, post-zero rejection, monotonic earnings bands, fixed rank prices, all
sixteen provisional production items, effect composition, Continuity Reserve
launch protection, planetary target projection, overflow headroom, exact HUD
copy and save-v16 migration/round-trip behavior.

The M15 grant-free report is a required alpha gate, not a grant-based acceptance
fixture. It reads the live catalogues into an isolated ledger, emits one JSON
report for each fixed policy, checks that `GameState` and `InventoryManager`
remain byte-for-byte unchanged, and exits non-zero unless all three policies
complete inside two to four hours:

```bash
set -o pipefail
"$GODOT" --headless --path . res://core/tools/m15_grant_free_pacing_probe.tscn \
  | tee /tmp/axeman-m15-pacing.jsonl
```

Current 2026-08-09 result: **PASS** for the fixed deterministic policies. The
report reaches watched automation at about 35 minutes, company scale at about
70 minutes, Earth zero at about 159 minutes and modeled credits at about 200
minutes including fifteen minutes of management/read time. It projects 159
terrestrial manual logs and a 54.4% tactile share. These remain labelled
simulation placeholders; two uninterrupted novice fresh-save sessions are the
human approval gate.

`full_campaign_acceptance.tscn` starts from `GameState.reset_to_defaults()` and
empty inventory. Large public cash/XP/output grants compress tuning time, but
all campaign transitions use public purchase/progression methods and receipt
application. It opens all seven supplier routes, manually masters Earth,
completes Lignum Vitae, builds the launch programme, manually certifies and
masters all three alien woods, builds fleets/orbital lines, applies one
idempotent combined company receipt, buys all nine Frontier ranks and verifies
that credits emit exactly once only after every gate. It also
checks the migration chain through v14 for preserved campaign purchases, the
approved skill refund, and no invented Earth/space rewards.

The read-only overhaul pacing snapshot covers every terrestrial and alien
representative anchor and prints the final Frontier active-time projection:

```bash
"$GODOT" --headless --path . res://core/tools/m8_slice6_pacing_probe.tscn
"$GODOT" --headless --path . res://core/tools/m9_commission_pacing_probe.tscn
"$GODOT" --headless --path . res://core/tools/xp_pacing_probe.tscn
```

It prints unlock cost, unit sale value, contract count/base/bonus, profile cost,
mastery target and base splitter cash/XP. A passing snapshot confirms the
authored formulae and labels, not final pacing approval.

`xp_pacing_balance_acceptance.tscn` additionally pins one point per level through
the 84-point terrestrial tree, the provisional 90–120 minute manual completion
band, splitter XP-per-minute invariance and fractional carry, and a binary,
source-aware Masterwork reward. Fractional carry is applied after global/skill
multipliers to prevent rounding inflation. The current no-bonus projection
reaches point 84 at about 104.6 minutes. Even the deliberately impossible upper
bound of a max-rate splitter running beside every manual swing from minute zero
remains about 52.3 minutes, safely beyond the reported 30-minute cap-out. Both remain modelled
values requiring a real fresh-save feel pass.

The M9 probe prints three generations at levels 3, 49 and 96. It confirms slot
roles, effort bands, rotation coverage and the labelled 5% mixed/frontier cash
anchor, not final quantities, rotation ratios or timing.

M1 deliberately exercises error paths; expected red engine messages are not
failures. Treat lines beginning with `FAIL:` as failures.

`pile_smoke.tscn` and render/shot tools must run non-headless. The pile check
depends on the real animation clock, while shot tools require a renderer. Visual
or geometry changes should run their focused shot tool and be inspected, not
only asserted numerically.

M8's focused non-headless render tool captures the next-contract strip; mixed
Open and early/middle/level-99 Completed boards; each missing later-profile gate;
actionable, Purchased and Tree Catalog profile states; early/middle/final
assignments; ready, maximum-speed processing, settlement, blocked/retry and
simultaneous manual/splitter receipt states to
`/private/tmp/axeman_m8_splitter_*.png`:

```bash
"$GODOT" --path . res://core/tools/m8_splitter_shot.tscn
```

The startup stand-in has a focused non-headless render check which captures the
saved-yard menu and its New Game replacement confirmation without touching the
real save:

```bash
"$GODOT" --path . res://core/tools/startup_shot.tscn
```

M9's focused non-headless tool captures the earned offer board, compact and
expanded active-task stack, multiple-active board, delivery refresh and repeat
history without touching the player's real save:

```bash
"$GODOT" --path . res://core/tools/m9_commission_shot.tscn
```

The continuous-campaign visual tool uses only in-memory acceptance fixtures and
never calls `SaveSystem`. It renders the persistent goal, all-at-once standing
commission choice, phased skill view, atlas, World Wood Catalogue, Earth Master
closure, launch yard/programme, all three alien woods in fresh/scarred/cut
states, the repeatable orbital company and credits to
`/private/tmp/axeman_campaign_*.png`:

```bash
"$GODOT" --path . res://core/tools/campaign_visual_shot.tscn
```

Every emitted image must report 1280×720. Confirm the objective has exact
progress, all three commission offers fit without scrolling, and the stump stays
unobstructed. Inspect the atlas and launch card for
clipping/action visibility; compare the three alien materials for separation,
tiling, cut-face readability and visible strike cues; confirm the Earth Master
candidate does not obscure its native headline. M7D's four foundational yard
states remain captured separately by `core/tools/m7d_yard_shot.tscn`.

The approved reward-feedback checkpoint was also inspected in the production
1280x720 yard: XP orbs advance the live bar edge per receipt, coins remain in the
yard until their exact payout exists and disappear on counter impact, stacked
coin impacts grow the cash counter, and the prewarmed level-up effect surrounds
the workpiece without a first-trigger hitch. These animated checks require a
live play session; the static HUD/startup/M8 tools remain the layout regression
captures.

`xp_delivery_acceptance.tscn` is also a non-headless timing capture. It writes
`/private/tmp/axeman_xp_bar_full.png` before rollover and
`/private/tmp/axeman_xp_level_advanced.png` afterwards; both must be 1280x720.
`orb_scale_shot.tscn` additionally writes
`/private/tmp/axeman_level_up_no_ground_halo.png`; inspect it for rising rays and
sparks with no torus or halo travelling along the ground.

Phase 1 reward audio is generated deterministically with
`tools/audio/generate_phase1_sfx.py`. The focused acceptance validates exact
tier reconciliation, the safe-economy maximum, every cue path, startup gating,
and the mixer buses. Run `core/tools/phase1_audio_audition.tscn` non-headless to
hear each cue in manifest order, or play
`assets/audio/review/phase1_preview.wav` for the combined review reel. Do not
begin the UI/machinery audio phase until this reel and the live chopping/reward
loop have been approved.

Run `tools/audio/validate_phase1_sfx.py` after regeneration. The non-headless
`core/tools/reward_tier_shot.tscn` writes four cash-tier captures to
`/private/tmp/axeman_reward_cash_*.png`; inspect coin, green-note, blue-note and
bundle silhouettes before accepting the reward-art thresholds.

On a fresh clone, run the import pass twice before trusting test results:

```bash
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . --import
```

Also import after adding a new `class_name`, because headless suite runs do not
refresh the global script class cache. See `SETUP.md` only for full machine
bootstrap and engine-install details.

The proc-driven equipment slice adds a focused 99/99 suite. Its Compatibility
render audit writes `equipment_stage_01.png` through `equipment_stage_08.png` to
the project user-data folder:

```bash
"$GODOT" --path . --rendering-method gl_compatibility \
  res://core/tools/equipment_progression_shot.tscn
```

Every stage must report `result=OK`; inspect the eight frames for distinct axe
and stump tint identities and unchanged cutting geometry.
