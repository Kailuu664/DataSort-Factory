extends Button

func _ready() -> void:
	_check_lock()

func _check_lock() -> void:
	var progress = {}
	if FileAccess.file_exists("user://progress.dat"):
		var file   = FileAccess.open("user://progress.dat", FileAccess.READ)
		var parsed = JSON.parse_string(file.get_as_text())
		file.close()
		if parsed != null and typeof(parsed) == TYPE_DICTIONARY:
			progress = parsed
	disabled = not progress.get("quick_done", false)

func _on_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/heapsort.tscn")
