# The Axeman — Earth to Alien Timber Master Roadmap

**Status:** Creative Director direction, 2026-08-01; scope clarified 2026-08-02;
store, skill-tree and automation lifecycle clarified 2026-08-02; M7A catalogue
and M7C-next sequence approved 2026-08-04; M7A explicitly signed off 2026-08-04.
This is an extensive design roadmap, not an implementation order. It extends
the cozy-lumberyard direction into global wood mastery and a spacefaring postgame. The existing module sign-off
rule, frozen Part A contracts, Godot 4.7 Compatibility constraints and Sam's
ownership of final tuning values all remain in force.

**One-line pitch:** Start with one axe, one log and one coin; build the company
that masters every kind of log on Earth; then spend the resulting timber
fortune launching expeditions to bring back impossible logs from space.

## Executive decision

The perfect escalation for this game is not “add another shop with a larger
multiplier.” It is a sequence of revelations in which the same satisfying axe
swing takes on a larger meaning:

1. A swing earns a coin.
2. A good swing completes an order.
3. A session grows a lumberyard.
4. A lumberyard attracts suppliers from new regions.
5. A regional yard becomes the world's finest log-chopping company.
6. The final terrestrial species becomes a handcrafted mastery finale.
7. A completed Earth wood catalogue becomes the launchpad for an alien-timber age.

The player should spend the opening hours believing this is a warm, tactile
firewood game. The scale then widens one layer at a time until the cozy yard is
somehow the headquarters of an interstellar log-chopping concern. The absurdity is
earned because every new system grows from a tool, person, customer or problem
the player already understands.

The Earth campaign should have a real ending: **Earth wood catalogue complete**.
Space is not a reset that undoes it. It is the consequence and reward.

## North star

### The fantasy

The player begins by doing everything with their own two hands. The long-term
fantasy is not to keep hand-chopping the same solved log forever: it is to become
the Axeman who can understand an unknown wood, teach the company how to process
it, automate that solved commodity and move on to the next harder species.
Manual chopping is the discovery and power phase for each new wood; automation
is the earned proof that the player has mastered it.

### The emotional curve

| Era | Player feeling | What changes |
|---|---|---|
| Stump | “That cut felt good.” | The axe, log and payout become legible. |
| Yard | “This place is mine.” | Orders, tools, skills and visible upgrades arrive. |
| Company | “I built a machine around my craft.” | Staff and logistics remove friction. |
| Nation | “Logs are arriving from everywhere.” | Regional suppliers, routes and new woods expand the queue. |
| Planet | “I can master every wood on Earth.” | A global catalogue and prestigious contracts dominate. |
| Earth Master | “One terrestrial species remains.” | The hardest Earth log becomes a handcrafted finale. |
| Orbit | “The yard was only the beginning.” | Launch projects and expeditions unfold. |
| Alien timber | “What even counts as wood now?” | Exotic log behaviours reinvent chopping. |

### Non-negotiable pillars

1. **Learn by hand, then automate.** Every new species begins at the chopping
   block and must be manually learned and certified. Once solved, automated
   lines are expected to replace manual commodity chopping for that species and
   carry the company toward trillion-scale output. The player returns to the
   block for the next unknown species, rare specimens and optional handcrafted
   work—not to compete with a factory on volume.
2. **Every era visibly changes the yard.** A number is never the only proof of a
   major upgrade. Buildings, traffic, piles, machinery, skyline and eventually
   spacecraft make growth physical.
3. **Progression unfolds.** Do not show a global supplier atlas, skill constellation,
   launchpad and five currencies in hour one. Each layer appears only when the
   preceding loop has become comfortable.
4. **Earth mastery is finite.** Regions have authored species, suppliers,
   customers and mastery goals. Completing them fills a permanent global wood
   catalogue; no forests are depleted or simulated.
5. **Failure creates texture, not a stop sign.** The current scar-and-pity rule
   remains the model: imperfect work still advances the game and improves the
   next attempt.
6. **The joke escalates; the controls do not.** Numbers may become astronomical,
   but the player still aims, swings, reads grain and watches wood split.
7. **No feature exists only to extend playtime.** Every system must create a
   decision, a new sensation, a visible transformation or a meaningful goal.

## Current-state audit — what the game already is

The live build is beyond the first draft of the old M7A roadmap. Any future work
must start from this real baseline.

### Strong foundations already implemented

- Runtime plane-sliced logs with tactile axe anticipation, impact, hit-pause,
  shake, physics and a satisfying pile animation.
- A 25-species, level-gated Janka ladder with cash purchases, data-driven value,
  XP rewards, difficulty and a working wood selector. The first species have
  authored art; later rows remain content work.
- A swing roll with a maximum chance below certainty, visible failed-hit scars,
  scar weakening, size relief and forced-roll test seams.
- A real swing cooldown, XP to level 99, one skill point per earned level and a
  validated prerequisite-based skill-tree prototype.
- Automatic sale as each piece lands, with cash ticking alongside the pile.
- A 50-piece haul-away spectacle that never blocks continued chopping.
- Persistent cash, lifetime wood chopped, yard-pile state and upgrade levels.
- A shop catalogue, atomic purchases, data-driven prices and a production entry
  flow between yard and chopping block.
- A strong acceptance culture: geometry, economy, saving, UI and visuals have
  dedicated checks and shot tools.

### The progression gaps

- No authored orders or customer goals.
- No reputation or career rank.
- No finalized proc-led skill catalogue, species mastery/certification loop,
  equipment loadout or automation bridge.
- No yard expansion beyond the current pile and shop panel.
- No staff, routes, passive logistics or offline outcome.
- No regional, national or global supplier progression.
- No finite Earth wood catalogue or terrestrial-mastery finale.
- No industrial projects, launch economy, expeditions or alien logs.
- No long-horizon goal presentation beyond earning the next amount of cash.

### Important technical interpretation

**Tree felling is not in scope in any form.** This roadmap must not restore the
deleted M5 FPS forest game or replace it with an abstract felling-management
layer. There are no standing-tree counts, forest depletion, felling crews,
skidders or harvesting controls.

Regions are data-driven **log suppliers**. They unlock delivered species,
customers, orders and transport relationships. Every meaningful piece of wood
returns to the existing chopping block, and global progression is measured by
species mastery and completed work—not by removing trees from a map.

## Genre research and what The Axeman should steal

Research was conducted on 2026-08-01. “Steal” below means learn the design
lesson, not copy content or presentation.

| Game | Relevant structure | Lesson for The Axeman | Do not inherit |
|---|---|---|---|
| [Scritchy Scratchy](https://store.steampowered.com/app/3948120/Scritchy_Scratchy/) | A tactile manual gesture, three understandable stats, riskier content, auto-scratching, run-ending danger and a prestige skill tree. | Keep the physical action satisfying while upgrades change its ease, speed and odds. Let automation handle safe/repetitive work while manual play handles risky/high-value work. | Hand strain, mandatory repetition, or opaque expected-value traps. |
| [Cookie Clicker](https://cookieclicker.wiki.gg/wiki/Upgrades) | Tiered buildings, clicking upgrades, building synergies, achievements, rare active opportunities and a large ascension tree. | Use milestone upgrades and cross-system synergies so an old purchase can become exciting again. Maintain a long tail of celebratory goals. | Hundreds of nearly identical percentage upgrades or a prestige reset too early. |
| [Universal Paperclips](https://decisionproblem.com/paperclips/) | A tiny manual business radically changes phase: market, planetary industry, then autonomous space exploration. | This is the clearest structural reference. Finish each fantasy, then replace the central question. The Earth-to-space reveal should feel inevitable in hindsight and shocking in the moment. | A mostly textual presentation or a phase change that abandons the chopping interaction. |
| [A Dark Room](https://adarkroom.doublespeakgames.com/) | Mechanics and story reveal gradually: room, village, resources, world, ending. | Hide future systems until they are narratively earned. The player should discover the scale rather than read the entire roadmap in the first UI. | Harsh survival failure or exploration as a second full game. |
| [Kittens Game](https://wiki.kittensgame.com/) | Jobs, buildings, technologies, conversion chains, trade, space, challenges and prestige. | Let staff assignments and buildings create strategic production choices. Space should reuse Earth systems at a new scale. | An unreadable lattice of resources, caps, energy penalties and conversion ratios. |
| [(the) Gnorp Apologue](https://store.steampowered.com/app/1473350/the_Gnorp_Apologue/) | Visible physical accumulation plus build-defining units, structures, upgrades, talents, status effects and strong synergies. | Make the yard itself the graph of the economy. Offer a few genuinely different company builds rather than one obvious upgrade ladder. | Effects so interdependent that the player needs a wiki to know why income changed. |
| [Leaf Blower Revolution](https://store.steampowered.com/app/1468260/Leaf_Blower_Revolution__Idle_Game/) | Manual tools escalate into absurd equipment, automation, areas, crafting, pets, shops and prestige. | Escalate the axe fantasy without embarrassment: better tools can progress from grounded steel to ridiculous gravitic technology. Regions and species can refresh the visual/action loop. | Dozens of currencies and shops, or automation that makes touching the core action pointless. |
| [Melvor Idle 2](https://store.steampowered.com/app/3218350/Melvor_Idle_2/) | Many interlocking skills, mastery, equipment, offline progress and an event log. | Give manual chopping permanent skill identity and species mastery. If offline progress is approved, explain exactly what happened while away. | Twenty-nine parallel skills. The Axeman needs a small, legible set. |
| [Idle Slayer](https://store.steampowered.com/app/1353300/Idle_Slayer/) | Active and offline progress, regions, materials, crafting, a large skill tree, equipment, achievements and side challenges. | A skill tree is strongest when it unlocks mechanics, not only multipliers. Regions should provide distinctive materials and rules. | Unrelated minigames added only to broaden content. |
| [Antimatter Dimensions](https://store.steampowered.com/app/1399720/Antimatter_Dimensions/) | Deeply unfolding layers, challenges that alter rules, prestige and extensive automation of solved tasks. | Automate a system once the player has demonstrated understanding; use optional contracts/challenges to make familiar chopping rules newly interesting. | Nested reset layers and UI complexity that erase the grounded fantasy. |
| [Mr. Mine](https://store.steampowered.com/app/1397920/MrMine/) | A physical depth axis, workers, drill upgrades, buildings, relics, secrets and feature unlocks tied to progress. | Make global wood mastery spatial and visible: every supplier region fills a clear catalogue section and reveals new mechanics. | Random treasure as a mandatory progression gate. |
| [Rusty's Retirement](https://store.steampowered.com/app/2666510/Rusty%27s_Retirement/) | A cozy visible workplace, automation helpers and a focus mode that respects attention. | Staff should be charming, visible and easy to understand. The game should be pleasant to watch without demanding constant check-ins. | Becoming so passive that active chopping has no reason to exist. |
| [Cell to Singularity](https://store.steampowered.com/app/977400/) | A clear thematic journey that expands from microscopic beginnings to civilization, speculative technology, Mars and space. | Use scale itself as story. A tech/project tree can make the path from hand axe to launch vehicle feel coherent. | A generic “tap anywhere for abstract energy” interaction. |
| [Clicker Heroes](https://store.steampowered.com/app/363970/Clicker_Heroes/) | Active clicks, recruitable producers, skills, critical hits, idle growth, absurd numbers and ascension. | Named staff with clear specialties can make passive production personable. Critical/manual moments should remain satisfying beside idle growth. | Endless zones that differ only in health and number size. |
| [Dwarf Eats Mountain](https://store.steampowered.com/app/4078200/Dwarf_Eats_Mountain/) | Visible throughput, hauling tension, many specialised units, active buffs, artefacts and build synergies. | Separate supplier delivery, chopping, stacking and shipping so logistics matter without adding another action loop. | A failure spiral where output is lost because support capacity was misjudged. |

Two broader design sources reinforce the same conclusion. Alexander King's
[incremental design analysis](https://code.tutsplus.com/numbers-getting-bigger-the-design-and-math-of-incremental-games--cms-24023a)
identifies discovery, active-versus-idle expression and coherent theme/art as
core design concerns, while Anthony Pecorella's GDC talk
[Quest for Progress](https://www.gdcvault.com/play/1023863/Quest-for-Progress-The-Math)
examines the genre through growth curves and unfolding mechanics. The Axeman's
competitive advantage is that it already has a better tactile action and more
physical visualisation than most games in the genre. The roadmap should exploit
that rather than bury it under menus.

## The core loop at every scale

```text
Unlock an unfamiliar species
    ↓
Chop it manually and learn its behaviour
    ↓
Earn XP + cash + species mastery
    ↓
Complete its authored certification
    ↓
Buy/install its automated cutting profile
    ↓
Automation turns solved wood into volume and cash
    ↓
Reinvest in tools, yard, logistics and the next species
    ↺
```

At company scale, a support loop runs beside it:

```text
Suppliers prepare and dispatch certified logs
    ↓
Feeders keep automated lines supplied
    ↓
Cutters process solved species at industrial scale
    ↓
Staff sort, bundle and ship the output
    ↓
The player reinvests, expands capacity and resolves bottlenecks
```

The loops meet at **certification**. Company infrastructure brings an unknown
species to the block; manual work teaches and certifies it; the resulting cutting
profile moves that species into industrial production. Momentum may remain as
an optional active surge, but established automation must not depend on the
player repeatedly chopping solved logs. Passive production intentionally
invalidates manual *commodity grinding* while preserving manual discovery.

## Progression economy — few currencies, many meaningful counters

### Spendable values

1. **Cash** — the universal business currency from stump through space. It buys
   equipment, wages, buildings, routes, industrial projects and expeditions.
2. **Skill points** — one is earned for each level gained and spent in the player
   skill tree. They represent the Axeman's growing strength, speed, technique
   and chance-driven talents, not business capital. Respeccing should be
   forgiving.

Do not add separate “yard coins,” “regional tokens,” “rocket bucks,” “prestige
shards” or a currency per wood species. Space projects can require cash plus
physical project materials. Those are items and requirements, not parallel
money systems.

### Unlock/progress values

- **Reputation:** permanent, non-spendable career rank progress. Unlocks
  customers, suppliers, permits and company scale.
- **Lifetime hand-chopped:** permanent celebration and skill-point milestone
  input. Keep it a background stat until a milestone makes it relevant.
- **Total timber processed:** company-wide output from hand work and certified
  auto-cutting lines. It begins as individual pieces/logs and may later be
  displayed as shipment or source-tree equivalents when throughput reaches the
  trillions. It never replaces the separate hand-chopped record.
- **Species mastery:** per-species experience from manual chopping. Unlocks
  knowledge and techniques for that wood, not generic cash bonuses alone.
- **Earth wood catalogue:** permanent record of discovered and mastered
  terrestrial species, signature logs and regional contracts.
- **Supplier standing:** per-region relationship progress earned through
  chopping and orders; it unlocks better shapes, rarer species and contracts.
- **Expedition readiness:** a project checklist/bar, not a banked currency.
- **Collection records:** best perfect-log streak, hardest wood split, fastest
  order, alien specimens catalogued and other achievement statistics.

### Large-number philosophy

Early numbers should remain human: single coins, individual pieces, one truck.
Abbreviations appear only when the fantasy genuinely reaches industrial scale.
The interface should preserve exact values in tooltips/history while presenting
compact values on the main HUD. Scientific notation belongs only in the far
cosmic postgame, where its arrival is itself a joke.

## Species lifecycle — master it, automate it, move upward

Manual chopping is a finite **power phase for each new species**, not the
permanent way the company produces solved timber. A player cannot and should not
click through twelve trillion logs. The repeatable arc is:

1. **Discovery:** an unfamiliar species is delivered to the block and is
   manual-only. Its traits are initially incomplete or unknown.
2. **Learning:** the player chops a small authored set of logs, earns XP and
   cash, reveals the wood's behaviour and builds species mastery.
3. **Certification:** the player proves understanding through a short species-
   appropriate checklist. Exact counts and criteria are tuning/content calls.
4. **Industrialisation:** certification unlocks that species' cutting profile;
   cash buys a compatible machine or installs the profile in an owned line.
5. **Production:** automation replaces routine hand-chopping for that species,
   generating the volume and cash that funds the next unknown wood.

### Manual-only progression

- First encounters and trait discovery.
- Axeman XP and player levels.
- Species mastery and first certification.
- Rare specimens, authored finales and optional signature handwork.
- Perfect-log and personal chopping records.

### Automation's job

- Replace manual commodity production for certified species.
- Scale solved woods from individual pieces to industrial and astronomical
  totals.
- Generate the sustained cash required for later tools, routes and projects.
- Expose understandable supply, machine, power, queue and dispatch bottlenecks.
- Continue operating solved production chains while the player works on a new
  species and, if separately approved, while the player is away.

Auto-cutters are visible, purchased production lines with auditable inputs and
outputs. They cannot accept an unknown or uncertified species and cannot award
first mastery or Axeman XP. After certification, however, they are not a weaker
consolation prize: they are the intended superior source of commodity volume.
Manual chopping an old species remains available for pleasure or special work,
but is no longer strategically required.

The exact relationship between Sam's trillion-scale target, delivered logs and
“source-tree equivalents processed” needs a later tuning/content decision. Do
not hardcode a literal world total until that unit is defined.

## Craftsmanship model

The slicer already knows the geometry. M7B should turn that into a forgiving,
legible craft score without turning every swing into a spreadsheet.

### Per-piece measurements

- Requested size-band match.
- Distance of the cut from the aimed/ideal plane.
- Resulting piece symmetry or size consistency within the current log.
- Scar count inherited before the successful split.
- Whether the player cut through a revealed weak-grain zone.

### Per-log outcomes

- **Rough:** valid output; always sold at base value.
- **Workmanlike:** most pieces fall in the requested range.
- **Clean:** consistent sizing and few failed blows.
- **Perfect:** authored criteria met across the full log.

The names are proposed; exact thresholds and payout effects require Sam's
tuning sign-off. The UI should present one plain-language reason for the grade,
such as “four evenly sized stove pieces” or “two scars, but no waste.” Do not
show the raw geometry formula during ordinary play.

### Streaks

A short **Rhythm** streak can reward consecutive successful, intentional cuts.
It should decay gently on a miss and end on leaving the block, not punish the
player with lost stock. Rhythm contributes to Momentum and spectacle more than
direct exponential cash, avoiding a runaway rich-get-richer loop.

## Player skills

Every earned level grants one skill point. A level must buy more than a smaller
timer: the tree's identity comes from random bonus mechanics, branching proc
chains and rule-changing capstones. Repeated stat ranks may support those
mechanics, but cannot be the main reward.

Each branch contains four node types:

1. **Foundation:** dependable improvements to the underlying action.
2. **Proc:** introduces a chance for a named bonus event.
3. **Modifier:** changes what that event can do or how far it can chain.
4. **Capstone:** a rare, highly visible expression of the branch fantasy.

### Branch A — Strength / explosive chopping

| Skill concept | Gameplay effect |
|---|---|
| Strong Arms | Improves ordinary performance against resistant wood without guaranteeing a split. |
| Deep Bite | Failed strikes sometimes leave a more effective scar or multiple weakness marks. |
| Critical Cleave | A successful roll can partially ignore the species' resistance. |
| Echoing Blow | Introduces a chance for one swing to perform a second real slice. |
| Rolling Thunder | A double strike can chain into a third slice. |
| Unstoppable | A very lucky chain can reach four slices from one swing. |
| Earthshaker | Capstone: the rare quadruple strike receives its own escalating impact, audio, hit-pause and announcement. |

One swing may therefore perform multiple valid slicer operations: two cuts can
produce up to three pieces, three cuts up to four, and four cuts up to five.
Each continuation targets a remaining valid piece and stops cleanly when no
useful geometry remains.

### Branch B — Speed / rhythm and flurries

| Skill concept | Gameplay effect |
|---|---|
| Quick Hands | Modestly shortens recovery while preserving axe weight. |
| Ready Stance | Modestly shortens the anticipation before impact. |
| Follow-Up | A strike can instantly ready the next manual swing. |
| Free Swing | A successful hit can consume no cooldown. |
| Hot Streak | Intentional successes raise proc odds until a bonus fires; a miss softens rather than erases the streak. |
| Blur | Chance for a rapid bonus after-strike with its own visible axe echo. |
| Flow State | Capstone: a lucky sequence opens a short, audiovisual chopping frenzy rather than a permanent extreme speed multiplier. |

### Branch C — Technique / knowledge and reward jackpots

| Skill concept | Gameplay effect |
|---|---|
| Grain Glimpse | Occasionally reveals a golden weak-grain opportunity. |
| Edge Control | Broadens the precision band for an intentional cut. |
| Controlled Failure | Failed strikes land closer to the intended plane and teach the next attempt. |
| Quick Study | A manually finished log has a chance to award double XP. |
| Flash of Insight | A rarer proc can produce a larger XP event with a distinct orb burst. |
| Perfect Fracture | Bonus slices prefer useful spacing and requested size bands instead of creating random rubbish. |
| Eureka | Capstone: an unfamiliar species can trigger a major mastery/XP discovery during its learning phase. |

Double or multiplied XP must be shown physically through extra or distinct XP
orbs and a named result; an invisible total change is not enough.

### Cross-branch skills

| Combination | Hybrid effect |
|---|---|
| Strength + Speed | Rolling multi-strikes can inherit follow-up and streak behaviour. |
| Strength + Technique | Multi-slices follow useful geometry and can contribute strongly to certification. |
| Speed + Technique | Completing a log during a hot streak improves the chance of an XP discovery. |
| All three | A rare Master's Swing combines a multi-cut, clean fracture and learning bonus. |

### Proc fairness and control

- Use bad-luck protection or a shuffled/weighted sequence so a build cannot go
  dry for an unreasonable stretch; exact odds remain tuning calls.
- Bonus cuts occur only when another valid, useful slice exists.
- Precision and signature work must not be ruined by an unwanted random chain.
  Multi-strike skills may be equipped/disabled at the yard, and Technique can
  make them respect an active size request.
- Every proc is named on screen—DOUBLE STRIKE, TRIPLE STRIKE, QUAD CLEAVE,
  DOUBLE XP—and receives proportionate sound, animation and game feel.
- Proc odds and maximum chain depth must be legible in the skill detail view.
- Player levels and species difficulty must never make every ordinary swing a
  certainty; scars and failure remain part of the texture.

The full authored tree should cost more points than level 99 awards so builds
remain distinct, while a forgiving yard respec prevents experimentation from
bricking a save. Final node counts, costs, odds and magnitudes require Creative
Director tuning sign-off.

## Equipment, items and productivity tools

The store is the physical/business half of progression. Skills change what the
Axeman can do; cash changes the axe, workstation, yard and company. The store
should evolve from percentage rows into a physical catalogue in which each
purchase creates a yard prop, axe change, animation, UI capability, production
line or clearly felt rule change.

### Store departments and presentation

1. **Axes and active tools:** loadout sidegrades biased toward Force, Tempo or
   Control, with different models, animations and proc affinities.
2. **Workstation/environment:** stump, cradle, grain lamp, turntable, clamps and
   other features that make the manual learning phase more capable.
3. **Automated production:** cutters, installed species profiles, line capacity,
   force, speed and parallelism.
4. **Yard and logistics:** input racks, feeders, power, sorting, storage,
   loading, routes and dispatch capacity that keep production moving.
5. **Session supplies:** optional short-lived modifiers; never mandatory upkeep.

Every store card must show what changes, the current/next tier, price, relevant
trade-off and the physical yard consequence. The player may pin one purchase as
their active cash goal so every payout visibly fills an understandable target.
The store should almost always expose one affordable action, one session-sized
goal and one aspirational machine or expansion.

Axes and proc skills deliberately interact: skills define **what can happen**;
the equipped tool weights **how often, how strongly or how safely it happens**.
A maul may favour multi-strikes, a hatchet follow-ups, a broad axe clean fracture
and a balanced axe moderate access to every proc family. No tool may have ten
tiny opaque stats.

### Axes and strike tools

| Item concept | Role | Felt difference |
|---|---|---|
| Starter Axe | Current balanced tool. | Baseline timing, odds and cut behaviour. |
| Camp Hatchet | Fast kindling specialist. | Quicker recovery and narrow cuts; struggles with high-tier hardwood. |
| Splitting Axe | General progression tool. | Better size relief and clean-split reliability. |
| Splitting Maul | Slow hardwood specialist. | Long anticipation/recovery, strong scar and hard-wood performance. |
| Broad Axe | Craftsmanship sidegrade. | Wider sweet spot for large even pieces, poor for kindling. |
| Wedge and Sledge | Multi-step tool set. | A failed first strike can place a wedge; the follow-up has a special high-confidence roll and animation. |
| Hydraulic Axe | Industrial-era active tool. | Powered wind-up, charge choice and huge impact; still aimed manually. |
| Resonance Axe | Late-Earth experimental tool. | Reads and attacks a species-specific frequency/weak band. |
| Gravitic Axe | Space-era tool. | Curves fragments toward the capture field and handles impossible density. |

These are sidegrades plus tiers, not a straight sequence that makes every old
tool trash. Orders and species should create reasons to revisit them.

### Chopping-block and bench upgrades

- Seasoned stump: a visual first upgrade and steadier default placement.
- Iron banding: handles harder species and changes impact audio.
- Log cradle: reduces roll and lets the player rotate before committing.
- Grain lamp: makes weak-grain hints readable in shade/night variants.
- Wedge tray: enables the wedge-and-sledge technique.
- Powered turntable: rapidly reorients large or oddly shaped logs.
- Fragment catcher: controls the most extreme late-game piece trajectories.
- Specimen clamp: required for fossil, living or reactive alien logs.
- Orbital capture ring: converts the familiar stump silhouette into the zero-g
  endgame rig without losing the visual identity of the block.

### Automated cutting lines

Auto-cutting is the payoff of the species-learning loop, not tree felling. The
first slow Mechanical Splitter should appear during the early grounded-company
progression, after the player has manually certified the first small group of
woods. It must establish the promise “I taught my yard how to cut this” well
before global scale; later lines expand that proven idea toward twelve trillion.

| Line concept | Role | Boundary |
|---|---|---|
| Mechanical Splitter | First slow commodity line; makes automation physical and legible. | Certified common species only; no mastery or premium grade. |
| Hydraulic Split Bank | Processes several delivered logs in parallel. | Requires delivery capacity and a mechanic; creates commodity output only. |
| Grain-Vision Cell | Selects a certified cutting profile per species. | The profile is unlocked by the player's manual specimen work. |
| Continental Cutting Hall | Major global-volume multiplier represented in the yard/company view. | Cannot accept rare, signature or unknown logs. |
| Orbital Mass Splitter | Space-era line for certified alien commodity timber. | Requires manual alien mastery and specialised containment. |

Every line consumes delivered-log supply, has a visible output rate and produces
an auditable quantity of commodity firewood/material. It cannot earn Axeman XP,
species mastery, perfect-log records, signature-order credit or first-discovery
rewards. Once a species is certified, the line is expected to surpass manual
commodity output. Momentum may provide an optional temporary surge, but the
factory must not require repetitive hand-chopping to remain economically valid.

### Consumables and temporary boosts

Consumables should change a short session's approach, not become chores that
must always be active.

- **Coffee** — existing faster recovery effect.
- **Protein Bar** — existing split-chance effect.
- **Whetstone** — improves clean-cut/craft tolerance for a limited number of
  swings or logs.
- **Chalk** — reveals weak grain sooner or more clearly for one order.
- **Hearty Stew** — extends the duration of Momentum earned during the next
  chopping session.
- **Resin Solvent** — removes a resinous species' specific cooldown/drag trait.
- **Cooling Wrap** — permits a short session on heat-reactive alien timber.

Coffee and food should not need hunger, fatigue, cooking or survival systems.
They are optional session modifiers sold by the yard shop or earned from named
customers.

### Wearable and cosmetic rewards

- Gloves, apron, boots and ear protection that visually mark career rank.
- Axe-head finishes, haft wraps and engraved wedges.
- Customer patches and regional badges on a work jacket.
- Yard signs, flags, plaques and the preserved cross-section of each mastered
  species.
- The final Earth tree ring mounted in Mission Control.

Cosmetics are ideal achievement rewards because they celebrate without
distorting balance.

## Species ladder and mechanical identity

New wood cannot be “same log, larger price.” Each species should combine a
shape family, visual identity, split profile, customer use and one readable
trait. The following names and ordering are **design candidates**, not approved
item IDs or final values.

### Grounded Earth woods

| Species | Identity | Chopping trait | Economy role |
|---|---|---|---|
| Pine | Soft, common, resinous. | High base split chance; occasional sticky scar/cooldown trait later. | Tutorial wood and bulk campfire orders. |
| Oak | Dense, familiar benchmark. | Balanced resistance; rewards central, even work. | Core homeowner and smokehouse market. |
| Birch | Valuable and visually distinctive. | Lower base split chance; clean grain makes precise work rewarding. | First premium species and mastery test. |
| Cedar | Aromatic, fibrous. | Split can follow grain more strongly than the exact aim. | Specialty cooking, sauna and artisan orders. |
| Eucalyptus | Hard, twisted grain. | Weak band moves/curves; scars matter greatly. | High-value regional breakthrough. |
| Mahogany | Heavy luxury timber. | Difficult, slow and intolerant of rough technique. | Prestige customer and boardroom-contract wood. |
| Redwood | Enormous authored log shapes. | Many-stage log; tests consistency and endurance rather than raw odds alone. | Monumental orders and infrastructure material. |
| Ebony/Ironwood | Extreme late-Earth hardness. | Maul/wedge or powered tools strongly favoured. | Final terrestrial mastery and launch-project component. |

### Alien woods

| Species concept | Visual/mechanical reveal | New decision |
|---|---|---|
| Martian Fossilwood | Stone-like growth rings, dust and delayed fractures. | Decide between repeated scars or a charged powered hit. |
| Europan Kelpwood | Translucent wet fibres that flex back after impact. | Cut during a brief tension window. |
| Venusian Cloudwood | Impossibly light, buoyant pieces. | Aim while the log drifts inside the capture ring. |
| Lunar Salvage Timber | Ancient Earth wood found in a buried human cache; dry and brittle. | Preserve valuable pieces by avoiding over-splitting. |
| Mycelial Log | Living grain rearranges after each failed hit. | Re-read the piece instead of repeating the same aim. |
| Magnetwood | Fragments attract/repel one another. | Orient the log to control the pile/capture pattern. |
| Prism Bark | Cut face refracts colour and reveals value bands. | Choose between easy ordinary cuts and difficult rare-core cuts. |
| Neutron Heartwood | Absurdly dense endgame specimen. | Requires accumulated scars, a gravitic axe and a long ceremonial strike. |
| Timewood | The cut appears before the swing and resolves after it. | Read a preview/echo and commit; a late-game rule-bending mastery test. |

Alien traits must remain readable and skill-based. Randomness can vary a log,
but the player needs a visible cue and a fair response.

## Customers, orders and contracts

The basic buyer always exists and buys all valid output as it lands. Orders are
optional goals that redirect matching pieces and pay a premium/reputation bonus.
No order may make free chopping impossible.

### Order families

1. **Quantity:** deliver a number of any valid pieces.
2. **Species:** supply a named wood.
3. **Size:** kindling, stove wood, campfire splits or large billets.
4. **Quality:** workmanlike/clean/perfect, with rough pieces still going to the
   basic buyer.
5. **Efficiency:** complete a full log within a scar or swing allowance.
6. **Mixed load:** a readable recipe of two or three species/sizes.
7. **Signature:** a named customer, handcrafted only, generous reward and a
   unique story/cosmetic.
8. **Infrastructure:** contribute bulk company timber to a bridge, railhead,
   port or launch project.
9. **Expedition:** prepare a precise set of Earth woods for a spacecraft or
   return an alien specimen intact.

### Customer ladder

- Campsite manager — loose pine/kindling work; teaches order routing.
- Homeowner — consistent stove pieces; teaches craft grading.
- Smokehouse — species preference; teaches supply selection.
- Bakery/brickworks — steady bulk fuel; introduces repeating contracts.
- Furniture artisan — small premium clean cuts; introduces signature work.
- Railway contractor — bulk company output and transport capacity.
- Government works office — regional infrastructure and permits.
- Global Timber Board — worldwide mastery targets and huge project contracts.
- Space agency procurement — precision Earth materials for launch systems.
- Orbital habitat quartermaster — recurring mixed Earth/alien loads.
- Xenobotanist — intact specimens, unusual cut rules and mastery certification.
- Interstellar clients — absurd final requests that remix every learned skill.

### Contract presentation

Show at most three meaningful choices at once early on: safe, specialised and
aspirational. Later upgrades can add a slot or a refresh, but the screen should
never become a job-board spreadsheet. Real-time expiry is opt-in “rush work”
only; normal contracts wait patiently.

## Staff and automation

Staff appear only after the player has personally performed the task they
simplify. They are visible characters/vehicles with one clear job each.

### Yard staff

| Role | Removes friction from | Does not replace |
|---|---|---|
| Log Driver | Delivery delay and species queue. | Choosing supply or chopping. |
| Yard Hand | Gathering, tidying and pile reset speed. | Craft quality or payouts. |
| Stacker | Visual pile organisation and load preparation. | The satisfying fly-in/haul-away event. |
| Order Clerk | Matching eligible pieces and claiming completed contracts. | Choosing which order matters. |
| Mechanic | Machine uptime and upgrade inspection. | Tool choice or active strikes. |
| Dispatcher | Route priorities and truck assignment. | Strategic capacity decisions. |

### Supplier and route staff

- Supplier scouts reveal available species, log shapes and regional customers.
- Purchasing agents negotiate access to rarer delivered logs.
- Truck, rail and ship crews move prepared logs between supplier depots and the
  yard.
- Depot managers increase queue capacity and delivery reliability.
- Quality inspectors improve advance information about incoming log traits.
- Route coordinators reduce delays rather than introducing a punitive worker
  needs or failure simulation.

### Space staff

- Mission planner reveals travel time, cargo risk and return profile.
- Launch crew reduces turnaround.
- Xenobotanist identifies new species traits.
- Quarantine officer prevents reactive logs disrupting the yard.
- Cargo liaison manages repeat deliveries from established expedition partners.

### Offline progress recommendation

Do not implement offline progress until M8 logistics is fun while watched.
When approved, offline time should advance only systems the player has actually
automated. On return, present a concise ledger: logs delivered, logs auto-cut,
loads bundled, cash earned, contracts completed, incidents and capped/blocked
systems. Never
hide a bottleneck behind “welcome back” confetti.

The offline cap, rate and whether Momentum can persist are final tuning calls
for Sam.

## The Earth supplier atlas

The supplier atlas is the bridge from cozy yard to global scale. It represents
business relationships and wood knowledge—not standing forests or harvesting.

### Region data

Each region is an authored resource containing:

- display name and visual card/map treatment;
- available species and authored delivery shapes;
- one signature log shape/specimen;
- supplier standing and transport modifier;
- customer and contract set;
- discoveries and project unlocks;
- required reputation/permit project;
- mastery requirements, completion reward and permanent catalogue entry.

Exact region and species counts are tuning/content calls. Use enough regions for
distinct acts, not dozens of palette swaps.

### Region loop

1. Meet or discover the regional supplier.
2. Manually chop its first delivered specimen.
3. Learn its species trait and unlock basic contracts.
4. Improve supplier standing through orders and mastery.
5. Solve the delivery/queue bottleneck with road, rail or port routes.
6. Build Momentum at the block while staff keep valuable logs arriving.
7. Discover a landmark contract or rare specimen at milestones.
8. Master the region's signature wood and receive a permanent catalogue trophy
   or project unlock.

### Visual consequence

The atlas should fill with supplier stamps, route lines, species cross-sections
and completed signature contracts. The yard receives regional signs, vehicles,
packing styles and trophy cuts. Progress communicates a widening craft network,
never forest depletion.

### Global mastery dashboard

When several regions exist, unfold a simple top-level dashboard:

- Earth species discovered and mastered.
- Regional signature contracts completed.
- Delivery and yard-handling capacity.
- Active supplier/queue bottleneck.
- Current unknown-species mastery/certification state.
- Next global mastery milestone/project.

This is the point where global completion becomes useful. Do not show the whole
catalogue on the opening yard screen.

## The launch programme

Space should be built out of terrestrial success, not unlocked by an arbitrary
prestige button.

### Project chain

1. Global Wood Catalogue — proves the Axeman has mastered every known
   terrestrial species and reveals anomalous off-world timber signatures.
2. Timber Materials Laboratory — uses mastered species for advanced composites.
3. Launch Authority — converts global reputation into permission and contracts.
4. Yard Expansion: Mission Control — a visible building arrives at the home
   yard.
5. Prototype Engine/Launch Gantry — cash and physical company materials become
   a giant construction progress bar.
6. Orbital Test — short mission returning a cosmetic/technical unlock.
7. Deep-Space Telescope — discovers candidate timber signatures.
8. Cargo Vessel — configurable range, shielding and return capacity.
9. First Timber Expedition — returns the first impossible log to the familiar
   block.

Projects are sequential or branching checklists, not a new “science points”
economy. Cash, mastered woods, company output and authored achievements fund
them.

### Expedition decisions

- Destination and travel time.
- Cargo capacity versus shielding/safety.
- Survey intensity versus specimen-retrieval capacity.
- Crew speciality.
- Which axe/rig module travels.
- Whether to prioritise common logs, intact rare specimens or seeds/spores.

Missions must never be real-money timers. Chopping, Momentum and project
upgrades can accelerate preparation or improve outcomes, but a mission already
in flight should complete predictably.

### Expedition return

The return is a spectacle: vessel arrival, cargo doors, quarantine scan, then a
single alien log placed on the same block that started the game. The first cut
should be a major mechanical reveal, not just a large payout.

## Prestige recommendation

Do **not** add a conventional full reset during the Earth campaign. It would
erase the visible yard and force replay of mastered woods instead of delivering
the next revelation.

Use two softer structures instead:

1. **Supplier onboarding:** a new region begins with basic standing and delivery
   capacity, but all character skills, equipment and home-yard progress remain.
   This creates fresh optimisation without deleting history.
2. **Expedition charters:** each alien destination begins with incomplete survey
   knowledge and limited cargo access. The player chooses a mission doctrine
   while retaining Earth, skills, mastered species and spacecraft technology.

An optional time-loop/parallel-universe reset can exist only after the complete
space campaign, if Sam later wants an endless mode. It is not part of the core
roadmap.

## Full feature roadmap

Every milestone below is a separate sign-off gate. Do not start the next one
because the prior test suite is green.

### M7A — close the current playable slice

**Goal:** Make the existing cash/chop/shop loop feel intentional and shippable
for a short session.

**Already present:** auto-sale on landing, pile haul-away, cash/save, scars and
pity, Coffee and Protein Bar, three live woods, yard/chopping entry flow.

**Finish:**

- Tune and sign off the current swing, split chances, scars, cooldown, payout
  spread and two shop effects.
- Add the three introductory authored orders already promised by the approved
  M7A scope, while keeping unmatched work on the unlimited auto-sell path.
- Expand the catalogue to the approved total of five tangible upgrades.
- Make one additional species a deliberate unlock/supply choice rather than
  having every live species arrive without progression.
- Replace placeholder shop presentation with a legible but modest catalogue.
- Add a visible “next useful purchase” goal without putting lifetime totals on
  the permanent HUD.
- Make the 50-piece haul threshold discoverable through the pile/animation or a
  contextual cue, without duplicating ownership of the value.
- Decide and resolve the leftover `slice_poc.tscn` harness and stale duplicate
  folders separately; they are not gameplay features.

**Approved catalogue (2026-08-04):** Balanced Axe (one-time), Reinforced
Chopping Block (tiered, rank 1 in M7A), Supplier Ledger (one-time), Handcart
(one-time), Coffee Thermos (permanent one-time). Their binding roles, unlocks,
physical consequences, acceptance requirements and measured tuning procedure
are in `handoff/11_M7A_FIVE_PURCHASE_IMPLEMENTATION_BRIEF.md`. Order bonuses are
50 / 150 / 400 cash. Do not invent final shop prices or effect magnitudes.

**Exit test:** A new player can chop freely or pursue an introductory order,
understand a failed hit, earn money, buy a felt upgrade, unlock another wood,
see a haul-away and save/return without explanation.

### M7C — Axeman career and species mastery (next after M7A)

**2026-08-04 sequence amendment:** M7C is the next sign-off gate after M7A.
Starter Balanced Axe and rank-1 Reinforced Chopping Block now belong to M7A;
M7C retains the full Strength/Speed/Technique identities, proc families,
species mastery, later sidegrades and loadout. The approved prototype migration
is recorded in the M7A brief and `AGENTS.md`.

The binding preparation brief for this milestone is
`handoff/12_M7C_AXEMAN_CAREER_AND_SPECIES_MASTERY_BRIEF.md`. Its scope fence,
save-v2 migration, mockup reconciliation, staged slices and approval gate apply
before feature coding.

**Goal:** Make the player's hands progress, not only the business.

**Features:**

- One skill point per earned level and named Axeman Rank bands.
- Initial Strength/Speed/Technique branches with foundation, proc, modifier and
  capstone nodes.
- First double-strike and double-XP proc families, with bad-luck protection,
  visible announcements and safe geometry.
- Species mastery and authored certification for the live woods.
- Grain-reading feedback and perfect-log tracking.
- First post-starter axe sidegrade and the next block feature/rank after M7A.
- Equipment loadout with plain comparison text.
- Achievements/milestones that unlock cosmetics, not raw clutter.
- Temporary consumables expanded beyond Coffee/Protein Bar only if they create
  distinct session choices.

**Exit test:** Two players can spend the same early skill points differently and
feel the distinction at the block; a random bonus produces a visible mechanical
event rather than only a smaller timer or hidden number.

### M7B — craftsmanship, customers and reputation (follows M7C)

**Goal:** Give every chopping session a choice and a medium-term purpose.

**Features:**

- Always-available basic buyer remains unchanged.
- Expand the M7A order set into quantity, species, size, quality and signature
  families.
- Extend contract routing and history while unmatched output still auto-sells.
- Reputation as a permanent non-spendable unlock track.
- Customer cards, completion celebration and an order history.
- First craftsmanship grade derived from geometry.
- First named signature customer and premium handcrafted-only work.
- A proper wood-supply selector for currently unlocked species.

**Do not include yet:** staff, offline income, world map, timed daily quests or
dozens of customer types.

**Exit test:** Pine, oak and birch produce meaningfully different choices; rough
work always earns money; a skilled player can intentionally earn a better order
result.

### M7D — the yard visibly grows

**Goal:** Turn cash progression into place progression.

**Features:**

- Authored yard states: stump, shed, working yard, depot.
- New equipment/props appear physically after purchase.
- Dedicated contract crates and delivery area.
- Vehicles arrive/depart with logs and haul-away loads.
- Trophy wall/species cross-sections.
- Shop becomes a physical yard building/panel context rather than an empty room.
- Yard overview remains a lightweight management space, not a walkable village.

**Exit test:** A before/after screenshot communicates major progress without any
numbers visible.

### M8 — first automation, staff and logistics

**Goal:** Prove the full learn → certify → automate loop and build the first
passive company system while the fantasy is still grounded and legible.

**Features:**

- Log Driver, Yard Hand, Stacker, Order Clerk, Mechanic and Dispatcher in an
  authored introduction order.
- Clear task/capacity model and visible activity.
- Log queues and route priority.
- Delivery, stacking, order fulfilment and haul-away improvements.
- Staff upgrades that change equipment/behaviour, not a needs or morale sim.
- The first visible Mechanical Splitter, initially accepting only the early
  species the player has manually certified.
- Installed species cutting profiles, a visible input queue, output rate and
  one understandable bottleneck.
- Optional Axeman's Momentum may temporarily boost staff or machinery, but
  solved production does not require it.
- Offline progress only after the watched loop is approved.
- Return ledger and safe offline cap if approved.

**Exit test:** The player manually learns and certifies a species, buys its
machine/profile, watches automation decisively replace routine hand production
for that wood, and uses the resulting cash toward the next species.

### M9 — regional supply network

**Goal:** Reveal that the yard can attract logs and customers from around the
world without adding another action loop.

**Features:**

- First supplier atlas with a small authored set of regions.
- Discovery, standing, depot and transport steps.
- Region-specific species, customers, traits and visual completion.
- Regional mastery pages and signature-log records.
- First long-distance delivery routes and specialist buyers.
- First atlas discoveries and infrastructure projects.
- Supplier onboarding creates fresh optimisation without deleting the home yard.

**Exit test:** The player can explain why a desired log is slow to arrive—supplier
standing, dispatch, route or yard queue—and can fix it with a meaningful purchase
or priority change.

### M10 — national and continental company

**Goal:** Move from several regions to an economy of routes and specialisation.

**Features:**

- Railheads, ports and bulk routes.
- Multiple simultaneous regions with limited dispatcher capacity.
- Company doctrines/builds: craftsmanship-first, logistics-first or contract-
  first, with respec/adjustment that does not brick a save.
- Cedar/eucalyptus/mahogany-tier species candidates and harder signature work.
- Large infrastructure contracts and government customers.
- Hydraulic Split Banks and additional profile/capacity upgrades that expand the
  already-proven Mechanical Splitter loop.
- Logistics equipment that keeps auto-cut lines supplied while the player
  personally handles unknown species and optional premium/signature specimens.
- Visible yard transition from depot to headquarters.

**Exit test:** Two viable companies can reach the same milestone through
different bottleneck solutions, and older equipment/species still has a role.

### M11 — global wood mastery campaign

**Goal:** Master every authored terrestrial wood and complete the World Wood
Catalogue.

**Features:**

- Full Earth species/mastery dashboard.
- Continental supplier relationships, shipping lanes and global project board.
- Late-Earth redwood/ironwood-scale mastery challenges.
- Enormous but visually readable delivery and yard-handling machinery.
- Successive auto-cutting lines that turn certified commodity logs into the
  trillion-scale processed-timber number.
- Global news/headlines celebrating the increasingly improbable chopping
  business.
- Milestone discoveries at authored catalogue/mastery thresholds.
- Launch-programme foreshadowing begins well before the Earth catalogue is
  complete.
- Anti-stall systems always identify the missing species, contract or mastery
  requirement and allow meaningful action.

**Exit test:** Earth mastery is achievable without repetitive filler, but long
enough to make the final terrestrial species feel momentous. No new species or
first-time mastery event completes invisibly while the player is offline.

### M11B — the final terrestrial species

**Goal:** Deliver the finite Earth-mastery ending promised by the catalogue.

**Sequence:**

1. The final catalogue slot and its requirements become explicit.
2. The supplier atlas, yard staff and customers acknowledge the moment.
3. A final extraordinary terrestrial-species log is delivered to the original
   block.
4. The player completes a multi-stage hand-crafted split using the skills they
   developed across the campaign.
5. Failed hits scar and weaken as usual; the finale is never hard-failed.
6. The last split completes the World Wood Catalogue and awards Earth Master
   status.
7. The haul-away becomes a unique global celebration.
8. The final cross-section is mounted in the yard/Mission Control.
9. The launch programme becomes the new headline goal.

**Exit test:** The Earth campaign has credits/closure and the save remains
playable. The player cannot accidentally miss the final terrestrial mastery
because passive progress crossed its threshold.

### M12 — launch programme

**Goal:** Convert the entire Earth economy into a spacecraft.

**Features:**

- Mission Control and launch gantry physically expand the yard skyline.
- Project checklist using cash, company output, species mastery and signature
  materials.
- Frontier skill branch revealed.
- Orbital test and deep-space telescope.
- Configurable cargo craft and named launch staff.
- Clear expedition planning UI with no premium/real-money timing mechanics.
- Chopping and Momentum accelerate preparation/building, not time already spent
  in flight.

**Exit test:** Every launch component traces back to a system learned on Earth;
space does not feel like an unrelated menu game.

### M13 — first alien timber expedition

**Goal:** Renew the tactile chopping loop with the first impossible log.

**Features:**

- One fully authored destination and expedition chain.
- Vessel departure/return spectacle.
- Quarantine and specimen-identification sequence.
- One alien species with a genuinely new readable split behaviour.
- Specimen mastery unlocks repeat cargo requests from that destination.
- Manual certification is required before any future alien auto-cutting line
  can accept that species.
- Orbital/specimen chopping rig evolves from the familiar stump.
- Alien wood creates a new premium order family and one spacecraft upgrade.

**Exit test:** The first alien log is mechanically surprising, visually clear
and still recognisably The Axeman.

### M14 — interplanetary timber company

**Goal:** Turn expeditions into a repeatable alien-log discovery and mastery
loop.

**Features:**

- Several authored planets/moons with distinct recovered log ecologies.
- Expedition charters as soft prestige/build choice.
- Survey → specimen retrieval → certification → repeat cargo → mastery loop.
- Cargo fleets, range, shielding and supplier liaisons.
- Alien customers/materials and cross-species projects.
- Gravitic tools and Frontier mastery.
- Orbital auto-cutting lines that replace commodity hand-processing for mastered
  alien species while new specimens still begin at the manual rig.
- Earth remains visible as the headquarters and completed first campaign.

**Exit test:** Each destination changes strategy and chopping behaviour; none is
merely a larger price multiplier.

### Postgame — the cosmic wood catalogue

**Goal:** Provide endless aspiration only after the authored campaign is
complete.

Candidates:

- Procedurally assembled but trait-bounded star systems.
- Rare authored cosmic log specimens between procedural destinations.
- Company doctrines/challenges that alter rules without deleting history.
- A final catalogue for woods mastered across the known universe.
- Optional timeline/parallel-universe reset for players who explicitly choose
  it, with permanent museum records of completed universes.

This is not active scope until M14 is complete and signed off.

## Build variety and synergies

The shop and skill tree should support at least three understandable strategies:

### Craft house

- Precise tools, broad sweet spots, mastery and premium orders.
- Lower total volume, highest hand-split value and reputation.
- Synergy: perfect logs build stronger Momentum, which temporarily fixes bulk
  bottlenecks.

### Logistics company

- Drivers, routes, queues, ports and dispatch capacity.
- Best at keeping many regions moving and converting field output to cash.
- Synergy: the player chooses rare/high-value logs while staff keep ordinary
  supply flowing.

### Global specialist

- Hard-species gear, premium supplier access and major catalogue projects.
- Best at difficult woods, rare log shapes and global mastery progress.
- Synergy: manual specimen certification unlocks each new supplier tier.

The player can hybridise. Builds should be preferences and temporary
bottlenecks, not irreversible classes.

## Progression and balance architecture

All numerical examples below are targets to tune, not approved constants.

### Three clocks

1. **Swing clock:** seconds. Aim, anticipation, strike, result, recovery.
2. **Session clock:** minutes. Finish logs, complete an order, afford a felt
   upgrade, trigger a haul-away.
3. **Campaign clock:** hours. Unlock a species, yard state, region, company tier,
   continent, last-tree act or expedition.

Every era needs activity on all three clocks. A global catalogue filling does
not excuse a ten-minute gap with no interesting purchase; a constant shower of
coins does not replace a meaningful hour-scale goal.

### Goal ladder

The player should nearly always see:

- one affordable action now;
- one purchase/order achievable this session;
- one major unlock that feels aspirational but understandable.

If all visible goals are far away, the curve is stalled. If every purchase is
immediate, decisions have no weight.

### Cost/output curves

- Repeated scalar upgrades may use geometric cost growth, stored in data.
- Mechanic unlocks and physical tiers use authored costs tied to expected
  income at their reveal.
- New regions/species create step changes in value and difficulty.
- Synergies should revive older assets rather than only multiply the newest
  producer.
- Diminishing returns should redirect spending, not secretly nullify it.
- Every global multiplier must identify its source in a breakdown view.

No literal costs, growth factors, timers, odds or multipliers in this document
are implementation approval. Each milestone needs a tuning sheet signed off by
Sam.

### Active versus passive target

Active and passive play have different jobs rather than competing rates. Manual
chopping advances the unknown: Axeman XP, species discovery, mastery and
certification. Automation exploits the known: commodity volume, cash and project
materials. Balance should be evaluated on **time from first encounter to
automation** and **time from automation to the next meaningful purchase**, not
on forcing hand work to beat a production line. Once a species is solved, its
machine should make returning to manual commodity grinding economically
unnecessary.

### RNG fairness

- Keep the current forced-roll test seam.
- Every required split has a bounded path to success through scars/pity.
- Skill procs use a test seam and bounded dry streaks; a proc-focused build must
  not silently fail to express itself for an unreasonable session.
- Random bonus cuts cannot ruin required precision work or create invalid
  geometry.
- Rare discoveries may surprise but never gate the only route forward.
- Expedition outcome bands are shown before launch.
- A failed expedition returns useful survey information or common cargo; it is
  a setback in efficiency, not erased hours.

## UI and information architecture

### Early yard

Keep the permanent HUD minimal: cash, current contextual goal and an affordable
shop cue. Lifetime totals remain in records/office screens.

### Career era

Unfold tabs/panels only when earned:

- Orders
- Shop/equipment
- Skills/mastery
- Records

### Company era

Add:

- Staff/logistics
- Region map
- Capacity/bottleneck breakdown

### Planet/space era

Add:

- Earth dashboard
- Global projects
- Mission Control
- Expedition planning
- Specimen catalogue

The home yard is the navigational anchor. Avoid a permanent top bar with a dozen
currencies. Contextual screens can show the number they own.

### Accessibility and comfort

- Hold-to-swing or repeated-input alternatives must never require frantic
  clicking.
- Clear high-contrast grain/scar cues independent of bark colour.
- Reduced camera shake/hit-pause settings without changing economic outcome.
- Optional reduced fragment motion.
- Number-format choice and full-value tooltip.
- Autosave around purchases, contract completion, region completion and mission
  launch/return.
- Offline ledger and event history so nothing important is missed.

## Audio/visual escalation

### Grounded opening

Birds, axe leather/metal/wood layers, nearby vehicle sounds, hand-painted yard
props and modest UI.

### Growing company

Forklifts, trucks, saws in the distance, radios, rail horns and a busier horizon.
The chopping impact remains the loudest, cleanest foreground sound.

### Global era

Map lights, radio dispatch, huge distant machinery and a skyline crowded with
infrastructure. The original stump remains visible as a deliberate relic.

### Space era

Mission-control electronics, launch rumble and near-silence in the orbital rig.
Alien cuts have species-specific audio rules. The familiar axe impact motif
survives inside every new sound so the player hears the lineage.

## Content cadence

Each major release slice should contain a balanced packet:

- one new strategic system;
- one new visible yard transformation;
- one new chopping sensation/species/tool;
- one new medium-term goal/customer/project;
- one piece of permanent celebration (record, cosmetic, trophy or map change).

Do not release a system-only update containing ten panels and no new thing to
touch or see.

## Testing and analytics requirements

### Automated acceptance

- Economy transactions remain atomic.
- No unpriced item auto-sells.
- Contract routing cannot double-sell or lose a piece.
- Rough pieces always retain base value.
- Reputation and mastery never decrease.
- Supplier standing and hand-chopped mastery cannot contaminate one another.
- Hand-chopped and auto-cut totals remain distinct while both contribute to
  total timber processed.
- Auto-cutters refuse unknown, uncertified, rare and signature-only logs.
- Auto-cut output cannot earn mastery, perfect-log records or handcrafted-order
  credit or Axeman XP.
- Double/triple/quadruple strikes perform the announced number of valid slice
  operations and stop when no valid continuation remains.
- XP procs award once per completed manual log and cannot recursively multiply
  themselves.
- Delivered-log consumption and commodity output are atomic; a blocked output
  cannot destroy input.
- Catalogue and contract progress never exceeds authored bounds.
- Passive progress cannot complete a first-time species mastery or final Earth
  showcase.
- Offline simulation is deterministic from saved inputs and respects its cap.
- Expedition cargo and project payments are atomic.
- New species preserve slicer materials/tangents/winding and respect physics
  budgets.

### Visual acceptance

- Every yard tier gets before/after shots from the real main scene.
- Every species gets fresh/cut/scarred/perfect reference shots.
- Staff and vehicles are checked in motion, not only counted in the tree.
- Region completion and the final terrestrial-species showcase cannot be
  approved headless-only.
- Alien traits need recorded visual checks for readability.

### Playtest telemetry (local development, not invasive analytics by default)

- Time to first successful split, first purchase and first order.
- Swings and failures per species/size.
- Cash source/sink breakdown.
- Time spent with no affordable/meaningful action.
- Upgrade purchase order and unused options.
- Active versus passive time to the next milestone.
- Regions where supplier standing, delivery or yard queues are misunderstood.
- Manual logs required to understand/certify each species and whether that power
  phase stays exciting rather than becoming a grind.
- Time from first encounter to certification, machine purchase and decisive
  automated replacement.
- Auto-cut share of total volume, including whether each solved species leaves
  manual commodity production at the intended point.
- Whether players notice the haul threshold, Momentum and current contract.

The purpose is to find dead zones and unreadable systems, not to optimise
compulsion.

## Anti-patterns — features to refuse

- A generic auto-chopper that produces the same premium output as the player.
- Daily streaks, energy systems, ads, loot boxes or fear-of-missing-out events.
- More currencies as a substitute for new mechanics.
- Resetting the Earth catalogue and forcing mastered woods to be repeated.
- An alien log that is only “same wood, 1,000× price.”
- Equipment with ten tiny stats and no felt difference.
- Mandatory consumable maintenance, hunger or worker-needs simulation.
- Any tree-felling, forest-depletion, harvesting or exploration layer competing
  with the chopping block.
- Timed contracts as the default loop.
- Random rare drops required for story progress.
- Offline progress that completes the final Earth species or a first-time story
  event.
- Background progress that discovers, masters or certifies an unknown species
  before the player has personally worked it at the block.
- A joke-first opening that spoils the earned shift from cozy yard to cosmic
  timber.

## Creative Director tuning calls by milestone

The following must be presented to Sam before implementation of their milestone.

### M7B

- Exact three introductory orders, requirements and payouts.
- Reputation gains and unlock thresholds.
- Craft grade definitions and reward effects.
- Order choice/refresh behaviour.

### M7C

- Rank milestones and skill-point cadence.
- Initial skill nodes, magnitude and respec rule.
- Mastery thresholds and perfect-log criteria.
- Axe sidegrade and block-upgrade behaviours/costs.

### M8

- Staff hiring and upgrade costs.
- Task rates/capacities.
- Momentum duration/effect.
- Offline progress approval, rate and cap.

### M9–M11

- Region list, species catalogue and supplier progression.
- Delivery, queue and supplier-standing curves.
- Transport rules and capacity costs.
- First auto-cutter timing, certification scope, input capacity, output rate,
  commodity value and optional Momentum interaction.
- Definition of the trillion-scale unit: literal logs, timber mass, shipments
  or source-tree equivalents; clarify Sam's `4 × 3.04 trillion` target before it
  becomes saved data or a completion threshold.
- Earth campaign target duration.
- Tone and presentation of the final terrestrial-species showcase.

### M12–M14

- Launch-project costs and sequence.
- Expedition duration/outcome rules.
- First destination and alien species.
- Alien-species certification and orbital auto-cutting rules.
- Expedition charter choices.
- Scope of the authored space campaign versus postgame procedural content.

## Recommended production priority

### Must prove first

1. Orders make chopping more purposeful without harming free play.
2. Craft geometry is readable and fair.
3. Skills create genuinely different hand-feel/build choices.
4. A visible yard upgrade is more motivating than another multiplier.
5. First automation makes mastering a wood by hand feel like the path out of its
   manual power phase.

### Then prove scale

6. A supplier region can be completed through clear discovery, delivery,
   chopping, contracts and mastery.
7. Multiple regions remain understandable.
8. Visible auto-cutters decisively replace manual commodity output for certified
   species while the next unknown wood still requires the chopping block.
9. Trillion-scale progression stays readable and achievable without an idle
   wall.
10. The final terrestrial species lands as an emotional/mechanical climax.

### Only then build space

11. Launch projects reuse existing systems.
12. The first alien log changes chopping in a legible way.
13. Expedition charters provide replay variety without erasing the player's
    history.

## The promise

At the beginning, the player sees a log on a stump.

At the midpoint, they see a world atlas filling with supplier routes, mastered
species and signature contracts because of a company built around that stump.

At the Earth finale, the world's final unmastered species arrives and is split
by hand.

Then a launch vehicle rises behind the same yard, crosses the sky, and returns
with a piece of wood that should not exist.

The player puts it on the stump and swings.

That is The Axeman.
