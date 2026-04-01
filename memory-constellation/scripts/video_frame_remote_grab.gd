extends Node
class_name VideoFrameRemoteGrab


## Handles remote (distance) grab for a VideoFrame.
## Displays floating grab point indicators at each hand and lines to the frame center.
## Single-hand grab translates the frame. Two-hand grab translates, rotates, and scales.

@export_range(0.0, 1.0, 0.01) var remote_smoothing: float = 0.04

@onready var _frame: VideoFrame = $".."
@onready var _scaler: VideoFrameTwoHandScaler = $"../VideoFrameTwoHandScaler"

var _gizmo: PlayerRemoteGrabGizmo

var _hovering_hands: Array[Node3D] = []
var _grabbing_hands: Array[Node3D] = []

var _floating_primary: MeshInstance3D
var _floating_secondary: MeshInstance3D
var _line_primary: MeshInstance3D
var _line_secondary: MeshInstance3D

var _initial_frame_transform: Transform3D
var _initial_scale: float = 1.0
var _initial_ray_distances: Array[float] = []
var _initial_manipulator: Transform3D
var _frame_in_manipulator: Transform3D
var _initial_endpoint_distance: float = 0.0


func _ready() -> void:
	_floating_primary = _create_sphere_indicator(Color(0.3, 0.8, 1.0))
	_floating_secondary = _create_sphere_indicator(Color(1.0, 0.6, 0.2))
	add_child(_floating_primary)
	add_child(_floating_secondary)

	_line_primary = _create_line_instance(Color(0.3, 0.8, 1.0))
	_line_secondary = _create_line_instance(Color(1.0, 0.6, 0.2))
	add_child(_line_primary)
	add_child(_line_secondary)


func set_gizmo(gizmo: PlayerRemoteGrabGizmo) -> void:
	_gizmo = gizmo


func on_remote_hover_start(hand: Node3D) -> void:
	if hand not in _hovering_hands:
		_hovering_hands.append(hand)


func on_remote_hover_end(hand: Node3D) -> void:
	_hovering_hands.erase(hand)
	if hand in _grabbing_hands:
		on_remote_grab_end(hand)


func on_remote_grab_start(hand: Node3D) -> void:
	if hand in _grabbing_hands:
		return
	_grabbing_hands.append(hand)
	_capture_initial_state()


func on_remote_grab_end(hand: Node3D) -> void:
	_grabbing_hands.erase(hand)
	if not _grabbing_hands.is_empty():
		_capture_initial_state()


func _process(_delta: float) -> void:
	if not _frame.visible:
		return
	_update_floating_points()
	_update_lines()
	if not _grabbing_hands.is_empty() and not _frame.is_picked_up():
		_update_frame_transform()


func _capture_initial_state() -> void:
	_initial_frame_transform = _frame.global_transform
	_initial_scale = _frame.scalable_scale
	_initial_ray_distances.clear()
	for hand: Node3D in _grabbing_hands:
		var to_frame: Vector3 = _frame.global_position - hand.global_position
		var ray_distance: float = maxf(to_frame.dot(-hand.global_transform.basis.z), 0.1)
		_initial_ray_distances.append(ray_distance)
	if _grabbing_hands.size() >= 2:
		var pos_a: Vector3 = _grabbing_hands[0].global_position
		var pos_b: Vector3 = _grabbing_hands[1].global_position
		var avg_up: Vector3 = (_grabbing_hands[0].global_transform.basis.y
			+ _grabbing_hands[1].global_transform.basis.y).normalized()
		_initial_endpoint_distance = pos_a.distance_to(pos_b)
		_initial_manipulator = _build_manipulator(pos_a, pos_b, avg_up)
		_frame_in_manipulator = _initial_manipulator.affine_inverse() * _initial_frame_transform


func _update_frame_transform() -> void:
	if _grabbing_hands.size() == 1:
		var target_pos: Vector3 = _ray_endpoint(0)
		var lerped_pos: Vector3 = _frame.global_position.lerp(target_pos, remote_smoothing)
		_frame.global_transform = Transform3D(_initial_frame_transform.basis, lerped_pos)
		return

	var endpoint_a: Vector3 = _ray_startpoint(0)
	var endpoint_b: Vector3 = _ray_startpoint(1)
	var avg_up: Vector3 = (_grabbing_hands[0].global_transform.basis.y
		+ _grabbing_hands[1].global_transform.basis.y).normalized()
	var current_manipulator: Transform3D = _gizmo.get_current_manipulator() \
		if _gizmo != null else _build_manipulator(endpoint_a, endpoint_b, avg_up)
	var target_transform: Transform3D = current_manipulator * _frame_in_manipulator
	var lerped_basis: Basis = _frame.basis.slerp(target_transform.basis, remote_smoothing)
	_frame.global_transform = Transform3D(lerped_basis, _frame.global_position)

	if _initial_endpoint_distance > 0.0:
		var scale_factor: float = endpoint_a.distance_to(endpoint_b) / _initial_endpoint_distance
		_frame.scalable_scale = clampf(_initial_scale * scale_factor, _scaler.min_scale, _scaler.max_scale)
		_scaler.apply_scale()


func _ray_endpoint(grab_index: int) -> Vector3:
	var hand: Node3D = _grabbing_hands[grab_index]
	var aim_direction: Vector3 = -hand.global_transform.basis.z
	return hand.global_position + aim_direction * _initial_ray_distances[grab_index]


func _ray_startpoint(grab_index: int) -> Vector3:
	return _grabbing_hands[grab_index].global_position


func _build_manipulator(pos_a: Vector3, pos_b: Vector3, ref_up: Vector3 = Vector3.UP) -> Transform3D:
	var origin: Vector3 = (pos_a + pos_b) * 0.5
	var x_axis: Vector3 = (pos_b - pos_a).normalized()
	if absf(x_axis.dot(ref_up)) > 0.99:
		ref_up = Vector3.FORWARD
	var z_axis: Vector3 = x_axis.cross(ref_up).normalized()
	var y_axis: Vector3 = z_axis.cross(x_axis).normalized()
	return Transform3D(Basis(x_axis, y_axis, z_axis), origin)


func _update_floating_points() -> void:
	var all_hands: Array[Node3D] = _get_all_hands()
	_floating_primary.visible = all_hands.size() > 0
	_floating_secondary.visible = all_hands.size() > 1
	if all_hands.size() > 0:
		var grab_index: int = _grabbing_hands.find(all_hands[0])
		_floating_primary.global_position = _ray_endpoint(grab_index) if grab_index >= 0 else all_hands[0].global_position
	if all_hands.size() > 1:
		var grab_index: int = _grabbing_hands.find(all_hands[1])
		_floating_secondary.global_position = _ray_endpoint(grab_index) if grab_index >= 0 else all_hands[1].global_position


func _update_lines() -> void:
	var all_hands: Array[Node3D] = _get_all_hands()
	var frame_center: Vector3 = _frame.global_position
	_line_primary.visible = all_hands.size() > 0
	_line_secondary.visible = all_hands.size() > 1
	if all_hands.size() > 0:
		_draw_line(_line_primary.mesh as ImmediateMesh, all_hands[0].global_position, frame_center)
	if all_hands.size() > 1:
		_draw_line(_line_secondary.mesh as ImmediateMesh, all_hands[1].global_position, frame_center)


func _draw_line(mesh: ImmediateMesh, from: Vector3, to: Vector3) -> void:
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(from)
	mesh.surface_add_vertex(to)
	mesh.surface_end()


func _get_all_hands() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for hand: Node3D in _hovering_hands:
		result.append(hand)
	for hand: Node3D in _grabbing_hands:
		if hand not in result:
			result.append(hand)
	return result


func _create_sphere_indicator(color: Color) -> MeshInstance3D:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.top_level = true
	mesh_instance.visible = false
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.03
	sphere.height = 0.06
	mesh_instance.mesh = sphere
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.5
	mesh_instance.material_override = material
	return mesh_instance


func _create_line_instance(color: Color) -> MeshInstance3D:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.top_level = true
	mesh_instance.visible = false
	mesh_instance.mesh = ImmediateMesh.new()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.flags_no_depth_test = true
	mesh_instance.material_override = material
	mesh_instance.sorting_offset = 20
	return mesh_instance
