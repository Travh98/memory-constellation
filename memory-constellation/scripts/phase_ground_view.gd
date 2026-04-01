class_name PhaseGroundView
extends Node3D


const POOL_SIZE: int = 40
const PHOTO_FRAME_SCENE: PackedScene = preload("res://scenes/photo_frame.tscn")
const NEXT_PHASE_PORTAL_SCENE: PackedScene = preload("res://scenes/next_phase_portal.tscn")
const NOTE_FRAME_SCENE: PackedScene = preload("res://scenes/note_frame.tscn")
const VIDEO_FRAME_SCENE: PackedScene = preload("res://scenes/video_frame.tscn")
const NOTE_POOL_SIZE: int = 10
const NOTE_ARC_RADIUS: float = 1.4
const NOTE_ARC_HEIGHT: float = 2.1
const NOTE_ARC_HALF_ANGLE_DEG: float = 50.0
const ARC_RADIUS: float = 1.8
const ARC_HEIGHT: float = 1.3
const ARC_HALF_ANGLE_DEG: float = 80.0
const PORTAL_POOL_SIZE: int = 8
const PORTAL_RADIUS: float = 20.0
const PORTAL_HEIGHT: float = 10
const VIDEO_POOL_SIZE: int = 5
const VIDEO_ARC_RADIUS: float = 2.5
const VIDEO_ARC_HEIGHT: float = 1.3
const VIDEO_ARC_HALF_ANGLE_DEG: float = 60.0
const BROWSER_FRAME_SCENE: PackedScene = preload("res://scenes/browser_frame.tscn")
const BROWSER_DEFAULT_POSITION: Vector3 = Vector3(0.0, 1.5, -1.8)


var _pool: Array[PhotoFrame] = []
var _portal_pool: Array[NextPhasePortal] = []
var _note_pool: Array[NoteFrame] = []
var _video_pool: Array[VideoFrame] = []
var _browser_pool: Array[BrowserFrame] = []
var _loaded_textures: Array[ImageTexture] = []
var _active_phase: PhaseModel = null
var _active_photo_names: Array[String] = []
var _active_note_count: int = 0
var _active_video_names: Array[String] = []
var _browser_active: bool = false
# Node typed as Node so the project parses without GDCef installed.
var _cef: Node = null


func _ready() -> void:
	GlobalCollections.reset_current_phase_photo_positions.connect(on_reset_current_phase_photo_pos)

	for i: int in range(POOL_SIZE):
		var frame: PhotoFrame = PHOTO_FRAME_SCENE.instantiate() as PhotoFrame
		add_child(frame)
		frame.deactivate()
		_pool.append(frame)

	for i: int in range(PORTAL_POOL_SIZE):
		var portal: NextPhasePortal = NEXT_PHASE_PORTAL_SCENE.instantiate() as NextPhasePortal
		add_child(portal)
		_portal_pool.append(portal)

	for i: int in range(NOTE_POOL_SIZE):
		var note_frame: NoteFrame = NOTE_FRAME_SCENE.instantiate() as NoteFrame
		add_child(note_frame)
		note_frame.deactivate()
		_note_pool.append(note_frame)

	for i: int in range(VIDEO_POOL_SIZE):
		var video_frame: VideoFrame = VIDEO_FRAME_SCENE.instantiate() as VideoFrame
		add_child(video_frame)
		video_frame.deactivate()
		_video_pool.append(video_frame)

	var browser_frame: BrowserFrame = BROWSER_FRAME_SCENE.instantiate() as BrowserFrame
	add_child(browser_frame)
	browser_frame.deactivate()
	_browser_pool.append(browser_frame)

	if ClassDB.class_exists("GDCef"):
		_cef = ClassDB.instantiate("GDCef")
		add_child(_cef)
	else:
		push_warning("PhaseGroundView: GDCef addon not installed — browser frames will not display. See https://github.com/Lecrapouille/gdcef")


func load_phase(phase: PhaseModel) -> void:
	_active_phase = phase
	_active_photo_names.clear()
	_active_video_names.clear()
	var folder_path: String = phase.folder_path
	var photo_paths: Array[String] = _scan_photos(folder_path)
	var count: int = mini(photo_paths.size(), POOL_SIZE)
	var saved: Dictionary = GlobalCollections.phase_repository.photo_positions_dict(phase)
	var active_index: int = 0
	for i: int in range(count):
		var tex: ImageTexture = _load_texture(photo_paths[i])
		if tex == null:
			continue
		_loaded_textures.append(tex)
		var filename: String = photo_paths[i].get_file()
		_active_photo_names.append(filename)
		var frame: PhotoFrame = _pool[active_index]
		set_photo_to_semicircle(frame, active_index, count)
		frame.activate(tex)
		if saved.has(filename):
			var pd: Dictionary = saved[filename]
			frame.position = _vec3_from_dict(pd.get("position", {}))
			frame.rotation = _vec3_from_dict(pd.get("rotation", {}))
			frame.scalable_scale = pd.get("scale", Vector3.ONE).x
			frame.freeze = true
			frame.frame_two_hand_scaler.apply_scale()
		else:
			print("Loaded photo frame with no save data")
		active_index += 1

	_load_notes(phase)
	_load_videos(phase)
	_load_browser(phase)
	_load_portals(phase)


func set_photo_to_semicircle(frame: PhotoFrame, active_index: int, total_photos: int):
	frame.position = _semicircle_position(active_index, total_photos)
	frame.basis = Basis.looking_at(frame.position.normalized(), Vector3.UP)


func unload_phase(do_save: bool) -> void:
	if do_save:
		_save_photo_positions()
		_save_note_positions()
		_save_video_positions()
		_save_browser_position()
	for frame: PhotoFrame in _pool:
		frame.deactivate()
	for portal: NextPhasePortal in _portal_pool:
		portal.deactivate()
	for note_frame: NoteFrame in _note_pool:
		note_frame.deactivate()
	for video_frame: VideoFrame in _video_pool:
		video_frame.deactivate()
	_browser_pool[0].deactivate()
	_loaded_textures.clear()
	_active_photo_names.clear()
	_active_note_count = 0
	_active_video_names.clear()
	_browser_active = false


func _load_notes(phase: PhaseModel) -> void:
	_active_note_count = 0
	var notes: Array[NoteModel] = phase.notes
	var count: int = mini(notes.size(), NOTE_POOL_SIZE)
	var saved: Dictionary = GlobalCollections.phase_repository.note_positions_dict(phase)
	for i: int in range(count):
		var note_frame: NoteFrame = _note_pool[i]
		var file_name: String = notes[i].file_name
		if saved.has(file_name):
			var nd: Dictionary = saved[file_name]
			note_frame.position = _vec3_from_dict(nd.get("position", {}))
			note_frame.rotation = _vec3_from_dict(nd.get("rotation", {}))
			note_frame.scalable_scale = nd.get("scale", Vector3.ONE).x
			note_frame.freeze = true
			note_frame.frame_two_hand_scaler.apply_scale()
		else:
			note_frame.position = _note_semicircle_position(i, count)
			note_frame.basis = Basis.looking_at(note_frame.position.normalized(), Vector3.UP)
		note_frame.activate(notes[i])
		_active_note_count += 1


func _load_videos(phase: PhaseModel) -> void:
	_active_video_names.clear()
	var folder_path: String = phase.folder_path
	var video_paths: Array[String] = _scan_videos(folder_path)
	var count: int = mini(video_paths.size(), VIDEO_POOL_SIZE)
	var saved: Dictionary = GlobalCollections.phase_repository.video_positions_dict(phase)
	for i: int in range(count):
		var video_path: String = video_paths[i]
		var file_name: String = video_path.get_file()
		_active_video_names.append(file_name)
		var video_frame: VideoFrame = _video_pool[i]
		if saved.has(file_name):
			var vd: Dictionary = saved[file_name]
			video_frame.position = _vec3_from_dict(vd.get("position", {}))
			video_frame.rotation = _vec3_from_dict(vd.get("rotation", {}))
			video_frame.scalable_scale = vd.get("scale", Vector3.ONE).x
			video_frame.freeze = true
			video_frame.frame_two_hand_scaler.apply_scale()
		else:
			video_frame.position = _video_semicircle_position(i, count)
			video_frame.basis = Basis.looking_at(video_frame.position.normalized(), Vector3.UP)
		video_frame.activate(video_path)


func _save_video_positions() -> void:
	if _active_phase == null or _active_video_names.is_empty():
		return
	var videos: Array = []
	for i: int in range(_active_video_names.size()):
		var video_frame: VideoFrame = _video_pool[i]
		videos.append({
			"name": _active_video_names[i],
			"position": _vec3_to_dict(video_frame.position),
			"rotation": _vec3_to_dict(video_frame.rotation),
			"scale": _vec3_to_dict(Vector3.ONE * video_frame.scalable_scale),
		})
	GlobalCollections.phase_repository.save_video_positions(_active_phase, videos)


func _load_browser(phase: PhaseModel) -> void:
	_browser_active = false
	if phase.playlist_link.is_empty():
		return
	var frame: BrowserFrame = _browser_pool[0]
	var saved: Dictionary = GlobalCollections.phase_repository.browser_position_dict(phase)
	if saved.is_empty():
		frame.position = BROWSER_DEFAULT_POSITION
		frame.basis = Basis.looking_at(BROWSER_DEFAULT_POSITION.normalized(), Vector3.UP)
		frame.scalable_scale = 1.0
		frame.freeze = true
		frame.frame_two_hand_scaler.apply_scale()
	else:
		frame.position = _vec3_from_dict(saved.get("position", {}))
		frame.rotation = _vec3_from_dict(saved.get("rotation", {}))
		frame.scalable_scale = saved.get("scale", Vector3.ONE).x
		frame.freeze = true
		frame.frame_two_hand_scaler.apply_scale()
	frame.activate(phase.playlist_link, _cef)
	_browser_active = true


func _save_browser_position() -> void:
	if _active_phase == null or not _browser_active:
		return
	var frame: BrowserFrame = _browser_pool[0]
	GlobalCollections.phase_repository.save_browser_position(_active_phase, {
		"position": _vec3_to_dict(frame.position),
		"rotation": _vec3_to_dict(frame.rotation),
		"scale": _vec3_to_dict(Vector3.ONE * frame.scalable_scale),
	})


func _scan_videos(folder_path: String) -> Array[String]:
	var results: Array[String] = []
	var dir: DirAccess = DirAccess.open(folder_path)
	if dir == null:
		return results
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "" and results.size() < VIDEO_POOL_SIZE:
		if not dir.current_is_dir():
			if file_name.get_extension().to_lower() in PhaseRepository.VIDEO_EXTENSIONS:
				results.append(folder_path.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()
	return results


func _video_semicircle_position(index: int, total: int) -> Vector3:
	var t: float = 0.5 if total <= 1 else float(index) / float(total - 1)
	var angle_rad: float = deg_to_rad(lerp(-VIDEO_ARC_HALF_ANGLE_DEG, VIDEO_ARC_HALF_ANGLE_DEG, t))
	return Vector3(VIDEO_ARC_RADIUS * sin(angle_rad), VIDEO_ARC_HEIGHT, -VIDEO_ARC_RADIUS * cos(angle_rad))


func _save_note_positions() -> void:
	if _active_phase == null or _active_note_count <= 0:
		return
	var note_positions: Array = []
	var notes: Array[NoteModel] = _active_phase.notes
	for i: int in range(mini(_active_note_count, notes.size())):
		var note_frame: NoteFrame = _note_pool[i]
		note_positions.append({
			"name": notes[i].file_name,
			"position": _vec3_to_dict(note_frame.position),
			"rotation": _vec3_to_dict(note_frame.rotation),
			"scale": _vec3_to_dict(Vector3.ONE * note_frame.scalable_scale),
		})
	GlobalCollections.phase_repository.save_note_positions(_active_phase, note_positions)


func _note_semicircle_position(index: int, total: int) -> Vector3:
	var t: float = 0.5 if total <= 1 else float(index) / float(total - 1)
	var angle_rad: float = deg_to_rad(lerp(-NOTE_ARC_HALF_ANGLE_DEG, NOTE_ARC_HALF_ANGLE_DEG, t))
	return Vector3(NOTE_ARC_RADIUS * sin(angle_rad), NOTE_ARC_HEIGHT, -NOTE_ARC_RADIUS * cos(angle_rad))


func _load_portals(phase: PhaseModel) -> void:
	var graph_positions: Dictionary = GlobalCollections.constellation_model.graph_positions
	var current_pos: Dictionary = graph_positions.get(phase.phase_name, {})
	var current_x: float = float(current_pos.get("x", 0.0))
	var current_y: float = float(current_pos.get("y", 0.0))

	var neighbor_names: Array[String] = phase.connections.duplicate()
	for other: PhaseModel in GlobalCollections.constellation_model.phases:
		if other.phase_name != phase.phase_name \
				and phase.phase_name in other.connections \
				and other.phase_name not in neighbor_names:
			neighbor_names.append(other.phase_name)

	var portal_index: int = 0
	for neighbor_name: String in neighbor_names:
		if portal_index >= PORTAL_POOL_SIZE:
			break
		var neighbor_phase: PhaseModel = GlobalCollections.constellation_model.find_phase(neighbor_name)
		if neighbor_phase == null:
			continue
		var neighbor_pos: Dictionary = graph_positions.get(neighbor_name, {})
		var dx: float = float(neighbor_pos.get("x", 0.0)) - current_x
		var dy: float = float(neighbor_pos.get("y", 0.0)) - current_y
		var dir_2d: Vector2 = Vector2(dx, dy)
		if dir_2d.length_squared() < 0.0001:
			dir_2d = Vector2(1.0, 0.0)
		dir_2d = dir_2d.normalized()
		var portal: NextPhasePortal = _portal_pool[portal_index]
		portal.position = Vector3(dir_2d.x * PORTAL_RADIUS, PORTAL_HEIGHT, dir_2d.y * PORTAL_RADIUS)
		portal.basis = Basis.looking_at(Vector3(-dir_2d.x, 0.0, -dir_2d.y), Vector3.UP)
		portal.activate(neighbor_phase)
		portal_index += 1


func _save_photo_positions() -> void:
	if _active_phase == null:
		return
	if _active_phase.folder_path.is_empty():
		push_warning("No folder path for phase ", _active_phase.phase_name)
		return
	var photos: Array = []
	var num_photos: int = _active_photo_names.size()
	if num_photos <= 0:
		#print("Tried saving photo positions for 0 photos.")
		# This would override any existing saves
		return
	for i: int in range(num_photos):
		var frame: PhotoFrame = _pool[i]
		photos.append({
			"name": _active_photo_names[i],
			"position": _vec3_to_dict(frame.position),
			"rotation": _vec3_to_dict(frame.rotation),
			"scale": _vec3_to_dict(Vector3.ONE * frame.scalable_scale),
		})
	print("Saving data for %d photos" % _active_photo_names.size())
	GlobalCollections.phase_repository.save_photo_positions(_active_phase, photos)


func _scan_photos(folder_path: String) -> Array[String]:
	var results: Array[String] = []
	var dir: DirAccess = DirAccess.open(folder_path)
	if dir == null:
		return results
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "" and results.size() < POOL_SIZE:
		if not dir.current_is_dir():
			if file_name.get_extension().to_lower() in PhaseRepository.PHOTO_EXTENSIONS:
				results.append(folder_path.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()
	return results


func _load_texture(path: String) -> ImageTexture:
	var img: Image = Image.new()
	if img.load(path) != OK:
		push_warning("PhaseGroundView: failed to load image: " + path)
		return null
	return ImageTexture.create_from_image(img)


func _semicircle_position(index: int, total: int) -> Vector3:
	var t: float = 0.5 if total <= 1 else float(index) / float(total - 1)
	var angle_rad: float = deg_to_rad(lerp(-ARC_HALF_ANGLE_DEG, ARC_HALF_ANGLE_DEG, t))
	return Vector3(ARC_RADIUS * sin(angle_rad), ARC_HEIGHT, -ARC_RADIUS * cos(angle_rad))


func _vec3_to_dict(v: Vector3) -> Dictionary:
	return {"x": v.x, "y": v.y, "z": v.z}


func _vec3_from_dict(d: Dictionary, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	return Vector3(d.get("x", fallback.x), d.get("y", fallback.y), d.get("z", fallback.z))


func on_reset_current_phase_photo_pos():
	if _active_phase == null: 
		push_warning("Failed to reset photo positions, no active phase")
		return
	
	var folder_path: String = _active_phase.folder_path
	var photo_paths: Array[String] = _scan_photos(folder_path)
	var count: int = mini(photo_paths.size(), POOL_SIZE)
	var active_index: int = 0
	for i: int in range(count):
		var frame: PhotoFrame = _pool[active_index]
		set_photo_to_semicircle(frame, active_index, count)
		active_index += 1
