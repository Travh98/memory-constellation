extends Node
class_name PlayerHandMode


## Child node of VrPlayer. Tracks whether hands are in edit mode and
## manages remote grab interactions with PhotoFrames via raycasting.
## Assign left_controller and right_controller in the Godot editor.

signal remote_grab_started(controller: XRController3D, initial_ray_endpoint: Vector3)
signal remote_grab_ended(controller: XRController3D)

@export var left_controller: XRController3D
@export var right_controller: XRController3D
@onready var remote_grab_gizmo: PlayerRemoteGrabGizmo = $"../PlayerRemoteGrabGizmo"
@export var raycast_distance: float = 10.0
@export var photo_frame_collision_mask: int = 4

var is_hands_in_edit_mode: bool = true:
	set(value):
		is_hands_in_edit_mode = value
		if not value:
			_clear_hand(left_controller, true)
			_clear_hand(right_controller, false)

var _left_pointed_frame: XRToolsPickable = null
var _right_pointed_frame: XRToolsPickable = null
var _left_grip_held: bool = false
var _right_grip_held: bool = false


func _ready() -> void:
	left_controller.button_pressed.connect(_on_left_button_pressed)
	left_controller.button_released.connect(_on_left_button_released)
	right_controller.button_pressed.connect(_on_right_button_pressed)
	right_controller.button_released.connect(_on_right_button_released)
	GlobalCollections.gamemode_changed.connect(_on_gamemode_changed)


func _on_gamemode_changed(_new_mode: GameModes.GAME_MODES, _do_save: bool) -> void:
	_clear_hand(left_controller, true)
	_clear_hand(right_controller, false)


func _process(_delta: float) -> void:
	if not is_hands_in_edit_mode:
		return
	_update_pointing(left_controller, true)
	_update_pointing(right_controller, false)


func _is_actively_grabbing(is_left: bool) -> bool:
	var grip_held: bool = _left_grip_held if is_left else _right_grip_held
	var pointed_frame: XRToolsPickable = _left_pointed_frame if is_left else _right_pointed_frame
	return grip_held and pointed_frame != null


func _update_pointing(controller: XRController3D, is_left: bool) -> void:
	if _is_physically_grabbing(controller):
		_clear_hand(controller, is_left)
		return

	var grip_held: bool = _left_grip_held if is_left else _right_grip_held
	if grip_held:
		return

	if _is_actively_grabbing(not is_left):
		var current_frame: XRToolsPickable = _left_pointed_frame if is_left else _right_pointed_frame
		if current_frame != null:
			var remote: BaseFrameRemoteGrab = _get_remote_grab(current_frame)
			if remote != null:
				remote.on_remote_hover_end(controller)
			_set_pointer_enabled(controller, true)
			if is_left:
				_left_pointed_frame = null
			else:
				_right_pointed_frame = null
		return

	var current_frame: XRToolsPickable = _left_pointed_frame if is_left else _right_pointed_frame
	var hit_frame: XRToolsPickable = _raycast_for_frame(controller)

	if hit_frame == current_frame:
		return

	if current_frame != null:
		var remote: BaseFrameRemoteGrab = _get_remote_grab(current_frame)
		if remote != null:
			remote.on_remote_hover_end(controller)
		_set_pointer_enabled(controller, true)

	if is_left:
		_left_pointed_frame = hit_frame
	else:
		_right_pointed_frame = hit_frame

	if hit_frame != null:
		var remote: BaseFrameRemoteGrab = _get_remote_grab(hit_frame)
		if remote != null:
			remote.on_remote_hover_start(controller)
			remote.set_gizmo(remote_grab_gizmo)
			_set_pointer_enabled(controller, false)


func _clear_hand(controller: XRController3D, is_left: bool) -> void:
	var current_frame: XRToolsPickable = _left_pointed_frame if is_left else _right_pointed_frame
	if current_frame == null:
		return
	var grip_held: bool = _left_grip_held if is_left else _right_grip_held
	var remote: BaseFrameRemoteGrab = _get_remote_grab(current_frame)
	if remote != null:
		if grip_held:
			remote.on_remote_grab_end(controller)
			remote_grab_ended.emit(controller)
		remote.on_remote_hover_end(controller)
	_set_pointer_enabled(controller, true)
	if is_left:
		_left_pointed_frame = null
		_left_grip_held = false
	else:
		_right_pointed_frame = null
		_right_grip_held = false


func _raycast_for_frame(controller: XRController3D) -> XRToolsPickable:
	var space_state: PhysicsDirectSpaceState3D = controller.get_world_3d().direct_space_state
	var from: Vector3 = controller.global_position
	var aim_direction: Vector3 = -controller.global_transform.basis.z
	var to: Vector3 = from + aim_direction * raycast_distance
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from, to, photo_frame_collision_mask)
	var result: Dictionary = space_state.intersect_ray(query)
	if result.is_empty():
		return null
	return result.get("collider") as XRToolsPickable


func _get_remote_grab(frame: XRToolsPickable) -> BaseFrameRemoteGrab:
	for child: Node in frame.get_children():
		if child is BaseFrameRemoteGrab:
			return child as BaseFrameRemoteGrab
	return null


func _on_left_button_pressed(button: String) -> void:
	if button == "ax_button":
		is_hands_in_edit_mode = not is_hands_in_edit_mode
		return
	if button != "grip_click" or not is_hands_in_edit_mode:
		return
	if _is_physically_grabbing(left_controller):
		return
	_left_grip_held = true
	if _is_actively_grabbing(false):
		if _left_pointed_frame != null and _left_pointed_frame != _right_pointed_frame:
			var old_remote: BaseFrameRemoteGrab = _get_remote_grab(_left_pointed_frame)
			if old_remote != null:
				old_remote.on_remote_hover_end(left_controller)
			_set_pointer_enabled(left_controller, true)
		_left_pointed_frame = _right_pointed_frame
	if _left_pointed_frame != null:
		var remote: BaseFrameRemoteGrab = _get_remote_grab(_left_pointed_frame)
		if remote != null:
			remote.on_remote_grab_start(left_controller)
			remote_grab_started.emit(left_controller, _compute_ray_endpoint(left_controller, _left_pointed_frame))
			_set_pointer_enabled(left_controller, false)


func _on_left_button_released(button: String) -> void:
	if button != "grip_click":
		return
	_left_grip_held = false
	if _left_pointed_frame != null:
		var remote: BaseFrameRemoteGrab = _get_remote_grab(_left_pointed_frame)
		if remote != null:
			remote.on_remote_grab_end(left_controller)
			remote_grab_ended.emit(left_controller)


func _on_right_button_pressed(button: String) -> void:
	if button == "by_button":
		is_hands_in_edit_mode = not is_hands_in_edit_mode
		return
	if button != "grip_click" or not is_hands_in_edit_mode:
		return
	if _is_physically_grabbing(right_controller):
		return
	_right_grip_held = true
	if _is_actively_grabbing(true):
		if _right_pointed_frame != null and _right_pointed_frame != _left_pointed_frame:
			var old_remote: BaseFrameRemoteGrab = _get_remote_grab(_right_pointed_frame)
			if old_remote != null:
				old_remote.on_remote_hover_end(right_controller)
			_set_pointer_enabled(right_controller, true)
		_right_pointed_frame = _left_pointed_frame
	if _right_pointed_frame != null:
		var remote: BaseFrameRemoteGrab = _get_remote_grab(_right_pointed_frame)
		if remote != null:
			remote.on_remote_grab_start(right_controller)
			remote_grab_started.emit(right_controller, _compute_ray_endpoint(right_controller, _right_pointed_frame))
			_set_pointer_enabled(right_controller, false)


func _on_right_button_released(button: String) -> void:
	if button != "grip_click":
		return
	_right_grip_held = false
	if _right_pointed_frame != null:
		var remote: BaseFrameRemoteGrab = _get_remote_grab(_right_pointed_frame)
		if remote != null:
			remote.on_remote_grab_end(right_controller)
			remote_grab_ended.emit(right_controller)


func _compute_ray_endpoint(controller: XRController3D, frame: XRToolsPickable) -> Vector3:
	var aim_dir: Vector3 = -controller.global_transform.basis.z
	var to_frame: Vector3 = frame.global_position - controller.global_position
	var distance: float = maxf(to_frame.dot(aim_dir), 0.1)
	return controller.global_position + aim_dir * distance


func _is_physically_grabbing(controller: XRController3D) -> bool:
	var pickup: XRToolsFunctionPickup = controller.get_node_or_null("XRToolsFunctionPickup")
	return pickup != null and pickup.picked_up_object != null


func _set_pointer_enabled(controller: XRController3D, enabled: bool) -> void:
	var pointer: XRToolsFunctionPointer = controller.get_node_or_null("FunctionPointer")
	if pointer != null:
		pointer.enabled = enabled


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if left_controller == null:
		warnings.append("left_controller is not assigned")
	if right_controller == null:
		warnings.append("right_controller is not assigned")
	return warnings
