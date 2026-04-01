class_name BrowserFrame
extends BaseFrame

# Displays an interactive web browser in VR using GDCef (Chromium Embedded Framework).
# Install GDCef from https://github.com/Lecrapouille/gdcef to enable browser functionality.
# Without GDCef, activate() will emit a warning and the frame will remain invisible.

const BROWSER_WIDTH: int = 1280
const BROWSER_HEIGHT: int = 720
const SCREEN_WIDTH_M: float = 0.853
const SCREEN_HEIGHT_M: float = 0.48

@onready var _screen: MeshInstance3D = $Screen
@onready var _screen_material: StandardMaterial3D = _screen.get_surface_override_material(0)

# Typed as Node so the script parses without GDCef installed.
var _browser: Node = null


func activate(url: String, cef: Node) -> void:
	if cef == null:
		push_warning("BrowserFrame: no GDCef node — install the GDCef addon to enable browser frames")
		return
	if _browser == null:
		_browser = cef.create_browser(url, BROWSER_WIDTH, BROWSER_HEIGHT)
		if _browser.has_signal("on_page_loaded"):
			_browser.on_page_loaded.connect(_on_page_loaded)
	else:
		_browser.load_url(url)
	visible = true
	freeze = true
	activated.emit()


func deactivate() -> void:
	if _browser != null and _browser.has_method("set_muted"):
		_browser.call("set_muted", true)
	super.deactivate()


func send_mouse_position(hit_position: Vector3) -> void:
	if _browser == null or not visible:
		return
	var bx: int
	var by: int
	_hit_to_browser_coords(hit_position, bx, by)
	_browser.call("mouse_move", bx, by)


func send_mouse_click(hit_position: Vector3, pressed: bool) -> void:
	if _browser == null or not visible:
		return
	var bx: int
	var by: int
	_hit_to_browser_coords(hit_position, bx, by)
	# GDCef left mouse button = 0
	_browser.call("mouse_click", 0, pressed, bx, by)


func _hit_to_browser_coords(hit_position: Vector3, out_x: int, out_y: int) -> void:
	# Convert world-space hit point → frame-local space → UV [0,1] → browser pixels.
	# to_local() lands in BrowserFrame's node space (not Screen's child space).
	# Screen.scale = (scalable_scale, scalable_scale, 1), so divide by scalable_scale.
	var local_pos: Vector3 = to_local(hit_position)
	var u: float = clampf(local_pos.x / (SCREEN_WIDTH_M * scalable_scale) + 0.5, 0.0, 1.0)
	var v: float = clampf(0.5 - local_pos.y / (SCREEN_HEIGHT_M * scalable_scale), 0.0, 1.0)
	out_x = int(u * BROWSER_WIDTH)
	out_y = int(v * BROWSER_HEIGHT)


func _on_page_loaded(_node: Node) -> void:
	if _browser == null or not _browser.has_method("get_texture"):
		return
	var tex: Texture2D = _browser.call("get_texture") as Texture2D
	if tex != null and _screen_material != null:
		_screen_material.albedo_texture = tex
