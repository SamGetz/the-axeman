# Skills and proc area guide

Read this only for XP, level progression, the skill tree, proc resolution,
grain cues, Follow-Up, Ready Stance, or related VFX.

## Current model

- Level is derived from total XP and is uncapped. The curve rises to an authored
  endgame plateau, then repeats that achievable level span indefinitely.
- `skill_points_earned_total` is persisted. Terrestrial levels pay points only
  until the exact 84-point core-tree entitlement, then pay cash. Earth Master
  does not reopen level-point grinding: each of the three alien manual masteries
  grants exactly three points for Frontier.
- XP and level rewards are banked immediately for save safety, but their visible
  presentation follows orb delivery. The old level reaches a full bar first;
  then the level label, skill-point count, Skills reveal/tutorial, and level-up
  effect advance together. The full-bar hold is a labelled placeholder in
  the XP Pacing section of `data/game_config.tres` pending a fresh-save feel pass.
- The skill tree is a validated DAG in `data/skill_tree.tres`. Effects are named
  kinds; callers decide how their numeric values compose.
- A node with two incoming skill paths is an either/or merge: fully ranking one
  preceding branch unlocks it. Single-parent nodes still require that one parent
  to be fully ranked.
- Proc definitions live in `data/proc_table.tres` and resolve through
  `core/proc_resolver.gd`, including bounded bad-luck protection and debug seams.
- Named proc data must be reachable from either a skill capability or a typed
  equipment contribution. `grain_read` is available from the Grain Reader
  capability, an active stump, or both.

## Signed-off vertical slices

- The live graph is exactly 45 nodes: 12 Strength, 12 Speed, 12 Mastery and 9
  Frontier. The core trees cost 84 points. Every Frontier node is one rank, for
  nine alien-earned purchases and 93 purchases across the complete tree.
- The skill window shows one branch graph at a time: Strength from the first
  point, Speed in Working Yard, Mastery at Regional Company and Frontier in the
  Cosmic Finale. Unmet paths remain visible inside the active branch with locked
  styling and prerequisite hover copy. Square buttons buy immediately; full
  names, effects, prerequisites and cost use the high-contrast hover card.
- Respec returns every learned node to the existing point entitlement and costs
  20% of the player's current cash, rounded down to whole coins. The transaction
  also clears proc dry streaks and queued Masterwork state.
- Strength: Double/Triple/Quad Chop resolve one proc roll and then perform up to
  one/two/three valid non-recursive bonus cuts. Earthshaker visibly scars valid
  pieces left after the chain.
- Mastery: Quick Study and grain reading provide visible precision cues and
  manual-XP rewards. Invalid or ineligible geometry must not reach proc rewards.
- Eureka converts a fired Quick Study into one guaranteed future valid grain
  opportunity. Master Axeman queues one Masterwork XP/cash event per level.
- Speed: Follow-Up is an automatic bonus swing after any landed root swing,
  whether the root split or scarred. It re-enters the ordinary strike resolver
  and makes its own real split roll.
- Work Rhythm enables hold-to-chop. Later nodes retain held input through camera
  correction and log handoff while turnaround effects respect authored floors.
- A root swing may create at most one bonus family. On a successful root Strike
  has first refusal; Follow-Up rolls only when Strike does not fire. A failed root
  may still roll Follow-Up. Bonus cuts and swings cannot create another chain.
- Follow-Up must visibly replay the axe swing. The strike result remains
  synchronous so existing debug/test seams stay deterministic.
- Ready Stance (`CHOP_SPEED`) accelerates only the wind-up. Axe contact restores
  the normal rate immediately so the authored follow-through is unchanged.
- Frontier has nine one-rank nodes for alien handling, contribution efficiency,
  fleets and orbital infrastructure, ending in Frontier Master at the credits
  gate. It does not introduce a space currency or shorten an expedition already
  in flight.

## Open tuning and gaps

- Skill magnitudes, proc chances, bad-luck limits and Masterwork/Frontier skill
  bonuses are finalized and shown in plain language in every hover card.
- Non-skill timing floors and XP-orb presentation parameters remain explicitly
  labelled placeholders.
- Equipment adds independent weaker access without granting skill identity:
  axes contribute Double/Triple/Quad Strike chance/depth; active stumps contribute
  Quick Study XP, terrestrial Mastery Echo and Golden Grain; Tool Care and
  Handcart facilities contribute Follow-Up and Express Handoff. Matching skills
  add their approved chance/depth, while Steady Continuation, Earthshaker, Flurry
  and Eureka remain skill-only enhancements.
- `mastery_echo` and `express_handoff` append the proc-family enum and reuse the
  shared persisted fairness resolver with provisional 20- and 12-event bounds.
  Mastery Echo routes one root receipt with an award of one or two through
  `GameState`; it never touches alien mastery, trees, XP, cash, jobs or output.
- Every genuine terrestrial and alien XP award passes through the labelled global
  `1.55` campaign multiplier before presentation. This happens after manual
  mastery/proc composition, so the final orb receipt remains exact.
- The XP Pacing section of `data/game_config.tres` owns pacing and orb review anchors. The automated
  probe reaches a derived ~114-second final level-span projection; a real timed manual
  session is still required before the remaining pacing placeholders become
  approved tuning.

Use `core/tests/xp_delivery_acceptance.tscn` for the full-bar-before-level
presentation contract, `core/tests/m7c_acceptance.tscn` for typed graph validation,
`core/tests/skill_overhaul_acceptance.tscn` for the 45-node/infinite-level/reward
contract, `core/tools/xp_pacing_probe.tscn` for every species anchor, and
`core/tests/m12_acceptance.tscn` for Frontier/launch exclusions, `proc_shot` and `grain_shot`
for non-headless presentation, `axe_shot` for Ready Stance timing, and
`save_probe.tscn` only to seed temporary feel-test saves.

The old `handoff/12_M7C_AXEMAN_CAREER_AND_SPECIES_MASTERY_BRIEF.md` predates the
signed-off automatic Follow-Up behavior and the 45-node overhaul and is historical. Do not use its
earlier player-initiated Follow-Up description as current authority.
