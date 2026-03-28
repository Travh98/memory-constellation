class_name PhaseGraphView
extends Control

# View layer — force-directed graph visualization of phases and connections.
# Handles physics simulation, year-band layout, pan/zoom, click-to-connect,
# drag-to-reposition, and persisting node positions to phase-graph-positions.json.

signal connection_toggled(from_phase: String, to_phase: String)
signal view_reset

# Physics
const REPULSION: float = 8000.0
const ATTRACTION: float = 1.2
const REST_LENGTH: float = 280.0 # 180
const DAMPING: float = 0.85
const MAX_SPEED: float = 400.0
const CENTER_STRENGTH: float = 0.04
const SECOND_DEGREE_REPULSION: float = 57500.0
const DAY_SHIFT_SCALE = 10
const INCOMING_RISE_STRENGTH: float = 30.0

# Visuals
const CIRCLE_RADIUS: float = 20.0
const ARROW_HEAD_LEN: float = 12.0
const ARROW_HEAD_WIDTH: float = 6.0
const LABEL_GAP: float = 8.0
const FONT_SIZE: int = 14
const ZOOM_STEP: float = 0.1
const ZOOM_MIN: float = 0.2
const ZOOM_MAX: float = 4.0
const GRAPH_BASE_SIZE: float = 2000.0

# Year bands
const BAND_HEIGHT_PER_PHASE: float = 100.0
const BAND_HEIGHT_MIN: float = 24.0
const BAND_HEIGHT_MAX: float = 600.0
const BAND_PADDING: float = 30.0

var _phases: Array[PhaseModel] = []
var _nodes: Array[Dictionary] = []  # {phase_name: String, pos: Vector2, vel: Vector2}
var _selected: String = ""
var _pan_offset: Vector2 = Vector2.ZERO
var _zoom: float = 1.0
var _is_panning: bool = false
var _sim_active: bool = false
var _pan_initialized: bool = false
var _drag_node_idx: int = -1
var _drag_start_screen: Vector2 = Vector2.ZERO
var _dragged: bool = false
var _year_bands: Dictionary = {}  # int → {y_top: float, y_bottom: float}
var _year_list: Array[int] = []   # sorted descending
var _default_year: int = 2024



func _on_reset_view_pressed() -> void:
	if _nodes.is_empty():
		return
	var min_pos: Vector2 = _nodes[0]["pos"]
	var max_pos: Vector2 = _nodes[0]["pos"]
	for node: Dictionary in _nodes:
		var p: Vector2 = node["pos"]
		min_pos = Vector2(minf(min_pos.x, p.x), minf(min_pos.y, p.y))
		max_pos = Vector2(maxf(max_pos.x, p.x), maxf(max_pos.y, p.y))
	var margin: float = 20.0 + CIRCLE_RADIUS
	var content_w: float = max_pos.x - min_pos.x + margin * 2.0
	var content_h: float = max_pos.y - min_pos.y + margin * 2.0
	var viewport_size: Vector2 = get_parent().size
	var new_zoom: float = clampf(minf(viewport_size.x / content_w, viewport_size.y / content_h), ZOOM_MIN, ZOOM_MAX)
	var content_center: Vector2 = (min_pos + max_pos) * 0.5
	_zoom = new_zoom
	var canvas_center: Vector2 = custom_minimum_size * 0.5
	_pan_offset = canvas_center - content_center * _zoom
	view_reset.emit()
	queue_redraw()


func _get_saved_positions() -> Dictionary:
	return GlobalCollections.constellation_model.graph_positions


func _save_positions() -> void:
	var folder_path: String = GlobalCollections.constellation_model.folder_path
	if folder_path.is_empty():
		return
	var pos_dict: Dictionary = {}
	for node: Dictionary in _nodes:
		var p: Vector2 = node["pos"]
		pos_dict[node["phase_name"]] = {"x": p.x, "y": p.y, "locked": node.get("locked", false)}
	GlobalCollections.constellation_model.graph_positions = pos_dict
	GlobalCollections.phase_repository.save_positions(folder_path, pos_dict)


func _build_year_bands() -> void:
	_year_bands.clear()
	_year_list.clear()
	if _phases.is_empty():
		return
	var max_year: int = 2024
	var min_year: int = 2024
	var found: bool = false
	for phase: PhaseModel in _phases:
		var start: String = phase.start_date
		if start.length() >= 4:
			var yr: int = int(start.substr(0, 4))
			if not found:
				max_year = yr
				min_year = yr
				found = true
			else:
				max_year = maxi(max_year, yr)
				min_year = mini(min_year, yr)
	_default_year = max_year
	var year_counts: Dictionary = {}
	for phase: PhaseModel in _phases:
		var start: String = phase.start_date
		var yr: int = max_year
		if start.length() >= 4:
			yr = int(start.substr(0, 4))
		year_counts[yr] = year_counts.get(yr, 0) + 1
	for y: int in range(max_year + 1, min_year - 2, -1):
		_year_list.append(y)
	var total_height: float = 0.0
	var heights: Dictionary = {}
	for yr: int in _year_list:
		var count: int = year_counts.get(yr, 0)
		var h: float = clampf(float(count) * BAND_HEIGHT_PER_PHASE, BAND_HEIGHT_MIN, BAND_HEIGHT_MAX)
		heights[yr] = h
		total_height += h
	var current_y: float = -total_height * 0.5
	for yr: int in _year_list:
		var h: float = heights[yr]
		_year_bands[yr] = {"y_top": current_y, "y_bottom": current_y + h}
		current_y += h


func _get_node_year(phase_name: String) -> int:
	var phase: PhaseModel = _find_phase(phase_name)
	if phase != null:
		var start: String = phase.start_date
		if start.length() >= 4:
			return int(start.substr(0, 4))
	return _default_year


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and not _pan_initialized and size.x > 0.0:
		_pan_offset = size / 2.0
		_pan_initialized = true
		queue_redraw()


func load_phases(all_phases: Array[PhaseModel]) -> void:
	_phases.clear()
	for p: PhaseModel in all_phases:
		if not p.archived:
			_phases.append(p)
	if not _pan_initialized and size.x > 0.0:
		_pan_offset = size / 2.0
		_pan_initialized = true
	_build_year_bands()
	_rebuild_nodes()
	_sim_active = true
	queue_redraw()


func _rebuild_nodes() -> void:
	var sorted: Array[PhaseModel] = []
	for p: PhaseModel in _phases:
		sorted.append(p)
	sorted.sort_custom(func(a: PhaseModel, b: PhaseModel) -> bool:
		return a.start_date > b.start_date
	)

	var existing_pos: Dictionary = {}
	var existing_locked: Dictionary = {}
	for node: Dictionary in _nodes:
		existing_pos[node["phase_name"]] = node["pos"]
		existing_locked[node["phase_name"]] = node.get("locked", false)

	var saved_pos: Dictionary = _get_saved_positions()

	_nodes.clear()

	for i: int in range(sorted.size()):
		var phase_name: String = sorted[i].phase_name
		var pos: Vector2
		if phase_name in existing_pos:
			pos = existing_pos[phase_name]
		elif phase_name in saved_pos:
			var sp: Dictionary = saved_pos[phase_name]
			pos = Vector2(float(sp.get("x", 0.0)), float(sp.get("y", 0.0)))
		else:
			var start_date: String = sorted[i].start_date
			var day_shift: float = 0.0
			var yr: int = _default_year
			var month: int = 6
			if start_date.length() == 10:
				yr = int(start_date.substr(0, 4))
				month = int(start_date.substr(5, 2))
				var day: int = int(start_date.substr(8, 2))
				day_shift = (15.0 - float(day)) * DAY_SHIFT_SCALE
			var spawn_y: float = 0.0
			if _year_bands.has(yr):
				var band: Dictionary = _year_bands[yr]
				var t: float = (float(month) - 1.0) / 11.0
				spawn_y = band["y_top"] + BAND_PADDING + t * (band["y_bottom"] - band["y_top"] - 2.0 * BAND_PADDING)
			pos = Vector2(day_shift, spawn_y)
		var saved_lock: bool = false
		if saved_pos.has(phase_name):
			var sp_lock: Dictionary = saved_pos[phase_name]
			saved_lock = bool(sp_lock.get("locked", false))
		_nodes.append({
			"phase_name": phase_name,
			"pos": pos,
			"vel": Vector2.ZERO,
			"locked": existing_locked.get(phase_name, saved_lock),
		})


func _process(delta: float) -> void:
	if not _sim_active or _nodes.size() == 0:
		return

	var forces: Array[Vector2] = []
	for i: int in range(_nodes.size()):
		forces.append(Vector2.ZERO)

	# Count incoming connections per node
	var incoming_counts: Array[int] = []
	for i: int in range(_nodes.size()):
		incoming_counts.append(0)
	for phase: PhaseModel in _phases:
		for conn: String in phase.connections:
			var target_idx: int = _find_node_idx(conn)
			if target_idx != -1:
				incoming_counts[target_idx] += 1

	# Repulsion between all pairs + centering pull + incoming-connection rise
	for i: int in range(_nodes.size()):
		var pos_i: Vector2 = _nodes[i]["pos"]
		forces[i] -= pos_i * CENTER_STRENGTH
		forces[i].y -= float(incoming_counts[i]) * INCOMING_RISE_STRENGTH

		for j: int in range(i + 1, _nodes.size()):
			var pos_j: Vector2 = _nodes[j]["pos"]
			var diff: Vector2 = pos_i - pos_j
			var dist: float = maxf(diff.length(), 10.0)
			var repulsion_force: Vector2 = diff.normalized() * REPULSION / (dist * dist)
			forces[i] += repulsion_force
			forces[j] -= repulsion_force

	# Spring forces along connections (applied symmetrically)
	for phase: PhaseModel in _phases:
		var from_idx: int = _find_node_idx(phase.phase_name)
		if from_idx == -1:
			continue
		for conn: String in phase.connections:
			var to_idx: int = _find_node_idx(conn)
			if to_idx == -1:
				continue
			var diff: Vector2 = _nodes[to_idx]["pos"] - _nodes[from_idx]["pos"]
			var dist: float = maxf(diff.length(), 1.0)
			var spring: Vector2 = diff.normalized() * ATTRACTION * (dist - REST_LENGTH)
			forces[from_idx] += spring
			forces[to_idx] -= spring

	# 2nd degree repulsion: nodes that share a common neighbor push each other away
	var neighbor_sets: Array = []
	for i: int in range(_nodes.size()):
		neighbor_sets.append(_get_undirected_neighbor_indices(i))

	for i: int in range(_nodes.size()):
		for j: int in range(i + 1, _nodes.size()):
			if j in neighbor_sets[i]:
				continue  # direct neighbors already handled by spring
			var shared_neighbor: bool = false
			var neighbors_i: Array = neighbor_sets[i]
			var neighbors_j: Array = neighbor_sets[j]
			for ni: int in neighbors_i:
				if ni in neighbors_j:
					shared_neighbor = true
					break
			if shared_neighbor:
				var diff: Vector2 = _nodes[i]["pos"] - _nodes[j]["pos"]
				var dist: float = maxf(diff.length(), 10.0)
				var second_degree_repulsion_force: Vector2 = diff.normalized() * SECOND_DEGREE_REPULSION / (dist * dist)
				forces[i] += second_degree_repulsion_force
				forces[j] -= second_degree_repulsion_force

	# Integrate velocities and positions
	var any_moving: bool = false
	for i: int in range(_nodes.size()):
		if _nodes[i].get("locked", false):
			_nodes[i]["vel"] = Vector2.ZERO
			continue
		var vel: Vector2 = (_nodes[i]["vel"] + forces[i] * delta) * DAMPING
		if vel.length() > MAX_SPEED:
			vel = vel.normalized() * MAX_SPEED
		if vel.length() > 0.5:
			any_moving = true
		_nodes[i]["vel"] = vel
		_nodes[i]["pos"] = _nodes[i]["pos"] + vel * delta
		var node_yr: int = _get_node_year(_nodes[i]["phase_name"])
		if _year_bands.has(node_yr):
			var band: Dictionary = _year_bands[node_yr]
			_nodes[i]["pos"].y = clampf(_nodes[i]["pos"].y, band["y_top"] + CIRCLE_RADIUS, band["y_bottom"] - CIRCLE_RADIUS)

	_sim_active = any_moving
	queue_redraw()


func _draw() -> void:
	_draw_year_bands()
	# Connections (arrows)
	for phase: PhaseModel in _phases:
		var from_idx: int = _find_node_idx(phase.phase_name)
		if from_idx == -1:
			continue
		var from_screen: Vector2 = _to_screen(_nodes[from_idx]["pos"])
		for conn: String in phase.connections:
			var to_idx: int = _find_node_idx(conn)
			if to_idx == -1:
				continue
			_draw_arrow(from_screen, _to_screen(_nodes[to_idx]["pos"]))

	# Phase nodes (circles only)
	for node: Dictionary in _nodes:
		var screen_pos: Vector2 = _to_screen(node["pos"])
		var radius: float = CIRCLE_RADIUS * _zoom
		var phase: PhaseModel = _find_phase(node["phase_name"])
		var color: Color = Color(phase.color) if phase != null else Color.CORNFLOWER_BLUE

		draw_circle(screen_pos, radius, color)

		if node["phase_name"] == _selected:
			draw_arc(screen_pos, radius + 3.0 * _zoom, 0.0, TAU, 48, Color.WHITE, 2.0)
		if node.get("locked", false):
			draw_arc(screen_pos, radius + 6.0 * _zoom, 0.0, TAU, 48, Color.GOLD, 2.0)

	# Labels drawn last so they always appear on top of all circles
	var font: Font = get_theme_font("font", "Label")
	for node: Dictionary in _nodes:
		var screen_pos: Vector2 = _to_screen(node["pos"])
		var radius: float = CIRCLE_RADIUS * _zoom
		var fs: int = int(float(FONT_SIZE) * _zoom)
		var label_pos: Vector2 = screen_pos + Vector2(radius + LABEL_GAP * _zoom, font.get_height(fs) * 0.35)
		draw_string(font, label_pos, node["phase_name"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


func _draw_year_bands() -> void:
	if _year_list.is_empty():
		return
	var font: Font = get_theme_font("font", "Label")
	for idx: int in range(_year_list.size()):
		var yr: int = _year_list[idx]
		var band: Dictionary = _year_bands[yr]
		var y_top_screen: float = _to_screen(Vector2(0.0, band["y_top"])).y
		var y_bottom_screen: float = _to_screen(Vector2(0.0, band["y_bottom"])).y
		var fill_color: Color = Color(1.0, 1.0, 1.0, 0.03) if idx % 2 == 0 else Color(0.0, 0.0, 0.0, 0.05)
		draw_rect(Rect2(0.0, y_top_screen, size.x, y_bottom_screen - y_top_screen), fill_color)
		_draw_dashed_line(Vector2(0.0, y_top_screen), Vector2(size.x, y_top_screen), Color(1.0, 1.0, 1.0, 0.18), 1.0, 10.0, 6.0)
		var fs: int = maxi(int(float(FONT_SIZE) * _zoom), 8)
		var label_y: float = clampf(y_top_screen + float(fs) + 4.0, y_top_screen + 4.0, y_bottom_screen - 4.0)
		draw_string(font, Vector2(8.0, label_y), str(yr), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 1.0, 1.0, 0.3))
	var last_band: Dictionary = _year_bands[_year_list[-1]]
	var y_last_screen: float = _to_screen(Vector2(0.0, last_band["y_bottom"])).y
	_draw_dashed_line(Vector2(0.0, y_last_screen), Vector2(size.x, y_last_screen), Color(1.0, 1.0, 1.0, 0.18), 1.0, 10.0, 6.0)


func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, width: float, dash: float, gap: float) -> void:
	var dir: Vector2 = (to - from).normalized()
	var total: float = from.distance_to(to)
	var traveled: float = 0.0
	while traveled < total:
		var seg_start: Vector2 = from + dir * traveled
		var seg_end: Vector2 = from + dir * minf(traveled + dash, total)
		draw_line(seg_start, seg_end, color, width)
		traveled += dash + gap


func _draw_arrow(from_screen: Vector2, to_screen: Vector2) -> void:
	var diff: Vector2 = to_screen - from_screen
	if diff.length() < 1.0:
		return
	var dir: Vector2 = diff.normalized()
	var r: float = CIRCLE_RADIUS * _zoom
	var start: Vector2 = from_screen + dir * r
	var end: Vector2 = to_screen - dir * r
	if start.distance_to(end) < 2.0:
		return

	var arrow_color: Color = Color(0.85, 0.85, 0.85, 0.9)
	draw_line(start, end, arrow_color, 1.5, true)

	var head_len: float = ARROW_HEAD_LEN * _zoom
	var head_w: float = ARROW_HEAD_WIDTH * _zoom
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	draw_colored_polygon(
		PackedVector2Array([end, end - dir * head_len + perp * head_w, end - dir * head_len - perp * head_w]),
		arrow_color
	)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			var hit: String = _hit_test(_to_world(mb.position))
			if not hit.is_empty():
				var idx: int = _find_node_idx(hit)
				if idx != -1:
					_nodes[idx]["locked"] = not _nodes[idx].get("locked", false)
					queue_redraw()
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_is_panning = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var hit: String = _hit_test(_to_world(mb.position))
				if not hit.is_empty():
					_drag_node_idx = _find_node_idx(hit)
					_drag_start_screen = mb.position
					_dragged = false
				else:
					_selected = ""
					queue_redraw()
			else:
				if _drag_node_idx != -1:
					if _dragged:
						_save_positions()
					else:
						_handle_left_click_on(_drag_node_idx)
				_drag_node_idx = -1
				_dragged = false
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if _is_panning:
			_pan_offset += mm.relative
			queue_redraw()
		elif _drag_node_idx != -1:
			if not _dragged and mm.position.distance_to(_drag_start_screen) > 4.0:
				_dragged = true
			if _dragged:
				var world_pos: Vector2 = _to_world(mm.position)
				var drag_yr: int = _get_node_year(_nodes[_drag_node_idx]["phase_name"])
				if _year_bands.has(drag_yr):
					var band: Dictionary = _year_bands[drag_yr]
					world_pos.y = clampf(world_pos.y, band["y_top"] + CIRCLE_RADIUS, band["y_bottom"] - CIRCLE_RADIUS)
				_nodes[_drag_node_idx]["pos"] = world_pos
				_nodes[_drag_node_idx]["vel"] = Vector2.ZERO
				_sim_active = true
				queue_redraw()


func unlock_all() -> void:
	for node: Dictionary in _nodes:
		node["locked"] = false
	_save_positions()
	queue_redraw()


func zoom_in() -> void:
	_zoom_at(_viewport_center(), _zoom + ZOOM_STEP)


func zoom_out() -> void:
	_zoom_at(_viewport_center(), _zoom - ZOOM_STEP)


func _viewport_center() -> Vector2:
	var scroll := get_parent() as ScrollContainer
	if scroll == null:
		return size / 2.0
	return Vector2(scroll.scroll_horizontal, scroll.scroll_vertical) + scroll.size / 2.0


func _zoom_at(screen_pos: Vector2, new_zoom: float) -> void:
	new_zoom = clampf(new_zoom, ZOOM_MIN, ZOOM_MAX)
	var world_pos: Vector2 = _to_world(screen_pos)
	_zoom = new_zoom
	_pan_offset = screen_pos - world_pos * _zoom
	queue_redraw()


func _handle_left_click_on(node_idx: int) -> void:
	var clicked: String = _nodes[node_idx]["phase_name"]

	if _selected.is_empty():
		_selected = clicked
	elif _selected == clicked:
		_selected = ""
	else:
		var a_to_b: bool = _has_connection(_selected, clicked)
		var b_to_a: bool = _has_connection(clicked, _selected)
		if a_to_b or b_to_a:
			if a_to_b:
				connection_toggled.emit(_selected, clicked)
			if b_to_a:
				connection_toggled.emit(clicked, _selected)
		else:
			connection_toggled.emit(_selected, clicked)
		_selected = ""
	queue_redraw()


func _hit_test(world_pos: Vector2) -> String:
	for node: Dictionary in _nodes:
		var node_pos: Vector2 = node["pos"]
		if (world_pos - node_pos).length() <= CIRCLE_RADIUS:
			return node["phase_name"]
	return ""


func _to_screen(world_pos: Vector2) -> Vector2:
	return world_pos * _zoom + _pan_offset


func _to_world(screen_pos: Vector2) -> Vector2:
	return (screen_pos - _pan_offset) / _zoom


func _find_node_idx(phase_name: String) -> int:
	for i: int in range(_nodes.size()):
		if _nodes[i]["phase_name"] == phase_name:
			return i
	return -1


func _find_phase(phase_name: String) -> PhaseModel:
	for p: PhaseModel in _phases:
		if p.phase_name == phase_name:
			return p
	return null


func _has_connection(from_name: String, to_name: String) -> bool:
	var from_phase: PhaseModel = _find_phase(from_name)
	if from_phase == null:
		return false
	return to_name in from_phase.connections


func _get_undirected_neighbor_indices(node_idx: int) -> Array:
	var result: Array = []
	var node_name: String = _nodes[node_idx]["phase_name"]

	# Outgoing: node → others
	var node_phase: PhaseModel = _find_phase(node_name)
	if node_phase != null:
		for conn: String in node_phase.connections:
			var other_idx: int = _find_node_idx(conn)
			if other_idx != -1 and other_idx not in result:
				result.append(other_idx)

	# Incoming: others → node
	for other_phase: PhaseModel in _phases:
		if other_phase.phase_name == node_name:
			continue
		for conn: String in other_phase.connections:
			if conn == node_name:
				var other_idx: int = _find_node_idx(other_phase.phase_name)
				if other_idx != -1 and other_idx not in result:
					result.append(other_idx)

	return result
