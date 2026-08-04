# M7A Five-Purchase Shop — Approval Brief

**Status:** **Approved by Sam, Creative Director, 4 August 2026.** Implementation authorised subject to the measured-tuning gate below; final prices, percentages, tier counts and magnitudes still require the prescribed follow-up approval.
**Decision source:** Sam's completed 4 August 2026 creative-direction workbook.
**Technical source:** `AGENTS.md`, the live Godot project, and the two current roadmaps.
**Catalogue order:** Balanced Axe → Reinforced Chopping Block → Supplier Ledger → Handcart → Coffee Thermos.

**Implementation checkpoint, 4 August 2026:** The approved structure, gates,
greybox physical consequences, shop presentation, save support, pacing probe and
acceptance coverage are implemented. M1–M4, M7A (285/285), slicer, chopping
smoke and non-headless pile smoke are green under Godot 4.7.1 Compatibility.
Final authored art/audio and the measured 30-minute tuning/sign-off session are
still outstanding; all shop prices and effect magnitudes remain candidate data.

**Interim art direction, 4 August 2026:** Balanced Axe and Reinforced Chopping
Block are colour variants of the existing authored axe and stump assets. Their
runtime material overrides preserve the original meshes and textures. Supplier
Ledger, Handcart and Coffee Thermos still lack art-directed assets, so their
named native-node greyboxes remain visible in the live yard and carry explicit
`art_status` metadata for replacement by the art team. Missing final art is not
allowed to make a purchased object disappear.

**Shop and arrival direction, 4 August 2026:** Items and Trees now occupy two
tabs of one Shop overlay; Skills remains its own overlay. Skills and Shop icons
carry red live-count badges for spendable points and currently affordable
purchases respectively. Handcart staging no longer changes the arrival path:
the next log appears over the block with the original compact 0.25 m drop/little
hop, then a randomly varied six-piece low-poly smoke puff fires around its base
on contact. Its procedural geometry/materials are prewarmed and pooled rather
than allocated synchronously on the landing frame.

## Approved boundaries carried into this proposal

- First purchase target: roughly five minutes.
- First level of all five purchases: approximately 20–30 minutes on a new save.
- Introductory orders are the intended early-purchase route. Their approved bonuses are **50 / 150 / 400 cash** and are now present in live data.
- Cash spending is an occasional substantial commitment. The first choice must offer at least two attractive options, not a compulsory tutorial buy.
- Early equipment begins with linear improvement; sidegrades arrive after the basics.
- Major purchases have an immediate physical yard consequence. Minor purchases may be UI-only. Every purchase appears immediately.
- Manual chopping remains central. No M7A purchase swings, slices, discovers, masters or certifies wood for the player.
- Equipment may change baseline performance or weight an already learned mechanic. It never grants Strength multi-strikes, Speed rhythm/follow-ups, or Technique Golden Grain/precision opportunities.
- Consumables remain deferred. Coffee Thermos is therefore treated as permanent equipment.
- The shop shows the current item plus the next nearby locked item(s); distant progression stays hidden.
- M7C, the complete Strength/Speed/Technique identity, is the next milestone after M7A.
- No final price, percentage, tier count or magnitude is set below. Those values come from the measured session in this brief and require Sam's sign-off.

## What the current project can already support

Reusable now:

- `Shop`, `UpgradeDef`, and `UpgradeTable` already provide data-driven catalogue order, atomic cash purchase, repeatable levels, and a maximum level.
- `GameState` already owns cash and persisted building tiers; `building_upgraded` already provides a purchase notification.
- `yard_hud.gd` already builds shop rows at runtime and refreshes affordability live.
- The chopping scene already has one camera-mounted axe FBX, one stump FBX, editable axe animations, a real swing cooldown, split-chance seams, selected species, 50-piece pile/haul logic, and save/autosave.
- Orders already route normal sale value first and persist one patient active order.

Missing supporting systems:

- Catalogue unlock/reveal conditions and “nearby locked only” filtering.
- One-time-versus-tier presentation beyond the raw `max_level` value.
- Typed equipment effects separate from skill effects.
- A persistent physical-equipment presenter that builds the correct purchased state at scene ready and reacts immediately to a purchase.
- An equipment/loadout comparison model; not required for the recommended M7A linear-first catalogue, but required for later sidegrades.
- Supplier-access gating beyond the current level + cash species purchase.
- A delivered-log/preload timing seam for the Handcart proposal.
- Per-purchase icons, physical-scene references, purchase presentation, and effect/trade-off text in shop data.
- Order reveal-by-player-level with the next order teased. Live code currently gates only on species ownership.

Existing art is limited to the basic axe, current stump, logs, ground, wood textures, coin icon and three management SVG icons. There are no finished upgraded axe, reinforced block, ledger, handcart or thermos models; there are no project audio files.

## Pacing notation

The workbook authorises minute targets but not invented log counts. During the measured session record:

- **L5 / L10 / L15 / L20 / L25 / L30:** median completed logs by that minute.
- **C5 … C30:** median spendable cash at that minute, before and after each order bonus.
- **F5 … F30:** median failed swings and split swings, needed to price felt effects rather than authored percentages.

Where an option says “L5”, its log target is the measured log count at five minutes—not a guessed integer. Final catalogue data must contain prices and effect values derived from these observations, not the symbols.

## 1. Balanced Axe

### Option A — one-time generalist upgrade **(recommended)**

- **Form:** One-time M7A purchase. Later axes become sidegrades; this item is not an endlessly rising stat line.
- **Gameplay role:** Modestly improves ordinary whole-log split reliability while preserving failures, scars, the species difficulty order and the global maximum split chance. It is the first linear “better tool” buy.
- **Skill interaction:** Once M7C exists, applies only a small, even weighting to signature procs the player has already learned. It cannot create Double/Triple/Quad strikes, follow-ups, hot streaks, Golden Grain or precision targets.
- **Unlock:** Available on a fresh catalogue alongside Reinforced Chopping Block. Both are priced so the intended first order route makes either—not both—affordable around the first-buy target.
- **Pacing:** 4–6 minutes / approximately L5. If the block is bought first, the axe becomes the next substantial target around 8–12 minutes / L10.
- **Consequence:** Immediate viewmodel swap to a visibly balanced axe; a distinct but restrained successful-impact timbre.
- **Limitation:** No cooldown, wind-up, order, XP, sale-value or species-access benefit; never makes any swing certain.
- **Assets:** Existing axe viewmodel, animation library and basic axe are reusable. **New balanced-axe model/material is required. New impact audio is required.** A recoloured basic axe is acceptable only as a greybox, not final sign-off art.
- **Acceptance before sign-off:** atomic buy/refusal; effect absent before purchase and present after; observed failure rate improves by the approved measured band but stays positive; max-chance cap holds; species difficulty ordering holds; save/load restores model and effect; purchase swaps the model immediately; future-proc guard proves no unlearned proc can fire; before/after render plus Creative Director swing feel test.

### Option B — tiered balanced-tool line

- **Form:** Tiered; first rank is the M7A goal and later ranks stay hidden until nearby progression makes them relevant. Tier count is a tuning decision.
- **Gameplay role:** Each rank adds a measured slice of general reliability; final ranks may improve feedback consistency rather than keep stacking chance.
- **Skill interaction:** Same boundary as Option A; ranks may weight learned mechanics but cannot unlock them.
- **Unlock:** Rank 1 at fresh save; later ranks after authored player/yard milestones, shown only one rank ahead.
- **Pacing:** Rank 1 at 4–6 minutes / L5; later ranks intentionally outside the “first level of all five” 20–30 minute target.
- **Consequence:** Model/material detail changes per visible rank, or one model plus clearly authored head/haft variants and impact layers.
- **Limitation:** Risks becoming an automatic best buy and creates more art/tuning burden before sidegrades exist.
- **Assets:** Same missing art/audio as Option A, multiplied by every visible rank unless material variants are accepted.
- **Acceptance before sign-off:** all Option A checks plus rank cap/cost progression, one-rank-ahead visibility, every visible rank having a distinguishable consequence, and no purchase sequence that erases scars.

## 2. Reinforced Chopping Block

### Option A — one-time larger, steadier work surface

- **Form:** One-time M7A purchase. Future block facilities become separate sidegrades/features rather than invisible ranks.
- **Gameplay role:** Increases the stable usable work surface and piece-retention envelope. Useful billets remain separated and selectable with less corrective crowding/reorientation; split chance and cut geometry remain player-controlled.
- **Skill interaction:** Helps every build by keeping targets readable. It does not widen Technique target bands, trigger Strength chains or accelerate Speed timing.
- **Unlock:** Available beside Balanced Axe from the start; it is the visible-yard-growth alternative to immediate chopping power.
- **Pacing:** 4–7 minutes / L5 if chosen first; 8–12 minutes / L10 if chosen after the axe.
- **Consequence:** The existing stump is replaced immediately by a larger reinforced block with visible bands/fasteners; impacts gain a more solid block resonance.
- **Limitation:** No split-odds, cooldown, XP, cash, order or species benefit. A larger surface must not increase physics count or create extra commodity output.
- **Assets:** Current stump mesh, procedural collision build and placement logic are reusable as references. **A new reinforced-block model/material and impact audio are required.** Current stump art is not visibly reinforced.
- **Acceptance before sign-off:** owned state changes measured work radius/retention but not size classification or slicer result; collision and visible top align; every retained target stays pickable; active rigid-body cap holds; no extra inventory/cash; save/load and immediate swap work; M4 slicer suite remains green; before/after and crowded-block renders plus Creative Director click test.

### Option B — tiered workstation foundation **(recommended)**

- **Form:** Tiered line whose future visible states could be seasoned stump → iron banding → cradle. Exact tier count is not approved.
- **Gameplay role:** Rank 1 adds usable area; later ranks may add log placement/control systems, each as a visible rule rather than another percentage.
- **Skill interaction:** Later control features may make learned precision mechanics safer but cannot create Golden Grain or perfect-cut rewards.
- **Unlock:** Rank 1 from start; later ranks gated by nearby species/workstation needs and hidden until adjacent.
- **Pacing:** Rank 1 at 4–7 minutes / L5; later ranks outside M7A.
- **Consequence:** Each rank must alter the physical station, not only its shop label.
- **Limitation:** Commits future block concepts early and requires multiple authored models/collision states.
- **Assets:** New art and audio for every approved state; only the starting stump exists.
- **Acceptance before sign-off:** Option A checks plus safe state transitions, no collision left from an old tier, visible rank distinction, and later-rank data hidden until relevant.

## 3. Supplier Ledger

### Option A — one-time first supplier relationship **(recommended)**

- **Form:** One-time M7A purchase; later ledgers/contracts become region or supplier relationships, not repeated generic ranks.
- **Gameplay role:** Adds the missing **supplier-access gate** to the next species. The ledger makes the next species eligible to purchase and shows its value, hardness, level gate and cash cost. The player must still meet the level gate, pay the separate species price, receive the specimen and manually chop it.
- **Skill interaction:** None. It changes business access, never Axeman capability, mastery or certification.
- **Unlock:** Visible nearby from the start but locked until Campfire Warm-up is completed. Completion reveals it immediately. It does not require either axe or block purchase.
- **Pacing:** Target 8–14 minutes / L10–L15, after the first major buy. Its price must still leave a meaningful decision against buying Eastern White Pine itself.
- **Consequence:** Immediate ledger/clipboard prop at the shop or delivery edge and a supplier card in the Woods panel. The recommended configuration includes the physical prop; a native-node greybox is acceptable until final art arrives.
- **Limitation:** Does not include a species, discount it, increase rare-log frequency, alter payouts or automate delivery. It adds a gate, so unlock text must always explain the next action.
- **Assets:** Woods UI and species data exist. **Supplier gate/reveal data and manual specimen-introduction support do not. New ledger icon/prop art is required for a physical version; no suitable art exists.** A StyleBox/Label-based UI version uses existing native nodes and needs no imported art.
- **Acceptance before sign-off:** without ledger the next species is teased but not buyable; owning ledger still enforces level and species cash cost; buying the species still selects/delivers a manual specimen; only nearby species is revealed; no distant ladder leak; save/load restores access and prop/UI; current owned species cannot be stranded; first-order completion reveals the ledger once; rendered locked/unlocked/purchased states.

### Option B — one-time information and goal-pinning tool

- **Form:** One-time minor purchase.
- **Gameplay role:** Does not add a species gate; instead unlocks value/hardness comparisons, the next-species requirement card and a pinned cash goal. Existing level + cash purchase remains unchanged.
- **Skill interaction:** None.
- **Unlock:** Available after Campfire Warm-up.
- **Pacing:** 8–12 minutes / L10.
- **Consequence:** Immediate ledger UI and optional clipboard prop.
- **Limitation:** Safest technically, but may be too weak for a substantial cash commitment and does not truly “improve access.”
- **Assets:** Requires new UI treatment and optional art, but no supplier-access logic.
- **Acceptance before sign-off:** information is absent before purchase, accurate after purchase, updates from live tables, reveals nearby only, pins/unpins without changing economy, persists, and renders legibly at 1280×720.

### Option C — tiered supplier-slot line

- **Form:** Tiered; each rank opens one additional nearby supplier/species agreement. Tier count is not approved.
- **Gameplay role:** Expands simultaneous wood access while every species retains its own level, cash and manual-introduction requirements.
- **Skill interaction:** None.
- **Unlock:** First rank after Campfire Warm-up; later ranks by supplier-region/reputation milestones.
- **Pacing:** First rank 8–14 minutes / L10–L15; later ranks post-M7A.
- **Consequence:** Ledger pages/stamps visibly accumulate.
- **Limitation:** Prematurely introduces slot management before the regional supplier system and is not recommended for this slice.
- **Assets:** New page/stamp UI, supplier-slot state and later region integration; none exists.
- **Acceptance before sign-off:** capacity cannot grant unpurchased woods, removing/retuning a supplier cannot strand the selected species, tiers persist, and only adjacent slots appear.

## 4. Handcart

### Option A — one-time next-log staging upgrade **(recommended)**

- **Form:** One-time major logistics purchase.
- **Gameplay role:** Stages the next selected log while the current completed log is being settled, reducing only non-interactive between-log delivery time. It never swings, slices, sells early, changes the 50-piece pile capacity or raises per-piece value.
- **Skill interaction:** None. Speed continues to own swing rhythm and free follow-ups; the Handcart improves yard logistics outside the active axe sequence.
- **Unlock:** Visible as the next nearby lock after Supplier Ledger; unlock on the first 50-piece haul-away. The measured session must confirm that event still fits the 20–30 minute catalogue target; if it does not, return with a level-gate alternative rather than silently changing it.
- **Pacing:** 14–22 minutes / L15–L20, funded primarily by the middle introductory-order route rather than passive chopping alone.
- **Consequence:** A cart appears at the yard edge immediately. It stages the next log, but the log still appears centred over the block with the original drop/little hop and a small low-poly landing puff; it never flies laterally from the cart.
- **Limitation:** One staged log maximum; current log must be fully processed first; no queue, offline supply, staff, auto-cutting or 50-piece-capacity change.
- **Assets:** Current spawn/drop and haul animation code are reusable. **A staged-log timing seam/one-slot delivery state does not exist. A new handcart model, wheel/depart animation and cart/wood audio are required; none exists.** Native AnimationPlayer/Tween and nodes are sufficient; no vehicle physics is needed.
- **Acceptance before sign-off:** measured non-interactive inter-log interval decreases by the approved amount while swing/contact/split timing is identical; only one future log stages; it spawns at block centre with no lateral travel; selected species changes resolve safely; no early inventory/cash/XP; pile still hauls at exactly 50; player can keep chopping during haul; save/load restores cart ownership and prop; immediate purchase appearance; arrival-puff and mid-haul renders plus live feel test.

### Option B — one-time physical haul presentation only

- **Form:** One-time major visual yard purchase.
- **Gameplay role:** Replaces the magical outbound wave with a cart collection/departure while preserving the exact current economy and timing.
- **Skill interaction:** None.
- **Unlock:** First 50-piece haul-away.
- **Pacing:** 14–22 minutes / L15–L20.
- **Consequence:** Strongest possible visible yard-growth beat; cart remains parked between hauls.
- **Limitation:** No numerical benefit. It must be priced/presented as a yard milestone, not falsely described as productivity.
- **Assets:** Same new cart art/animation/audio as Option A; no delivery-state system.
- **Acceptance before sign-off:** no change to payout, pile count/capacity, chopping concurrency or save; all 50 visual proxies leave; cart sequence cannot block a fresh log; purchase appears immediately and renders cleanly.

## 5. Coffee Thermos

### Option A — one-time permanent recovery equipment **(recommended)**

- **Form:** One-time permanent minor equipment upgrade, explicitly not a consumable and not a refill/upkeep system.
- **Gameplay role:** Modestly shortens the ordinary cooldown between player-initiated swings, using the existing real cooldown seam. Axe contact weight and a measurable minimum recovery floor remain.
- **Skill interaction:** Quick Hands may still provide a Speed foundation adjustment, but Speed's identity comes from Second Wind, rhythm, follow-ups and Flow—not this baseline reduction. Thermos and Quick Hands combine through an approved stacking rule and cap; Thermos cannot refund a swing, open a follow-up window or start a streak.
- **Unlock:** Nearby locked item after Handcart; unlock after Aspen Hearth Load completion, keeping introductory orders as the intended early-purchase route.
- **Pacing:** 20–30 minutes / L20–L30. It should consume a meaningful share of the final early-session purse, not be a trivial add-on.
- **Consequence:** Thermos appears immediately at the block/work area; subtle steam when idle and a restrained purchase/sip cue. No repeated drinking input.
- **Limitation:** No wind-up, split chance, scar, proc chance, XP, cash or order effect; hard recovery floor preserves axe weight and accessibility.
- **Assets:** Existing cooldown calculation and axe speed scaling are reusable, but currently read skill effects only. **A separate equipment modifier/stacking seam is required. No thermos model/icon/audio exists.** A native CylinderMesh plus simple particle/mesh steam is a viable M7A prototype under Compatibility; final art still needs approval.
- **Acceptance before sign-off:** permanent ownership; approved stacking order with Quick Hands; recovery decreases by the approved measured band but never crosses the floor; contact key remains aligned; holding input and repeated clicks cannot bypass the gate; no Speed signature mechanic fires without its skill; save/load and immediate prop work; cooldown probe, axe render and Creative Director rhythm test.

### Option B — tiered permanent thermos line

- **Form:** Tiered permanent equipment, never consumed. Rank/tier count is not approved.
- **Gameplay role:** Each rank shortens baseline recovery; later ranks may change presentation instead of stacking indefinitely.
- **Skill interaction:** Same boundary and cap as Option A.
- **Unlock:** First rank late in the M7A catalogue; later ranks hidden until nearby career milestones.
- **Pacing:** First rank 20–30 minutes / L20–L30; later ranks post-M7A.
- **Consequence:** Larger/better thermos or accumulated cup/steam presentation per visible rank.
- **Limitation:** A pure speed tier line risks replacing Quick Hands and damaging axe weight; requires stricter diminishing returns and more art. Not recommended.
- **Assets:** Same missing systems/assets as Option A, plus rank variants.
- **Acceptance before sign-off:** Option A checks plus rank cap, diminishing measured effect, visible rank distinction and proof that a fully ranked thermos does not dominate the Speed branch.

## Final handoff

### 1. Recommended five-item catalogue

| Order | Purchase | Recommended form and role | Unlock | Target window | Immediate consequence |
|---:|---|---|---|---|---|
| 1 | Balanced Axe | One-time generalist; modest ordinary split reliability | Available from start | 4–6 min / L5 | New viewmodel axe + impact timbre |
| 2 | Reinforced Chopping Block | Tiered workstation line; M7A rank 1 adds a larger/steadier selectable work surface, later ranks remain post-M7A | Available from start | Rank 1 at 4–7 min first, or 8–12 min / L5–L10 | Reinforced block model + solid resonance |
| 3 | Supplier Ledger | One-time first supplier-access gate; next species still requires level + cash + manual specimen | Campfire Warm-up complete | 8–14 min / L10–L15 | Ledger prop/UI + next supplier card |
| 4 | Handcart | One-time one-log staging; reduces only non-interactive delivery downtime | First 50-piece haul-away | 14–22 min / L15–L20 | Parked cart, staged delivery and haul route |
| 5 | Coffee Thermos | One-time permanent baseline recovery equipment | Aspen Hearth Load complete | 20–30 min / L20–L30 | Thermos/steam + cue |

Catalogue presentation recommendation:

- At fresh save show Balanced Axe and Reinforced Chopping Block as the two first goals; show Supplier Ledger locked beneath them.
- After one of the first pair is bought, keep the other visible and reveal at most the next one or two nearby locks.
- Never show later machinery, regions, global/space progression or unapproved ranks in this M7A panel.
- Each card shows name, one plain-language effect, price, one limitation/trade-off, owned state, and the physical consequence. Exact detailed statistics can wait for the optional detailed view chosen in the workbook.
- Price relationship, not final prices: the first-order route buys either Axe or Block but not both; the next order route supports the remaining first pair plus Ledger; the later order route supports Cart/Thermos while competing with the second species purchase. Eastern White Pine's current 60 cost remains a placeholder and must be measured in the same purse model.

### 2. Recommended prototype-skill migration

The current six-node prototype should not survive unchanged. Preserve useful foundations, remove duplicate identities, and defer mechanic-changing replacements to M7C.

| Current prototype | Recommendation | Destination and reason |
|---|---|---|
| Strong Arms | **Retain name and mechanical role; move explicitly to Strength foundation.** | Ordinary resistant-wood reliability supports Strength but does not define it. Multi-strikes remain the named Strength identity. Final ranks/magnitude await M7C tuning. |
| Quick Hands | **Retain name and role; move explicitly to Speed foundation.** | A modest recovery foundation is compatible with permanent Thermos equipment if stacking has a floor. Second Wind, rhythm, follow-ups and Flow define Speed. |
| Keen Edge | **Rename to Ready Stance; move to Speed foundation/support.** | Its actual effect is wind-up/anticipation, not blade sharpness. The new name stops it sounding like axe equipment or Technique precision. Preserve owned ranks through an explicit save-id migration if the internal id changes. |
| Splitter | **Replace in M7C with Double Strike (or roadmap name Echoing Blow). Do not silently convert ranks.** | Its current extra split chance duplicates Strong Arms. The replacement is Strength's approved first signature mechanic. Retire the old id and refund its prototype skill-point spend; a proc is too different for one-to-one rank conversion. |
| Woodsman | **Rename to Quick Study and move to Technique.** | Manual finished-log XP supports reading/learning wood and Technique's multiplied-manual-XP direction. Preserve owned ranks via explicit id migration because the mechanical role remains the same. |
| Master Axeman / Negotiator | **Remove from the three player-skill branches; reintroduce as Negotiator in M7B reputation/customer/business progression.** | Keep its purpose—raising log/firewood sale value—but earning better commercial terms is company standing, not Strength, Speed or Technique. Market must eventually read a business/reputation modifier instead of `SkillTree.CASH_GAIN`. Prototype points spent here should be refunded; do not invent reputation conversion before M7B exists. |

Migration timing recommendation:

1. Do not implement Double Strike, Golden Grain or other signature mechanics inside the M7A shop task.
2. During M7A, document the mapping and ensure new equipment code does not depend on the obsolete CASH_GAIN skill path.
3. At the start of M7C, perform the save-aware skill migration, add branch metadata/UI, then implement signature mechanics and their safety rules.
4. At M7B, establish the business/reputation modifier that owns Negotiator. If M7C is intentionally built before M7B, temporarily remove Negotiator from new purchases and refund prototype points; do not leave it in Technique as a convenience.

### 3. Proposed measured tuning session

#### Session A — instrumented baseline, no purchases

Run one focused new-save Creative Director session using current approved feel values. Record timestamps and logs at: first order accepted/completed, each log completed, each level, first haul-away, second species eligibility/purchase, and each cash balance change. Capture L5–L30, C5–C30 and F5–F30. Use approved order bonuses 50/150/400 in the tuning branch, but do not commit final shop prices.

#### Session B — two first-choice routes

Create data-only candidate profiles after Session A:

- **Route Axe-first:** Axe at ~5 minutes, Block second.
- **Route Block-first:** Block at ~5 minutes, Axe second.

For each route, derive prices so the first order makes exactly one first choice affordable, ordinary chopping cannot buy both immediately, and the selected introductory-order route reaches all five first purchases inside 20–30 minutes while still forcing a decision against Eastern White Pine access.

#### Session C — effect bands and regression feel

Test at least three data-only magnitude bands for Axe, Block, Cart and Thermos: conservative, middle and strong. Measure observed—not authored—failure rate, selectable-piece crowding, non-interactive inter-log time and real swing-to-swing time. Sam selects the band by feel. Confirm scars remain regular enough to read, the axe retains weight, and no upgrade turns manual play into waiting or automation.

#### Session D — sign-off route

Wipe save; complete one uninterrupted 30-minute run using the recommended route, then reload and verify the physical yard. Automated acceptance and rendered before/after states must pass first. Per the workbook, one focused Creative Director play session is the final M7A sign-off method.

### 4. Exact implementation sequence after approval

1. Record Sam's remaining decisions listed below and amend binding documentation before coding any changed scope.
2. Add a temporary M7A pacing probe/tool that records minutes, completed logs, failures/splits, cash sources/spend, orders, levels, haul-away and species purchase; do not alter live balance.
3. Apply the already approved order bonuses (50/150/400) in data and add the approved level-reveal/next-order-tease fields and tests.
4. Run measured Session A; return the captured L/C/F table and candidate price/effect bands for Sam's explicit tuning approval.
5. Extend `UpgradeDef`/catalogue data with purchase form, unlock/reveal rule, nearby visibility, player-facing limitation, effect key, physical consequence and optional icon/scene references. Keep `Shop` stateless and `GameState` the sole progression writer.
6. Add catalogue validation and atomic purchase tests before adding effects: unique ids, positive approved prices, legal unlock references, one-time cap, nearby visibility, immediate signal and save/load.
7. Add the persistent physical-equipment presenter. It must build owned equipment from `GameState` on scene ready/load and react immediately to `building_upgraded`; no physical object owns progression state.
8. Implement Balanced Axe and Reinforced Chopping Block first, with independent effect seams and greybox physical states; run M4, slicer and M7A suites plus axe/block renders.
9. Implement Supplier Ledger access/reveal and manual specimen delivery. Verify it never grants, discounts, masters or certifies a species.
10. Implement Handcart's one-slot staging and physical delivery/haul presentation. Keep the 50-piece threshold and concurrent chopping intact.
11. Implement Coffee Thermos as a permanent equipment modifier with the approved stacking order and recovery floor; keep Speed signature mechanics absent.
12. Rebuild the shop UI to show the two first choices, adjacent locks, effect, limitation, price and immediate owned state at 1280×720. Add catalogue icons only when approved assets exist.
13. Run Sessions B and C; enter only Sam-approved prices, magnitudes, gates and any tier decisions into `.tres` data.
14. Add per-item acceptance coverage, prove each regression check fails without its fix, run M1–M4, M7A, slicer, chopping smoke and non-headless pile smoke, then render every shop/yard/equipment state.
15. Run Session D and wait for explicit M7A sign-off. Only then begin the separately amended M7C milestone.

### 5. Decisions Sam must approve before coding

1. Approve or replace the **recommended option** for each of the five purchases.
2. Confirm Axe and Block are the two fresh-save choices and that first-order cash buys either but not both.
3. Confirm Supplier Ledger is a real supplier-access gate (recommended) rather than information-only.
4. Confirm the recommended Handcart unlock at the first 50-piece haul-away, with a level-gate alternative returned only if measurement misses the approved pacing window.
5. Confirm the recommended Thermos unlock on Aspen Hearth Load completion.
6. Confirm Handcart may reduce only non-interactive next-log delivery time.
7. Confirm Coffee Thermos and Quick Hands may both affect baseline recovery under a measured stacking rule and hard floor.
8. Confirm the recommended physical Ledger prop; UI-only remains the lower-scope alternative.
9. Approve greybox native-node stand-ins while Sam authors final Axe, Block, Ledger, Handcart, Thermos and audio assets—or require final art before gameplay sign-off.
10. Approve the prototype-skill migration and the point-refund rule for Splitter and Master Axeman/Negotiator.
11. Approve the measured tuning method; final prices, magnitudes, tier counts and exact level gates will return from it for a second approval before entering live data.

### 6. Roadmap amendments required after approval

Do not edit the roadmaps until Sam approves this brief. Approval requires these documentation changes:

1. **M7A catalogue amendment:** name and order the five purchases, their approved roles, first-buy/all-five pacing, order bonuses 50/150/400, nearby-only catalogue visibility, immediate arrival and permanent Coffee Thermos interpretation.
2. **M7A/M7C boundary amendment:** move the first Balanced Axe and Reinforced Chopping Block from the current M7C feature list into M7A. M7C retains later sidegrades/loadout and owns full branch identities/procs.
3. **Milestone-order amendment:** the current roadmaps say M7B follows M7A; Sam selected M7C next. Record the deliberate order change and its dependency consequence: Negotiator's reputation/business home remains designed for M7B and cannot be smuggled into a player branch while M7B is deferred.
4. **Skill-tree amendment:** record the Strong Arms/Quick Hands foundations, Ready Stance and Quick Study renames/moves, Splitter replacement, and Negotiator removal from the three branches.
5. **Order-presentation amendment:** orders reveal by player level with only the next order teased; no cancellation for introductory orders; progress remains only in Contracts; non-matching wood sells normally without warning.
6. **Supplier-access amendment:** if recommended Ledger Option A is approved, species unlock becomes access relationship + level gate + separate cash purchase + delivered manual specimen. This extends the current live level + cash rule and must be explicit.
