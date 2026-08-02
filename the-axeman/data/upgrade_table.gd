class_name UpgradeTable
extends Resource
## FILE: res://data/upgrade_table.gd
## ATTACHES TO: nothing. The single instance is res://data/upgrade_table.tres,
## read through res://core/shop.gd.
##
## Everything the shop sells for CASH, in the order it is shown. Adding an upgrade
## is a row here plus whatever reads its level — no scene edit, exactly like
## adding a wood species is a row in res://data/species_table.tres.
##
## EMPTY SINCE 2026-08-02, and deliberately so. It held Coffee (swing timer) and
## the Protein Bar (strength), bought with cash. Sam then split the two economies:
## "the currency we generate goes to things like new axes, auto cutters, unlocking
## new logs etc and the skill tree goes towards player enhancements, like cutting
## speed, swing timers, strength". Both of those are player enhancements by that
## definition, so they moved to res://data/skill_tree.tres as Quick Hands and
## Strong Arms, keeping Sam's 5% steps.
##
## What cash buys now is WOODS, which the woodshed sells directly. Axes and
## auto-cutters are named in the same direction but are not designed yet — they
## are the next conversation, not rows to invent here (Directive 3).

@export var upgrades: Array[UpgradeDef] = []


func get_upgrade(id: StringName) -> UpgradeDef:
	for u: UpgradeDef in upgrades:
		if u != null and u.id == id:
			return u
	return null
