# M15 four-hour campaign tuning report — working checkpoint

Status: **not final sign-off**. No M15 price, earnings threshold, multiplier,
rank cap or interval floor is approved. This file records the first validated
implementation checkpoint so later bands are not tuned to hide earlier pacing
problems.

## Implemented and measured

| Checkpoint | Result |
|---|---|
| Fresh Earth total | 3,040,000,000,000 exact |
| Manual conversion | Four unique completed manual logs equal one Earth tree; partial 0–3 progress persists |
| Authoritative sources | Manual, watched, active company and offline company use exactly-once Earth receipts |
| Final cycle | Tree budget caps before recovered output, XP and cash |
| Planetary maximum projection | More than 3 trillion trees in 990 seconds; zero before 1,020 seconds |
| Projected Earth depletion | 16.5–17 minute maximum-rate planetary band after the terrestrial campaign |
| No-bonus terrestrial gate | 255 manual logs / about 173 active minutes; down from 768 logs / about 538 minutes |
| Fixed post-Earth time | 12 minutes of flights plus about 12.6 minutes of alien manual mastery |
| Completion projection | About 224–234 minutes including a 10–20 minute management allowance |
| Maximum recovered output | Above 3.04 trillion logs and below the signed-64-bit campaign envelope |
| Offline zero | Settles once on return; duplicate and post-zero receipts are rejected |
| Continuity Reserve | Final Dispatch Core rank is guarded; all four minimum launch projects remain sequentially buildable at zero cash |
| Focused M15 acceptance | 29/29 |
| Focused reveal/tutorial acceptance | 31/31 |
| Stabilization regression | Complete documented suite matrix green: M7A 294/294, M8 122/122, skill overhaul 278/278, M4 55/55 without its former shutdown leak |
| Deterministic policy report | Cautious, expected and optimized all fail the four-hour completion gate; live progression/inventory remain unchanged |
| Reveal/tutorial captures | Seventeen 1280×720 captures rendered; the empty fresh dock, level-3 Jobs reveal, first-job board and completed-job Shop reveal were inspected |
| Compatibility captures | Four 1280×720 campaign captures inspected: fresh counter, depot Shop, planetary Shop and zero/exhaustion/launch |

The maximum planetary candidate is intentionally a backward target, not an
approval. It combines the existing five-second company cycle with Depot Power
Drive's provisional floor, the existing Hydraulic Split Banks, all provisional
dispatch/parallel ranks, Satellite Forest Survey and five 220,000-tree
Autonomous Harvest Fleet ranks. The XP curve now keeps the no-bonus terrestrial
route near its 10-log-per-species mastery floor, with extra logs concentrated in
the final three unlocks. Earlier cash bands must still independently prove that
the player can afford and reach the maximum production set without a drought or
exploit.

## Reinvestment rows awaiting validation

All sixteen rows in `the-axeman/data/upgrade_table.tres` retain the exact label
`PLACEHOLDER — four-hour reinvestment validation required`:

- Timber depot: Parallel Splitter Bay, Recovery Saw Bench, Commercial Grading Desk.
- Continental company: Depot Power Drive, Rail Consist Expansion, Port Crane Array, Automated Species Router.
- Planetary industry: Satellite Forest Survey, Autonomous Harvest Fleet, Global Mill Network, Continuity Reserve, Planetary Dispatch Core.
- Interplanetary company: Fleet Cargo Racks, Orbital Saw Arrays, Alien Grading Laboratory, Navigation Relay.

Each row is bounded, has a fixed resource-authored price curve, a monotonic
lifetime-earnings gate, a separate campaign prerequisite, current → next copy
and an estimated production change. None has completed payback or reinvestment
validation yet.

## Grant-free policy checkpoint — blocking

The read-only structured report now runs all three fixed reinvestment policies
from the same fresh local ledger and records every provisional production
purchase, payback, spendable/lifetime cash, reinvestment, throughput, Earth
zero and M14 receipt fields. It grants no cash, XP, inventory, mastery or
unlock, and verifies that the live autoload state is unchanged.
It records the first company-production timestamp separately. First watched
Mechanical Splitter automation remains `-1`/unmodeled until the required public
runtime integration driver exists; the report does not relabel depot throughput
as the earlier watched milestone.

| Policy | Earth zero | Purchases | M14 receipt by 240 min | Result |
|---|---:|---:|---:|---|
| Cautious | 14,005 s / 233.4 min | 50 | No | Blocked |
| Expected | 14,003 s / 233.4 min | 50 | No | Blocked |
| Optimized | 14,003 s / 233.4 min | 50 | No | Blocked |

This closes the reporting/tooling slice but not economy approval. The first
sequential rerun also caught and repaired a report bug that could skip the
timber and continental cash gates after a drought. The corrected result must be
reviewed with Sam before any `.tres` value changes. All affected values retain
their `PLACEHOLDER` label.

## Required next validation — deliberately incomplete

- Review the failed cautious/expected/optimized report with Sam and decide which
  opening/depot/continental band to change first. Do not tune from the final
  multiplier backward.
- Replace the isolated ledger with a grant-free integration driver that invokes
  the same public manual settlement, purchase, progression and injected-clock
  receipt paths as the live campaign. The current report is intentionally
  read-only and therefore does not claim this integration proof.
- Validate the first automation target before retuning the next cash band.
- Validate each later band in order; do not use the planetary multiplier to
  compensate for an unresolved earlier band.
- Run an uninterrupted real-time fresh-save Godot 4.7 Compatibility campaign,
  including the fixed 120/240/360-second flights, and review it before changing
  any placeholder to approved.

The former M8 Quick Study setup, machine-unlock copy and freed presentation-node
failures are repaired; M8 is 122/122. M7A is 294/294, the ranked-skill proc
finalization check is 278/278, and M4 exits without its former leaked resource.
