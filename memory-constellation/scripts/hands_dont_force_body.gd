extends Node

@export var hand_l: AnimatableBody3D
@export var hand_r: AnimatableBody3D
@export var body: CharacterBody3D

func _ready():
	if hand_l == null:
		push_warning("Hands Dont Force Body missing left hand")
		return
	if hand_r == null:
		push_warning("Hands Dont Force Body missing right hand")
		return
	hand_l.add_collision_exception_with(body)
	hand_r.add_collision_exception_with(body)
	print("Disable collision with hands to body")
