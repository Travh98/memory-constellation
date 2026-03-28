class_name ConfigurationToolView
extends Control

# View layer — main UI layout for the Memory Constellation tool.
# Builds and owns all UI nodes. Emits signals upward to the Presenter;
# never holds business state or touches the filesystem.

signal folder_selected(path: String)
signal add_phase_requested()
signal open_folder_requested()
signal sort_changed(index: int)
signal sort_direction_toggled()
signal refresh_requested()
signal context_edit_requested(phase_name: String)
signal context_archive_requested(phase_name: String, is_archived: bool)

var _presenter: PhasePresenter

# UI references
var folder_path_edit: LineEdit
var add_phase_btn: Button
var open_folder_btn: Button
var sort_option: OptionButton
var sort_asc_btn: Button
var tab_container: TabContainer
var active_list: VBoxContainer
var archived_list: VBoxContainer
var context_menu: PopupMenu
var phase_dialog: PhaseDialogView
var phase_graph: PhaseGraphView
var _file_dialog: FileDialog

var _graph_scroll: ScrollContainer

var _context_phase_name: String = ""
var _context_is_archived: bool = false


func _ready() -> void:
	_build_ui()
	_presenter = PhasePresenter.new()
	_presenter.initialize(self, phase_dialog, phase_graph)
	_presenter.load_session()
	await get_tree().process_frame
	_graph_scroll.scroll_horizontal = int((phase_graph.custom_minimum_size.x - _graph_scroll.size.x) / 2.0)
	_graph_scroll.scroll_vertical = int((phase_graph.custom_minimum_size.y - _graph_scroll.size.y) / 2.0)


# ---------------------------------------------------------------------------
# UI Construction
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	var root_margin := MarginContainer.new()
	root_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 10)
	root_margin.add_theme_constant_override("margin_right", 10)
	root_margin.add_theme_constant_override("margin_top", 10)
	root_margin.add_theme_constant_override("margin_bottom", 10)
	add_child(root_margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	root_margin.add_child(vbox)

	# --- Folder row ---
	var folder_row := HBoxContainer.new()
	folder_row.add_theme_constant_override("separation", 6)
	vbox.add_child(folder_row)

	var folder_lbl := Label.new()
	folder_lbl.text = "MemoryConstellation Folder:"
	folder_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	folder_row.add_child(folder_lbl)

	folder_path_edit = LineEdit.new()
	folder_path_edit.editable = false
	folder_path_edit.placeholder_text = "No folder selected..."
	folder_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	folder_row.add_child(folder_path_edit)

	var browse_btn := Button.new()
	browse_btn.text = "Browse..."
	browse_btn.pressed.connect(_on_browse_pressed)
	folder_row.add_child(browse_btn)

	open_folder_btn = Button.new()
	open_folder_btn.text = "Open Folder"
	open_folder_btn.disabled = true
	open_folder_btn.pressed.connect(func() -> void: open_folder_requested.emit())
	folder_row.add_child(open_folder_btn)

	var launcher_btn := Button.new()
	launcher_btn.text = "Back to Launcher"
	launcher_btn.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/launcher_view.tscn"))
	folder_row.add_child(launcher_btn)


	# --- Main Tab Container (Phases / Connections) ---
	var main_tabs := TabContainer.new()
	main_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(main_tabs)

	# ---- Phases Tab ----
	var phases_margin := MarginContainer.new()
	phases_margin.name = "Phases"
	phases_margin.add_theme_constant_override("margin_left", 6)
	phases_margin.add_theme_constant_override("margin_right", 6)
	phases_margin.add_theme_constant_override("margin_top", 6)
	phases_margin.add_theme_constant_override("margin_bottom", 6)
	main_tabs.add_child(phases_margin)

	var phases_vbox := VBoxContainer.new()
	phases_vbox.add_theme_constant_override("separation", 6)
	phases_margin.add_child(phases_vbox)

	var add_phase_row := HBoxContainer.new()
	add_phase_row.add_theme_constant_override("separation", 8)
	phases_vbox.add_child(add_phase_row)

	add_phase_btn = Button.new()
	add_phase_btn.text = "+ Add Phase"
	add_phase_btn.disabled = true
	add_phase_btn.pressed.connect(func() -> void: add_phase_requested.emit())
	add_phase_row.add_child(add_phase_btn)

	var add_phase_sep := HSeparator.new()
	add_phase_sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_phase_row.add_child(add_phase_sep)

	# Sort row
	var sort_row := HBoxContainer.new()
	sort_row.add_theme_constant_override("separation", 6)
	phases_vbox.add_child(sort_row)

	var sort_lbl := Label.new()
	sort_lbl.text = "Sort by:"
	sort_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sort_row.add_child(sort_lbl)

	sort_option = OptionButton.new()
	sort_option.add_item("Alphabetical", 0)
	sort_option.add_item("Phase Date", 1)
	sort_option.add_item("Photo Count", 2)
	sort_option.add_item("Connections", 3)
	sort_option.item_selected.connect(func(index: int) -> void: sort_changed.emit(index))
	sort_row.add_child(sort_option)

	sort_asc_btn = Button.new()
	sort_asc_btn.text = "↑ Ascending"
	sort_asc_btn.pressed.connect(func() -> void: sort_direction_toggled.emit())
	sort_row.add_child(sort_asc_btn)

	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.pressed.connect(func() -> void: refresh_requested.emit())
	sort_row.add_child(refresh_btn)

	# Active / Archived tab container
	tab_container = TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	phases_vbox.add_child(tab_container)

	var active_scroll := ScrollContainer.new()
	active_scroll.name = "Active"
	active_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	active_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tab_container.add_child(active_scroll)

	active_list = VBoxContainer.new()
	active_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_list.add_theme_constant_override("separation", 2)
	active_scroll.add_child(active_list)

	var archived_scroll := ScrollContainer.new()
	archived_scroll.name = "Archived"
	archived_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	archived_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tab_container.add_child(archived_scroll)

	archived_list = VBoxContainer.new()
	archived_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	archived_list.add_theme_constant_override("separation", 2)
	archived_scroll.add_child(archived_list)

	# ---- Connections Tab ----
	var connections_margin := MarginContainer.new()
	connections_margin.name = "Connections"
	connections_margin.add_theme_constant_override("margin_left", 6)
	connections_margin.add_theme_constant_override("margin_right", 6)
	connections_margin.add_theme_constant_override("margin_top", 6)
	connections_margin.add_theme_constant_override("margin_bottom", 6)
	main_tabs.add_child(connections_margin)

	var graph_wrapper := Control.new()
	graph_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	connections_margin.add_child(graph_wrapper)

	_graph_scroll = ScrollContainer.new()
	_graph_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	graph_wrapper.add_child(_graph_scroll)

	phase_graph = PhaseGraphView.new()
	phase_graph.custom_minimum_size = Vector2(2000, 2000)
	_graph_scroll.add_child(phase_graph)

	var graph_overlay := Control.new()
	graph_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	graph_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	graph_wrapper.add_child(graph_overlay)

	var reset_btn := Button.new()
	reset_btn.text = "Reset View"
	reset_btn.position = Vector2(8.0, 8.0)
	reset_btn.pressed.connect(phase_graph._on_reset_view_pressed)
	graph_overlay.add_child(reset_btn)
	phase_graph.view_reset.connect(func() -> void:
		await get_tree().process_frame
		_graph_scroll.scroll_horizontal = int((phase_graph.size.x - _graph_scroll.size.x) / 2.0)
		_graph_scroll.scroll_vertical = int((phase_graph.size.y - _graph_scroll.size.y) / 2.0)
	)

	var unlock_all_btn := Button.new()
	unlock_all_btn.text = "Unlock All"
	unlock_all_btn.position = Vector2(8.0, 44.0)
	unlock_all_btn.pressed.connect(phase_graph.unlock_all)
	graph_overlay.add_child(unlock_all_btn)

	var zoom_in_btn := Button.new()
	zoom_in_btn.text = "+"
	zoom_in_btn.position = Vector2(8.0, 80.0)
	zoom_in_btn.custom_minimum_size = Vector2(32.0, 32.0)
	zoom_in_btn.pressed.connect(phase_graph.zoom_in)
	graph_overlay.add_child(zoom_in_btn)

	var zoom_out_btn := Button.new()
	zoom_out_btn.text = "-"
	zoom_out_btn.position = Vector2(44.0, 80.0)
	zoom_out_btn.custom_minimum_size = Vector2(32.0, 32.0)
	zoom_out_btn.pressed.connect(phase_graph.zoom_out)
	graph_overlay.add_child(zoom_out_btn)

	var hint_lbl := Label.new()
	hint_lbl.text = "Select two phases to add/remove a connection"
	hint_lbl.position = Vector2(8.0, 120.0)
	hint_lbl.add_theme_font_size_override("font_size", 12)
	hint_lbl.modulate = Color(1.0, 1.0, 1.0, 0.55)
	hint_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	graph_overlay.add_child(hint_lbl)

	# --- Context Menu ---
	context_menu = PopupMenu.new()
	context_menu.add_item("Edit", 0)
	context_menu.add_item("Archive", 1)
	context_menu.id_pressed.connect(_on_context_menu_id_pressed)
	add_child(context_menu)

	# --- Phase Dialog ---
	phase_dialog = PhaseDialogView.new()
	add_child(phase_dialog)
	phase_dialog.visible = false

	# ---- Instructions Tab ----
	var instructions_scroll := ScrollContainer.new()
	instructions_scroll.name = "Instructions"
	instructions_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	instructions_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_tabs.add_child(instructions_scroll)

	var instructions_margin := MarginContainer.new()
	instructions_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	instructions_margin.add_theme_constant_override("margin_left", 16)
	instructions_margin.add_theme_constant_override("margin_right", 16)
	instructions_margin.add_theme_constant_override("margin_top", 12)
	instructions_margin.add_theme_constant_override("margin_bottom", 12)
	instructions_scroll.add_child(instructions_margin)

	var instructions_vbox := VBoxContainer.new()
	instructions_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	instructions_vbox.add_theme_constant_override("separation", 12)
	instructions_margin.add_child(instructions_vbox)

	var _video_labels: Array[String] = [
		"Instructions:\n\nDefine the phases of your life and form connections between them.",  # mc_tutorial_1
		"Organize your photos in the folders.\nThis is hopefully how most people keep their photos organized.\nMemory Constellation also detects any folders inside the selected Memory Constellation folder, so if your photos are already sorted like this you can just drag in those folders.",  # mc_tutorial_2
		"Edit phases and lock them to form your unique constellation.",  # mc_tutorial_3
		"As you add more photo folders, the story of your life is shown in the constellation.",  # mc_tutorial_4
		"Step into your memories and design your story in 3D space.",  # mc_tutorial_5
		"Move around and resize your photos and notes to feel like you're back in that memory.",  # mc_tutorial_6
	]
	for i: int in range(1, 7):
		instructions_vbox.add_child(HSeparator.new())
		var video_lbl := RichTextLabel.new()
		video_lbl.bbcode_enabled = true
		video_lbl.fit_content = true
		video_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		video_lbl.scroll_active = false
		video_lbl.text = _video_labels[i - 1]
		instructions_vbox.add_child(video_lbl)
		instructions_vbox.add_child(_create_video_player("res://assets/tutorial/mc_tutorial_%d.ogv" % i))

	var instructions_label := RichTextLabel.new()
	instructions_label.bbcode_enabled = true
	instructions_label.fit_content = true
	instructions_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	instructions_label.scroll_active = false
	instructions_label.text = _build_instructions_text()
	instructions_vbox.add_child(instructions_label)

	# tab index 1 = Connections
	main_tabs.tab_changed.connect(func(tab: int) -> void:
		if tab == 1:
			await get_tree().create_timer(0.1).timeout
			phase_graph._on_reset_view_pressed()
	)

	# --- File Dialog ---
	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.dir_selected.connect(_on_folder_selected)
	add_child(_file_dialog)


# ---------------------------------------------------------------------------
# Presenter-facing display methods
# ---------------------------------------------------------------------------

func set_folder_loaded(path: String) -> void:
	folder_path_edit.text = path
	add_phase_btn.disabled = false
	open_folder_btn.disabled = false


func display_phases(active: Array[PhaseModel], archived: Array[PhaseModel]) -> void:
	for child in active_list.get_children():
		child.queue_free()
	for child in archived_list.get_children():
		child.queue_free()
	for phase: PhaseModel in active:
		active_list.add_child(_create_list_item(phase, false))
	for phase: PhaseModel in archived:
		archived_list.add_child(_create_list_item(phase, true))


func update_sort_direction_button(ascending: bool) -> void:
	sort_asc_btn.text = "↑ Ascending" if ascending else "↓ Descending"


func apply_session(sort_mode: int, sort_asc: bool, folder: String) -> void:
	sort_option.selected = sort_mode
	sort_asc_btn.text = "↑ Ascending" if sort_asc else "↓ Descending"
	if folder != "":
		folder_path_edit.text = folder
		add_phase_btn.disabled = false
		open_folder_btn.disabled = false


# ---------------------------------------------------------------------------
# Internal UI handlers
# ---------------------------------------------------------------------------

func _on_browse_pressed() -> void:
	if folder_path_edit.text != "":
		_file_dialog.current_dir = folder_path_edit.text
	_file_dialog.popup_centered(Vector2i(900, 600))


func _on_folder_selected(path: String) -> void:
	folder_path_edit.text = path
	folder_selected.emit(path)


func _show_context_menu(phase_name: String, is_archived: bool) -> void:
	_context_phase_name = phase_name
	_context_is_archived = is_archived
	context_menu.set_item_text(1, "Unarchive" if is_archived else "Archive")
	if get_viewport().is_embedding_subwindows():
		context_menu.position = Vector2i(get_viewport().get_mouse_position())
	else:
		context_menu.position = DisplayServer.mouse_get_position()
	context_menu.popup()


func _on_context_menu_id_pressed(id: int) -> void:
	match id:
		0:  context_edit_requested.emit(_context_phase_name)
		1:  context_archive_requested.emit(_context_phase_name, _context_is_archived)


func _build_instructions_text() -> String:
	return """[b]Desktop — Configuration Tool[/b]

[b]Setup[/b]
Click [b]Browse...[/b] to select your MemoryConstellation folder. Each sub-folder becomes a phase and is scanned automatically for photos and notes.

[b]Phases Tab[/b]
• [b]+ Add Phase[/b] — creates a new phase folder and config file.
• [b]Right-click[/b] a phase to Edit its name, color, dates, or playlist link, or to Archive / Unarchive it.
• [b]Sort[/b] the list by name, date, photo count, or connection count; toggle ascending/descending.
• [b]Refresh[/b] re-scans the folder from disk (useful after copying in new photos externally).

[b]Connections Tab — Phase Graph[/b]
• [b]Left-click[/b] a node to select it, then [b]left-click[/b] a second node to add or remove the connection between them.
• [b]Left-click drag[/b] a node to reposition it.
• [b]Right-click[/b] a node to lock or unlock it (locked nodes show a gold ring and are excluded from physics).
• [b]Middle-click drag[/b] to pan the canvas.
• [b]+ / −[/b] buttons or scroll wheel to zoom in and out.
• [b]Reset View[/b] fits all nodes into the visible area.
• [b]Unlock All[/b] releases all locked nodes.
• Node positions and lock state are saved automatically when you drag or unlock.

---

[b]VR — Constellation View[/b]

Look around to see all your phases as glowing spheres arranged by year.
• [b]Enter a phase:[/b] Point at a sphere and [b]hold the trigger for 1 second[/b].

---

[b]VR — Phase Ground View[/b]

Browse the photos and notes inside a phase. Photos and notes are grabbable objects you can arrange in 3D space.

[b]Edit Mode[/b]
• [b]Toggle edit mode:[/b] Press [b]A / X[/b] (left hand) or [b]B / Y[/b] (right hand). Edit mode must be active to move photos and notes.

[b]Grabbing — Remote (distance)[/b]
• [b]Single-hand remote grab:[/b] In edit mode, aim at a photo or note and hold [b]Grip[/b]. The item follows the aim ray. Release Grip to drop.
• [b]Two-hand remote grab:[/b] Grab with one hand, then aim the other and grip. The item rotates and scales to match your hands. Spread apart to scale up, pinch to scale down.

[b]Grabbing — Physical (close range)[/b]
• Reach your hand close to a photo or note — grab handles appear at the corners.
• Hold [b]Grip[/b] to pick it up. Release to drop.
• [b]Two-hand physical scale:[/b] Grip with both hands simultaneously, then spread or pinch to resize.

[b]Navigation[/b]
• [b]Go to a connected phase:[/b] Point at a directional portal at the edge of the space and [b]hold the trigger for 1 second[/b]. Your changes are saved automatically.
• [b]Return to constellation:[/b] Point at the [b]Return to Constellation[/b] portal and hold for 1 second. Changes are saved.
• [b]Exit without saving:[/b] Point at [b]Cancel Changes[/b] and hold for 1 second.
• [b]Reset photo positions:[/b] Point at [b]Reset Positions[/b] and hold for 1 second. Photos return to their default arc layout (notes are unaffected)."""


func _create_video_player(path: String) -> AspectRatioContainer:
	var aspect := AspectRatioContainer.new()
	aspect.ratio = 16.0 / 9.0
	aspect.stretch_mode = AspectRatioContainer.STRETCH_WIDTH_CONTROLS_HEIGHT
	aspect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	aspect.custom_minimum_size = Vector2(640 * 2.5, 480 * 2) 

	var player := VideoStreamPlayer.new()
	player.stream = load(path)
	player.autoplay = true
	player.loop = true
	player.expand = true
	aspect.add_child(player)

	return aspect


func _create_list_item(phase: PhaseModel, is_archived: bool) -> Control:
	var item := PanelContainer.new()
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.tooltip_text = "Right-click to Edit / Archive"

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	item.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	margin.add_child(hbox)

	# Colored dot
	var dot_wrap := CenterContainer.new()
	dot_wrap.custom_minimum_size = Vector2(22, 22)
	hbox.add_child(dot_wrap)

	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(16, 16)
	var dot_style := StyleBoxFlat.new()
	dot_style.bg_color = Color(phase.color)
	dot_style.corner_radius_top_left = 8
	dot_style.corner_radius_top_right = 8
	dot_style.corner_radius_bottom_left = 8
	dot_style.corner_radius_bottom_right = 8
	dot.add_theme_stylebox_override("panel", dot_style)
	if is_archived:
		dot.modulate = Color(0.5, 0.5, 0.5, 0.7)
	dot_wrap.add_child(dot)

	# Phase name
	var name_lbl := Label.new()
	name_lbl.text = phase.phase_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if is_archived:
		name_lbl.modulate = Color(0.6, 0.6, 0.6)
	hbox.add_child(name_lbl)

	# Outgoing connection count
	var conn_count: int = phase.connections.size()
	if conn_count > 0:
		var conn_lbl := Label.new()
		conn_lbl.text = "→ %d" % conn_count
		conn_lbl.custom_minimum_size = Vector2(40, 0)
		conn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		conn_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hbox.add_child(conn_lbl)

	# Photo count
	var count_lbl := Label.new()
	count_lbl.text = "%d photo%s" % [phase.photo_count, "" if phase.photo_count == 1 else "s"]
	count_lbl.custom_minimum_size = Vector2(90, 0)
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(count_lbl)

	# Date range
	var date_lbl := Label.new()
	date_lbl.text = phase.start_date + (" - ongoing" if phase.end_date.is_empty() else " - " + phase.end_date)
	date_lbl.custom_minimum_size = Vector2(230, 0)
	date_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	date_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(date_lbl)

	# Right-click handler
	var captured_name: String = phase.phase_name
	var captured_archived: bool = is_archived
	item.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				_show_context_menu(captured_name, captured_archived)
	)

	return item
