class_name ConstellationModel
extends RefCounted

# Model layer — single in-memory source of truth for a loaded constellation.
# Owns the folder path, all phase data, graph positions, and the selected phase.


var folder_path: String = ""
var phases: Array[PhaseModel] = []
var graph_positions: Dictionary = {}
var selected_phase: PhaseModel = null


func set_phases(new_phases: Array[PhaseModel]) -> void:
	phases = new_phases


func upsert_phase(phase: PhaseModel) -> void:
	for i: int in range(phases.size()):
		if phases[i].phase_name == phase.phase_name:
			phases[i] = phase
			return
	phases.append(phase)


func set_archived(phase_name: String, archived: bool) -> void:
	for phase: PhaseModel in phases:
		if phase.phase_name == phase_name:
			phase.archived = archived
			return


func rename_phase(old_name: String, new_name: String) -> Array[String]:
	var changed: Array[String] = []
	for phase: PhaseModel in phases:
		if phase.phase_name == old_name:
			phase.phase_name = new_name
		else:
			var idx: int = phase.connections.find(old_name)
			if idx >= 0:
				phase.connections[idx] = new_name
				changed.append(phase.phase_name)
	return changed


func toggle_connection(from_name: String, to_name: String) -> void:
	for phase: PhaseModel in phases:
		if phase.phase_name == from_name:
			if to_name in phase.connections:
				phase.connections.erase(to_name)
			else:
				phase.connections.append(to_name)
			return


func get_active() -> Array[PhaseModel]:
	return phases.filter(func(p: PhaseModel) -> bool: return not p.archived)


func get_archived() -> Array[PhaseModel]:
	return phases.filter(func(p: PhaseModel) -> bool: return p.archived)


func find_phase(phase_name: String) -> PhaseModel:
	for phase: PhaseModel in phases:
		if phase.phase_name == phase_name:
			return phase
	return null


func get_all_names() -> Array[String]:
	var names: Array[String] = []
	for phase: PhaseModel in phases:
		names.append(phase.phase_name)
	return names


func get_names_except(excluded_name: String) -> Array[String]:
	var names: Array[String] = []
	for phase: PhaseModel in phases:
		if phase.phase_name != excluded_name:
			names.append(phase.phase_name)
	return names


func sort_phases(list: Array[PhaseModel], sort_mode: int, ascending: bool) -> Array[PhaseModel]:
	var sorted: Array[PhaseModel] = list.duplicate()
	match sort_mode:
		0:
			sorted.sort_custom(func(a: PhaseModel, b: PhaseModel) -> bool:
				var na: String = a.phase_name.to_lower()
				var nb: String = b.phase_name.to_lower()
				return na < nb if ascending else na > nb
			)
		1:
			sorted.sort_custom(func(a: PhaseModel, b: PhaseModel) -> bool:
				return a.start_date < b.start_date if ascending else a.start_date > b.start_date
			)
		2:
			sorted.sort_custom(func(a: PhaseModel, b: PhaseModel) -> bool:
				return a.photo_count < b.photo_count if ascending else a.photo_count > b.photo_count
			)
		3:
			sorted.sort_custom(func(a: PhaseModel, b: PhaseModel) -> bool:
				return a.connections.size() < b.connections.size() if ascending else a.connections.size() > b.connections.size()
			)
	return sorted
