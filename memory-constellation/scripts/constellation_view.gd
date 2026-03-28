class_name ConstellationView
extends Node3D

# View layer — 3D constellation visualization of phases and connections.
# Reads phase positions from constellation_model.graph_positions and renders spheres,
# cylinder+cone arrows, and billboard labels. Read-only; no interaction.

const PHASE_STAR_SPHERE_SCENE: PackedScene = preload("res://scenes/phase_star_sphere.tscn")
const BRIDGE_MATERIAL: Material = preload("res://assets/materials/transparent_white.material")
const SPHERE_RADIUS: float = 0.25
const SHAFT_RADIUS: float = 0.02
const LABEL_OFFSET_Y: float = 0.2
const POSITION_SCALE: float = 0.01
const LABEL_PIXEL_SIZE: float = 0.005

var _phases: Array[PhaseModel] = []


func _ready() -> void:
	load_phases(GlobalCollections.constellation_model.get_active())
	GlobalCollections.phase_repository.phase_positions_changed.connect(func() -> void:
		load_phases(GlobalCollections.constellation_model.get_active())
	)


func load_phases(all_phases: Array[PhaseModel]) -> void:
	_phases = all_phases.duplicate()
	_rebuild()


func _rebuild() -> void:
	for child: Node in get_children():
		child.queue_free()

	var saved: Dictionary = GlobalCollections.constellation_model.graph_positions
	var pos_map: Dictionary = {}

	for phase: PhaseModel in _phases:
		var phase_name: String = phase.phase_name
		if saved.has(phase_name):
			var p: Dictionary = saved[phase_name]
			pos_map[phase_name] = Vector3(
				float(p.get("x", 0.0)) * POSITION_SCALE,
				0.0,
				float(p.get("y", 0.0)) * POSITION_SCALE
			)
		else:
			pos_map[phase_name] = Vector3.ZERO

	for phase: PhaseModel in _phases:
		var phase_name: String = phase.phase_name
		var pos: Vector3 = pos_map[phase_name] if pos_map.has(phase_name) else Vector3.ZERO
		var sphere: PhaseStarSphere = PHASE_STAR_SPHERE_SCENE.instantiate() as PhaseStarSphere
		sphere.position = pos
		sphere.name = "Sphere_" + phase_name
		add_child(sphere)
		sphere.set_phase_data(phase)
		sphere.set_phase_name(phase_name)


	for phase: PhaseModel in _phases:
		var phase_name: String = phase.phase_name
		if not pos_map.has(phase_name):
			continue
		var from_pos: Vector3 = pos_map[phase_name]
		for conn: String in phase.connections:
			if not pos_map.has(conn):
				continue
			_spawn_arrow(from_pos, pos_map[conn], BRIDGE_MATERIAL)


func _spawn_arrow(from: Vector3, to: Vector3, mat: Material) -> void:
	var diff: Vector3 = to - from
	if diff.length() < 0.001:
		return

	var dir: Vector3 = diff.normalized()
	var shaft_start: Vector3 = from + dir * SPHERE_RADIUS / 2
	var shaft_end: Vector3 = to - dir * SPHERE_RADIUS / 2
	var shaft_len: float = shaft_start.distance_to(shaft_end)

	if shaft_len > 0.001:
		var shaft_mesh: CylinderMesh = CylinderMesh.new()
		shaft_mesh.top_radius = SHAFT_RADIUS
		shaft_mesh.bottom_radius = SHAFT_RADIUS * 2
		shaft_mesh.height = shaft_len

		var shaft: MeshInstance3D = MeshInstance3D.new()
		shaft.mesh = shaft_mesh
		shaft.material_override = mat
		shaft.position = (shaft_start + shaft_end) * 0.5
		shaft.basis = _y_aligned_basis(dir)
		add_child(shaft)
	pass


func _y_aligned_basis(dir: Vector3) -> Basis:
	var new_y: Vector3 = dir.normalized()
	var ref: Vector3 = Vector3.RIGHT if abs(new_y.dot(Vector3.RIGHT)) < 0.9 else Vector3.UP
	var new_z: Vector3 = new_y.cross(ref).normalized()
	var new_x: Vector3 = new_z.cross(new_y).normalized()
	return Basis(new_x, new_y, new_z)
