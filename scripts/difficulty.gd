extends Node2D

func _ready() -> void:
	# "intermidiate" is the exact node name in difficulty.tscn (note the typo)
	$diffbg/intermidiate.pressed.connect(_on_interm_pressed)
	$diffbg/advance.pressed.connect(_on_advance_pressed)

func _on_interm_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/intermediatemode.tscn")

func _on_advance_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/advancedmode.tscn")
