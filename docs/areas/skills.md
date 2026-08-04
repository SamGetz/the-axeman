# Skills and proc area guide

Read this only for XP, level progression, the skill tree, proc resolution,
grain cues, Follow-Up, Ready Stance, or related VFX.

## Current model

- Level is derived from total XP, with a maximum of 99. Skill points are derived
  from level and recorded skill purchases rather than kept as a drifting purse.
- The skill tree is a validated DAG in `data/skill_tree.tres`. Effects are named
  kinds; callers decide how their numeric values compose.
- Proc definitions live in `data/proc_table.tres` and resolve through
  `core/proc_resolver.gd`, including bounded bad-luck protection and debug seams.
- Named proc data must be reachable from a skill node. `grain_read` is the
  intentional exception because Quick Study enables it through a grain-cue
  modifier rather than a `proc_id`.

## Signed-off vertical slices

- Strength: Double Strike awards an extra cut after a successful split. It
  bypasses the ordinary split roll and does not create recursive chains.
- Technique: Quick Study and grain reading provide visible precision cues and
  manual-XP rewards. Invalid or ineligible geometry must not reach proc rewards.
- Speed: Follow-Up is an automatic bonus swing after any landed root swing,
  whether the root split or scarred. It re-enters the ordinary strike resolver
  and makes its own real split roll.
- A root swing may create at most one chain of each supported kind. Bonus swings
  are marked so they cannot create bonus chains of their own.
- Follow-Up must visibly replay the axe swing. The strike result remains
  synchronous so existing debug/test seams stay deterministic.
- Ready Stance (`CHOP_SPEED`) accelerates only the wind-up. Axe contact restores
  the normal rate immediately so the authored follow-through is unchanged.

## Open tuning and gaps

- Proc probabilities, chain caps, bad-luck bounds, node costs/levels, and the
  maximum wind-up scale are placeholders until Sam tunes them.
- Follow-Up has no precision-guard escape modifier equivalent to Steady
  Continuation.
- `WINDUP_TIME` and `SWING_RECOVERY` modifier kinds are declared but unused.

Use `core/tests/m7c_acceptance.tscn` for contracts, `proc_shot` and `grain_shot`
for non-headless presentation, `axe_shot` for Ready Stance timing, and
`save_probe.tscn` only to seed temporary feel-test saves.

The old `handoff/12_M7C_AXEMAN_CAREER_AND_SPECIES_MASTERY_BRIEF.md` predates the
signed-off automatic Follow-Up behavior and is historical. Do not use its
earlier player-initiated Follow-Up description as current authority.
