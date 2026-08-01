# The Axeman — Cozy Lumberyard Roadmap

**Status:** Creative Director-approved direction, 2026-08-01. This replaces the
pre-pivot M6–M8 module plan. It is a roadmap, not permission to skip the normal
module-by-module sign-off or to invent final tuning values.

**Expanded direction:** This grounded roadmap remains the foundation, but its
long horizon is now extended by
[`10_EARTH_TO_ALIEN_TIMBER_ROADMAP.md`](10_EARTH_TO_ALIEN_TIMBER_ROADMAP.md):
the yard grows into a global log-chopping company, masters every terrestrial
wood, then launches expeditions for alien logs. Regions are suppliers only;
there is no standing-tree, forest-depletion or felling layer of any kind.

## North star

Build a cozy “number go up” game about growing the world’s greatest firewood
business. The tactile M4 chopping is the source of value and the star of the
game: choose work, chop logs by hand, turn the pieces into useful stock, fulfil
orders, improve the yard, then take on better wood and more prestigious work.

The player should feel two kinds of progress at once:

- **Numbers grow:** stock, cash, reputation and lifetime wood chopped.
- **The place grows:** the woodpile, equipment and lumberyard visibly improve.

Cozy lumberyard comes first. A restrained streak of absurd incremental
escalation may arrive much later, after the grounded fantasy is established.

## Non-negotiable design pillars

1. **Chopping remains central forever.** The game must not automate away its
   best interaction. Manual chopping remains the highest-value active play.
2. **Skill helps; imperfection never blocks progress.** Clean, intentional cuts
   can earn bonuses, but awkward chunks remain sellable and useful.
3. **Upgrades should be felt or seen.** Prefer a new axe behaviour, log supply,
   block, yard space or customer over a screen full of invisible percentages.
4. **Keep the economy readable.** Do not create a collection of overlapping
   currencies just to manufacture progression.
5. **Orders guide rather than grant permission.** There is always a basic,
   unlimited buyer so the player can relax and chop freely.
6. **Automation handles the work around chopping.** Staff and machines remove
   downtime and logistics friction; they do not out-chop the player.

## Core loop

```text
Choose an order or chop freely
        ↓
Chop logs by hand
        ↓
Create firewood with measurable species, size and quality
        ↓
Fill an order or sell to the basic buyer
        ↓
Earn cash and reputation; grow stock and lifetime totals
        ↓
Improve axe, block, supply, yard, transport or workshop
        ↓
Unlock more valuable woods, customers and contracts
        ↺
```

## Progression spine

Use four clear values:

- **Cash:** the primary spendable value for upgrades.
- **Firewood stock:** the literal inventory of produced wood, reflected by a
  visible pile wherever practical.
- **Reputation:** unlocks customers, contracts, wood supplies and regions.
- **Lifetime wood chopped:** a permanent celebratory number with milestone
  rewards; it never decreases.

Inventory writes remain inside `InventoryManager`; progression writes remain
inside `GameState`. Any new contract required to represent these values must go
through the existing amendment/sign-off process before implementation.

## Craftsmanship and cut quality

The runtime slicer should matter economically, not merely count clicks. M7B may
build a forgiving craftsmanship layer around these approved behaviours:

- Clean, evenly sized pieces earn a value bonus.
- Central or accurate cuts can build a short craftsmanship streak/multiplier.
- Efficiently finishing a whole log can award a perfect-log bonus.
- Orders can request piece sizes such as kindling, stove wood or campfire wood.
- Species-specific orders create reasons to unlock and select different logs.
- Awkward and imperfect pieces always retain a base sale value.

“Quality” needs an explicit, testable definition derived from slice geometry
before code is written. Thresholds, multiplier values, combo windows and the
exact requested size bands are Creative Director tuning calls, not defaults to
invent in code.

## Customers and orders

The always-available basic buyer purchases any valid firewood at its base value.
Authored orders add direction and bonuses. Customer families may include:

- **Campsite:** many inexpensive pieces with loose size requirements.
- **Homeowner:** consistently sized stove wood.
- **Smokehouse:** a requested wood species.
- **Festival:** a large bulk contract, optionally time-limited later.
- **Artisan:** a small quantity of very high-quality pieces.
- **Winter contract:** an escalating multi-stage order with a major payoff.

Timed work is optional special content, never the default pressure. The basic
loop must remain playable at the player’s own pace.

## Upgrade families

- **Axes:** materially change strike feel, valid-cut forgiveness, clean-cut
  rewards or suitability for different woods.
- **Chopping block:** improves usable space, log placement and piece control.
- **Log supply:** unlocks larger logs, rarer species and more valuable timber.
- **Yard:** increases storage and visibly expands the working space and piles.
- **Transport:** unlocks bigger contracts and bulk sales.
- **Workshop:** later converts selected stock into secondary products such as
  bundles, charcoal or boards. This is post-core-loop scope; board species and
  new item IDs still require their existing explicit design decision.

Percentage bonuses may support these upgrades, but should not be their only
player-facing effect.

## Target rhythm

These are experience targets, not locked test thresholds or final timing:

- Roughly every **10–30 seconds:** finish a log or meaningful chopping beat,
  collect pieces and see stock rise.
- Roughly every **2–5 minutes:** complete an order or afford an upgrade.
- Roughly every **15–30 minutes:** unlock a customer, species, axe, yard
  expansion or mechanic.
- Long term: grow from a stump and small pile into a busy, prosperous yard with
  prestigious contracts and an enormous visible body of work.

The exact cadence must be tuned with Sam in live play rather than enforced from
these illustrative ranges.

## Automation and yard staff (M8)

Staff may eventually:

- deliver fresh logs to the block;
- gather and stack finished firewood;
- bundle and ship completed orders;
- sell excess stock according to player rules;
- run passive secondary production;
- maintain supply while the player is away, if offline progress is later
  approved.

Late-game automated cutting is now approved for the trillion-scale commodity
volume in the expanded roadmap, but it is not part of M8. A species must be
manually mastered/certified before an auto-cutter accepts it; player-cut goods
remain premium, and manual Momentum accelerates the whole operation enough that
returning to the block is always valuable.

## Approved module sequence

### M1–M4 — preserve and finish

Core contracts, shell, GameFeel and chopping already exist. Complete Creative
Director sign-off and tuning without destabilising the chopping that prompted
the pivot.

### M5 — retired

Tree felling, forest traversal and bucking were deleted in the pivot and remain
recoverable from git only.

### M6 — retired from the active roadmap

Do not build ore mining. `04_M6_ORE_MINING.md`, `OreVeinDef` and related files
are archival until Sam makes a separate deletion call.

### M7A — first playable progression slice

Prove that chopping can carry the economy with the smallest coherent slice:

- an always-available basic buyer;
- three authored customer orders;
- cash, firewood stock and lifetime wood chopped;
- five tangible upgrades spread across the approved upgrade families;
- one unlockable second wood species;
- a visible stockpile that grows with the player’s output;
- a real entry flow that replaces the temporary M-key path.

Before implementation, specify the exact three orders, five upgrades, prices,
payouts and lifetime milestones with Sam. Do not infer those tuning values from
this roadmap.

### M7B — craftsmanship and lumberyard expansion

After M7A sign-off, add reputation, the forgiving cut-quality layer, requested
piece sizes/species, additional customer families and meaningful axe/block/
supply/yard/transport progression. This phase proves that player skill and
business growth reinforce one another.

### M8 — optional logistics staff

After M7 sign-off, add yard staff only where they support delivery, gathering,
stacking, bundling, shipping or secondary production. No dialogue simulation,
needs system, walkable village or morale layer is implied by this roadmap.

### Post-M8 candidates — not active modules

- **Wood-supply regions:** biome-flavoured suppliers that unlock species,
  customers and contracts; not explorable forest levels.
- **Workshop products:** bundles, charcoal, boards or other premium goods once
  the base firewood economy is proven.
- **Restrained escalation:** unusually valuable, rare or fantastical timber
  only after the cozy grounded progression has earned it.

Each candidate requires a fresh Creative Director scope call before work starts.

## Explicitly out of scope

- Ore mining or another competing action mini-game.
- Tree felling, FPS forest exploration or biome traversal.
- A heavy village-builder, refining-chain simulator or worker-needs game.
- Automation that makes chopping strategically irrelevant.
- Punitive quality rules that discard imperfect firewood.
- Unapproved currencies, item IDs, contracts or hardcoded tuning values.
