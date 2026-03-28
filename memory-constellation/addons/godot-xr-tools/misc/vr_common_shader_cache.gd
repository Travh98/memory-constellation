extends Node3D

## Seems like this loads the shaders so they are ready to be used

signal cooldown_finished

var countdown: int = 2


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float):
	countdown = countdown - 1
	if countdown == 0:
		visible = false
		set_process(false)
		cooldown_finished.emit()
