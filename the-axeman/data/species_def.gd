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
## PLAYER LEVEL at which this wood goes ON SALE, and what it then costs.
##
## REPLACED `unlock_at` (a lifetime-chopped milestone) on 2026-08-02, when Sam
## made cash the thing that buys woods and levels the thing that gates them:
## "the currency we generate goes to things like new axes, auto cutters,
## unlocking new logs etc". The level says a wood MAY be bought; only the
## purchase says it was, which is why owned species are now saved rather than
## derived (see GameState._owned_species).
##
## Level 1 + cost 0 = the starting wood, owned on a fresh save.
##
## PLACEHOLDERS per Directive 3, both of them. The ladder is one curve and these
## want tuning together in live play against the XP curve, not one at a time.
@export var unlock_level: int = 1
@export var unlock_cost: int = 0
## Optional physical/business access gate. The species is still separately
## level-gated and purchased; this merely names the supplier relationship that
## must already exist. Empty means no supplier equipment requirement.
@export var supplier_upgrade_id: StringName = &""
## Odds that ONE swing cleaves a WHOLE log of this wood, before size relief,
## scars and the strength upgrade are added (see chopping_minigame.split_chance_
## for, which is where the whole sum lives). Descends as `janka` climbs.
@export_range(0.0, 1.0, 0.01) var split_chance: float = 0.55
## Experience a FINISHED log of this wood awards, dropped as orbs when the last
## piece becomes firewood (Creative Director call, 2026-08-02: "higher skill logs
## drop more exp"). PLACEHOLDER per Directive 3, laid out up the Janka ladder so
## the wood that resists most teaches most.
@export var xp_reward: int = 10

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
## Legacy fallback multiplier over an imported exterior. WHITE means the species
## has a texture path (bespoke or placeholder) and is the intended steady state.
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
## True when either exterior path is generated stand-in art. Keeping this in the
## data schema makes placeholder debt visible to tools without parsing filenames.
@export var exterior_textures_placeholder: bool = false
## Optional normal-map source paths retained for future art passes. The approved
## initial procedural exterior is deliberately albedo-only, matching the lab;
## runtime fresh-inside normals remain independent and unchanged.
@export var bark_normal: String = ""
@export var top_normal: String = ""
## Object-space repeats per metre for the triplanar bark shader. PLACEHOLDER per
## Directive 3. The 1.8 default is the lower-frequency pass Sam approved in the
## material lab; conifer and birch exceptions remain labelled placeholders too.
## Only affects bark. Authored end grain is mapped once and runtime fresh-cut
## inside grain keeps its existing independent metres-based UV strategy.
@export_range(0.25, 24.0, 0.05) var bark_projection_scale: float = 1.8


## Is this the wood a fresh save starts on — free and available at level 1?
func is_starting_wood() -> bool:
	return unlock_level <= 1 and unlock_cost <= 0


## Player levels still to gain before this wood goes on sale. 0 once it has.
func levels_remaining(player_level: int) -> int:
	return maxi(0, unlock_level - player_level)
