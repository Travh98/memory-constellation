extends Node
class_name XRToolsTwoHandScaler

## Allows grabbing and scaling the parent object with 2 hands

@onready var target_node: Node3D = $".."
@export var min_scale : float = 0.05
@export var max_scale : float = 150.0
@export var smoothing : float = 0.15
@export var uniform_scale := true
@export var lock_z := true

var hands : Array = []

var initial_distance := 0.0
var initial_scale := Vector3.ONE
var scaling_active := false
var _final_scale := Vector3.ONE

func _ready():
	if not target_node:
		target_node = get_parent()

	if not target_node.is_class("XRToolsPickable"):
		push_warning("XRToolsTwoHandScaler needs to have parent XRToolsPickable")

	target_node.connect("grabbed", _on_grabbed)
	target_node.connect("released", _on_released)
	target_node.connect("dropped", _on_dropped)


func _on_grabbed(_pickable, by):
	if by not in hands:
		hands.append(by)

	if hands.size() == 2:
		_start_scaling()


func _on_released(_pickable, by):
	hands.erase(by)


func _on_dropped(_pickable):
	if scaling_active:
		target_node.scale = _final_scale
	hands.clear()
	scaling_active = false


func _start_scaling():
	if hands.size() < 2:
		return

	var a = hands[0]
	var b = hands[1]

	initial_distance = _get_distance(a, b)
	initial_scale = target_node.scale
	scaling_active = true


func _process(_delta):
	if not scaling_active:
		return

	if hands.size() < 2:
		target_node.scale = _final_scale
		scaling_active = false
		return

	var a = hands[0]
	var b = hands[1]

	var current_distance = _get_distance(a, b)

	if initial_distance <= 0:
		return

	var factor = current_distance / initial_distance
	var target_scale = initial_scale * factor

	# Clamp
	target_scale.x = clamp(target_scale.x, min_scale, max_scale)
	target_scale.y = clamp(target_scale.y, min_scale, max_scale)
	target_scale.z = clamp(target_scale.z, min_scale, max_scale)

	# Axis constraints
	if uniform_scale:
		var s = clamp(target_scale.x, min_scale, max_scale)
		target_scale = Vector3(s, s, s)

	if lock_z:
		target_scale.z = initial_scale.z

	# Smooth
	_final_scale = target_scale
	target_node.scale = target_node.scale.lerp(target_scale, smoothing)


func _get_distance(a, b) -> float:
	if not a or not b:
		return 0.0

	return a.global_transform.origin.distance_to(
		b.global_transform.origin
	)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	# Verify parent supports highlighting
	var parent := get_parent()
	if not parent or not parent.is_class("XRToolsPickable"):
		warnings.append("Parent is not XRToolsPickable")

	return warnings
