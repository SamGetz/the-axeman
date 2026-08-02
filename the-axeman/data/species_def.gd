class_name SpeciesDef
extends Resource
## FILE: res://data/species_def.gd
## ATTACHES TO: nothing. Schema only; instances live inside
## res://data/species_table.tres and are read through res://data/species_table.gd.
##
## ONE WOOD SPECIES — everything the game needs to know about a kind of log:
## what it is called, what it looks like on the block, what it yields when it is
## chopped, how hard it fights back, and how much lifetime work it takes to earn.
##
## THIS REPLACES THE `_LOG_SPECIES` CONST that lived in chopping_minigame.gd.
## It had to move for two reasons that only appeared once Sam named all 25 woods
## (2026-08-02): twenty-five rows of dictionary literal do not belong in a
## gameplay script, and the YARD HUD — which is 2D-side and must never import the
## 3D mini-game — has to read species to draw the wood selector. A Resource is
## readable from both sides and editable without touching code.
##
## THE LADDER IS ORDERED BY JANKA HARDNESS, which is Sam's own ordering (the 25
## species were given in almost exactly ascending Janka). That single axis drives
## the whole progression honestly:
##
##     harder wood  ->  splits less often  ->  pays more  ->  unlocks later
##
## which is the rule Sam already approved for the first three woods ("the wood
## that pays most resists most"). `janka` is carried here as the DERIVATION
## RECORD: it is what `split_chance` and the price ladder were laid out from, so
## a future species can be slotted in by looking up one real-world number instead
## of guessing where it goes.
##
## WHAT IS AND IS NOT SAM'S:
##   - the 25 species and their ORDER are Sam's, given verbatim on 2026-08-02;
##   - `split_chance` on the STARTING wood is Sam's 0.55 ("roughly 45% to start"),
##     which he tuned on the starting log — it moves with that role, so it now
##     sits on Quaking Aspen rather than on oak;
##   - Sam delegated pricing explicitly ("You can set the pricing") and naming
##     ("I will leave it to you to give them more easily recognizable names");
##   - EVERY OTHER NUMBER — the other 24 split chances, all 25 unlock thresholds,
##     every tint — IS A PLACEHOLDER per Directive 3, laid out to be a defensible
##     curve rather than a final one. They are data, so retuning any single wood
##     is a one-line edit that no test asserts a literal of.

## Stable internal key, e.g. &"quaking_aspen". NOT the item id — a species is the
## tree, `yield_item` is the firewood it becomes.
@export var id: StringName
## Player-facing name, e.g. "Quaking Aspen".
@export var display_name: String
## The registered RAW_WOOD item a finished piece of this log deposits
## (res://data/item_registry.tres). MUST be registered, or InventoryManager
## errors and ignores the gather and the log yields nothing.
@export var yield_item: StringName

@export_group("The ladder")
## Real-world Janka hardness in lbf. NOT read by gameplay — it is the record of
## what `split_chance`, the price and the unlock threshold were derived from, and
## it is shown in the wood selector because "how hard is this wood" is exactly
## what the player is choosing between.
@export var janka: int = 350
## Lifetime wood chopped required before this species can be selected. 0 = the
## starting wood, available on a fresh save.
##
## PLACEHOLDER per Directive 3. The whole ladder is one curve, so these want
## tuning together in live play rather than one at a time — and the late
## thresholds are deliberately beyond what hand-chopping alone should reach,
## because M8's staff and the roadmap's certified auto-cutting arrive first.
@export var unlock_at: int = 0
## Odds that ONE swing cleaves a WHOLE log of this wood, before size relief,
## scars and the strength upgrade are added (see chopping_minigame.split_chance_
## for, which is where the whole sum lives). Descends as `janka` climbs.
@export_range(0.0, 1.0, 0.01) var split_chance: float = 0.55

@export_group("Art")
## The authored log SHAPES this species can be cut from. A LIST on purpose (the
## reason predates this file): the species is picked first and a shape second, so
## a wood with six meshes never turns up more often than a wood with one.
##
## ART DEBT, 2026-08-02: only oak and birch logs exist. Every species that is not
## a birch currently points at the two oak FBXs and leans on `bark_tint` to tell
## itself apart. Dropping real art for a species is a one-line edit here.
@export var meshes: PackedStringArray = PackedStringArray()
## The exposed inside grain of a cut face, generated at runtime rather than by the
## FBX. MUST be TILEABLE — cut-face UVs are a metres-based tiling mapping, so a
## log-end "disc" texture repeats into a grid of discs. Empty falls back to oak.
@export var inside_tex: String = ""
@export var inside_normal: String = ""
## Albedo multiplier over that inside texture. PLACEHOLDER wherever it is not
## WHITE: it stands in for a species' real tileable inside texture.
@export var inside_tint: Color = Color.WHITE
## Albedo multiplier over the log's OWN BARK material, for a species wearing
## another wood's art. WHITE means "this species has its own art, leave it alone",
## and is the value every species should end up at once Sam has authored it.
@export var bark_tint: Color = Color.WHITE

## ---------------------------------------------------------- authored skins
## THE LOG GEOMETRY IS SHARED; THE SKIN IS NOT (Creative Director call,
## 2026-08-02: *"I think we can have the log geo be the same and we just apply
## different textures"*). A species that supplies these stops being a tinted
## stand-in and wears its own painted bark and end grain on the same FBX.
##
## They are bound at runtime onto the imported log's two material slots — see
## `chopping_minigame._apply_species_look()`, which is also where the
## duplicate-don't-mutate rule is explained. Empty means "keep the imported
## material", so a species can supply bark alone and still read as itself.
##
## `bark_tex`  TILING side-of-the-log texture -> the `oak_bark` slot.
## `top_tex`   the authored log END. NOT tileable and must not be: it is a
##             single painted disc, and the FBX's end UVs are laid out to fit
##             exactly one of it. -> the `oak_top` slot.
@export var bark_tex: String = ""
@export var top_tex: String = ""
## Optional normal maps for the two skins above. LEAVING THESE EMPTY IS
## MEANINGFUL, not merely unset: a species that brings its own albedo but no
## normal has the imported wood's normal map CLEARED rather than inherited,
## because Sam's log textures are hand-painted with their light and shadow
## already in them and oak's normal map would emboss oak's crack pattern
## straight through another wood's painted cracks.
@export var bark_normal: String = ""
@export var top_normal: String = ""
## How many times `bark_tex` repeats around the log. PLACEHOLDER per Directive 3.
##
## This exists because the two bark textures in the project are painted at very
## different scales: oak's is roughly 20 plates across its square, Sam's Eastern
## White Pine roughly 8. Both are tiling squares and the log's UVs are identical,
## so at 1.0 the pine shows about four enormous plates on the visible face and
## reads as dark blobs rather than as bark. Scaling the UV is the non-destructive
## fix — the alternative is repainting the art finer, which is Sam's call.
##
## Only affects the bark slot. The END is a single painted disc that the FBX's UVs
## are laid out to fit exactly once, so scaling it would tile a grid of discs.
@export var bark_uv_scale: float = 1.0


## Has the player chopped enough, ever, to have earned this wood?
func is_unlocked(lifetime_wood_chopped: int) -> bool:
	return lifetime_wood_chopped >= unlock_at


## Pieces still to chop before this species unlocks. 0 once it is earned.
func chops_remaining(lifetime_wood_chopped: int) -> int:
	return maxi(0, unlock_at - lifetime_wood_chopped)
