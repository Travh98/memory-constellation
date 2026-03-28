class_name PhotoFrame
extends XRToolsPickable

signal activated

const MAX_SIZE: float = 20.0
const START_SIZE: float = 0.4
const MIN_SIZE: float = 0.1
const FRAME_DEPTH: float = 0.01


@onready var _sprite: Sprite3D = $Photo
@onready var _collision: CollisionShape3D = $CollisionShape3D
var scalable_scale: float = 1.0
@onready var photo_frame_two_hand_scaler: PhotoFrameTwoHandScaler = $PhotoFrameTwoHandScaler


func activate(tex: ImageTexture) -> void:
	_sprite.texture = tex

	var img_w: float = float(tex.get_width())
	var img_h: float = float(tex.get_height())
	var pixel_size: float = 0.001
	if img_w > 0.0 and img_h > 0.0:
		pixel_size = START_SIZE / maxf(img_w, img_h)
		pixel_size = maxf(pixel_size, MIN_SIZE / minf(img_w, img_h))
	
	_sprite.pixel_size = pixel_size
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(img_w * pixel_size, img_h * pixel_size, FRAME_DEPTH)
	_collision.shape = box
	visible = true
	freeze = true
	# freeze = false
	activated.emit()


func deactivate() -> void:
	_sprite.texture = null
	visible = false
	freeze = true
	global_position = Vector3(0.0, -1000.0, 0.0)
