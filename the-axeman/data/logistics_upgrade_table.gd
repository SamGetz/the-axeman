class_name LogisticsUpgradeTable
extends Resource

@export var upgrades: Array[LogisticsUpgradeDef] = []


func by_id(id: StringName) -> LogisticsUpgradeDef:
	for upgrade: LogisticsUpgradeDef in upgrades:
		if upgrade != null and upgrade.id == id:
			return upgrade
	return null
