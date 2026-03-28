extends Node3D

@onready var _origin: XROrigin3D = $XROrigin3D


func _ready() -> void:
	GlobalCollections.player_origin_reset.connect(_on_player_origin_reset)


func _on_player_origin_reset() -> void:
	_origin.position = Vector3.ZERO
