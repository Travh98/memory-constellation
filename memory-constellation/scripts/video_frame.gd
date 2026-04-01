class_name VideoFrame
extends BaseFrame

# Godot natively supports .ogv (Ogg Theora).
# For .mp4/.mov support, install the GodotFFmpeg gdextension.

@onready var _player: VideoStreamPlayer = $SubViewport/VideoStreamPlayer


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
	super.deactivate()
