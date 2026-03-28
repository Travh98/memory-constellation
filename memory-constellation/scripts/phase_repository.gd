class_name PhaseRepository
extends RefCounted

signal phase_positions_changed

# Repository layer — all disk I/O for the Memory Constellation tool.
# Stateless: every method is a pure function of its arguments.
# Handles reading/writing phase configs, session state, and graph positions.

const PHASE_CONFIG := "phase-config.json"
const SESSION_FILE := "user://mc_session.json"
const POSITIONS_FILE := "phase-graph-positions.json"
const PHOTO_EXTENSIONS := ["jpg", "jpeg", "png", "gif", "bmp", "webp", "tiff", "tif", "heic"]
const NOTE_EXTENSIONS := ["md"]


func scan_phases(mc_folder: String) -> Array[PhaseModel]:
	var result: Array[PhaseModel] = []
	var renames: Dictionary = {}
	var dir := DirAccess.open(mc_folder)
	if dir == null:
		return result
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with("."):
			var phase_path := mc_folder + "/" + entry
			var config_path := phase_path + "/" + PHASE_CONFIG
			if not FileAccess.file_exists(config_path):
				_generate_phase_config(phase_path, entry)
			if FileAccess.file_exists(config_path):
				var phase: PhaseModel = _load_phase_from_config(config_path)
				if phase != null:
					phase.folder_path = phase_path
					phase.photo_count = count_photos(phase_path)
					phase.notes = scan_notes(phase_path)
					if phase.phase_name != entry:
						renames[phase.phase_name] = entry
						phase.phase_name = entry
						save_phase(phase)
					result.append(phase)
		entry = dir.get_next()
	dir.list_dir_end()
	if not renames.is_empty():
		_remap_connections(result, renames)
	return result


func _remap_connections(phases: Array[PhaseModel], renames: Dictionary) -> void:
	for phase: PhaseModel in phases:
		var changed := false
		for i: int in range(phase.connections.size()):
			if renames.has(phase.connections[i]):
				phase.connections[i] = renames[phase.connections[i]]
				changed = true
		if changed:
			save_phase(phase)


func scan_notes(folder_path: String) -> Array[NoteModel]:
	var result: Array[NoteModel] = []
	var dir := DirAccess.open(folder_path)
	if dir == null:
		return result
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			if file_name.get_extension().to_lower() in NOTE_EXTENSIONS:
				var note := NoteModel.from_file(folder_path + "/" + file_name)
				if note != null:
					result.append(note)
		file_name = dir.get_next()
	dir.list_dir_end()
	return result


func count_photos(folder_path: String) -> int:
	var count := 0
	var dir := DirAccess.open(folder_path)
	if dir == null:
		return 0
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			if file_name.get_extension().to_lower() in PHOTO_EXTENSIONS:
				count += 1
		file_name = dir.get_next()
	dir.list_dir_end()
	return count


func save_phase(phase: PhaseModel) -> void:
	var config_path: String = phase.folder_path.path_join(PHASE_CONFIG)
	var file := FileAccess.open(config_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(phase.to_dict(), "\t"))
	file.close()


func create_phase_folder(mc_folder: String, phase_name: String) -> Error:
	var dir := DirAccess.open(mc_folder)
	if dir == null:
		return ERR_CANT_OPEN
	return dir.make_dir(phase_name)


func rename_phase_folder(mc_folder: String, old_name: String, new_name: String) -> Error:
	var dir := DirAccess.open(mc_folder)
	if dir == null:
		return ERR_CANT_OPEN
	return dir.rename(old_name, new_name)


func load_positions(mc_folder: String) -> Dictionary:
	var path := mc_folder + "/" + POSITIONS_FILE
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var content := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(content) != OK:
		return {}
	var data: Variant = json.data
	if data is Dictionary:
		return data
	return {}


func save_positions(mc_folder: String, positions: Dictionary) -> void:
	var file := FileAccess.open(mc_folder + "/" + POSITIONS_FILE, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(positions, "\t"))
	file.close()
	phase_positions_changed.emit()


func rename_position_key(mc_folder: String, old_name: String, new_name: String) -> void:
	var path := mc_folder + "/" + POSITIONS_FILE
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var content := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(content) != OK:
		return
	var data: Variant = json.data
	if not data is Dictionary or not (data as Dictionary).has(old_name):
		return
	(data as Dictionary)[new_name] = (data as Dictionary)[old_name]
	(data as Dictionary).erase(old_name)
	var wfile := FileAccess.open(path, FileAccess.WRITE)
	if wfile == null:
		return
	wfile.store_string(JSON.stringify(data, "\t"))
	wfile.close()
	phase_positions_changed.emit()


func photo_positions_dict(phase: PhaseModel) -> Dictionary:
	var result: Dictionary = {}
	for entry: Variant in phase.photos:
		if entry is Dictionary:
			var n: String = (entry as Dictionary).get("name", "")
			if not n.is_empty():
				result[n] = entry as Dictionary
	return result


func save_photo_positions(phase: PhaseModel, photos: Array) -> void:
	phase.photos = photos
	save_phase(phase)


func note_positions_dict(phase: PhaseModel) -> Dictionary:
	var result: Dictionary = {}
	for entry: Variant in phase.note_positions:
		if entry is Dictionary:
			var n: String = (entry as Dictionary).get("name", "")
			if not n.is_empty():
				result[n] = entry as Dictionary
	return result


func save_note_positions(phase: PhaseModel, note_positions: Array) -> void:
	phase.note_positions = note_positions
	save_phase(phase)


func load_session() -> Dictionary:
	if not FileAccess.file_exists(SESSION_FILE):
		return {}
	var file := FileAccess.open(SESSION_FILE, FileAccess.READ)
	if file == null:
		return {}
	var content := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(content) != OK:
		return {}
	var data: Variant = json.data
	if data is Dictionary:
		return data
	return {}


func save_session(data: Dictionary) -> void:
	var file := FileAccess.open(SESSION_FILE, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func _load_phase_dict(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var content := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(content) != OK:
		return {}
	var result: Variant = json.data
	if result is Dictionary:
		return result
	return {}


func _load_phase_from_config(path: String) -> PhaseModel:
	var d: Dictionary = _load_phase_dict(path)
	if d.is_empty():
		return null
	return PhaseModel.from_dict(d)


func _generate_phase_config(phase_path: String, folder_name: String) -> void:
	var earliest_time: int = 0
	var dir := DirAccess.open(phase_path)
	if dir != null:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				if file_name.get_extension().to_lower() in PHOTO_EXTENSIONS:
					var mtime: int = FileAccess.get_modified_time(phase_path + "/" + file_name)
					if earliest_time == 0 or mtime < earliest_time:
						earliest_time = mtime
			file_name = dir.get_next()
		dir.list_dir_end()
	var start_date := ""
	if earliest_time > 0:
		var dt: Dictionary = Time.get_datetime_dict_from_unix_time(earliest_time)
		start_date = "%d-%02d-%02d" % [dt.year, dt.month, dt.day]
	var phase := PhaseModel.new()
	phase.phase_name = folder_name
	phase.start_date = start_date
	phase.folder_path = phase_path
	save_phase(phase)
