extends Node3D

## Allows returning to constellation

@onready var _hold_button: XRToolsHoldButton = $HoldButton
@onready var _pointer_body: StaticBody3D = $PointerBody


func _ready() -> void:
	_pointer_body.pointer_event.connect(_on_pointer_event)
	_hold_button.pressed.connect(_on_hold_complete)


func _on_pointer_event(event: XRToolsPointerEvent) -> void:
	match event.event_type:
		XRToolsPointerEvent.Type.PRESSED:
			_hold_button.set_enabled(true)
		XRToolsPointerEvent.Type.RELEASED:
			_hold_button.set_enabled(false)


func _on_hold_complete() -> void:
	GlobalCollections.set_gamemode(GameModes.GAME_MODES.CONSTELLATION_VIEW, true)
