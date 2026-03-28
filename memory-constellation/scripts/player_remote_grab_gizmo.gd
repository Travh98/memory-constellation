extends Node
class_name PlayerRemoteGrabGizmo


## Visualizes remote grab state while hands are gripping a PhotoFrame at distance.
## Two hands: axes gizmo at manipulator midpoint, reference bar between initial ray
## endpoints, and spheres at current and initial ray endpoints.
## One hand: world-aligned axes offset towards the other controller, one pair of spheres.

const AXIS_LENGTH: float = 0.08
const SPHERE_RADIUS_CURRENT: float = 0.025
const SPHERE_RADIUS_INITIAL: float = 0.015
const SINGLE_HAND_GIZMO_OFFSET: float = 0.12

@onready var _hand_mode: PlayerHandMode = $"../PlayerHandMode"

var _grabbing_controllers: Array[XRController3D] = []
var _initial_ray_startpoints: Dictionary = {}
var _ray_distances: Dictionary = {}

var _lines_instance: MeshInstance3D
var _sphere_current_primary: MeshInstance3D
var _sphere_current_secondary: MeshInstance3D
var _sphere_initial_primary: MeshInstance3D
var _sphere_initial_secondary: MeshInstance3D


func _ready() -> void:
	_lines_instance = _create_lines_instance()
	add_child(_lines_instance)

	_sphere_current_primary = _create_sphere(SPHERE_RADIUS_CURRENT, Color(0.3, 0.8, 1.0))
	_sphere_current_secondary = _create_sphere(SPHERE_RADIUS_CURRENT, Color(1.0, 0.6, 0.2))
	_sphere_initial_primary = _create_sphere(SPHERE_RADIUS_INITIAL, Color(0.15, 0.4, 0.5))
	_sphere_initial_secondary = _create_sphere(SPHERE_RADIUS_INITIAL, Color(0.5, 0.3, 0.1))
	add_child(_sphere_current_primary)
	add_child(_sphere_current_secondary)
	add_child(_sphere_initial_primary)
	add_child(_sphere_initial_secondary)

	_hand_mode.remote_grab_started.connect(_on_remote_grab_started)
	_hand_mode.remote_grab_ended.connect(_on_remote_grab_ended)
	_set_all_visible(false)


func _on_remote_grab_started(controller: XRController3D, initial_ray_endpoint: Vector3) -> void:
	if controller not in _grabbing_controllers:
		_grabbing_controllers.append(controller)
	_initial_ray_startpoints[controller] = controller.global_position
	_ray_distances[controller] = initial_ray_endpoint.distance_to(controller.global_position)


func _on_remote_grab_ended(controller: XRController3D) -> void:
	_grabbing_controllers.erase(controller)
	_initial_ray_startpoints.erase(controller)
	_ray_distances.erase(controller)
	if _grabbing_controllers.is_empty():
		_set_all_visible(false)


func _process(_delta: float) -> void:
	if _grabbing_controllers.is_empty():
		return
	_update_gizmo()


func _update_gizmo() -> void:
	var count: int = _grabbing_controllers.size()

	_sphere_current_primary.visible = count >= 1
	_sphere_initial_primary.visible = count >= 1
	_sphere_current_secondary.visible = count >= 2
	_sphere_initial_secondary.visible = count >= 2

	# Show the gizmo between the user's hands

	var endpoint_a: Vector3 = _grabbing_controllers[0].global_position
	_sphere_current_primary.global_position = endpoint_a
	_sphere_initial_primary.global_position = _initial_ray_startpoints[_grabbing_controllers[0]]

	if count >= 2:
		var endpoint_b: Vector3 = _grabbing_controllers[1].global_position
		_sphere_current_secondary.global_position = endpoint_b
		_sphere_initial_secondary.global_position = _initial_ray_startpoints[_grabbing_controllers[1]]
		_draw_two_hand_lines(endpoint_a, endpoint_b)
	else:
		_draw_single_hand_lines(endpoint_a)

	_lines_instance.visible = true


func _avg_controller_up() -> Vector3:
	return (_grabbing_controllers[0].global_transform.basis.y
		+ _grabbing_controllers[1].global_transform.basis.y).normalized()


func _draw_two_hand_lines(endpoint_a: Vector3, endpoint_b: Vector3) -> void:
	var mesh: ImmediateMesh = _lines_instance.mesh as ImmediateMesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_emit_axes(mesh, _build_manipulator(endpoint_a, endpoint_b, _avg_controller_up()))
	_emit_reference_bar(mesh)
	mesh.surface_end()


func get_current_manipulator() -> Transform3D:
	if _grabbing_controllers.size() < 2:
		return Transform3D.IDENTITY
	return _build_manipulator(
		_grabbing_controllers[0].global_position,
		_grabbing_controllers[1].global_position,
		_avg_controller_up())


func _draw_single_hand_lines(endpoint_a: Vector3) -> void:
	var controller: XRController3D = _grabbing_controllers[0]
	var other: XRController3D = _hand_mode.left_controller \
		if controller == _hand_mode.right_controller else _hand_mode.right_controller
	var to_center: Vector3 = (other.global_position - controller.global_position).normalized()
	var gizmo_origin: Vector3 = endpoint_a + to_center * SINGLE_HAND_GIZMO_OFFSET
	var mesh: ImmediateMesh = _lines_instance.mesh as ImmediateMesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_emit_axes(mesh, Transform3D(Basis.IDENTITY, gizmo_origin))
	mesh.surface_end()


func _emit_axes(mesh: ImmediateMesh, manip: Transform3D) -> void:
	var o: Vector3 = manip.origin
	mesh.surface_set_color(Color.RED)
	mesh.surface_add_vertex(o)
	mesh.surface_set_color(Color.RED)
	mesh.surface_add_vertex(o + manip.basis.x * AXIS_LENGTH)
	mesh.surface_set_color(Color.GREEN)
	mesh.surface_add_vertex(o)
	mesh.surface_set_color(Color.GREEN)
	mesh.surface_add_vertex(o + manip.basis.y * AXIS_LENGTH)
	mesh.surface_set_color(Color(0.3, 0.5, 1.0))
	mesh.surface_add_vertex(o)
	mesh.surface_set_color(Color(0.3, 0.5, 1.0))
	mesh.surface_add_vertex(o + manip.basis.z * AXIS_LENGTH)


func _emit_reference_bar(mesh: ImmediateMesh) -> void:
	var init_a: Vector3 = _initial_ray_startpoints[_grabbing_controllers[0]]
	var init_b: Vector3 = _initial_ray_startpoints[_grabbing_controllers[1]]
	mesh.surface_set_color(Color(0.7, 0.7, 0.7))
	mesh.surface_add_vertex(init_a)
	mesh.surface_set_color(Color(0.7, 0.7, 0.7))
	mesh.surface_add_vertex(init_b)


func _current_ray_endpoint(controller: XRController3D) -> Vector3:
	var aim_dir: Vector3 = -controller.global_transform.basis.z
	return controller.global_position + aim_dir * _ray_distances[controller]


func _build_manipulator(pos_a: Vector3, pos_b: Vector3, ref_up: Vector3 = Vector3.UP) -> Transform3D:
	var origin: Vector3 = (pos_a + pos_b) * 0.5
	var x_axis: Vector3 = (pos_b - pos_a).normalized()
	if absf(x_axis.dot(ref_up)) > 0.99:
		ref_up = Vector3.FORWARD
	var z_axis: Vector3 = x_axis.cross(ref_up).normalized()
	var y_axis: Vector3 = z_axis.cross(x_axis).normalized()
	return Transform3D(Basis(x_axis, y_axis, z_axis), origin)


func _set_all_visible(visible_state: bool) -> void:
	_lines_instance.visible = visible_state
	_sphere_current_primary.visible = visible_state
	_sphere_current_secondary.visible = visible_state
	_sphere_initial_primary.visible = visible_state
	_sphere_initial_secondary.visible = visible_state


func _create_lines_instance() -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.top_level = true
	instance.mesh = ImmediateMesh.new()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.flags_no_depth_test = true
	instance.material_override = material
	return instance


func _create_sphere(radius: float, color: Color) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.top_level = true
	instance.visible = false
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	instance.mesh = sphere
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.3
	instance.material_override = material
	return instance
