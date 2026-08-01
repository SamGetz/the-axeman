class_name TreeCutState
extends RefCounted
## FILE: res://scenes/3d_action/tree_cut_state.gd
## ATTACHES TO: nothing — one of these hangs off every `TreeTrunk` as `trunk.cut`.
##
## WHAT THE PLAYER HAS DONE TO ONE TREE. Every field here used to be a bare variable on
## `tree_felling.gd`, which was correct for exactly as long as there was exactly one tree.
##
## `handoff/08_FPS_FOREST.md` §3b calls this "the single most error-prone item in the
## plan", and it is right: left on the game node, chopping tree B inherits tree A's cut
## sites, its committed fall direction, its accumulated stress and its crack progression.
## Nothing would error. The second tree would simply already have a notch in it, facing a
## way nobody chose, and fall when the FIRST tree's loading said it should.
##
## `TreeTrunk` declares the field and NEVER READS IT. The trunk's job is to hold wood and
## report what that wood is doing; what a notch MEANS — which way the tree is committed to
## falling, how many warning cracks have been spent — is the game's, and lives here so it
## can travel with the tree it belongs to.

## EVERY PLACE THE AXE IS WORKING on this tree, not just one. A blow near a cut already in
## progress advances that cut; a blow anywhere else opens a new one, so the player can work
## wherever they like up and down the trunk and on any face of it.
##
## Each site: { "side", "y", "aim" (the height that was aimed at), "dir" (outward
## horizontal), "depth" (how far in it has eaten, m), "angle" (the last blade angle used),
## "opened" }. There is no distinction between a notch and a back cut — a cut is a cut, and
## what it becomes is whatever angles the player drives into it.
var sites: Array[Dictionary] = []
## The site the last blow on this tree worked on.
var site := -1
## 0 = nothing cut yet; else the side of the trunk the fall is committed to.
var face_side := 0
## World horizontal: the way the notch opens, and so the fall line.
var face_dir := Vector3.RIGHT
## The load model's verdict after this tree's latest blow. 1.0 is failure.
var last_stress := 0.0
## ...and how thick the holding wood measured (m).
var last_thickness := INF
## How many of `crack_stress_levels` this tree has already spent.
var next_crack := 0
## How far it is leaning (rad) as the wood gives.
var lean := 0.0
## ...and the tween easing it there. PER TREE, and it matters: a tween is live and
## mutating, so one shared between trees would keep leaning whichever tree was most
## recently chopped instead of the one it was started for.
var lean_tween: Tween


## Has anything been cut into this tree at all?
func is_untouched() -> bool:
	return face_side == 0 and sites.is_empty()


## The deepest any cut has been driven, in metres.
func deepest() -> float:
	var d := 0.0
	for s in sites:
		d = maxf(d, s.depth as float)
	return d


func kill_lean() -> void:
	if lean_tween != null and lean_tween.is_valid():
		lean_tween.kill()
	lean_tween = null
