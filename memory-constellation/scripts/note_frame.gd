@tool
class_name NoteFrame
extends BaseFrame

@onready var _viewport: XRToolsViewport2DIn3D = $Viewport2Din3D


func activate(note: NoteModel) -> void:
	var display: NoteDisplay = _viewport.get_scene_instance() as NoteDisplay
	if display != null:
		display.display(note)
	visible = true
	freeze = true
	activated.emit()
