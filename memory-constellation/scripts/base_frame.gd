class_name BaseFrame
extends XRToolsPickable

signal activated

const FRAME_DEPTH: float = 0.01

@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var frame_two_hand_scaler: BaseFrameTwoHandScaler = $FrameTwoHandScaler
var scalable_scale: float = 1.0


func deactivate() -> void:
	visible = false
	freeze = true
	global_position = Vector3(0.0, -1000.0, 0.0)
