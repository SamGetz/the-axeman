# Project history

`CLAUDE.md` at the repo root is the lean operating file and task router. It is
loaded into Claude sessions automatically. `AGENTS.md` provides the equivalent
small entry point for Codex.

This folder holds the full narrative behind that file: Creative Director
quotes, the reasoning behind each build decision, and post-mortems on bugs
that were caught and fixed. Nothing here is required reading for a typical
task — pull a file in when you need the "why" behind something CLAUDE.md
only summarizes, or when a CLAUDE.md line points here directly.

| File | Covers |
|---|---|
| [01_pivot_and_direction.md](01_pivot_and_direction.md) | The 2026-08-01 pivot away from tree-felling, the approved post-pivot direction, the Earth-to-alien-timber endgame, the skill tree/store direction, and the 2026-08-04 repo cleanup |
| [02_m4_chopping_game.md](02_m4_chopping_game.md) | M4: the chopping mini-game build, its bugfixes (tangent basis, cut-face UVs, the 14m log, winding, plane_to_local), and the axe-viewmodel rebuild onto an AnimationPlayer |
| [03_m7a_progression_economy.md](03_m7a_progression_economy.md) | M7A: cash/save system, the basic buyer + yard HUD + entry flow, the pile-pays-as-it-lands + haul-away model, the swing-is-a-roll + scars mechanic, and the introductory orders/contract board |
| Git history before the 2026-08-05 lean-doc refactor | Species-ladder, XP/orb, proc, amendment, and retired-contract narrative that was formerly embedded in `CLAUDE.md` |

Current implementation summaries are deliberately not duplicated here. Use
`docs/areas/` for current behavior and git history only when the reason behind
an older decision is material to the task.
