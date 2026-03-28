extends Node
class_name PhotoFrameTwoHandScaler


## Scales a PhotoFrame's contents when grabbed with two hands.
## Grab points spread with scale up to max_grab_width.

@onready var _frame: PhotoFrame = $".."
@onready var _photo: Node3D = $"../Photo"
@onready var _collision: Node3D = $"../CollisionShape3D"
@onready var _highlight: Node3D = $"../HighlightRing"
@onready var _grab_left_top: Node3D = $"../GrabPointHandLeft"
@onready var _grab_right_top: Node3D = $"../GrabPointHandRight"
@onready var _grab_left_bottom: Node3D = $"../GrabPointHandLeft2"
@onready var _grab_right_bottom: Node3D = $"../GrabPointHandRight2"

@export var min_scale: float = 0.05
@export var max_scale: float = 150.0
@export var smoothing: float = 0.15
@export var max_grab_width: float = 1.25

var _hands: Array[Node3D] = []
var _initial_distance: float = 0.0
var _initial_scale: float = 1.0
var _target_scale: float = 1.0
var _scaling_active: bool = false

var _grab_points: Array[Node3D]
var _grab_initial_positions: Array[Vector3] = []
var _grab_initial_width: float = 0.0


func _ready() -> void:
	_grab_points = [_grab_left_top, _grab_right_top, _grab_left_bottom, _grab_right_bottom]
	for p: Node3D in _grab_points:
		_grab_initial_positions.append(p.position)
	_grab_initial_width = _grab_right_top.position.x - _grab_left_top.position.x

	_frame.grabbed.connect(_on_grabbed)
	_frame.released.connect(_on_released)
	_frame.dropped.connect(_on_dropped)
	_frame.activated.connect(apply_scale)


func _on_grabbed(_pickable: Node, by: Node3D) -> void:
	if by not in _hands:
		_hands.append(by)
	if _hands.size() == 2:
		_start_scaling()


func _on_released(_pickable: Node, by: Node3D) -> void:
	_hands.erase(by)


func _on_dropped(_pickable: Node) -> void:
	if _scaling_active:
		_frame.scalable_scale = _target_scale
		apply_scale()
		_reset_grab_points()
	_hands.clear()
	_scaling_active = false


func _start_scaling() -> void:
	_initial_distance = _get_distance(_hands[0], _hands[1])
	_initial_scale = _frame.scalable_scale
	_target_scale = _initial_scale
	_scaling_active = true


func _process(_delta: float) -> void:
	if not _scaling_active:
		return

	# Not held by 2 hands
	if _hands.size() < 2:
		_frame.scalable_scale = _target_scale
		apply_scale()
		_reset_grab_points()
		_scaling_active = false
		return

	var current_distance := _get_distance(_hands[0], _hands[1])
	if _initial_distance <= 0.0:
		return

	_target_scale = clamp(_initial_scale * (current_distance / _initial_distance), 
		min_scale, max_scale)
	_frame.scalable_scale = lerpf(_frame.scalable_scale, _target_scale, smoothing)
	apply_scale()


func apply_scale() -> void:
	var uniform_scale: float = _frame.scalable_scale
	var scale_vector: Vector3 = Vector3(uniform_scale, uniform_scale, 1.0)
	_photo.scale = scale_vector
	_collision.scale = scale_vector
	_highlight.scale = scale_vector
	_update_grab_points(uniform_scale)


func _update_grab_points(uniform_scale: float) -> void:
	if _grab_initial_width <= 0.0:
		return
	var capped_scale: float = minf(uniform_scale, max_grab_width / _grab_initial_width)
	for i: int in _grab_points.size():
		var initial_pos: Vector3 = _grab_initial_positions[i]
		_grab_points[i].position = Vector3(initial_pos.x * capped_scale, initial_pos.y * capped_scale, initial_pos.z)


func _reset_grab_points() -> void:
	for i: int in _grab_points.size():
		_grab_points[i].position = _grab_initial_positions[i]


func _get_distance(a: Node3D, b: Node3D) -> float:
	return a.global_position.distance_to(b.global_position)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not get_parent() is XRToolsPickable:
		warnings.append("Parent is not XRToolsPickable")
	return warnings
