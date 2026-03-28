extends Node3D
class_name NextPhasePortal

## Allows moving to a connected neighbor phase from PhaseGroundView.
## Activated by PhaseGroundView with the target PhaseModel and world position.

const PHOTO_START_SIZE: float = 5
const DEACTIVATE_Y_OFFSET: int = -1000

@onready var _hold_button: XRToolsHoldButton = $HoldButton
@onready var _pointer_body: StaticBody3D = $PointerBody
@onready var _name_label: Label3D = $NextPhaseName
@onready var _photo: Sprite3D = $NextPhasePhoto

var _target_phase: PhaseModel = null


func _ready() -> void:
	_pointer_body.pointer_event.connect(_on_pointer_event)
	_hold_button.pressed.connect(_on_hold_complete)
	visible = false


func activate(target_phase: PhaseModel) -> void:
	_target_phase = target_phase
	_hold_button.set_enabled(false)
	_name_label.text = target_phase.phase_name
	_photo.texture = _load_first_photo(target_phase)
	if _photo.texture != null:
		var w: float = float(_photo.texture.get_width())
		var h: float = float(_photo.texture.get_height())
		_photo.pixel_size = PHOTO_START_SIZE / maxf(w, h)
	visible = true


func deactivate() -> void:
	_target_phase = null
	_hold_button.set_enabled(false)
	_photo.texture = null
	visible = false
	position = Vector3.UP * DEACTIVATE_Y_OFFSET


func _load_first_photo(phase: PhaseModel) -> ImageTexture:
	var dir: DirAccess = DirAccess.open(phase.folder_path)
	if dir == null:
		return null
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension().to_lower() in PhaseRepository.PHOTO_EXTENSIONS:
			var img: Image = Image.new()
			if img.load(phase.folder_path.path_join(file_name)) == OK:
				dir.list_dir_end()
				return ImageTexture.create_from_image(img)
		file_name = dir.get_next()
	dir.list_dir_end()
	return null


func _on_pointer_event(event: XRToolsPointerEvent) -> void:
	match event.event_type:
		XRToolsPointerEvent.Type.PRESSED:
			_hold_button.set_enabled(true)
		XRToolsPointerEvent.Type.RELEASED:
			_hold_button.set_enabled(false)


func _on_hold_complete() -> void:
	if _target_phase == null:
		return
	GlobalCollections.constellation_model.selected_phase = _target_phase
	GlobalCollections.set_gamemode(GameModes.GAME_MODES.PHASE_GROUND_VIEW, true)
