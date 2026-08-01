extends Node
## FILE: res://scenes/3d_action/fragment_physics_budget.gd
## ATTACHES TO: a plain Node child of a mini-game scene.
##
## A12: hard cap of 24 ACTIVE (non-frozen) rigid bodies per mini-game. When a
## new body would exceed the cap, the OLDEST still-active body is force-settled
## (frozen STATIC) — settled bodies are already frozen, so the cap really
## bounds bodies still in motion. Reused by M4/M5/M6.
##
## THE CAP IS ON MOTION, SO THE BOOKKEEPING IS TOO (2026-07-26). This used to answer
## "how many are active?" by walking every body it had ever been handed, and to do that
## on EVERY spawn, behind a `filter` that allocated a fresh array of the same length.
## M5 spawns about twelve bodies a blow and never retired one from the list, so by the
## end of a felling the list was hundreds long and a single spawn cost 0.29 ms at 100
## bodies and 0.95 ms at 850 — the game getting measurably heavier the longer the
## player chopped, which is exactly what Sam reported as spam clicking feeling heavy.
##
## A body is now dropped from the hot list the moment it settles (it says so itself —
## `fragment_piece` emits `settled`), so that list is bounded by the cap and the common
## case costs one size comparison. The full list survives only for `tracked_count`,
## which is a reporting seam, not a per-spawn one.
##
## `active_count()` and `tracked_count()` mean exactly what they always did.

const MAX_ACTIVE := 24

var _bodies: Array = []   # everything tracked and still valid — for the counts only
var _live: Array = []     # ...of which these are still moving, oldest first
var _prune_at := 64       # `_bodies` is compacted when it next reaches this


## Register a fragment_piece so the budget can enforce the cap on it.
func track(piece) -> void:
	if piece == null or not is_instance_valid(piece):
		return
	if not piece.settled.is_connected(_on_settled):
		piece.settled.connect(_on_settled)
	_bodies.append(piece)
	# Compacting on a doubling watermark rather than every spawn: the walk is then
	# amortised to a constant per body instead of being paid again by every body after it.
	if _bodies.size() >= _prune_at:
		_bodies = _bodies.filter(_is_valid)
		_prune_at = maxi(64, _bodies.size() * 2)
	if piece.is_settled():
		return
	_live.append(piece)
	_enforce()


## Count of tracked bodies that are still active (valid and not frozen).
func active_count() -> int:
	var n := 0
	for b in _bodies:
		if is_instance_valid(b) and not b.freeze:
			n += 1
	return n


## Total tracked (valid) bodies, active or frozen.
func tracked_count() -> int:
	var n := 0
	for b in _bodies:
		if is_instance_valid(b):
			n += 1
	return n


## A body has come to rest of its own accord (or was force-settled below). Either way
## it is no longer competing for the budget.
func _on_settled(piece) -> void:
	var i := _live.find(piece)
	if i >= 0:
		_live.remove_at(i)


func _enforce() -> void:
	if _live.size() <= MAX_ACTIVE:
		return   # the overwhelming common case, and it costs one comparison
	# Only now is it worth looking: bodies freed or frozen by some other route are
	# still in here, and they must not cost a live body its place.
	_live = _live.filter(_is_active)
	while _live.size() > MAX_ACTIVE:
		var victim = _live[0]
		# force_settle freezes STATIC and emits `settled`, so the mini-game's
		# collection bookkeeping stays consistent — and `_on_settled` takes the body
		# out of `_live`, which is what ends this loop.
		victim.force_settle()
		if not _live.is_empty() and _live[0] == victim:
			_live.remove_at(0)   # it did not report; do not spin on it


func _is_valid(b) -> bool:
	return is_instance_valid(b)


func _is_active(b) -> bool:
	return is_instance_valid(b) and not b.freeze
