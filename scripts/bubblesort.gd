extends Node2D

@onready var crates            = [$"30c", $"40c", $"20c", $"10c"]
@onready var swapbtn           = $swapbtn
@onready var hintbtn           = $hintbtn
@onready var resetbtn          = $resetbtn
@onready var undobtn           = $undobtn
@onready var claw              = $Claw
@onready var claw_anim         = $Claw/Anim
@onready var cable             = $Claw/Cable
@onready var machine           = $ProcessingMachine

const RAIL_Y = 27.0

func _process(_delta: float) -> void:
	if claw.visible:
		var local_top = (RAIL_Y - claw.global_position.y) / claw.scale.y
		cable.points = PackedVector2Array([Vector2(0, local_top), Vector2(0, 0)])

@onready var instruction_popup = $Howtoplaybtn/Instruction
@onready var instruction_label = $InstructionLabel
@onready var here_label        = $Label
@onready var star1             = $Winpoint/Panel/HBoxContainer/"1star"
@onready var moves_label       = $Winpoint/Panel/moves
@onready var efficiency_label  = $Winpoint/Panel/efficiency
@onready var retrybtn          = $Winpoint/Panel/retrybtn
@onready var mainmenubtn       = $Winpoint/Panel/mainmenubtn
@onready var nextlevelbtn      = $Winpoint/Panel/nextlevelbtn
@onready var redflash          = $RedFlash/ColorRect
@onready var fail_moves_label  = $Failpoint/Panel/moves
@onready var failretrybtn      = $Failpoint/Panel/retrybtn
@onready var failmenubtn       = $Failpoint/Panel/mainmenubtn

const STAR_1 = preload("res://assets/ui/stars_1.png")
const STAR_2 = preload("res://assets/ui/stars_2.png")
const STAR_3 = preload("res://assets/ui/stars_3.png")

var values       = [30, 40, 20, 10]
var history      = []
var is_animating = false
var sel_a        = -1
var sel_b        = -1
var move_count   = 0

const CLAW_UP    = 220
const CLAW_DOWN  = 430
const BASE_ANIM_SPEED = 0.6
var   ANIM_SPEED       = BASE_ANIM_SPEED


func _ready():
	instruction_popup.visible = false
	$Winpoint.visible         = false
	$Failpoint.visible        = false
	redflash.modulate.a       = 0.0
	claw.visible              = false
	here_label.visible        = false

	swapbtn.pressed.connect(_on_swap)
	hintbtn.pressed.connect(_on_hint)
	resetbtn.pressed.connect(_on_end)
	undobtn.pressed.connect(_on_undo)
	$Howtoplaybtn.pressed.connect(_on_howtoplay)
	retrybtn.pressed.connect(_on_reset)
	mainmenubtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/menu.tscn"))
	nextlevelbtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/easymode.tscn"))
	failretrybtn.pressed.connect(_on_reset)
	failmenubtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/menu.tscn"))

	for i in range(crates.size()):
		var node = crates[i]
		crates[i].pressed.connect(func(): _select(crates.find(node)))

	_update_instruction_text()
	machine.setup(values, [10, 20, 30, 40])


	_apply_settings()
func _on_howtoplay():
	instruction_popup.visible = !instruction_popup.visible


func _select(idx: int):
	if is_animating or idx == -1:
		return

	# Deselect A
	if idx == sel_a:
		_set_highlight(sel_a, false)
		sel_a = -1
		if sel_b != -1:
			_set_highlight(sel_b, false)
			sel_b = -1
		claw.visible = false
		_update_instruction_text()
		return

	# Deselect B
	if idx == sel_b:
		_set_highlight(sel_b, false)
		sel_b = -1
		_update_instruction_text()
		return

	# First selection
	if sel_a == -1:
		sel_a = idx
		_set_highlight(idx, true)
		claw.visible = true
		claw_anim.play("open")
		claw.position = Vector2(_cx(crates[idx]), CLAW_UP)
		_show_instruction("📦 Crate " + str(values[idx]) + " selected! Now tap an adjacent crate to compare.")
		return

	# Second selection — enforce adjacency
	if sel_b == -1:
		if abs(idx - sel_a) != 1:
			_show_error("Only adjacent crates can be compared and swapped!")
			return
		sel_b = idx
		_set_highlight(idx, true)
		var a_val = values[sel_a]
		var b_val = values[sel_b]
		if a_val > b_val:
			_show_instruction("⚠️ Crate " + str(a_val) + " > Crate " + str(b_val) + " — press SWAP to fix the order!")
		else:
			_show_instruction("✅ Crate " + str(a_val) + " < Crate " + str(b_val) + " — already in order! Try another pair.")
		_update_instruction_text()


func _on_swap():
	if is_animating or sel_a == -1 or sel_b == -1:
		_show_error("Select two adjacent crates first before swapping!")
		return

	# Double-check adjacency (safety guard)
	if abs(sel_a - sel_b) != 1:
		_show_error("Only adjacent crates can be swapped!")
		_set_highlight(sel_a, false)
		_set_highlight(sel_b, false)
		sel_a = -1
		sel_b = -1
		claw.visible = false
		return

	var a_val = values[sel_a]
	var b_val = values[sel_b]
	_show_instruction("🔄 Swapping crate " + str(a_val) + " and crate " + str(b_val) + "...")
	move_count += 1
	history.append({
		"values":    values.duplicate(),
		"positions": crates.map(func(c): return c.position),
		"order":     crates.duplicate()
	})
	_animate(sel_a, sel_b)


func _animate(a: int, b: int):
	is_animating = true
	var tween = create_tween()
	tween.tween_property(claw, "position", Vector2(_cx(crates[a]), CLAW_DOWN), ANIM_SPEED)
	tween.tween_callback(func(): claw_anim.play("grip"))
	tween.tween_property(claw, "position:y", CLAW_UP, ANIM_SPEED)
	tween.tween_property(claw, "position:x", _cx(crates[b]), ANIM_SPEED)
	tween.tween_property(claw, "position:y", CLAW_DOWN, ANIM_SPEED)
	tween.tween_callback(func():
		claw_anim.play("open")
		var tv = values[a]; values[a] = values[b]; values[b] = tv
		var tp = crates[a].position; crates[a].position = crates[b].position; crates[b].position = tp
		var tn = crates[a]; crates[a] = crates[b]; crates[b] = tn
	)
	tween.tween_property(claw, "position:y", CLAW_UP, ANIM_SPEED)
	tween.tween_callback(func():
		is_animating = false
		_set_highlight(a, false)
		_set_highlight(b, false)
		sel_a = -1
		sel_b = -1
		claw.visible = false
		_show_instruction("✅ Swap done! Check for any remaining out-of-order pairs.")
		machine.report_placement(values)
		if _is_sorted():
			_win()
		else:
			_update_instruction_text()
	)


func _on_hint():
	if is_animating:
		return
	for i in range(values.size() - 1):
		if values[i] > values[i + 1]:
			here_label.position.x = _cx(crates[i]) - here_label.size.x * 0.5
			here_label.visible = true
			_show_instruction("💡 Hint: Crate " + str(values[i]) + " and Crate " + str(values[i+1]) + " are out of order — swap them!")
			await get_tree().create_timer(2.0).timeout
			here_label.visible = false
			_set_highlight(sel_a, false)
			_set_highlight(sel_b, false)
			sel_a = i
			sel_b = i + 1
			_set_highlight(sel_a, true)
			_set_highlight(sel_b, true)
			claw.visible = true
			claw_anim.play("open")
			claw.position = Vector2(_cx(crates[sel_a]), CLAW_UP)
			return
	_show_instruction("🎉 Everything looks sorted already!")


func _on_reset():
	get_tree().reload_current_scene()


func _on_end() -> void:
	if is_animating:
		return
	swapbtn.disabled  = true
	hintbtn.disabled  = true
	undobtn.disabled  = true
	resetbtn.disabled = true
	claw.visible      = false

	redflash.visible = true
	var tween = create_tween()
	tween.tween_property(redflash, "modulate:a", 0.75, 0.12)
	tween.tween_property(redflash, "modulate:a", 0.0,  0.12)
	tween.tween_property(redflash, "modulate:a", 0.75, 0.12)
	tween.tween_property(redflash, "modulate:a", 0.0,  0.12)
	tween.tween_property(redflash, "modulate:a", 0.75, 0.12)
	tween.tween_property(redflash, "modulate:a", 0.0,  0.12)
	tween.tween_callback(func():
		redflash.visible         = false
		fail_moves_label.text    = "MOVES : " + str(move_count)
		$Failpoint.visible       = true
		$Failpoint/Panel.visible = true
	)


func _on_undo():
	if is_animating or history.is_empty():
		return
	var last = history.pop_back()
	values = last["values"]
	crates = last["order"]
	for i in range(crates.size()):
		crates[i].position = last["positions"][i]
	sel_a = -1
	sel_b = -1
	for i in range(crates.size()):
		_set_highlight(i, false)
	claw.visible     = false
	swapbtn.disabled = false
	hintbtn.disabled = false
	_show_instruction("↩️ Undo! Last swap reverted.")
	machine.report_placement(values)
	_update_instruction_text()


func _set_highlight(idx: int, on: bool):
	if idx < 0 or idx >= crates.size():
		return
	crates[idx].modulate = Color(1.5, 1.2, 0.3) if on else Color(1, 1, 1)


func _cx(crate: Control) -> float:
	return crate.position.x + crate.size.x * 0.5


func _update_instruction_text():
	if sel_a == -1 and sel_b == -1:
		instruction_label.text = "Tap a crate, then tap its neighbor to compare — only adjacent crates can be swapped!"
	elif sel_a != -1 and sel_b == -1:
		instruction_label.text = "Good! Now tap a crate directly next to crate " + str(values[sel_a]) + " to compare."
	elif sel_a != -1 and sel_b != -1:
		var a_val = values[sel_a]
		var b_val = values[sel_b]
		if a_val > b_val:
			instruction_label.text = str(a_val) + " > " + str(b_val) + " — out of order! Press SWAP."
		else:
			instruction_label.text = str(a_val) + " < " + str(b_val) + " — already in order. Try another pair."


func _show_instruction(msg: String):
	instruction_label.text     = msg
	instruction_label.modulate = Color(0.3, 0.85, 1)


func _show_error(msg: String):
	instruction_label.text     = "❌ " + msg
	instruction_label.modulate = Color(1, 0.3, 0.3)
	await get_tree().create_timer(2.0).timeout
	instruction_label.modulate = Color(0.3, 0.85, 1)
	_update_instruction_text()



# ── Settings loader (reads user://settings.dat on every level load) ────────────
func _apply_settings() -> void:
	const PATH = "user://settings.dat"
	if not FileAccess.file_exists(PATH):
		return
	var file   = FileAccess.open(PATH, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		return

	# ── Crane animation speed ──────────────────────────────────────────────────
	var speed_setting = int(parsed.get("anim_speed", 0))
	match speed_setting:
		0: ANIM_SPEED = BASE_ANIM_SPEED          # Normal
		1: ANIM_SPEED = BASE_ANIM_SPEED * 0.4    # Fast
		2: ANIM_SPEED = 0.001                     # Instant (near-zero, tweens still complete)

	# ── Hint mode (instruction label visibility) ───────────────────────────────
	var hint_on = bool(parsed.get("hint_mode", true))
	if instruction_label:
		instruction_label.visible = hint_on

	# ── Brightness (CanvasModulate added dynamically) ──────────────────────────
	var brightness = float(parsed.get("brightness", 1.0))
	if not has_node("SettingsBrightness"):
		var cm      = CanvasModulate.new()
		cm.name     = "SettingsBrightness"
		cm.color    = Color(brightness, brightness, brightness, 1.0)
		add_child(cm)
	else:
		$SettingsBrightness.color = Color(brightness, brightness, brightness, 1.0)

	# ── Audio ─────────────────────────────────────────────────────────────────
	var music_vol = float(parsed.get("music_volume", 1.0))
	var mute_all  = bool(parsed.get("mute_all",    false))
	for i in range(AudioServer.bus_count):
		AudioServer.set_bus_mute(i, mute_all)
	if not mute_all:
		var music_bus = AudioServer.get_bus_index("Music")
		if music_bus == -1: music_bus = 0
		AudioServer.set_bus_volume_db(music_bus, linear_to_db(music_vol))
		var sfx_bus = AudioServer.get_bus_index("SFX")
		if sfx_bus != -1:
			AudioServer.set_bus_volume_db(sfx_bus,
				linear_to_db(float(parsed.get("sfx_volume", 1.0))))


func _is_sorted() -> bool:
	var sorted = [10, 20, 30, 40]
	for i in range(values.size()):
		if values[i] != sorted[i]:
			return false
	return true


func _win():
	swapbtn.disabled = true
	hintbtn.disabled = true

	var progress = {}
	if FileAccess.file_exists("user://progress.dat"):
		var file   = FileAccess.open("user://progress.dat", FileAccess.READ)
		var parsed = JSON.parse_string(file.get_as_text())
		file.close()
		if parsed != null and typeof(parsed) == TYPE_DICTIONARY:
			progress = parsed

	progress["bubble_done"] = true
	var save = FileAccess.open("user://progress.dat", FileAccess.WRITE)
	save.store_string(JSON.stringify(progress))
	save.close()

	if move_count <= 4:
		star1.texture         = STAR_3
		efficiency_label.text = "EFFICIENCY REMAINING : HIGH"
	elif move_count <= 7:
		star1.texture         = STAR_2
		efficiency_label.text = "EFFICIENCY REMAINING : MEDIUM"
	else:
		star1.texture         = STAR_1
		efficiency_label.text = "EFFICIENCY REMAINING : LOW"

	moves_label.text        = "MOVES : " + str(move_count)
	$Winpoint.visible       = true
	$Winpoint/Panel.visible = true
