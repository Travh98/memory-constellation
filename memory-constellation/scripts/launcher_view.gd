class_name LauncherView
extends Control

var _vr_status_label: Label


func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "Memory Constellation"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title)

	var desktop_btn := Button.new()
	desktop_btn.text = "Desktop"
	desktop_btn.custom_minimum_size = Vector2(240, 56)
	desktop_btn.pressed.connect(_on_desktop_pressed)
	vbox.add_child(desktop_btn)

	var vr_btn := Button.new()
	vr_btn.text = "VR"
	vr_btn.custom_minimum_size = Vector2(240, 56)
	vr_btn.pressed.connect(_on_vr_pressed)
	vbox.add_child(vr_btn)

	_vr_status_label = Label.new()
	_vr_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vr_status_label.visible = false
	vbox.add_child(_vr_status_label)


func _on_desktop_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/configuration_tool_view.tscn")


func _on_vr_pressed() -> void:
	var xr_interface: XRInterface = XRServer.find_interface("OpenXR")
	if xr_interface == null:
		_vr_status_label.text = "No VR headset detected."
		_vr_status_label.visible = true
		return
	_vr_status_label.text = "Loading VR, put on headset..."
	_vr_status_label.visible = true
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://scenes/game_root.tscn")
