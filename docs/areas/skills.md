# Run powers area guide

Read this for run XP, level offers, rarity, six-slot ownership, rerolls, banishes,
Payday, boss bonus choices, or power effects.

## Current gate

The permanent SkillTree is retired. `SkillTree`, its `.tres` data, and legacy
proc definitions remain only so v19 migration can identify old entitlement and
temporary scenes can parse during the gated pivot. Their query and purchase
surfaces are behaviorally neutral; `GameState` has no permanent XP or skill
state.

The immutable `RunPowerTable` contract contains:

- twelve Core powers owned by every fresh/migrated profile;
- twelve Blueprint powers unlocked only through settled boss rolls;
- fixed Common/Rare/Epic identity, authored rank cap, typed effect ladders, and
  explicit `PLACEHOLDER` tuning on every row.

Slice 2 now runs from Level 1 with a fresh XP curve. Authoritative XP queues
levels immediately, while the choice pause waits until the matching orb fills
the displayed bar. Each normal event offers three distinct eligible cards;
Luck can add a fourth. Reroll replaces every remaining card without changing
event size, Banish removes a card from this and all future offers, and the last
card cannot be banished. Multiple levels resolve serially.

New identities can fill at most six stable slots. After that, only legal ranks
for those six appear. Active cards, bans, queued levels, utility charges, and RNG
state round-trip through the attempt snapshot, so reload cannot reroll an offer.
If no legal rank remains, the resolver falls back to Payday.

The production HUD renders the three/four-card modal and six-slot strip and owns
the pause boundary. Quick Study and Keen Appraisal already contribute through
the typed aggregation surface to delivery-snapshotted XP/cash rewards. The
remaining combat, automatic-tool, and completion-chain behaviors are not live
until Slice 4.

## Next implementation boundaries

Slice 4 implements the complete 24-power behavior set, boss bonus offers,
Blueprint rewards, visible automatic tools, and bounded completion cascades.

Do not revive permanent skill writes or make new code consume the retired
SkillTree/proc dictionaries. Chopping and arena effects will read one typed
permanent-plus-run modifier aggregation surface when those slices land.
