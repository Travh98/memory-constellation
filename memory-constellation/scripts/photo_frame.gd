class_name PhotoFrame
extends BaseFrame

const MAX_SIZE: float = 20.0
const START_SIZE: float = 0.4
const MIN_SIZE: float = 0.1

@onready var _sprite: Sprite3D = $Photo


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
	activated.emit()
