class_name VideoFrame
extends XRToolsPickable

signal activated

# Godot natively supports .ogv (Ogg Theora).
# For .mp4/.mov support, install the GodotFFmpeg gdextension.
const FRAME_WIDTH: float = 0.48
const FRAME_HEIGHT: float = 0.27
const FRAME_DEPTH: float = 0.01


@onready var _player: VideoStreamPlayer = $SubViewport/VideoStreamPlayer
@onready var _collision: CollisionShape3D = $CollisionShape3D
var scalable_scale: float = 1.0
@onready var video_frame_two_hand_scaler: VideoFrameTwoHandScaler = $VideoFrameTwoHandScaler


func activate(video_path: String) -> void:
	var stream: VideoStream = ResourceLoader.load(video_path, "VideoStream") as VideoStream
	if stream == null:
		push_warning("VideoFrame: failed to load video: " + video_path)
		return
	_player.stream = stream
	_player.loop = true
	_player.play()
	visible = true
	freeze = true
	activated.emit()


func deactivate() -> void:
	if _player.is_playing():
		_player.stop()
	_player.stream = null
	visible = false
	freeze = true
	global_position = Vector3(0.0, -1000.0, 0.0)
