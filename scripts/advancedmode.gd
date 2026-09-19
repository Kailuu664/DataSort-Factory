extends Node2D

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		if FileAccess.file_exists("user://progress.dat"):
			DirAccess.remove_absolute("user://progress.dat")
		print("Progress reset!")
		get_tree().reload_current_scene()
