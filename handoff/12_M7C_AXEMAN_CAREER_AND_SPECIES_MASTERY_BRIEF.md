# M7C — Axeman Career and Species Mastery Implementation Brief

**Status:** **Approved by Sam, Creative Director, 4 August 2026. M7C slice 1
(documentation and approval gate) is complete.** M7A is signed off and M7C is
the active milestone. Sam approved
the save-v2 migration, scope fence, recommended choices recorded below, and use
of clearly labelled `.tres` placeholders pending the mandatory Creative
Director tuning pass. No placeholder becomes final merely because it is used to
build or test a system.

**Authority:** `AGENTS.md`, `handoff/08_COZY_LUMBERYARD_ROADMAP.md`,
`handoff/10_EARTH_TO_ALIEN_TIMBER_ROADMAP.md`, the approved
`handoff/11_M7A_FIVE_PURCHASE_IMPLEMENTATION_BRIEF.md`, the live Godot project,
and Sam's 4 August 2026 direction in this brief's request.

**Visual reference:** `Axeman UI Mockups (standalone).html` is visual and layout
direction only. It is not gameplay, progression, content, or tuning authority.

## Creative Director approval record — 2026-08-04

Sam approved the brief with the exact instruction **“Approved—begin M7C slice
1.”** The approved implementation choices are now binding:

- save version 2 migration and refund behavior exactly as specified below;
- **Follow-Up** is Speed's first proc: it opens a limited opportunity for the
  next player-initiated swing to bypass ordinary recovery once; it never swings
  automatically and cannot recursively create another root proc event;
- M7C ships the first **Double Strike**, **Quick Study**, and **Follow-Up**
  families. Triple/Quad chains, Earthshaker, Flow State, Eureka, and other full
  capstones remain deferred unless Sam approves a later scope amendment;
- **Splitting Maul** is the first M7C axe sidegrade;
- **Log Cradle / Reinforced Chopping Block rank 2** is the next workstation
  feature/rank;
- precision protection is a per-log player guard, with automatic suppression
  during any strict precision work; suppression has no penalty and does not
  consume proc fairness state;
- discovery occurs when the player manually completes the delivered first
  specimen, never on access, purchase, or arrival;
- species mastery and certification are separate ordered states;
- respec is free and available at the yard: it atomically refunds player-skill
  spend without changing XP, career level, business equipment, species state,
  cash, or reputation; it cannot interrupt a committed swing or proc chain;
- unresolved odds, ranks, point costs, XP multipliers, certification counts,
  prices, gates, windows, and effect magnitudes may use clearly labelled `.tres`
  placeholders while their systems are built, and must return to Sam for the
  later Creative Director tuning/sign-off gate.

The mockup remains a creative representation only. Its exact composition,
dimensions, copy, assets, and numbers are not an implementation specification.

## Milestone outcome

M7C makes the player character, not only the purse and yard, meaningfully
progress. Two early builds must feel different at the chopping block. A proc
must be a named, visible mechanical event. Each owned species must move through
a legible manual discovery, mastery, and authored certification path, while
perfect manual work becomes a durable record.

The recommended M7C delivery is deliberately narrower than the complete
long-horizon skill catalogue:

1. migrate the six-node prototype safely;
2. establish the three branch identities and native three-bough UI;
3. ship the first complete Strength multi-slice family and Technique
   multiplied-manual-XP family;
4. give Speed one complete early proc family so all three branches have a
   mechanical identity;
5. add manual species discovery, mastery, certification, grain feedback, and
   perfect-log records;
6. add one approved axe sidegrade, one approved block feature/rank, and an
   equipment loadout/comparison screen;
7. verify the whole milestone with save migration, deterministic acceptance
   seams, real renders, and all older regression suites.

Later triple/quadruple chains, full Flow State, Golden Grain jackpots, broad
craft grading, reputation, and automation remain future work unless Sam
explicitly selects them for this milestone at the approval gate.

## Scope fence

M7C includes only Axeman career, player skills, manual species knowledge,
manual records, one axe sidegrade, one block feature/rank, loadout, and the UI
needed to understand them.

M7C does **not** implement:

- M7B customers, reputation, business modifiers, quality payouts, requested
  piece-size orders, signature contracts, or Negotiator;
- staff, auto-cutters, offline progress, logistics simulation, or routes;
- supplier regions, global progression, launch projects, space, or alien logs;
- a second action loop, mining, forest exploration, standing trees, depletion,
  felling, bucking, or any restoration of retired M5;
- species purchases from lifetime wood;
- a standalone Woodshed, Firewood, or Wood dock.

The M7A supplier path remains binding and unchanged:

```text
Supplier Ledger/access relationship
        + level gate
        + separate cash purchase
        -> delivered manual specimen
        -> discovery/mastery/certification by the player
```

## Prototype skill migration — save version 2

The live save format is version 1 and stores `skill_levels` by node id. The
live point balance is derived from earned levels minus the current tree's spend;
there is no separately banked point field. M7C must bump `SAVE_VERSION` to 2
and perform a deterministic `v1 -> v2` migration before `GameState` validates
the resulting dictionary.

| Version-1 id | Version-2 destination | Migration rule |
|---|---|---|
| `strong_arms` | `strong_arms` | Preserve valid owned ranks; Strength foundation. |
| `quick_hands` | `quick_hands` | Preserve valid owned ranks; Speed foundation. |
| `keen_edge` | `ready_stance` | Rename explicitly and preserve valid owned ranks; Speed support/foundation. |
| `splitter` | none | Remove. Do not convert to Double Strike. Its prototype spend becomes available again through the derived point balance. |
| `woodsman` | `quick_study` | Rename explicitly and preserve valid owned ranks; Technique/manual-learning family. |
| `master_axeman` or legacy `negotiator` | none | Remove and refund through the derived point balance. Its sale-value purpose is deferred to M7B business/reputation progression. |

Migration requirements:

- It is idempotent: loading a version-2 save never applies the mapping twice.
- It never increases a retained node above its approved current cap.
- It never silently merges old Splitter ranks into Double Strike.
- It recognises both `master_axeman` and `negotiator` as retired prototype ids.
- If an old and new rename id coexist in a development save, keep the greater
  valid rank, never add them together and mint ranks.
- The version-1 save remains untouched until the migrated state has loaded and
  the next atomic save succeeds. The existing newer-save backup protection
  remains intact.
- Migration emits normal post-load repaint signals only after the entire state
  is valid. It does not fire proc, certification, or purchase celebrations.
- Acceptance uses hand-authored version-1 fixtures for every mapping, partial
  or corrupt dictionaries, rank caps, exact refunds, and a load-save-reload pass.

Retained nodes must not put an old save into point debt merely because M7C
retunes their costs. The recommended rule is to preserve the prototype
per-rank point cost for retained migrated ranks in version 2; new purchases use
the approved M7C cost. If Sam wants retroactive cost changes, the alternative
migration and its refund/debt behavior require separate approval.

## Career and branch identity

Each branch uses the same readable vocabulary:

1. **Foundation** — dependable support for the ordinary action.
2. **Proc** — unlocks a named chance-driven event.
3. **Modifier** — changes that event's safety, result, or chain behavior.
4. **Capstone** — a rare, unmistakable expression of the branch fantasy.

The data model must identify this node type directly. UI position or display
name must never be the only source of gameplay meaning.

### Strength — force and explosive continuation

Strength improves resistant-wood reliability without making ordinary swings
certain. Its signature event is **Double Strike**: one player swing can perform
a second real, prevalidated slicer operation on a useful remaining target.

- Foundation: **Strong Arms**.
- First proc family: **Double Strike**.
- Modifiers may improve scar value, hard-wood expression, continuation choice,
  or later chain depth.
- Long-horizon capstone identity: a rare, escalating multi-strike spectacle.

M7C ships Double Strike and one geometry/safety modifier. Later triple/quad
chains and Earthshaker remain deferred and must not appear as purchasable or
nearby teased nodes in this milestone.

### Speed — recovery, readiness, and player-controlled flurries

Speed is not only a smaller cooldown. It changes the rhythm of manual input
while preserving axe weight and a hard recovery floor.

- Foundations: **Quick Hands** and **Ready Stance**.
- Recommended first proc: a clearly announced free/manual **Follow-Up** window.
- Modifiers may use hot-streak buildup and softened failure rather than an
  all-or-nothing combo reset.
- Long-horizon capstone identity: **Flow State**, a short audiovisual frenzy,
  never a permanent extreme multiplier.

The first Speed proc is approved as **Follow-Up**: it readies the next manual
swing and lets that one player-initiated swing bypass ordinary recovery. Its
chance, window, ranks, bad-luck behavior, and modifiers remain placeholder
tuning calls. Flow State remains deferred. Coffee Thermos remains baseline
equipment and cannot grant any of these mechanics.

### Technique — grain knowledge, precision, and learning jackpots

Technique helps the player read a species and turn intentional manual work into
knowledge. It does not replace M7B craftsmanship payouts.

- Foundation/support: grain-reading and precision assistance.
- First proc family: **Quick Study**, a manually finished-log XP multiplier.
- Modifier: a rarer, more visible insight result or better control over valid
  bonus geometry.
- Long-horizon capstone identity: **Eureka**, restricted to the manual learning
  phase of an unfamiliar species.

Quick Study applies once to the base XP event for one manually completed log.
It cannot recursively multiply its own bonus, multiply automation, or trigger
from loading/certification restoration.

### Axeman career ranks

Named career bands may present groups of levels, but level remains derived from
XP and skill points remain one per earned level. Career rank is presentation
and unlock metadata, not a new currency or separately mutable progression
track. Rank names, boundaries, and rewards are **Creative Director decisions**.

## Proc resolver and fairness contract

All chance-driven skills use one resolver path with data-defined families and a
forced-result test seam. Individual skills do not roll their own unrelated RNG.

Required behavior:

- **Bad-luck protection:** each proc family has bounded dry behavior. The exact
  model—pity accumulator, shuffled bag, or approved equivalent—and all odds are
  tuning decisions. Its state persists so save/reload cannot cheaply reroll.
- **One root event:** a manual swing or manual log completion receives a unique
  event id. A proc handles that root once; bonus work cannot recursively create
  unlimited new root events.
- **Chain limit:** every family has an explicit data cap. A continuation stops
  at the learned cap, the global safety cap, or the absence of useful geometry,
  whichever comes first.
- **Valid geometry:** a bonus cut is scheduled only after the actual slicer
  preflight proves that the plane intersects the chosen piece and both results
  satisfy the existing minimum-piece and usable-bound rules. Do not use banned
  runtime volume computation. Never announce a slice that cannot execute.
- **Stable target choice:** continuation selection is deterministic for a given
  outcome and prefers a useful remaining billet. It does not select settling,
  frozen, already-consumed, or unrelated pile pieces.
- **Precision protection:** the player can suppress multi-cut behavior without
  respeccing. A strict/manual precision mode and any future precision order
  suppress bonus cuts unless an owned modifier explicitly makes them safe.
  Suppression has no penalty and does not consume the proc's fairness state.
- **Visible announcement:** named banner, branch color/shape, distinct impact
  beat, and accessible non-color cue. Announcement intensity scales with the
  actual completed result, not the rolled intention.
- **Ordinary failure survives:** skill, equipment, level, scars, and pity still
  respect the approved maximum ordinary split chance below certainty.

The chopping scene may expose a local bonus-announcement signal that `main.gd`
wires to `UI_Overlay`. Do not add or alter a frozen A7 EventBus signal.

## Species discovery, mastery, certification, and records

These are distinct persisted states:

1. **Accessible:** the Ledger relationship permits the nearby species card.
2. **Purchased:** level and cash gates were met; a manual specimen is delivered.
3. **Discovered:** the player personally completes the approved first manual
   encounter. The recommended trigger is completion of the delivered specimen,
   not purchase or arrival.
4. **Learning:** manual eligible actions add species mastery and reveal authored
   knowledge entries.
5. **Certified:** an authored per-species checklist is satisfied through manual
   work. Certification is monotonic and idempotent.
6. **Mastered:** the authored mastery target is complete. Whether mastery and
   certification are the same threshold or two stages is a **Creative Director
   decision**.

Lifetime wood remains celebratory/background progression and does not buy,
discover, master, or certify a species.

### Authored certification

Certification requirements live in data per species and are visible before the
final attempt. Candidate requirement kinds include manual logs completed,
manual successful splits, a scar/efficiency demonstration, grain opportunities
used, and perfect logs. Which kinds and counts each live species uses are
**Creative Director content and tuning decisions**.

No required certification can depend on an unowned skill, sidegrade, random
rare proc, M7B order, staff, or automation. RNG may accelerate optional mastery,
but every required checklist has a bounded manual route.

### Perfect-log tracking

M7C records perfect manual logs and best per-species/lifetime results; it does
not add M7B quality payouts. The definition must be derived from slicer facts
and approved before implementation. It may consider authored target piece
count/size tolerance, valid useful output, scars, and efficiency, but awkward
pieces remain sellable and normal progression never hard-fails.

Perfect-log criteria, tolerance bands, record categories, and whether a perfect
log is required for early certification are **Creative Director decisions**.

### Grain-reading feedback

Grain feedback is an opportunity, not an automatic cut. A valid candidate plane
is precomputed for the current piece, then shown with:

- a high-contrast top-surface ribbon/mark that works under Compatibility (no
  `Decal` dependency);
- a matching screen-space bracket or icon for bark/color independence;
- a short plain-language cue in the Technique color/shape language;
- reduced-motion and non-color-readable variants.

The cue disappears safely when the piece changes, settles, splits, leaves the
block, or the candidate becomes invalid. Cue frequency, duration, width,
precision tolerance, and benefit are **Creative Director tuning decisions**.

## Equipment sidegrade, block rank, and loadout

M7A already owns the Balanced Axe and Reinforced Chopping Block rank 1. M7C
must add one sidegrade and one visible workstation feature/rank; it must not
turn either into an invisible best-in-slot percentage ladder.

### Approved M7C choices

- **Axe:** the **Splitting Maul** is the first true sidegrade. It is
  slower and weightier but suited to resistant woods and Strength/scar play.
  The Camp Hatchet remains a later candidate because it depends more heavily on
  kindling/size-request gameplay deferred to M7B.
- **Block:** **Log Cradle / Reinforced Block rank 2** is approved. It visibly
  steadies and lets the player deliberately reorient the active log, supporting
  grain reading and precision protection without changing the slice result.
  Iron banding remains a later candidate.

Their exact unlocks, prices, ranks, numeric effects, proc affinity, art status,
and magnitudes remain labelled `.tres` placeholders until Sam's tuning pass.

### Loadout contract

- One active axe and one active block/workstation configuration in M7C.
- Ownership and equipped choice are separate persisted facts.
- Equipping is free and reversible at the yard; changing equipment during a
  committed swing or unresolved proc chain is refused/deferred safely.
- A comparison shows only player-meaningful differences: ordinary reliability,
  timing/weight, control/precision, learned-proc affinity, and explicit
  trade-off. It does not expose ten opaque micro-stats.
- Equipment can weight a proc the player learned; it cannot unlock the proc.
- The Balanced Axe remains a generalist, never certainty and never a source of
  unlearned mechanics.

Loadout slot count, change timing, comparison dimensions, and whether a block
configuration is selected in the same screen are **Creative Director
decisions**.

## Mapping the HTML visual system to native Godot at 1280x720

The mockup's direction to preserve:

- parchment/cream background, timber brown, warm orange, and moss green;
- illustrated natural surfaces and restrained leaf/branch decoration;
- large rounded panels with soft ink-tinted shadow and clear hierarchy;
- corkboard/pinned-paper language for Contracts;
- pill-shaped tags for state, cost, branch, owned, locked, and active labels;
- a three-bough skill-tree composition with readable branch identities;
- generous spacing, short descriptions, and plain comparison copy.

Native implementation mapping:

| Mockup idea | Godot 4.7 native implementation |
|---|---|
| Full window card | `ModalBackdrop` + centered `PanelContainer` under `UI_Overlay`; authored anchors/margins for the 1280x720 base canvas. |
| Parchment/timber frame | `StyleBoxFlat` during greybox, then `NinePatchRect`/`StyleBoxTexture` from approved illustrated assets. |
| Header and tags | `HBoxContainer`, `Label`, `TextureRect`, and reusable themed `Button`/`PanelContainer` pill scenes. |
| Items / Trees | Existing Shop overlay with native tab buttons; no separate Wood dock. |
| Three boughs | A custom `Control` drawing approved branch curves plus positioned native skill-node `Button`s from normalized layout data; no web runtime and no third-party graph plugin. |
| Mastery/detail | Right-side `PanelContainer` or lower detail pane driven by the selected node/species; use `ScrollContainer` only for detail overflow. |
| Contracts corkboard | Preserve for the existing Contracts overlay; not an M7C system expansion. |

The skill screen should fit its primary tree, point/rank summary, branch legend,
selected-node detail, and close/back action in one 1280x720 modal. It must not
reproduce the mockup's tall standalone web page. Distant skill nodes and species
remain hidden or teased only when nearby; owned and adjacent content gets the
visual priority.

### Mockup reconciliations that are binding

- Delete the standalone **Firewood catalog / Woodshed** concept. Put useful
  hardness, grain, trait, discovery, mastery, certification, and record material
  in **Shop -> Trees** and the M7C species detail.
- Show owned species plus only the next nearby locked species. Never reveal the
  full 25-species ladder at this stage.
- Species access remains Ledger + level + cash + delivered manual specimen.
- Lifetime wood never purchases species.
- Items contains the five approved M7A purchases; it is not `COMING SOON` or an
  empty grid.
- Introductory order bonuses are 50 / 150 / 400 cash, not 5 / 10 / 30.
- Level `37 / 99`, skill percentages, shop cash, prices, species ranks, and
  similar mockup numbers are illustrative only unless separately approved.
- The mockup's complete species field guide and derived prices are not live
  data authority.

### Font availability and licensing

The standalone mockup embeds Caprasimo and Figtree WOFF2 subsets but no license
file. Authoritative Google Fonts directories identify both families under the
SIL Open Font License 1.1. They are legally suitable to bundle with the game
provided the exact upstream font files are used and the required copyright and
OFL text ship with the project.

Authoritative sources checked 4 August 2026:

- [Caprasimo directory and OFL](https://github.com/google/fonts/tree/main/ofl/caprasimo)
- [Figtree directory and OFL](https://github.com/google/fonts/tree/main/ofl/figtree)

Do not extract and silently import the mockup's anonymous WOFF2 subsets. At the
implementation asset gate, obtain the approved upstream TTF files, add their
OFL/copyright text beside the font assets, verify Godot import and glyph
coverage, and record provenance. Until then use the project's current fallback
font. Final Caprasimo/Figtree use remains an art-direction approval.

## Data and resource architecture

Recommended native, data-driven structure:

- Extend `SkillNodeDef` with branch id, node type, presentation position,
  proc/effect key, prerequisites, rank cap, point cost, and typed resource
  references for modifiers. Avoid gameplay decisions based on display strings.
- Add `SkillBranchDef`/table data for Strength, Speed, Technique colors, icons,
  branch copy, and authored bough layout.
- Add a proc definition resource for base family, eligibility, chain cap,
  bad-luck policy key, announcement key, and tuning fields. A resolver reads
  definitions; it does not own progression.
- Add `SpeciesMasteryDef`/table keyed by existing `SpeciesDef.id`, containing
  reveal steps, mastery awards, certification checklist, perfect criteria, and
  presentation references. Do not duplicate price, Janka, mesh, or supplier
  ownership fields already owned elsewhere.
- Add axe/block equipment definitions with comparison tags and scene/material
  references. Reuse the M7A shop/physical-presenter ownership path.
- Add a small immutable manual-log outcome object carrying species id, root
  event id, eligible source, slice/scar facts, perfect result, base XP, and
  certification observations. It is evaluated once at completion.

All final numeric fields live in `.tres` resources. Code contains validation,
caps, and behavior—not final odds, prices, multipliers, ranks, counts, windows,
or magnitudes.

## Progression ownership, save state, and signals

`GameState` remains the only writer of progression. It should persist:

- migrated skill ranks and any approved respec state;
- proc bad-luck state needed to prevent reload rerolls;
- per-species discovery, mastery value/checklist, certification, manual logs,
  perfect-log count/best record;
- owned and equipped axe/block ids.

Do not store derived career rank, derived skill points, or duplicated species
ownership. Validate every id against current tables and degrade safely to the
starting axe/block/species when content is removed or renamed.

Recommended local signals on `GameState`:

- `species_mastery_changed(species_id, value)`;
- `species_discovered(species_id)`;
- `species_certified(species_id)`;
- `perfect_log_recorded(species_id, total)`;
- `equipment_loadout_changed(slot, equipment_id)`.

Use one coalesced autosave after a completed transaction. Load restoration may
emit repaint signals but not reward celebrations. Transient proc announcements
use a local scene-to-main-to-HUD connection. Frozen A7 remains unchanged.

## Acceptance coverage

Create `m7c_acceptance.tscn/.gd` in the existing PASS/FAIL style. Every new
regression guard must be proven to fail without its fix.

Minimum automated groups:

1. Version-1 fixtures migrate every retained, renamed, removed, capped,
   duplicate, corrupt, and partial skill case; exact points are refunded and
   migration is idempotent.
2. Tree validation rejects duplicate ids, dangling prerequisites, cycles,
   illegal node types, unknown branches, invalid caps/costs, and impossible
   layout references.
3. Same points spent in different branches produce measurably different
   eligible behavior without unlearned procs.
4. Forced Double Strike performs exactly the announced valid slicer operations;
   stops at learned/global cap; refuses invalid continuation; leaves valid
   materials, winding, tangents, size classification, and physics budgets.
5. Precision guard suppresses bonus cuts without spending fairness state or
   affecting the player's base swing.
6. Bad-luck protection reaches its approved bound, persists across save/load,
   and cannot be exploited by reload or ineligible swings.
7. Forced Quick Study/multiplied-XP applies once to one manual completed log,
   shows the corresponding event, and cannot recurse or trigger from automated,
   restored, or incomplete work.
8. Discovery never occurs at access/purchase alone; mastery/certification are
   manual, monotonic, bounded, authored, and save-safe.
9. Certification cannot require an unowned skill or random-only event and
   cannot award twice.
10. Perfect-log criteria use positive geometry facts, record once, persist, and
    never prevent rough output from selling normally.
11. Grain cues exist only for valid current geometry and clean themselves up on
    split, target change, settle, exit, and load.
12. Equipment ownership/equip are separate, loadout fallback is safe, comparison
    text matches live typed effects, and equipment cannot grant an unlearned proc.
13. Shop -> Trees shows owned plus nearby only, Items shows all five approved
    M7A purchases, no Woodshed dock exists, and cash—not lifetime wood—buys a
    species after every access gate.
14. Autosave coalesces a proc/log/mastery/certification transaction and never
    serialises a half-applied chain.

## Visual and feel QA

Headless checks cannot approve this milestone alone. Add non-headless shot tools
that render the real main scene at 1280x720 for:

- fresh, partially learned, available, and locked states of all three boughs;
- selected-node detail, insufficient points, refund-after-migration, and respec
  state if approved;
- Shop Items with all five M7A purchases and Trees with owned + nearby species;
- species undiscovered, learning, certified, and perfect-record detail;
- grain cue on pale and dark bark with accessibility variant;
- Double Strike's actual two cuts and announcement, invalid-chain stop, Speed
  proc, Quick Study XP event, and precision suppression;
- every approved axe/block loadout and comparison state.

Run a Creative Director feel pass for axe weight, proc readability, cue clarity,
precision safety, branch distinction, and 1280x720 text fit. Final animation,
audio, VFX, color, spacing, and font choices remain Creative Director calls.

## Regression suites

After each independently testable slice, run the relevant narrow checks. Before
M7C delivery run the complete established set from the Godot project directory:

- M1, M2, M3, M4, M7A, and new M7C acceptance;
- slicer suite;
- chopping smoke;
- non-headless pile smoke;
- existing HUD/equipment/species/axe renders plus all new M7C renders.

M4 geometry and M7A economy/shop behavior are preserved. A green M7C suite
cannot excuse an older regression.

## Staged implementation sequence

Each slice is independently testable and committed only after its tests pass.

1. **Documentation and approved tuning sheet.** Record Sam's decisions below;
   no gameplay code before this gate.
2. **Save-v2 migration only.** Add fixtures and exact refund/rename tests before
   changing the live tree.
3. **Typed branch/proc/mastery/equipment schemas and validators.** No live
   effects; import/rescan and validate resources.
4. **Three-bough native UI and mockup theme foundation.** Use fallback fonts
   until licensed assets are approved/imported. Verify at 1280x720.
5. **Strength vertical slice.** Strong Arms + Double Strike + one approved
   modifier, forced seam, geometry preflight, precision suppression,
   announcements, renders.
6. **Technique vertical slice.** Grain feedback + Quick Study multiplied manual
   XP family, once-per-log guard, distinct XP presentation, renders.
7. **Speed vertical slice.** Quick Hands + Ready Stance + approved first Speed
   proc/modifier, with Thermos stacking/floor regression.
8. **Species lifecycle.** Discovery, mastery, authored checklist,
   certification, perfect tracking, detail UI, save/autosave.
9. **Equipment/loadout.** Approved axe sidegrade and block feature/rank,
   comparison, safe equip timing, immediate physical state.
10. **Integrated UI reconciliation.** Shop Items/ Trees, nearby-only species,
    mastery references, no Woodshed, correct order bonuses and badges.
11. **Full automated/regression pass and non-headless visual/feel QA.** Fix and
    rerun until green; then request explicit M7C sign-off. Do not begin M7B.

## Creative Director tuning decisions still unresolved

Sam explicitly authorised labelled `.tres` placeholders for every item below
so implementation can proceed. Each still requires Sam's final value or scope
decision at the later feel-tuning gate:

1. Career-rank names, level boundaries, and cosmetic/unlock rewards.
2. Complete M7C node graph: node names, prerequisites, point costs, rank caps,
   and whether the full tree must cost more than level 99 awards in this slice.
3. Retained foundation magnitudes and caps, including Strong Arms, Quick Hands,
   Ready Stance, Thermos stacking order, and hard timing floor.
4. Respec presentation and confirmation copy. Its M7C behavior is approved as a
   free, atomic yard action with no cash cost or cooldown.
5. Double Strike odds by rank, eligibility, bad-luck model/bound, target choice,
   modifier magnitude, and maximum chain depth.
6. Future Triple Strike/Quad Cleave/Earthshaker design and tuning. They are
   deferred and hidden throughout M7C.
7. Follow-Up's odds, bad-luck behavior, timing window, ranks, streak softening,
   and modifier. Flow State is deferred.
8. Quick Study odds/ranks, XP multiplier(s), bad-luck behavior, and larger
   insight presentation. Eureka is deferred.
9. Grain-reading proc/availability, cue duration/width, precision band,
   gameplay benefit, and accessibility presentation.
10. Precision-guard presentation, input binding, and announcement treatment.
    Its per-log scope and automatic strict-work suppression are approved.
11. Mastery award amounts and reveal thresholds for every live M7C species.
12. Mastery/certification presentation and exact ordered thresholds. Discovery
    on manual completion of the delivered first specimen and separate states
    are approved.
13. Authored certification requirement kinds and exact counts per live species.
14. Perfect-log geometric criteria, tolerance bands, record categories, and
    certification relationship.
15. Splitting Maul unlock, price, effects, trade-off magnitudes, proc affinity,
    and art/audio status. The item choice and slow resistant-wood role are
    approved.
16. Log Cradle rank-2 unlock, price, effect magnitudes, later rank count, and
    art/audio status. Deliberate reorientation/steadying is approved.
17. Loadout slots, when equipment may be changed, and final comparison fields.
18. Proc banner copy, duration, animation, audio, hit-pause/shake intensity,
    branch colors/shapes, reduced-motion treatment, and priority when events
    overlap.
19. Final panel dimensions/spacing, illustrated surface assets, node layout,
    and permission to import Caprasimo/Figtree with their OFL files.
20. M7C cosmetic achievements, if any; otherwise explicitly defer them.

## Conflicts found and reconciled

1. The mockup has a standalone Firewood/Woodshed catalog; binding direction has
   no Wood dock. Its useful reference material moves to Shop -> Trees/mastery.
2. The mockup reveals all 25 species and ranks; binding direction reveals owned
   and nearby only.
3. Mockup copy says lifetime wood buys species; live/binding progression uses
   Ledger access + level + cash + delivered specimen.
4. The mockup Items tab is empty/coming soon; live M7A Items contains the five
   approved purchases.
5. Mockup orders pay 5/10/30; approved bonuses are 50/150/400.
6. Mockup skill percentages, level 37/99, cash, ranks, and prices are
   illustrative and conflict with Sam's unapproved-tuning rule.
7. The long roadmap calls the first Strength proc `Echoing Blow`; the approved
   migration calls it **Double Strike**. M7C uses Double Strike as the
   player-facing name unless Sam explicitly renames it.
8. The roadmap places broad craftsmanship/quality payouts in M7B while M7C asks
   for perfect-log tracking. M7C records approved geometry outcomes only; it
   does not add quality payouts or customer systems.
9. The mockup fonts are embedded without license files. Authoritative upstream
   copies are OFL-1.1, so import is allowed only with exact upstream files,
   copyright/license text, and Sam's art approval.
10. The live prototype stores `master_axeman`, while current direction refers
    to Negotiator. Both legacy ids are retired/refunded; neither survives in a
    player branch.

## Approval gate — passed for M7C slice 1

Sam passed this gate on 4 August 2026 with **“Approved—begin M7C slice 1.”** The
approval covers:

1. approve this document as the M7C scope and confirm the exclusions;
2. approve the save-v2 mapping and refund rules exactly as written;
3. Double Strike, Quick Study, and Follow-Up as the three M7C proc families,
   with Triple/Quad, Earthshaker, Flow State, and Eureka deferred;
4. Follow-Up, Splitting Maul, Log Cradle rank 2, per-log precision guard with
   automatic strict suppression, discovery on first manual specimen completion,
   separate mastery/certification, and free yard respec;
5. labelled `.tres` placeholders for unresolved tuning with a mandatory later
   Creative Director tuning gate;
6. the 1280x720 native UI mapping. Font import remains a later art/asset call;
   use the current fallback until separately approved.

Any later changed choice must be recorded in this document before its
implementation changes.
