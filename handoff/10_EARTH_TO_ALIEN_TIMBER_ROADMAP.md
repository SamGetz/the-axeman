# The Axeman — Earth to Alien Timber Master Roadmap

**Status:** Creative Director direction, 2026-08-01; extensive design roadmap,
not an implementation order. This extends the cozy-lumberyard direction into a
finite Earth campaign and a spacefaring postgame. The existing module sign-off
rule, frozen Part A contracts, Godot 4.7 Compatibility constraints and Sam's
ownership of final tuning values all remain in force.

**One-line pitch:** Start with one axe, one log and one coin; build the company
that fells every tree on Earth; then spend the world's timber fortune launching
expeditions to bring back impossible logs from space.

## Executive decision

The perfect escalation for this game is not “add another shop with a larger
multiplier.” It is a sequence of revelations in which the same satisfying axe
swing takes on a larger meaning:

1. A swing earns a coin.
2. A good swing completes an order.
3. A session grows a lumberyard.
4. A lumberyard becomes a regional company.
5. A company builds a global felling network.
6. The last tree on Earth becomes a handcrafted finale.
7. The empty planet becomes the launchpad for an alien-timber age.

The player should spend the opening hours believing this is a warm, tactile
firewood game. The scale then widens one layer at a time until the cozy yard is
somehow the headquarters of an interstellar logging concern. The absurdity is
earned because every new system grows from a tool, person, customer or problem
the player already understands.

The Earth campaign should have a real ending: **Trees remaining: 0**. Space is
not a reset that undoes it. It is the consequence and reward.

## North star

### The fantasy

“I did this with my own two hands” must survive even after millions of workers
and machines exist. The business can become enormous, but the player is always
the Axeman: the person who understands a piece of wood by looking at its grain
and splitting it better than any machine.

### The emotional curve

| Era | Player feeling | What changes |
|---|---|---|
| Stump | “That cut felt good.” | The axe, log and payout become legible. |
| Yard | “This place is mine.” | Orders, tools, skills and visible upgrades arrive. |
| Company | “I built a machine around my craft.” | Staff and logistics remove friction. |
| Nation | “The map is yielding.” | Regions become finite progress bars and suppliers. |
| Planet | “We are actually going to finish this.” | Global operations and absurd machinery dominate. |
| Last Tree | “I have to make this final cut myself.” | Automation stops for a handcrafted finale. |
| Orbit | “The yard was only the beginning.” | Launch projects and expeditions unfold. |
| Alien timber | “What even counts as wood now?” | Exotic log behaviours reinvent chopping. |

### Non-negotiable pillars

1. **The chopping game remains the best active play.** Automation can own
   supply, transport, bulk felling and ordinary processing. Manual chopping
   owns mastery, rare specimens, signature work and the strongest temporary
   company boost.
2. **Every era visibly changes the yard.** A number is never the only proof of a
   major upgrade. Buildings, traffic, piles, machinery, skyline and eventually
   spacecraft make growth physical.
3. **Progression unfolds.** Do not show a planetary map, skill constellation,
   launchpad and five currencies in hour one. Each layer appears only when the
   preceding loop has become comfortable.
4. **Earth is finite.** Regions have authored totals and clear permanently.
   There is no “prestige and magically regrow the same forest” before the Earth
   ending.
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
- Pine, oak and birch as working species, with multiple birch shapes and
  species-specific value, cut materials and splitting difficulty.
- A swing roll with a maximum chance below certainty, visible failed-hit scars,
  scar weakening, size relief and forced-roll test seams.
- A real swing cooldown and two upgrade effects: Coffee shortens recovery and a
  Protein Bar improves split chance.
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
- No meaningful wood-selection/supply screen.
- No player skill tree, species mastery or equipment loadout.
- No yard expansion beyond the current pile and shop panel.
- No staff, routes, passive logistics or offline outcome.
- No regional, national or planetary progression.
- No finite tree population, “last tree” finale or world completion.
- No industrial projects, launch economy, expeditions or alien logs.
- No long-horizon goal presentation beyond earning the next amount of cash.

### Important technical interpretation

The new “fell every tree on the planet” direction does **not** require restoring
the deleted M5 FPS forest game. Planetary felling belongs to an abstract,
data-driven operations map. Regions provide log species, contracts and a finite
tree count; staff and industrial projects reduce that count. Selected logs are
delivered to the existing chopping block for the premium manual loop.

This preserves the pivot, avoids rebuilding an entire second action game, and
lets the fantasy reach planetary scale without pretending the player personally
walks to billions of tree meshes.

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
| [Mr. Mine](https://store.steampowered.com/app/1397920/MrMine/) | A physical depth axis, workers, drill upgrades, buildings, relics, secrets and feature unlocks tied to progress. | “Trees remaining” should be spatial and visible like depth: every region is a finite body the player measurably consumes. Discoveries punctuate the count. | Random treasure as a mandatory progression gate. |
| [Rusty's Retirement](https://store.steampowered.com/app/2666510/Rusty%27s_Retirement/) | A cozy visible workplace, automation helpers and a focus mode that respects attention. | Staff should be charming, visible and easy to understand. The game should be pleasant to watch without demanding constant check-ins. | Becoming so passive that active chopping has no reason to exist. |
| [Cell to Singularity](https://store.steampowered.com/app/977400/) | A clear thematic journey that expands from microscopic beginnings to civilization, speculative technology, Mars and space. | Use scale itself as story. A tech/project tree can make the path from hand axe to launch vehicle feel coherent. | A generic “tap anywhere for abstract energy” interaction. |
| [Clicker Heroes](https://store.steampowered.com/app/363970/Clicker_Heroes/) | Active clicks, recruitable producers, skills, critical hits, idle growth, absurd numbers and ascension. | Named staff with clear specialties can make passive production personable. Critical/manual moments should remain satisfying beside idle growth. | Endless zones that differ only in health and number size. |
| [Dwarf Eats Mountain](https://store.steampowered.com/app/4078200/Dwarf_Eats_Mountain/) | Visible destruction, mining/hauling tension, many specialised units, active buffs, artefacts and build synergies. | Separate extraction from hauling so transport capacity matters, and make global deforestation visually react to the operation. | A failure spiral where output is lost because support capacity was misjudged. |

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
Choose a goal
    ↓
Receive a log from the current supply region
    ↓
Read grain, aim and split it by hand
    ↓
Earn cash + mastery + active company momentum
    ↓
Complete an order or feed the unlimited buyer
    ↓
Buy equipment, skills, staff, routes or projects
    ↓
See the yard and the regional/planetary operation grow
    ↓
Unlock a new species, customer, region or technology
    ↺
```

At company scale, a passive loop runs beside it:

```text
Felling crews reduce finite regional tree totals
    ↓
Haulers move bulk timber through unlocked routes
    ↓
Industrial buyers create cash and project materials
    ↓
The player directs reinvestment and resolves bottlenecks
```

The loops meet in both directions. Company infrastructure brings better logs to
the block. Manual chopping creates mastery, fulfils premium work and activates
**Axeman's Momentum**, a temporary company-wide productivity state. The exact
duration and magnitude are tuning values, but the rule is structural: active
play makes the entire empire work better; passive play never invalidates active
play.

## Progression economy — few currencies, many meaningful counters

### Spendable values

1. **Cash** — the universal business currency from stump through space. It buys
   equipment, wages, buildings, routes, industrial projects and expeditions.
2. **Skill points** — earned only at authored Axeman Rank milestones and spent
   in the player skill tree. They represent knowledge, not another income rate.
   Respeccing, if allowed, should be forgiving.

Do not add separate “yard coins,” “regional tokens,” “rocket bucks,” “prestige
shards” or a currency per wood species. Space projects can require cash plus
physical project materials. Those are items and requirements, not parallel
money systems.

### Unlock/progress values

- **Reputation:** permanent, non-spendable career rank progress. Unlocks
  customers, suppliers, permits and company scale.
- **Lifetime hand-chopped:** permanent celebration and skill-point milestone
  input. Keep it a background stat until a milestone makes it relevant.
- **Species mastery:** per-species experience from manual chopping. Unlocks
  knowledge and techniques for that wood, not generic cash bonuses alone.
- **Trees remaining:** finite count per region and planet. Never spendable,
  never reset on Earth.
- **Company trees felled:** lifetime company total, separate from hand-chopped
  so staff never steal credit from the player's craftsmanship statistic.
- **Expedition readiness:** a project checklist/bar, not a banked currency.
- **Collection records:** best perfect-log streak, hardest wood split, fastest
  order, alien specimens catalogued and other achievement statistics.

### Large-number philosophy

Early numbers should remain human: single coins, individual pieces, one truck.
Abbreviations appear only when the fantasy genuinely reaches industrial scale.
The interface should preserve exact values in tooltips/history while presenting
compact values on the main HUD. Scientific notation belongs only in the far
cosmic postgame, where its arrival is itself a joke.

## How manual chopping remains valuable forever

Automation is necessary to fell a planet, but it must automate scale rather
than replace the player.

### Manual-only rewards

- **Species mastery:** machines cannot earn it.
- **Craft quality:** even size, accurate cuts, low scar count and efficient log
  completion improve premium contract value.
- **Signature orders:** named customers require hand-split pieces.
- **Specimen processing:** rare Earth and alien logs must be understood at the
  block before they can enter industrial supply.
- **Discovery cuts:** the first manual splits reveal unusual grain traits,
  research clues or build-defining materials.
- **Perfect-log milestones:** permanent achievements and skill progress.
- **Axeman's Momentum:** manual success temporarily accelerates the surrounding
  operation. Better craftsmanship builds the state faster or raises its tier.

### Automation-only strengths

- Reducing regional tree counts at a meaningful planetary rate.
- Moving, stacking, bundling and shipping ordinary output.
- Operating solved production chains while the player is away, if offline
  progress is approved.
- Providing reliable baseline income and project materials.

### The value rule

Automated bulk output should dominate **total volume** late in the game. Manual
work should dominate **value per log, progression information, mastery and
active leverage**. Pretending one person can physically outproduce a planetary
industry would make the scale feel fake; making their expertise the multiplier
on that industry makes the player feel essential.

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

Skill points arrive at authored Axeman Rank milestones. A node should unlock a
new behaviour, decision or visible affordance whenever possible. Repeated stat
nodes can fill gaps, but cannot be the whole tree.

### Branch A — Axecraft

| Skill concept | Gameplay effect |
|---|---|
| Comfortable Grip | Slightly shortens the real swing recovery; the existing Coffee effect remains a temporary/stackable route, not a replacement. |
| Grain Reader | Reveals a subtle weak-grain band on the current piece after observing it briefly. |
| Follow Through | Clean splits contribute more Momentum. |
| Patient Hands | A deliberately held aim widens the craftsmanship sweet spot without increasing raw split chance. |
| Scar Tissue | Existing scars weaken the piece more effectively. |
| Controlled Failure | Failed strikes place their scar closer to the aimed plane, making the next attempt more predictable. |
| Kindling Technique | Small-piece orders become easier to grade consistently. |
| Timber Technique | Large/hard species lose less maximum chance to difficulty. Never grants certainty. |
| Perfect Log | Unlocks perfect-log grading, milestone tracking and signature orders. |
| Axeman's Flow | At maximum Rhythm, the next successful split creates a distinctive camera/audio event and a larger Momentum contribution. |

### Branch B — Yardcraft

| Skill concept | Gameplay effect |
|---|---|
| Fast Reset | The next log arrives/settles sooner after a completed load. |
| Block Sense | Better default log orientation and clearer cut readability. |
| Sure Landing | Pieces take a cleaner flight to the pile without removing the animation. |
| Load Caller | Warns clearly when the next pieces will trigger haul-away. |
| Species Rack | Allows a small queue of chosen incoming species. |
| Order Crates | Automatically routes matching hand-split pieces to the active contract. |
| Clean Bench | Reduces visual clutter after very high piece counts. |
| Workshop Eye | Highlights which affordable equipment would change the current bottleneck. |

### Branch C — Enterprise

| Skill concept | Gameplay effect |
|---|---|
| Regular Customer | Adds another order choice, not another forced obligation. |
| Honest Estimate | Shows expected contract value before committing. |
| Material Sense | Reveals region/species traits before buying the supply permit. |
| Crew Briefing | Manual Momentum spreads to one additional company system. |
| Route Planner | Makes transport bottlenecks visible and allows a saved route priority. |
| Bulk Negotiator | Improves ordinary industrial contracts, not signature handwork. |
| Reputation | Adds a small reputation bonus for first-time order categories. |
| Trusted Name | Unlocks prestige customers and the planetary boardroom tier. |

### Branch D — Frontier (hidden until the launch programme)

| Skill concept | Gameplay effect |
|---|---|
| Zero-G Stance | Reduces alien-log drift in the orbital chopping rig. |
| Xenograin | Reveals the first trait of an unknown alien species sooner. |
| Quarantine Eye | Identifies dangerous spores/resin before a cut. |
| Cargo Instinct | Improves the chance that a mission returns an intact rare specimen. |
| Vacuum Rhythm | Maintains more Rhythm between unusually slow alien-log reactions. |
| Field Certification | After hand-mastering a species, remote crews may harvest it safely. |

No final node counts, point costs or magnitudes are approved here. The tree
should have meaningful forks and allow different early identities: fast rhythm,
precise craft, hard-wood specialist or business builder.

## Equipment, items and productivity tools

The shop should evolve from two percentage rows into a physical catalogue. Each
purchase needs a yard prop, axe change, character prop, new animation, new UI
capability or clearly felt rule change.

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
- Global Timber Board — planetary targets and huge project contracts.
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

### Field staff

- Survey crews reveal region size, traits and discoveries.
- Felling crews reduce the finite tree count.
- Skidder teams move felled timber from forest to depot.
- Truck, rail and ship crews move timber between regional nodes.
- Camp managers support larger crew capacity.
- Safety officers reduce adverse events/downtime rather than introducing worker
  death or a punitive morale simulation.

### Space staff

- Mission planner reveals travel time, cargo risk and return profile.
- Launch crew reduces turnaround.
- Xenobotanist identifies new species traits.
- Quarantine officer prevents reactive logs disrupting the yard.
- Remote foreman operates established alien outposts.

### Offline progress recommendation

Do not implement offline progress until M8 logistics is fun while watched.
When approved, offline time should advance only systems the player has actually
automated. On return, present a concise ledger: trees felled, timber hauled,
cash earned, contracts completed, incidents and capped/blocked systems. Never
hide a bottleneck behind “welcome back” confetti.

The offline cap, rate and whether Momentum can persist are final tuning calls
for Sam.

## The Earth operations map

The operations map is the bridge from cozy yard to planetary scale.

### Region data

Each region is an authored resource containing:

- display name and visual card/map treatment;
- finite tree count;
- species distribution;
- one signature log shape/specimen;
- terrain/transport modifier;
- customer and contract set;
- discoveries and project unlocks;
- required reputation/permit project;
- completion reward and permanent visual consequence.

Exact region count and tree totals are tuning/content calls. Use enough regions
for distinct acts, not dozens of palette swaps.

### Region loop

1. Survey the region.
2. Manually chop its first delivered specimen.
3. Learn its species trait and unlock basic contracts.
4. Fund a camp and first felling crew.
5. Solve the extraction/haul bottleneck with roads, rail or port.
6. Build Momentum at the block while crews reduce the tree count.
7. Discover a landmark contract or rare specimen at milestones.
8. Clear the final stand and receive a permanent trophy/project unlock.

### Visual consequence

The map should physically change from forested to cleared. Newspaper boards,
customer dialogue and yard props can acknowledge the increasingly absurd scale.
The game need not moralise or punish, but it should not act as if removing every
tree is visually neutral. The tonal turn—from cozy trade to cheerful corporate
ecocide—is part of the comedy.

### Planetary dashboard

When several regions exist, unfold a simple top-level dashboard:

- Earth trees remaining.
- Current trees felled per second/minute by the company.
- Extraction and transport capacity.
- Active regional bottleneck.
- Current manual Momentum state.
- Next planetary milestone/project.

This is the point where a rate becomes useful. Do not show trees-per-second on
the opening yard screen.

## The launch programme

Space should be built out of terrestrial success, not unlocked by an arbitrary
prestige button.

### Project chain

1. Global Survey Network — proves Earth is nearly exhausted and reveals the
   final stands.
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
- Survey intensity versus harvest capacity.
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
erase the visible yard, undermine the finite-tree promise and force replay of
content instead of delivering the next revelation.

Use two softer structures instead:

1. **Regional starts:** a new region begins with no local camp/route capacity,
   but all character skills, equipment and home-yard progress remain. This
   creates the acceleration pleasure of prestige without deleting history.
2. **Planetary charters:** each alien world is a new finite operation. The
   player chooses a charter/doctrine that shapes the outpost, while retaining
   Earth, skills, mastered species and spacecraft technology.

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

**Exit test:** A new player can chop freely or pursue an introductory order,
understand a failed hit, earn money, buy a felt upgrade, unlock another wood,
see a haul-away and save/return without explanation.

### M7B — craftsmanship, customers and reputation

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

### M7C — Axeman career and species mastery

**Goal:** Make the player's hands progress, not only the business.

**Features:**

- Axeman Rank milestones and skill points.
- Initial Axecraft/Yardcraft/Enterprise branches.
- Species mastery for the live woods.
- Grain-reading feedback and perfect-log tracking.
- First axe sidegrade and first block upgrade.
- Equipment loadout with plain comparison text.
- Achievements/milestones that unlock cosmetics, not raw clutter.
- Temporary consumables expanded beyond Coffee/Protein Bar only if they create
  distinct session choices.

**Exit test:** Two players can spend the same early skill points differently and
feel the distinction at the block.

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

### M8 — staff and logistics

**Goal:** Automate downtime and build the first passive company loop.

**Features:**

- Log Driver, Yard Hand, Stacker, Order Clerk, Mechanic and Dispatcher in an
  authored introduction order.
- Clear task/capacity model and visible activity.
- Log queues and route priority.
- Delivery, stacking, order fulfilment and haul-away improvements.
- Staff upgrades that change equipment/behaviour, not a needs or morale sim.
- Axeman's Momentum links manual craft to staff productivity.
- Offline progress only after the watched loop is approved.
- Return ledger and safe offline cap if approved.

**Exit test:** Leaving and returning produces understandable value, while an
active five-minute chopping session is still the best way to accelerate the
next business goal.

### M9 — regional supply network

**Goal:** Reveal that the yard is part of a finite world operation.

**Features:**

- First operations map with a small authored set of regions.
- Survey, permit, camp, crew, extraction and transport steps.
- Region-specific species, customers, traits and visual completion.
- Separate lifetime hand-chopped and company-felled counts.
- First bulk felling crews and industrial buyers.
- First map discoveries and infrastructure projects.
- Regional starts function as soft prestige without deleting the home yard.

**Exit test:** The player can explain why a region is slow—felling, extraction
or transport—and can fix it with a meaningful purchase or manual Momentum.

### M10 — national and continental company

**Goal:** Move from several regions to an economy of routes and specialisation.

**Features:**

- Railheads, ports and bulk routes.
- Multiple simultaneous regions with limited dispatcher capacity.
- Company doctrines/builds: craftsmanship-first, logistics-first or heavy
  industry, with respec/adjustment that does not brick a save.
- Cedar/eucalyptus/mahogany-tier species candidates and harder signature work.
- Large infrastructure contracts and government customers.
- Industrial equipment that processes common timber while the player handles
  premium specimens.
- Visible yard transition from depot to headquarters.

**Exit test:** Two viable companies can reach the same milestone through
different bottleneck solutions, and older equipment/species still has a role.

### M11 — global deforestation campaign

**Goal:** Make “fell every tree on Earth” the explicit primary objective.

**Features:**

- Full Earth trees-remaining dashboard.
- Continental operations, shipping lanes and global project board.
- Late-Earth redwood/ironwood-scale mastery challenges.
- Enormous but visually readable machinery and throughput.
- Global news/headlines that let the cozy premise turn into restrained dark
  comedy.
- Milestone discoveries at authored percentages of Earth completion.
- Launch-programme foreshadowing begins well before Earth reaches zero.
- Anti-stall systems: always identify the limiting region and allow meaningful
  action.

**Exit test:** Earth completion is mathematically achievable without unattended
years, but long enough to make the final approach feel momentous. The last
region cannot disappear unnoticed while the player is offline.

### M11B — the Last Tree finale

**Goal:** Deliver the finite ending promised from the map's reveal.

**Sequence:**

1. Automation halts before the last authored stand.
2. The world map, yard staff and customers acknowledge the moment.
3. A final extraordinary Earth log is delivered to the original block.
4. The player completes a multi-stage hand-crafted split using the skills they
   developed across the campaign.
5. Failed hits scar and weaken as usual; the finale is never hard-failed.
6. The last split takes Earth trees remaining to zero.
7. The haul-away becomes a unique global celebration.
8. The final cross-section is mounted in the yard/Mission Control.
9. The launch programme becomes the new headline goal.

This does not restore tree-felling traversal. It turns the last tree into the
ultimate delivered log and the ultimate version of the game's actual mechanic.

**Exit test:** The Earth campaign has credits/closure and the save remains
playable. The player cannot accidentally miss the final tree because passive
progress crossed zero.

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
- Specimen mastery unlocks safe remote harvesting.
- Orbital/specimen chopping rig evolves from the familiar stump.
- Alien wood creates a new premium order family and one spacecraft upgrade.

**Exit test:** The first alien log is mechanically surprising, visually clear
and still recognisably The Axeman.

### M14 — interplanetary timber company

**Goal:** Turn expeditions into a repeatable finite-planet meta-loop.

**Features:**

- Several authored planets/moons with distinct wood ecologies.
- Planetary charters as soft prestige/build choice.
- Survey → specimen → certification → outpost → finite harvest loop.
- Cargo fleets, range, shielding and remote foremen.
- Alien customers/materials and cross-species projects.
- Gravitic tools and Frontier mastery.
- Earth remains visible as the headquarters and completed first campaign.

**Exit test:** Each destination changes strategy and chopping behaviour; none is
merely a larger tree counter.

### Postgame — the observable forest

**Goal:** Provide endless aspiration only after the authored campaign is
complete.

Candidates:

- Procedurally assembled but trait-bounded star systems.
- Rare authored cosmic trees between procedural planets.
- Company doctrines/challenges that alter rules without deleting history.
- A final counter for trees remaining in the known universe.
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

### Heavy timber concern

- Felling crews, machines, hard-species gear and major projects.
- Best raw regional depletion and infrastructure progress.
- Synergy: manual specimen certification unlocks each new industrial target.

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

Every era needs activity on all three clocks. A planetary counter moving does
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

Measure active value as more than cash. A chopping session produces immediate
cash, contract progress, mastery and Momentum; passive operations produce bulk
cash/materials and reduce tree totals. Balance should be evaluated on **time to
next meaningful decision** with and without active play, not only coins per
second.

### RNG fairness

- Keep the current forced-roll test seam.
- Every required split has a bounded path to success through scars/pity.
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

### Planetary era

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
- Hand-chopped and company-felled totals cannot contaminate one another.
- Region and planet counts never go below zero.
- Passive progress halts before the authored Last Tree.
- Offline simulation is deterministic from saved inputs and respects its cap.
- Expedition cargo and project payments are atomic.
- New species preserve slicer materials/tangents/winding and respect physics
  budgets.

### Visual acceptance

- Every yard tier gets before/after shots from the real main scene.
- Every species gets fresh/cut/scarred/perfect reference shots.
- Staff and vehicles are checked in motion, not only counted in the tree.
- Region completion and Last Tree cannot be approved headless-only.
- Alien traits need recorded visual checks for readability.

### Playtest telemetry (local development, not invasive analytics by default)

- Time to first successful split, first purchase and first order.
- Swings and failures per species/size.
- Cash source/sink breakdown.
- Time spent with no affordable/meaningful action.
- Upgrade purchase order and unused options.
- Active versus passive time to the next milestone.
- Regions where extraction or transport is misunderstood.
- How often players return to manual chopping after automation unlocks.
- Whether players notice the haul threshold, Momentum and current contract.

The purpose is to find dead zones and unreadable systems, not to optimise
compulsion.

## Anti-patterns — features to refuse

- A generic auto-chopper that produces the same premium output as the player.
- Daily streaks, energy systems, ads, loot boxes or fear-of-missing-out events.
- More currencies as a substitute for new mechanics.
- Resetting Earth before the player fells it.
- A planet that is only “same trees, 1,000× health.”
- Equipment with ten tiny stats and no felt difference.
- Mandatory consumable maintenance, hunger or worker-needs simulation.
- A second full FPS exploration/felling game competing with the chopping block.
- Timed contracts as the default loop.
- Random rare drops required for story progress.
- Offline progress that completes the Last Tree or a first-time story event.
- Background rates so strong that returning to the block is economically silly.
- A joke-first opening that spoils the earned shift from cozy yard to cosmic
  deforestation.

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

- Region list, tree totals and species distribution.
- Company-felling rate curve.
- Transport rules and capacity costs.
- Earth campaign target duration.
- Tone of the deforestation comedy and Last Tree presentation.

### M12–M14

- Launch-project costs and sequence.
- Expedition duration/outcome rules.
- First destination and alien species.
- Planetary charter choices.
- Scope of the authored space campaign versus postgame procedural content.

## Recommended production priority

### Must prove first

1. Orders make chopping more purposeful without harming free play.
2. Craft geometry is readable and fair.
3. Skills create genuinely different hand-feel/build choices.
4. A visible yard upgrade is more motivating than another multiplier.
5. Staff automation makes returning to manual chopping *more* valuable.

### Then prove scale

6. A finite region can be consumed through a clear felling/extraction/transport
   model.
7. Multiple regions remain understandable.
8. Earth completion can create anticipation without an idle wall.
9. The Last Tree lands as an emotional/mechanical climax.

### Only then build space

10. Launch projects reuse existing systems.
11. The first alien log changes chopping in a legible way.
12. Planetary charters provide replay variety without erasing the player's
    history.

## The promise

At the beginning, the player sees a log on a stump.

At the midpoint, they see a world map whose forests are visibly disappearing
because of a company they built around that stump.

At the Earth finale, every machine waits while the last delivered log is split
by hand.

Then a launch vehicle rises behind the same yard, crosses the sky, and returns
with a piece of wood that should not exist.

The player puts it on the stump and swings.

That is The Axeman.
