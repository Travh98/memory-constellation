class_name PhasePresenter
extends RefCounted

# Presenter layer — business logic and orchestration.
# Connects to View signals, validates input, drives Model mutations,
# calls Repository for I/O, and updates Views via display methods.
# Holds all mutable app state (sort preferences).

var _model: ConstellationModel
var _repo: PhaseRepository
var _view: ConfigurationToolView
var _dialog: PhaseDialogView
var _graph: PhaseGraphView

var _sort_mode: int = 0
var _sort_asc: bool = true


func initialize(
		view: ConfigurationToolView,
		dialog: PhaseDialogView,
		graph: PhaseGraphView) -> void:
	_model = GlobalCollections.constellation_model
	_repo = GlobalCollections.phase_repository
	_view = view
	_dialog = dialog
	_graph = graph
	_connect_signals()


func load_session() -> void:
	var session: Dictionary = _repo.load_session()
	_sort_mode = int(session.get("sort_mode", 0))
	_sort_asc = bool(session.get("sort_asc", true))
	var last_folder: String = session.get("last_folder", "")
	_view.apply_session(_sort_mode, _sort_asc, last_folder)
	if last_folder != "" and DirAccess.dir_exists_absolute(last_folder):
		_load_folder(last_folder)


func _connect_signals() -> void:
	_view.folder_selected.connect(_on_folder_selected)
	_view.add_phase_requested.connect(_on_add_phase_requested)
	_view.open_folder_requested.connect(_on_open_folder_requested)
	_view.sort_changed.connect(_on_sort_changed)
	_view.sort_direction_toggled.connect(_on_sort_direction_toggled)
	_view.refresh_requested.connect(_on_refresh_requested)
	_view.context_edit_requested.connect(_on_context_edit_requested)
	_view.context_archive_requested.connect(_on_context_archive_requested)
	_dialog.submitted.connect(_on_dialog_submitted)
	_graph.connection_toggled.connect(_on_connection_toggled)


func _load_folder(path: String) -> void:
	_model.folder_path = path
	_model.set_phases(_repo.scan_phases(path))
	_model.graph_positions = _repo.load_positions(path)
	_view.set_folder_loaded(path)
	_refresh_views()


func _refresh_views() -> void:
	var active: Array[PhaseModel] = _model.sort_phases(_model.get_active(), _sort_mode, _sort_asc)
	var archived: Array[PhaseModel] = _model.sort_phases(_model.get_archived(), _sort_mode, _sort_asc)
	_view.display_phases(active, archived)
	_graph.load_phases(_model.get_active())


func _save_session() -> void:
	_repo.save_session({
		"last_folder": _model.folder_path,
		"sort_mode": _sort_mode,
		"sort_asc": _sort_asc,
	})


func _on_folder_selected(path: String) -> void:
	_load_folder(path)
	_save_session()


func _on_open_folder_requested() -> void:
	if not _model.folder_path.is_empty():
		OS.shell_show_in_file_manager(_model.folder_path)


func _on_add_phase_requested() -> void:
	_dialog.open_for_add()


func _on_context_edit_requested(phase_name: String) -> void:
	var phase: PhaseModel = _model.find_phase(phase_name)
	if phase != null:
		_dialog.open_for_edit(phase.to_dict())


func _on_context_archive_requested(phase_name: String, is_archived: bool) -> void:
	_set_phase_archived(phase_name, not is_archived)


func _on_sort_changed(index: int) -> void:
	_sort_mode = index
	_refresh_views()
	_save_session()


func _on_sort_direction_toggled() -> void:
	_sort_asc = not _sort_asc
	_view.update_sort_direction_button(_sort_asc)
	_refresh_views()
	_save_session()


func _on_refresh_requested() -> void:
	if _model.folder_path.is_empty():
		return
	_model.set_phases(_repo.scan_phases(_model.folder_path))
	_refresh_views()


func _on_dialog_submitted(data: Dictionary) -> void:
	var phase_name: String = data.get("phase_name", "").strip_edges()
	if phase_name.is_empty():
		_dialog.show_error("Phase name cannot be empty.")
		return
	var is_edit: bool = data.get("_edit_mode", false)
	var original_name: String = data.get("_original_name", "")
	var lower_name := phase_name.to_lower()
	var names_to_check: Array[String] = _model.get_names_except(original_name) if is_edit else _model.get_all_names()
	for existing: String in names_to_check:
		if existing.to_lower() == lower_name:
			_dialog.show_error('A phase named "%s" already exists.' % phase_name)
			return
	if is_edit:
		_apply_edit(data)
	else:
		_create_phase(data)


func _create_phase(data: Dictionary) -> void:
	var phase_name: String = data.get("phase_name", "")
	var new_folder := _model.folder_path + "/" + phase_name
	if DirAccess.dir_exists_absolute(new_folder):
		_dialog.show_error('Folder "%s" already exists on disk.' % phase_name)
		return
	var err := _repo.create_phase_folder(_model.folder_path, phase_name)
	if err != OK:
		_dialog.show_error("Failed to create folder.")
		return
	var phase := PhaseModel.new()
	phase.phase_name = phase_name
	phase.color = data.get("color", "#6495ed")
	phase.playlist_link = data.get("playlist_link", "")
	phase.start_date = data.get("start_date", "")
	phase.end_date = data.get("end_date", "")
	phase.folder_path = new_folder
	_repo.save_phase(phase)
	_model.set_phases(_repo.scan_phases(_model.folder_path))
	_refresh_views()
	_dialog.hide()


func _apply_edit(data: Dictionary) -> void:
	var original_name: String = data.get("_original_name", "")
	var new_name: String = data.get("phase_name", "")
	var phase: PhaseModel = _model.find_phase(original_name)
	if phase == null:
		return
	if new_name != original_name:
		var new_folder := _model.folder_path + "/" + new_name
		if DirAccess.dir_exists_absolute(new_folder):
			_dialog.show_error('Folder "%s" already exists on disk.' % new_name)
			return
		var err := _repo.rename_phase_folder(_model.folder_path, original_name, new_name)
		if err != OK:
			_dialog.show_error("Failed to rename folder.")
			return
		_repo.rename_position_key(_model.folder_path, original_name, new_name)
		var changed: Array[String] = _model.rename_phase(original_name, new_name)
		for changed_name: String in changed:
			var other: PhaseModel = _model.find_phase(changed_name)
			if other != null:
				_repo.save_phase(other)
	phase.phase_name = new_name
	phase.color = data.get("color", "#6495ed")
	phase.playlist_link = data.get("playlist_link", "")
	phase.start_date = data.get("start_date", "")
	phase.end_date = data.get("end_date", "")
	phase.folder_path = _model.folder_path + "/" + new_name
	_repo.save_phase(phase)
	_model.set_phases(_repo.scan_phases(_model.folder_path))
	_refresh_views()
	_dialog.hide()


func _set_phase_archived(phase_name: String, archived: bool) -> void:
	var phase: PhaseModel = _model.find_phase(phase_name)
	if phase == null:
		return
	phase.archived = archived
	_repo.save_phase(phase)
	_refresh_views()


func _on_connection_toggled(from_name: String, to_name: String) -> void:
	_model.toggle_connection(from_name, to_name)
	var phase: PhaseModel = _model.find_phase(from_name)
	if phase != null:
		_repo.save_phase(phase)
	_refresh_views()
