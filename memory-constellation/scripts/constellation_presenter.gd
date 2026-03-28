class_name ConstellationPresenter
extends Node

# Bootstraps ConstellationModel from the saved session on startup.
# Replaces the model-initialization that ConfigurationToolView's PhasePresenter
# previously performed. Must sit before ConstellationView in the scene tree so
# the model is populated before ConstellationView._ready() runs.


func _ready() -> void:
	var repo: PhaseRepository = GlobalCollections.phase_repository
	var model: ConstellationModel = GlobalCollections.constellation_model
	var session: Dictionary = repo.load_session()
	var last_folder: String = session.get("last_folder", "")
	if last_folder != "" and DirAccess.dir_exists_absolute(last_folder):
		model.folder_path = last_folder
		model.set_phases(repo.scan_phases(last_folder))
		model.graph_positions = repo.load_positions(last_folder)
	elif last_folder != "":
		push_warning("ConstellationPresenter: last_folder no longer exists: " + last_folder)
