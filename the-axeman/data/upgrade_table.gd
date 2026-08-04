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
## Sam approved the first five rows and their order on 2026-08-04. Prices and
## effect steps in the resource remain candidate tuning data until the measured
## session is signed off; the schema and purchase roles are approved.

@export var upgrades: Array[UpgradeDef] = []


func get_upgrade(id: StringName) -> UpgradeDef:
	for u: UpgradeDef in upgrades:
		if u != null and u.id == id:
			return u
	return null
