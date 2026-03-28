class_name GameModes
extends Node3D

@onready var constellation_view: ConstellationView = $ConstellationView
@onready var phase_ground_view: PhaseGroundView = $PhaseGroundView

const FAR_DIST: int = 500

enum GAME_MODES
{
	CONSTELLATION_VIEW,
	PHASE_GROUND_VIEW,
}


func _ready():
	if GlobalCollections.game_modes_node != null:
		push_warning("GameModes node already exists?")
		pass
	GlobalCollections.game_modes_node = self
	
	GlobalCollections.gamemode_changed.connect(on_gamemode_set)
	on_gamemode_set(GAME_MODES.CONSTELLATION_VIEW, false)
	


func on_gamemode_set(new_mode: GAME_MODES, do_save: bool) -> void:
	phase_ground_view.unload_phase(do_save)
	hide_gamemodes()
	GlobalCollections.player_origin_reset.emit()
	match new_mode:
		GAME_MODES.CONSTELLATION_VIEW:
			show_gamemode(constellation_view)
		GAME_MODES.PHASE_GROUND_VIEW:
			if GlobalCollections.constellation_model.selected_phase == null:
				push_warning("GameModes: cannot enter PHASE_GROUND_VIEW, selected_phase is null")
				show_gamemode(constellation_view)
				return
			phase_ground_view.load_phase(GlobalCollections.constellation_model.selected_phase)
			show_gamemode(phase_ground_view)


func hide_gamemodes() -> void:
	hide_gamemode(constellation_view)
	hide_gamemode(phase_ground_view)


func show_gamemode(gamemode_node: Node3D):
	gamemode_node.visible = true
	gamemode_node.position = Vector3.ZERO


func hide_gamemode(gamemode_node: Node3D):
	gamemode_node.visible = false
	gamemode_node.position = Vector3.ZERO - Vector3.UP * FAR_DIST
