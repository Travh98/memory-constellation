extends Node

# Global singleton — shared instances of model and repository.
# Register this script as an autoload named "GlobalCollections" in Project Settings.

signal gamemode_changed(new_mode: GameModes.GAME_MODES, do_save: bool)
signal reset_current_phase_photo_positions()
@warning_ignore("unused_signal")
signal player_origin_reset

var constellation_model: ConstellationModel = ConstellationModel.new()
var phase_repository: PhaseRepository = PhaseRepository.new()
var game_modes_node: GameModes


func set_gamemode(new_mode: GameModes.GAME_MODES, do_save: bool) -> void:
	gamemode_changed.emit(new_mode, do_save)


func reset_phase_photo_positions():
	reset_current_phase_photo_positions.emit()
