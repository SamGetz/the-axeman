class_name UpgradeTable
extends Resource
## FILE: res://data/upgrade_table.gd
## ATTACHES TO: nothing. The single instance is res://data/upgrade_table.tres,
## read through res://core/shop.gd.
##
## Everything the shop sells, in the order it is shown. Adding an upgrade is a
## row here plus whatever reads its level — no scene edit, exactly like adding a
## wood species is a row in res://data/species_table.tres.

@export var upgrades: Array[UpgradeDef] = []


func get_upgrade(id: StringName) -> UpgradeDef:
	for u: UpgradeDef in upgrades:
		if u != null and u.id == id:
			return u
	return null
