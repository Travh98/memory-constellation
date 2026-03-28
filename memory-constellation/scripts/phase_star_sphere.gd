class_name PhaseStarSphere
extends Node3D


@export var label_min_height: float = 0
@export var label_max_height: float = 0.9
@export var label_min_distance: float = 0.1
@export var label_max_distance: float = 20.0
@export var label_height_exponent: float = 2.0

@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _hold_button: XRToolsHoldButton = $HoldButton
@onready var _pointer_body: StaticBody3D = $PointerBody
@onready var _name_label: Label3D = $NamePoleBase/NameLabel
@onready var _name_pole_base: Node3D = $NamePoleBase


func _ready() -> void:
	var mat: ShaderMaterial = _mesh.get_surface_override_material(0) as ShaderMaterial
	if mat != null:
		_mesh.set_surface_override_material(0, mat.duplicate())
	_pointer_body.pointer_event.connect(_on_pointer_event)
	_hold_button.pressed.connect(_on_hold_complete)


var _phase_data: PhaseModel = null


func set_phase_data(phase: PhaseModel) -> void:
	_phase_data = phase
	set_phase_color(Color(phase.color))


func set_phase_color(color: Color) -> void:
	var mat: ShaderMaterial = _mesh.get_surface_override_material(0) as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("Sun_Color", color)


func set_phase_name(phase_name: String) -> void:
	_name_label.text = phase_name


func _process(_delta: float) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var dist: float = global_position.distance_to(cam.global_position)
	var t: float = clamp((dist - label_min_distance) / (label_max_distance - label_min_distance), 0.0, 1.0)
	_name_pole_base.position.y = lerp(label_min_height, label_max_height, pow(t, label_height_exponent))


func _on_pointer_event(event: XRToolsPointerEvent) -> void:
	match event.event_type:
		XRToolsPointerEvent.Type.PRESSED:
			_hold_button.set_enabled(true)
		XRToolsPointerEvent.Type.RELEASED:
			_hold_button.set_enabled(false)


func _on_hold_complete() -> void:
	GlobalCollections.constellation_model.selected_phase = _phase_data
	GlobalCollections.set_gamemode(GameModes.GAME_MODES.PHASE_GROUND_VIEW, true)
