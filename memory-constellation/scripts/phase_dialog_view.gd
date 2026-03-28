class_name PhaseDialogView
extends Window

# View layer — add/edit phase dialog.
# Handles form UI and character filtering only. Emits submitted(data) with
# no validation — the Presenter is responsible for all validation logic.

signal submitted(data: Dictionary)

var _edit_mode: bool = false
var _original_name: String = ""
var _filtering_name: bool = false

var name_edit: LineEdit
var color_picker: ColorPickerButton
var playlist_edit: LineEdit
var start_year: SpinBox
var start_month: SpinBox
var start_day: SpinBox
var end_year: SpinBox
var end_month: SpinBox
var end_day: SpinBox
var ongoing_check: CheckBox
var error_label: Label


func _ready() -> void:
	title = "Phase"
	size = Vector2i(440, 520)
	unresizable = true
	close_requested.connect(hide)
	_build_form()


func open_for_add() -> void:
	_edit_mode = false
	_original_name = ""
	title = "Add Phase"
	_clear_form()
	popup_centered()


func open_for_edit(phase_data: Dictionary) -> void:
	_edit_mode = true
	_original_name = phase_data.get("phase_name", "")
	title = "Edit Phase"
	_populate_form(phase_data)
	popup_centered()


func show_error(msg: String) -> void:
	error_label.text = msg
	error_label.visible = true


func _build_form() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# Error label
	error_label = Label.new()
	error_label.modulate = Color(1.0, 0.3, 0.3)
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error_label.visible = false
	vbox.add_child(error_label)

	# Phase Name
	vbox.add_child(_make_label("Phase Name"))
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "e.g. College Years"
	name_edit.text_changed.connect(_on_name_changed)
	vbox.add_child(name_edit)

	# Color
	vbox.add_child(_make_label("Color"))
	color_picker = ColorPickerButton.new()
	color_picker.color = Color.CORNFLOWER_BLUE
	color_picker.custom_minimum_size = Vector2(120, 30)
	vbox.add_child(color_picker)

	# Playlist Link
	vbox.add_child(_make_label("Playlist Link (Spotify / YouTube)"))
	playlist_edit = LineEdit.new()
	playlist_edit.placeholder_text = "https://..."
	vbox.add_child(playlist_edit)

	# Start Date
	vbox.add_child(_make_label("Start Date  (YYYY / MM / DD)"))
	var start_row := HBoxContainer.new()
	start_row.add_theme_constant_override("separation", 4)
	vbox.add_child(start_row)
	start_year = _make_spinbox(1900, 2100, 2024)
	start_month = _make_spinbox(1, 12, 1)
	start_day = _make_spinbox(1, 31, 1)
	start_row.add_child(start_year)
	start_row.add_child(_make_sep("/"))
	start_row.add_child(start_month)
	start_row.add_child(_make_sep("/"))
	start_row.add_child(start_day)

	# End Date
	vbox.add_child(_make_label("End Date  (YYYY / MM / DD)"))
	var end_row := HBoxContainer.new()
	end_row.add_theme_constant_override("separation", 4)
	vbox.add_child(end_row)
	end_year = _make_spinbox(1900, 2100, 2024)
	end_month = _make_spinbox(1, 12, 1)
	end_day = _make_spinbox(1, 31, 1)
	end_row.add_child(end_year)
	end_row.add_child(_make_sep("/"))
	end_row.add_child(end_month)
	end_row.add_child(_make_sep("/"))
	end_row.add_child(end_day)

	ongoing_check = CheckBox.new()
	ongoing_check.text = "Ongoing (no end date)"
	ongoing_check.toggled.connect(_on_ongoing_toggled)
	vbox.add_child(ongoing_check)

	# Push buttons to bottom
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# Buttons
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(hide)
	btn_row.add_child(cancel_btn)

	var confirm_btn := Button.new()
	confirm_btn.text = "Confirm"
	confirm_btn.pressed.connect(_on_confirm)
	btn_row.add_child(confirm_btn)


func _make_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	return lbl


func _make_spinbox(min_v: int, max_v: int, default_v: int) -> SpinBox:
	var sb := SpinBox.new()
	sb.min_value = min_v
	sb.max_value = max_v
	sb.value = default_v
	sb.custom_minimum_size = Vector2(80, 0)
	return sb


func _make_sep(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return lbl


func _on_name_changed(new_text: String) -> void:
	if _filtering_name:
		return
	var filtered := ""
	for c in new_text:
		if (c >= "A" and c <= "Z") or (c >= "a" and c <= "z") or (c >= "0" and c <= "9") \
				or c == " " or c == "-" or c == "_":
			filtered += c
	if filtered != new_text:
		_filtering_name = true
		var caret: int = max(0, name_edit.caret_column - (new_text.length() - filtered.length()))
		name_edit.text = filtered
		name_edit.caret_column = caret
		_filtering_name = false


func _on_ongoing_toggled(pressed: bool) -> void:
	end_year.editable = not pressed
	end_month.editable = not pressed
	end_day.editable = not pressed


func _on_confirm() -> void:
	error_label.visible = false
	var data := {
		"phase_name": name_edit.text.strip_edges(),
		"color": "#" + color_picker.color.to_html(false),
		"playlist_link": playlist_edit.text.strip_edges(),
		"start_date": "%04d-%02d-%02d" % [int(start_year.value), int(start_month.value), int(start_day.value)],
		"end_date": "" if ongoing_check.button_pressed else "%04d-%02d-%02d" % [int(end_year.value), int(end_month.value), int(end_day.value)],
		"_edit_mode": _edit_mode,
		"_original_name": _original_name,
	}
	submitted.emit(data)


func _clear_form() -> void:
	name_edit.text = ""
	color_picker.color = Color.CORNFLOWER_BLUE
	playlist_edit.text = ""
	var now := Time.get_datetime_dict_from_system()
	start_year.value = now["year"]
	start_month.value = now["month"]
	start_day.value = now["day"]
	end_year.value = now["year"]
	end_month.value = now["month"]
	end_day.value = now["day"]
	ongoing_check.button_pressed = true
	_on_ongoing_toggled(true)
	error_label.visible = false


func _populate_form(data: Dictionary) -> void:
	name_edit.text = data.get("phase_name", "")
	color_picker.color = Color(data.get("color", "#6495ed"))
	playlist_edit.text = data.get("playlist_link", "")

	var start: String = data.get("start_date", "")
	if start.length() == 10:
		start_year.value = int(start.substr(0, 4))
		start_month.value = int(start.substr(5, 2))
		start_day.value = int(start.substr(8, 2))
	else:
		var now := Time.get_datetime_dict_from_system()
		start_year.value = now["year"]
		start_month.value = now["month"]
		start_day.value = now["day"]

	var end_str: String = data.get("end_date", "")
	if end_str.is_empty():
		ongoing_check.button_pressed = true
		_on_ongoing_toggled(true)
	else:
		ongoing_check.button_pressed = false
		_on_ongoing_toggled(false)
		if end_str.length() == 10:
			end_year.value = int(end_str.substr(0, 4))
			end_month.value = int(end_str.substr(5, 2))
			end_day.value = int(end_str.substr(8, 2))

	error_label.visible = false
