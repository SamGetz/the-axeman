class_name LaunchProgramTable
extends Resource

@export var projects: Array[LaunchProjectDef] = []
@export var components: Array[SpacecraftComponentDef] = []


func project_by_id(id: StringName) -> LaunchProjectDef:
	for project: LaunchProjectDef in projects:
		if project != null and project.id == id:
			return project
	return null


func component_by_id(id: StringName) -> SpacecraftComponentDef:
	for component: SpacecraftComponentDef in components:
		if component != null and component.id == id:
			return component
	return null


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var project_ids: Dictionary = {}
	var stages: Dictionary = {}
	for project: LaunchProjectDef in projects:
		if project == null:
			errors.append("launch table contains null project")
			continue
		errors.append_array(project.validate())
		if project_ids.has(project.id) or stages.has(project.stage):
			errors.append("duplicate launch project id or stage:%s" % project.id)
		project_ids[project.id] = true
		stages[project.stage] = true
	var component_ids: Dictionary = {}
	for component: SpacecraftComponentDef in components:
		if component == null:
			errors.append("launch table contains null component")
			continue
		errors.append_array(component.validate())
		if component_ids.has(component.id):
			errors.append("duplicate spacecraft component:%s" % component.id)
		component_ids[component.id] = true
	return errors
