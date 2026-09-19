extends Node2D

func _ready():
	var progress = {}

	if FileAccess.file_exists("user://progress.dat"):
		var file = FileAccess.open("user://progress.dat", FileAccess.READ)
		var parsed = JSON.parse_string(file.get_as_text())
		file.close()
		if parsed != null and typeof(parsed) == TYPE_DICTIONARY:
			progress = parsed

	# Unlock Selection Sort if bubble is done
	if progress.get("bubble_done", false):
		$diffbg/selection.disabled = false
	else:
		$diffbg/selection.disabled = true

	# Unlock Insertion Sort if selection is done
	if progress.get("selection_done", false):
		$diffbg/insertion.disabled = false
	else:
		$diffbg/insertion.disabled = true

	# Connect insertion button to its scene
	if not $diffbg/insertion.pressed.is_connected(_on_insertion_pressed):
		$diffbg/insertion.pressed.connect(_on_insertion_pressed)


func _on_insertion_pressed():
	get_tree().change_scene_to_file("res://scenes/insertionsort.tscn")


func _input(event):
	# Press R to reset progress (remove this before releasing the game!)
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			if FileAccess.file_exists("user://progress.dat"):
				DirAccess.remove_absolute("user://progress.dat")
			print("Progress reset!")
			get_tree().reload_current_scene()
