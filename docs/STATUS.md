# Current project status

Last updated: 2026-08-17.

## Survivors progression pivot

The permanent and persistence authorities from Slice 1 remain in place, and the
Home hub, timed yard-one loop, run XP/offers, staged reward presentation, and
settlement/results flow are live. The current audit also completes the runtime
behavior and player-facing feedback for all 27 run powers without
changing their permanent unlock rules.

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

The player-facing game name is now **CAMPFIRE SURVIVORS**. The project/window
name, desktop export identity, title screen, Home header, and in-yard sign all
use the new name. The existing `the-axeman` user-data directory remains the
explicit save location so the rename does not strand current profiles.

Startup now opens a dedicated Home hub with all 18 permanent upgrades, four
yard-one starting-frequency choices, the 27-power catalogue, records, and
Start/Resume/Abandon controls. Permanent controls are locked while an attempt is
suspended, and exact-ledger full refunds persist through reload. The Home,
pause, results, and level-choice surfaces now share a Vampire-Survivors-inspired
menu hierarchy: a large centered brand, ember-lit forest backdrop, an obvious
primary action, compact bottom navigation, and gold keyboard/controller focus.
Returning Home is a true landing screen: **START** opens **LEVEL SELECT** without
starting gameplay, **QUICK START** launches the current selection directly, and
only Level Select owns **START RUN**. The landing layout mirrors the requested
reference hierarchy with an unboxed top title, open middle, centered primary
action, compact secondary pill, and three detached bottom buttons. The bottom
row is **COLLECTION / POWER UP / UNLOCKS**, with POWER UP visually singled out.
**POWER UP** opens a
dedicated four-column icon/rank grid with camp funds, Back, full refund, one-rank
purchase controls, and a fixed selected-upgrade detail panel. A newly created
profile routes directly into Level Select. Suspended attempts return to the
landing screen with Resume/Abandon; Pause focuses Resume and supports
`ui_cancel`; mandatory results and level choices remain modal.

Yard one runs for 15 gameplay minutes. Its countdown and delivery-pressure
timers pause with menus and power choices. Reaching the boundary opens an
explicit **Continue Endless** or **Bank & Go Home** decision; generic Resume
cannot choose Endless. Failure and cash-out show a result before routing Home.

The yard's three scheduled boss rows are now live five-root stump encounters
instead of one inflated "boss log." A due encounter waits for the current
active root, then all five boss-species roots drop as one vertical stack. Only
the top root is cuttable; each completion exposes the next layer and drives a
visible `5 → 0` counter. The run camera keeps its ordinary distance and FOV,
centres the complete exposed top root, then eases downward as each layer is
cleared before returning exactly to its normal stump framing.
Each layer uses ordinary current-level
hardness, while the authored single-boss Cash/XP jackpot is divided exactly
across the five completions. Only
zero records one boss defeat and one pending Blueprint roll. The encounter,
schedule cursor, rewards, active top, lower layers, counter, and framing all
survive attempt suspension and restore.

Run XP is authoritative when earned, while the visible XP value and level-choice
pause wait for the corresponding orb to reach the live edge of the XP bar.
Choices offer three distinct cards, with Luck able to add a fourth, and support
reroll, banish, serial queued levels, a hard six-slot limit, and deterministic
save/restore of cards and RNG. Choice cards are equal-width vertical rows with
icon, upgrade quality, exact effect delta, description, and Choose/Banish
actions; the first valid Choose action receives focus. Each card separately
rolls Common, Rare, Epic, or
very rare Legendary quality. Every eligible power identity is selected with the
same weight; Luck changes card count and quality odds, not identity odds.
Quality never changes unlock eligibility and never grants more than
one owned rank. Its only effect is a stronger value for that single rank's
upgrade. Current `PLACEHOLDER` quality weights are `1 / 0.20 / 0.05 / 0.005`;
current `PLACEHOLDER` value multipliers are `1× / 2× / 3× / 4×`. The
level-choice card band now rains small tree, log, and leaf accents from one
input-transparent pooled draw surface that keeps animating during the offer
pause, is physically clipped to the cards, and stops whenever the run HUD is
hidden as well as on selection or abandon.

All fourteen Core and thirteen Blueprint powers now operate from their first owned
rank. The set covers passive chopping/reward modifiers, guaranteed and off-block
cuts, completion chains, loose-log targeting/forces, boundary protection,
rescue charges, Momentum, and five visible automatic-tool families. The HUD
shows exact per-card value changes and a six-slot icon/rank strip, while
acquisition and trigger bursts provide color-coded feedback. Every power now
owns a distinct, named vector emblem using one neutral identity treatment;
Common/green, Rare/blue, Epic/purple, and Legendary/gold belong only to the
rolled upgrade quality. Offer cards, Home catalogue cards,
and active slots all consume the same icon path. The active loadout is now a
compact `356×42` strip centered immediately below the full-width XP bar instead
of occupying the lower playfield. During play, each owned slot shows only its
icon and `R#`; names, descriptions, effect details, and runtime text remain on
Home and level-up surfaces. Automatic
completions preserve exact-once cash/XP authority and still fire explicitly
source-neutral root-completion powers without creating manual outcome records.
Splinter Volley is restored to its original count model: every successful
primary strike fires a visible splinter into the nearest loose root for the
quality-adjusted value of its provisional `1`–`8` split ladder. Quality still
adds no ranks; Legendary Rank 1 is four splits on that one nearest target.
Flying Wedge carries a fixed,
quality-invariant six-cut payload that removes its single endangered loose-root
target on the existing fifth-cut completion boundary and pays it once; ranks and
quality improve only the separate cooldown ladder.
The catalogue now has a hard 32-power ceiling and currently contains 27. Area
Size is a new Core multiplier that expands the gameplay reach and matching
visual geometry of existing and new AoE powers. Sawblade Halo is a new Core
stump-centered periodic circle that cuts every loose root inside once. Timber
Burst is a Blueprint completion circle with the same one-cut-per-target rule.
Area Size also scales Earthshaker, Powder Keg, Kindling Chain, Whirling Axe,
Crosscut Sweep, and Stump Pulse; it does not resize the yard boundary. All new
numeric ladders remain explicitly provisional.
Yard Magnet now affects only loose roots in live floor contact, and its Rank 1
placeholder pull has been reduced from `0.5` to `0.1`. It cancels outward and
sideways floor drift and uses physics-tick steering toward a fixed approach dock
just outside the chopping block's solid collider. The dock accounts for the
root's current landed orientation, so a sideways root cannot be driven into the
stump. It now pulls in `0.5`-second pulses rather than continuously: Rank 1 fires
immediately and then every `5` seconds, while the explicitly provisional rank
ladder reduces that interval by `0.5` seconds per rank to `1.5` seconds at Rank
8. Once floor contact is proven, an active pulse consumes upward bounce and all
tumble so the root enters a controller-owned, zero-friction, rotation-locked
ground glide immediately. Contact impulses cannot reset its speed, and a short
ease-out settles it at the reachable rim instead of spinning, stalling, or
orbiting an unreachable centre. Between pulses—or if a root leaves the floor or
is claimed—ordinary friction, bounce, and rotation return. Pulse phase survives
suspend/restore and its HUD slot distinguishes `PULL` from the next-pulse timer.

Root cash is committed once at completion, independently of whether presentation
tokens survive. Each settled firewood receipt validates through
`InventoryManager` and releases only its visible share. The retired chopped
stack and haul-away are absent from the live scene: final billets become
collisionless where they landed, remain opaque for five active-play seconds from
the final chop, then immediately sink through the floor and despawn below it. Coins fly to the prominent session-cash counter,
while the permanent Home bank stays visible as a smaller locked counter.
Displayed cash never leads the authoritative purse.

Active, loose, and finished logs retain their opaque bark/end-grain materials.
Only a loose root or finished billet crossing the camera-to-block corridor is
temporarily made invisible; the active workpiece is explicitly excluded and
force-restored to opaque every frame. When the block is empty with no claimable
loose root, the next due delivery drops directly above the block without first
spawning into the yard.

Run-power hits now slice loose roots immediately rather than waiting for a block
claim. The root flashes white, receives a real top-to-bottom cut on a randomized
log-local X/Z axis, and keeps real descendant geometry/colliders. World tumble
cannot turn that mesh-space plane into a diagonal cut. Its square bias, rough cut
faces, half spacing, and post-flash materials now match block-cut pieces.
The fifth successful
off-block slice completes the root: its six pieces become independent physics
bodies and fall apart where the root stood, while cash and XP burst from that
same location exactly once. Once settled, the pieces immediately begin their
collisionless floor-sink cleanup. Partial cuts reconstruct through save/restore
and retain source attribution. New loose deliveries fall at exactly 2x their
prior speed, with that base gravity preserved through Slow Time. Each selectable
level now owns a standalone `YardDef` resource containing identity, duration,
species/rewards, delivery tiers, XP/hardness, bosses, and unlock metadata.
Falling-wave interval and log amount are native Godot curves by run level,
linked from that resource and sampled directly by `RunDirector`. Yard One's
migrated defaults retain the
`2.166667 / 1.7333335 / 1.3666665 / 1.0666665` Level 1 tier timings, reach the
`0.2`-second/two-log point at Level 20, ramp amount to ten by Level 28, and use
the rightmost `0.2`-second/ten-log endpoints for the final minute and Endless.
The provisional loose-root guard is `512`, which remains above two full
five-second boundary windows at the maximum 50 roots per second. Yard reward
snapshots are also reduced to nearest-whole `25%` of the prior Cash and `50%` of
the prior XP, including each five-root boss jackpot. A data-backed provisional
`1.30×` global run-XP gain then applies to ordinary roots, boss jackpots, and
bonus XP events, composing once with any run-power XP multiplier.

Claimed loose logs no longer travel diagonally across the yard. Their handoff
rises at a user-directed provisional 1.75x lift duration so the upward motion
reads clearly, while retaining the existing downward timing. The claimed arena
body is hidden synchronously, and a snapshot of its exact current meshes keeps
partially split roots split throughout delivery. The lift, hidden reposition,
and eased drop are separate phases: every mesh corner must clear the frame at
both endpoints before the X/Z switch. Generation guards cancel stale callbacks.
Ordinary autosave observes the hidden authoritative landing state without
touching the live flight; explicit suspend preparation lands the flight before
serialization. Restoring a mid-flight autosave creates one canonical landed
root and releases the boundary pause exactly once.

## New content contracts

- `MetaUpgradeTable`: exactly 18 visible, bounded permanent lines.
- `RunPowerTable`: 14 Core and 13 Blueprint powers with equal identity weight,
  authored caps, and a hard 32-power catalogue ceiling.
- `YardTable`: one 900-second yard row, six species, four starting frequency
  tiers, 35 level-pressure rows, and three scheduled five-root boss encounters.
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

Measured tuning, generated asset completion, and release captures remain
separate work. Every unapproved quality weight, multiplier, cadence, radius,
count, chance, camera-tracking value, and power value remains explicitly labelled
`PLACEHOLDER`. Retired Earth, Slow Time, ammunition, Woods, Harvest Capacity,
and in-run spending remain absent from the live UI.

## Verification

- Survivors Slice 1 authority/catalogue/migration acceptance: **108/108**.
- Home hub production acceptance: **23/23 headless**, **24/24 rendered**.
- Run XP/reward-flight acceptance: **21/21 headless**, **24/24 rendered**.
- Run-power offer production acceptance: **42/42 headless**, **45/45 rendered**.
- Distinct 27-power icon catalogue and full-frame gallery: **2/2 headless**,
  **3/3 rendered**.
- Run-power rank-one gameplay, targeting, persistence, and feedback acceptance:
  **60/60 headless**, **62/62 rendered**.
- Runtime chopping, unlocked held input, finished-piece settlement, and sink
  acceptance: **66/66**.
- Scheduled five-root boss encounter, rewards, save/restore, and camera framing:
  **18/18 headless**, **20/20 rendered**.
- Timed stage/results production acceptance: **25/25 headless**, **27/27 rendered**.
- Survival ownership, per-level curve control, and lifecycle regression:
  **46/46**.
- Production Main smoke: **19/19 headless and rendered**.
- Active cut-journal restore: **6/6**.
- Runtime slicer: **34/34**.
- Godot 4.7.1 headless editor import/parse: **PASS**.

Reviewed 1280×720 captures cover Home sections, XP flight/arrival, coin flight,
tree/log/leaf rain over three- and four-card choices, Epic/Legendary Blueprint
layouts, the six-slot HUD, run-power trigger feedback, and finished billets in
their opaque hold, opaque floor-sink, and removed states. The five-root boss
stack and its top-root camera lock at the final layer are captured separately,
as is the final-minute ten-root `0.2`-second delivery wave. A dedicated
`axeman_run_power_icons.png` contact sheet keeps all 27 emblems visible together,
and `axeman_run_six_slots.png` verifies the compact in-game placement.
