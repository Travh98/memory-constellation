@tool
class_name NoteFrame
extends XRToolsPickable

signal activated

const SCREEN_WIDTH: float = 0.4
const SCREEN_HEIGHT: float = 0.3
const FRAME_DEPTH: float = 0.01


@onready var _viewport: XRToolsViewport2DIn3D = $Viewport2Din3D
var scalable_scale: float = 1.0
@onready var note_frame_two_hand_scaler: NoteFrameTwoHandScaler = $NoteFrameTwoHandScaler


func activate(note: NoteModel) -> void:
	var display: NoteDisplay = _viewport.get_scene_instance() as NoteDisplay
	if display != null:
		display.display(note)
	visible = true
	freeze = true
	activated.emit()


func deactivate() -> void:
	visible = false
	freeze = true
	global_position = Vector3(0.0, -1000.0, 0.0)
