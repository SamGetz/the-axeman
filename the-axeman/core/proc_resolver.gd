class_name ProcResolver
extends RefCounted
## FILE: res://core/proc_resolver.gd
## ATTACHES TO: nothing. Static only, same precedent as SkillTree/Market/Shop —
## the trigger decision is pure data plus GameState's persisted fairness state;
## this owns no scene state and touches no meshes.
##
## THE SHARED PROC RESOLVER (M7C brief, "Proc resolver and fairness contract"):
## one path every named proc family rolls through, so a future Follow-Up or
## Quick Study never grows its own unrelated RNG. Geometry preflight and target
## selection deliberately stay in the caller (the chopping scene) — they need
## live `_on_block` state this class does not have and should not gain.

## Bounded dry-streak bad-luck protection: GameState tracks consecutive
## failures per proc id. Once `bad_luck_bound - 1` dry rolls have piled up, the
## next roll would be the bound-th dry one in a row — instead it is guaranteed
## (pity), and the streak resets. This is the only policy implemented today;
## `ProcDef.bad_luck_policy_key` exists so a future model (shuffled bag or an
## approved equivalent) can be swapped in without moving the call site.
const _POLICY_BOUNDED_DRY_STREAK := &"bounded_dry_streak"


## Rolls whether `proc` fires for one eligible event. `forced` mirrors this
## project's existing debug-seam pattern (chopping_minigame's
## `debug_split_roll`): -1 rolls for real, 0 always fails, 1 always fires.
## Every outcome — forced or rolled — is recorded to GameState so a reload or a
## fresh scene instance can never cheaply reroll a live streak.
static func should_proc(proc: ProcDef, forced: int = -1) -> bool:
	if proc == null:
		return false
	var fired: bool
	if forced == 0:
		fired = false
	elif forced == 1:
		fired = true
	else:
		fired = _roll(proc)
	GameState.note_proc_result(proc.id, fired)
	return fired


static func _roll(proc: ProcDef) -> bool:
	if proc.bad_luck_policy_key != _POLICY_BOUNDED_DRY_STREAK:
		push_warning("ProcResolver: unknown bad-luck policy '%s' for proc '%s' — rolling without pity."
			% [proc.bad_luck_policy_key, proc.id])
		return randf() < proc.base_chance
	var streak := GameState.get_proc_dry_streak(proc.id)
	if streak >= proc.bad_luck_bound - 1:
		return true   # pity: this roll would be the bound-th dry one in a row — guarantee it instead
	return randf() < proc.base_chance
