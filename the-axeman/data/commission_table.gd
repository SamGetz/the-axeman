class_name CommissionTable
extends Resource
## Repeatable commission identities. Quantities, ratios and selection remain
## explicitly provisional until Sam's measured M9 review.

@export var templates: Array[CommissionTemplateDef] = []


func by_id(id: StringName) -> CommissionTemplateDef:
	for template: CommissionTemplateDef in templates:
		if template != null and template.id == id:
			return template
	return null
