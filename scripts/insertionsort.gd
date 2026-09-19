extends Node2D

# Crates in starting display order (left → right): [40, 10, 30, 60, 20, 50]
# sorted_count starts at 1 — the leftmost crate is already "sorted"
@onready var crates            = [$"40c", $"10c", $"30c", $"60c", $"20c", $"50c"]
@onready var swapbtn           = $swapbtn       # repurposed: SLIDE LEFT
@onready var hintbtn           = $hintbtn
@onready var resetbtn          = $resetbtn
@onready var undobtn           = $undobtn
@onready var claw              = $Claw
@onready var claw_anim         = $Claw/Anim
@onready var cable             = $Claw/Cable
@onready var machine           = $ProcessingMachine   # ← processing machine

const RAIL_Y = 27.0   # world-space Y of the rail

func _process(_delta: float) -> void:
	if claw.visible:
		var local_top = (RAIL_Y - claw.global_position.y) / claw.scale.y
		cable.points = PackedVector2Array([Vector2(0, local_top), Vector2(0, 0)])
@onready var here_label        = $Label
@onready var instruction_label = $InstructionLabel
@onready var instruction_popup = $Howtoplaybtn/Instruction
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

var values       = [40, 10, 30, 60, 20, 50]
var history      = []
var is_animating = false
var selected     = -1
var move_count   = 0
var sorted_count = 1

const CLAW_UP    = 220
const CLAW_DOWN  = 430
const BASE_ANIM_SPEED = 0.35
var   ANIM_SPEED       = BASE_ANIM_SPEED


func _ready():
	instruction_popup.visible = false
	$Winpoint.visible         = false
	$Failpoint.visible        = false
	redflash.modulate.a       = 0.0
	claw.visible              = false
	here_label.visible        = false

	swapbtn.pressed.connect(_on_slide)
	hintbtn.pressed.connect(_on_hint)
	resetbtn.pressed.connect(_on_end)
	undobtn.pressed.connect(_on_undo)
	$Howtoplaybtn.pressed.connect(_on_howtoplay)
	retrybtn.pressed.connect(_on_reset)
	mainmenubtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/easymode.tscn"))
	nextlevelbtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/easymode.tscn"))
	failretrybtn.pressed.connect(_on_reset)
	failmenubtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/menu.tscn"))

	for i in range(crates.size()):
		var node = crates[i]
		node.pressed.connect(func(): _on_crate_tapped(crates.find(node)))

	_lock_crate(0)
	_auto_lock()
	_refresh_ui()

	# ── Processing Machine setup ──────────────────────────────────────────────
	machine.setup(values, [10, 20, 30, 40, 50, 60])


	_apply_settings()
func _on_howtoplay():
	instruction_popup.visible = !instruction_popup.visible


# ── Crate tap ────────────────────────────────────────────────────────────────
func _on_crate_tapped(idx: int):
	if is_animating:
		return

	# Locked crates can't be selected
	if idx < sorted_count:
		_show_error("This crate is already locked in place!")
		return

	# Tapping the same held crate → try to LOCK it in place
	if selected == idx:
		_try_lock_selected()
		return

	# Tapping a different crate while holding one → drop current, pick up new
	if selected != -1:
		_set_highlight(selected, false)

	selected = idx
	_set_highlight(idx, true)
	claw.visible = true
	claw.position = Vector2(_cx(crates[idx]), CLAW_UP)
	claw_anim.play("open")
	_show_instruction("📦 Crate " + str(values[idx]) + " picked up! Slide it left with SWAP, then tap it again to lock.")
	_refresh_ui()


# ── Try to lock the currently held crate ─────────────────────────────────────
# The player tapped the held crate again to confirm placement.
# Rules:
#   1. Can't lock if left neighbor is still larger (must slide further left first)
#   2. Can't lock if right neighbor is smaller (crate jumped too far left — it's
#      blocking a value that should be to its left)
#   3. Must be the next crate in sorted sequence
func _try_lock_selected():
	var idx = selected
	var val = values[idx]

	# Rule 1: left neighbor is larger → must slide further left
	if idx > 0 and values[idx - 1] > val:
		_show_error("Can't lock — the crate on the left is bigger, keep sliding!")
		return

	# Rule 2: right neighbor is smaller → slid too far, wrong position
	var right_idx = idx + 1
	if right_idx < crates.size() and right_idx >= sorted_count and values[right_idx] < val:
		_show_error("The crate on the right is smaller — you went too far left!")
		return

	# Rule 3: must be the next in sorted order (sorted_count)
	if idx != sorted_count:
		_show_error("Sort in order! You need to place the crate at position " + str(sorted_count + 1) + " first.")
		return

	# All checks pass — lock it in
	_show_instruction("🔒 Crate " + str(val) + " locked in place!")
	_set_highlight(idx, false)
	claw_anim.play("open")
	_lock_crate(idx)
	sorted_count += 1
	selected = -1
	claw.visible = false
	_auto_lock()
	# ── Report to machine after every lock ────────────────────────────────────
	machine.report_placement(values)
	_refresh_ui()
	if _is_sorted():
		_win()


# ── Slide left ───────────────────────────────────────────────────────────────
func _on_slide():
	if is_animating:
		return
	if selected == -1:
		_show_error("Pick up a crate first!")
		return
	if selected == 0:
		_show_error("Already at the leftmost position — can't slide further!")
		return
	if values[selected - 1] <= values[selected]:
		# Left neighbor is already smaller — sliding would be wrong
		# But the player still has to confirm placement by tapping the crate
		_show_error("Can't slide left — crate " + str(values[selected - 1]) + " on the left is already smaller. Tap this crate again to lock it if it's in the right spot!")
		return

	history.append({
		"values":       values.duplicate(),
		"positions":    crates.map(func(c): return c.position),
		"order":        crates.duplicate(),
		"sorted_count": sorted_count,
		"selected":     selected
	})

	move_count += 1
	_show_instruction("⬅️ Sliding crate " + str(values[selected]) + " left past " + str(values[selected - 1]) + "...")
	_animate_slide(selected, selected - 1)


func _animate_slide(from_idx: int, to_idx: int):
	is_animating = true
	var tween = create_tween()

	# Grip to show claw is holding the crate
	claw_anim.play("grip")
	tween.tween_property(claw, "position:x", _cx(crates[to_idx]), ANIM_SPEED)

	tween.tween_callback(func():
		var tv = values[from_idx]
		values[from_idx] = values[to_idx]
		values[to_idx]   = tv

		var tp = crates[from_idx].position
		crates[from_idx].position = crates[to_idx].position
		crates[to_idx].position   = tp

		var tn = crates[from_idx]
		crates[from_idx] = crates[to_idx]
		crates[to_idx]   = tn

		selected = to_idx
	)

	tween.tween_callback(func():
		is_animating = false
		# ── Report to machine after every slide ───────────────────────────────
		machine.report_placement(values)
		# ── Auto-finish: if the last crate slid into its correct spot ───────────
		if _is_sorted():
			_lock_crate(selected)
			sorted_count = crates.size()
			selected = -1
			claw.visible = false
			_win()
			return
		if selected == 0 or values[selected - 1] <= values[selected]:
			_show_instruction("✋ Crate " + str(values[selected]) + " can't slide further left. Tap it again to lock it if it's in the right spot!")
		else:
			_show_instruction("⬅️ Crate " + str(values[selected]) + " can still slide left past " + str(values[selected - 1]) + ". Keep sliding or tap to lock.")
		_refresh_ui()
	)


func _auto_lock():
	# Only auto-lock crates that are provably in the right position with no
	# player decision needed: value >= left neighbor AND value <= right neighbor
	while sorted_count < crates.size():
		var idx = sorted_count
		var left_ok  = (idx == 0 or values[idx] >= values[idx - 1])
		var right_ok = (idx == crates.size() - 1 or values[idx] <= values[idx + 1])
		if left_ok and right_ok:
			_lock_crate(idx)
			sorted_count += 1
		else:
			break


func _lock_crate(idx: int):
	crates[idx].modulate = Color(1.5, 1.2, 0.0)
	crates[idx].disabled = true


# ── Hint ─────────────────────────────────────────────────────────────────────
func _on_hint():
	if is_animating:
		return

	if sorted_count < crates.size():
		here_label.position.x = _cx(crates[sorted_count]) - here_label.size.x * 0.5
		here_label.visible = true
		_show_instruction("💡 Hint: Work on crate " + str(values[sorted_count]) + " next — pick it up and slide it to its correct spot!")
		await get_tree().create_timer(2.0).timeout
		here_label.visible = false

	if selected == -1:
		if sorted_count < crates.size():
			_set_highlight(sorted_count, true)
			await get_tree().create_timer(0.5).timeout
			if selected == -1:
				_set_highlight(sorted_count, false)
		return

	if selected > 0 and values[selected - 1] > values[selected]:
		var left = selected - 1
		crates[left].modulate = Color(0.3, 1.5, 0.5)
		await get_tree().create_timer(0.5).timeout
		if left >= sorted_count and left != selected:
			crates[left].modulate = Color(1, 1, 1)


# ── Reset ─────────────────────────────────────────────────────────────────────
func _on_reset():
	get_tree().reload_current_scene()


func _on_end() -> void:
	is_animating      = false
	selected          = -1
	swapbtn.disabled  = true
	hintbtn.disabled  = true
	undobtn.disabled  = true
	resetbtn.disabled = true
	claw.visible      = false

	for i in range(crates.size()):
		crates[i].modulate = Color(1, 1, 1)
		crates[i].disabled = false

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


# ── Undo ──────────────────────────────────────────────────────────────────────
func _on_undo():
	if is_animating or history.is_empty():
		return
	var last     = history.pop_back()
	values       = last["values"]
	crates       = last["order"]
	sorted_count = last["sorted_count"]
	selected     = last["selected"]

	for i in range(crates.size()):
		crates[i].position = last["positions"][i]
		if i < sorted_count:
			_lock_crate(i)
		else:
			crates[i].modulate = Color(1, 1, 1)
			crates[i].disabled = false

	if selected != -1:
		_set_highlight(selected, true)
		claw.visible  = true
		claw.position = Vector2(_cx(crates[selected]), CLAW_UP)
	else:
		claw.visible = false

	_show_instruction("↩️ Undo! Last move reverted.")
	# ── Report to machine after undo ──────────────────────────────────────────
	machine.report_placement(values)
	_refresh_ui()


# ── Helpers ────────────────────────────────────────────────────────────────────
func _set_highlight(idx: int, on: bool):
	if idx < 0 or idx >= crates.size():
		return
	if on:
		crates[idx].modulate = Color(1.5, 1.2, 0.3)
	else:
		crates[idx].modulate = Color(1, 1, 1)

# Returns the horizontal center of a crate (Control nodes report top-left via .position)
func _cx(crate: Control) -> float:
	return crate.position.x + crate.size.x * 0.5


func _refresh_ui():
	for i in range(crates.size()):
		if i < sorted_count:
			crates[i].disabled = true
		else:
			crates[i].disabled = false

	# SWAP (slide left) only enabled when holding a crate AND left neighbor is larger
	swapbtn.disabled = not (selected != -1 and selected > 0 and values[selected - 1] > values[selected])

	here_label.visible = false
	_update_instruction_text()


func _update_instruction_text():
	if sorted_count >= crates.size():
		instruction_label.text = "✅ All crates sorted!"
		return

	if selected == -1:
		instruction_label.text = "Tap any unsorted crate to pick it up  (press HINT for help)"
	else:
		var val = values[selected]
		if selected > 0 and values[selected - 1] > val:
			# Can (and must) still slide left
			instruction_label.text = "Crate " + str(val) + " held — left neighbor " + str(values[selected - 1]) + " is bigger. Press SWAP to slide left!"
		elif selected < crates.size() - 1 and selected + 1 < crates.size() and selected + 1 >= sorted_count and values[selected + 1] < val:
			# Overshot — right unsorted neighbor is smaller, wrong position
			instruction_label.text = "⚠️ The crate on the right is smaller — you went too far left! Use UNDO."
		else:
			# Left neighbor is smaller (or at position 0) — may be correct, player confirms
			instruction_label.text = "Crate " + str(val) + " can't slide further. Tap it again to lock it in place!"


func _show_instruction(msg: String):
	instruction_label.text = msg
	instruction_label.modulate = Color(0.3, 0.85, 1)


func _show_error(msg: String):
	instruction_label.text = "❌ " + msg
	instruction_label.modulate = Color(1, 0.3, 0.3)
	await get_tree().create_timer(2.5).timeout
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
	var target = [10, 20, 30, 40, 50, 60]
	for i in range(values.size()):
		if values[i] != target[i]:
			return false
	return true


# ── Win ────────────────────────────────────────────────────────────────────────
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

	progress["insertion_done"] = true
	var save = FileAccess.open("user://progress.dat", FileAccess.WRITE)
	save.store_string(JSON.stringify(progress))
	save.close()

	if move_count <= 8:
		star1.texture         = STAR_3
		efficiency_label.text = "EFFICIENCY REMAINING : HIGH"
	elif move_count <= 14:
		star1.texture         = STAR_2
		efficiency_label.text = "EFFICIENCY REMAINING : MEDIUM"
	else:
		star1.texture         = STAR_1
		efficiency_label.text = "EFFICIENCY REMAINING : LOW"

	moves_label.text  = "MOVES : " + str(move_count)
	$Winpoint.visible = true
	$Winpoint/Panel.visible = true
