extends Node2D

# Starting display order (left → right): [60, 20, 40, 10, 50, 30]
# Left half  (indices 0–2): [60, 20, 40]  →  sort to [20, 40, 60]
# Right half (indices 3–5): [10, 50, 30]  →  sort to [10, 30, 50]
# Merge target: [10, 20, 30, 40, 50, 60]

# ── Node refs ─────────────────────────────────────────────────────────────────
@onready var crates            = [$"60c", $"20c", $"40c", $"10c", $"50c", $"30c"]
@onready var swapbtn           = $swapbtn
@onready var hintbtn           = $hintbtn
@onready var resetbtn          = $resetbtn
@onready var undobtn           = $undobtn
@onready var claw              = $Claw
@onready var claw_anim         = $Claw/Anim
@onready var cable             = $Claw/Cable
@onready var machine           = $ProcessingMachine
@onready var here_label        = $Label
@onready var instruction_label = $InstructionLabel
@onready var instruction_popup = $Howtoplaybtn/Instruction
@onready var half_divider      = $HalfDivider
@onready var output_row        = $OutputRow
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

# ── Constants ─────────────────────────────────────────────────────────────────
const RAIL_Y     = 27.0
const CLAW_UP    = 220
const CLAW_DOWN  = 430
const BASE_ANIM_SPEED = 0.4
var   ANIM_SPEED       = BASE_ANIM_SPEED
const STAR_1     = preload("res://assets/ui/stars_1.png")
const STAR_2     = preload("res://assets/ui/stars_2.png")
const STAR_3     = preload("res://assets/ui/stars_3.png")

# ── State ─────────────────────────────────────────────────────────────────────
var values        = [60, 20, 40, 10, 50, 30]
var output_values : Array = []
var history       : Array = []
var is_animating  : bool  = false
var sel_a         : int   = -1
var sel_b         : int   = -1
var move_count    : int   = 0
var phase         : int   = 1     # 1=sort left, 2=sort right, 3=merge

var left_ptr      : int   = 0
var right_ptr     : int   = 3
var output_count  : int   = 0
var output_slots  : Array = []


# ── Cable update ──────────────────────────────────────────────────────────────
func _process(_delta: float) -> void:
	if claw.visible:
		var local_top = (RAIL_Y - claw.global_position.y) / claw.scale.y
		cable.points = PackedVector2Array([Vector2(0, local_top), Vector2(0, 0)])


# ── Ready ─────────────────────────────────────────────────────────────────────
func _ready() -> void:
	instruction_popup.visible = false
	$Winpoint.visible         = false
	$Failpoint.visible        = false
	redflash.modulate.a       = 0.0
	claw.visible              = false
	here_label.visible        = false
	output_row.visible        = false
	half_divider.visible      = true

	swapbtn.pressed.connect(_on_pick)
	hintbtn.pressed.connect(_on_hint)
	resetbtn.pressed.connect(_on_end)
	undobtn.pressed.connect(_on_undo)
	$Howtoplaybtn.pressed.connect(_on_howtoplay)
	retrybtn.pressed.connect(_on_reset)
	mainmenubtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/difficulty.tscn"))
	nextlevelbtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/quicksort.tscn"))
	failretrybtn.pressed.connect(_on_reset)
	failmenubtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/menu.tscn"))

	for i in range(crates.size()):
		var node = crates[i]
		node.pressed.connect(func(): _on_crate_tapped(crates.find(node)))

	for child in output_row.get_children():
		output_slots.append(child)

	_apply_phase_constraints()
	_update_instruction()
	machine.setup(values.duplicate(), [10, 20, 30, 40, 50, 60])


	_apply_settings()
func _on_howtoplay() -> void:
	instruction_popup.visible = !instruction_popup.visible


# ── Phase constraint enforcement ──────────────────────────────────────────────
func _apply_phase_constraints() -> void:
	match phase:
		1:
			for i in range(6):
				crates[i].disabled = (i >= 3)
				if i >= 3:
					crates[i].modulate = Color(0.5, 0.5, 0.5)
				elif crates[i].modulate == Color(0.5, 0.5, 0.5):
					crates[i].modulate = Color(1, 1, 1)
		2:
			for i in range(6):
				if i < 3:
					crates[i].modulate = Color(1.5, 1.2, 0.0)
					crates[i].disabled = true
				else:
					crates[i].disabled = false
					if crates[i].modulate == Color(0.5, 0.5, 0.5):
						crates[i].modulate = Color(1, 1, 1)
		3:
			half_divider.visible = false
			output_row.visible   = true
			swapbtn.disabled     = true   # PICK button disabled in phase 3
			_p3_highlight_fronts()


# ── Phase 3: highlight the two front crates ───────────────────────────────────
func _p3_highlight_fronts() -> void:
	# Grey everything first
	for i in range(6):
		if crates[i].visible:
			crates[i].modulate = Color(0.35, 0.35, 0.35)
			crates[i].disabled = true

	# Light up left front if still active
	if left_ptr < 3 and crates[left_ptr].visible:
		crates[left_ptr].modulate = Color(0.3, 0.85, 2.0)   # blue
		crates[left_ptr].disabled = false

	# Light up right front if still active
	if right_ptr < 6 and crates[right_ptr].visible:
		crates[right_ptr].modulate = Color(2.0, 0.7, 0.1)   # orange
		crates[right_ptr].disabled = false


# ── Crate tapped ──────────────────────────────────────────────────────────────
func _on_crate_tapped(idx: int) -> void:
	if is_animating:
		return

	if phase == 3:
		_p3_player_pick(idx)
		return

	var lo = 0 if phase == 1 else 3
	var hi = 2 if phase == 1 else 5
	if idx < lo or idx > hi:
		return

	# Deselect same crate
	if idx == sel_a:
		_set_highlight(sel_a, false)
		sel_a = -1
		claw.visible = false
		_update_instruction()
		return
	if idx == sel_b:
		_set_highlight(sel_b, false)
		sel_b = -1
		_update_instruction()
		return

	# First selection
	if sel_a == -1:
		sel_a = idx
		_set_highlight(idx, true)
		claw.visible = true
		claw_anim.play("open")
		claw.position = Vector2(_cx(crates[idx]), CLAW_UP)
		_show_instruction("📦 Crate %d selected — tap another to compare, then PICK to swap." % values[idx])
		return

	# Second selection
	sel_b = idx
	_set_highlight(idx, true)
	var a = values[sel_a]
	var b = values[sel_b]
	if a > b:
		_show_instruction("⚠️ %d > %d — press PICK to swap them!" % [a, b])
	else:
		_show_instruction("✅ %d < %d — already in order. Try another pair." % [a, b])


# ── Phase 3: player taps a front crate ───────────────────────────────────────
func _p3_player_pick(idx: int) -> void:
	# Only allow tapping the two front crates
	if idx != left_ptr and idx != right_ptr:
		return
	if not crates[idx].visible:
		return

	# Determine the correct pick
	var correct_idx: int
	if left_ptr >= 3:
		correct_idx = right_ptr
	elif right_ptr >= 6:
		correct_idx = left_ptr
	elif values[left_ptr] <= values[right_ptr]:
		correct_idx = left_ptr
	else:
		correct_idx = right_ptr

	move_count += 1
	_save_undo()

	if idx == correct_idx:
		# ✅ Correct — animate to output slot
		_animate_merge_pick(idx, output_count)
	else:
		# ❌ Wrong — flash error, don't move anything
		_show_error("❌ Wrong! %d is NOT the smallest — pick the smaller front crate first!" % values[idx])


# ── PICK button (phases 1 & 2 only) ──────────────────────────────────────────
func _on_pick() -> void:
	if is_animating or phase == 3:
		return

	if sel_a == -1 or sel_b == -1:
		_show_error("Select two crates first!")
		return

	_save_undo()
	move_count += 1
	_animate_swap(sel_a, sel_b)


# ── Swap animation (phases 1 & 2) ────────────────────────────────────────────
func _animate_swap(a: int, b: int) -> void:
	is_animating = true
	var tween = create_tween()

	claw.visible = true
	claw_anim.play("open")

	tween.tween_property(claw, "position", Vector2(_cx(crates[a]), CLAW_UP), ANIM_SPEED * 0.4)
	tween.tween_property(claw, "position:y", CLAW_DOWN, ANIM_SPEED)
	tween.tween_callback(func(): claw_anim.play("grip"))
	tween.tween_property(claw, "position:y", CLAW_UP, ANIM_SPEED)
	tween.tween_property(claw, "position:x", _cx(crates[b]), ANIM_SPEED)
	tween.tween_property(claw, "position:y", CLAW_DOWN, ANIM_SPEED)
	tween.tween_callback(func():
		claw_anim.play("open")
		var tv = values[a];      values[a]      = values[b];      values[b]      = tv
		var tp = crates[a].position; crates[a].position = crates[b].position; crates[b].position = tp
		var tn = crates[a];      crates[a]      = crates[b];      crates[b]      = tn
	)
	tween.tween_property(claw, "position:y", CLAW_UP, ANIM_SPEED)
	tween.tween_callback(func():
		is_animating = false
		_set_highlight(a, false)
		_set_highlight(b, false)
		sel_a        = -1
		sel_b        = -1
		claw.visible = false
		machine.report_placement(values)
		_check_phase_complete()
	)


func _check_phase_complete() -> void:
	if phase == 1 and values[0] < values[1] and values[1] < values[2]:
		_lock_half(0, 2)
		phase = 2
		_apply_phase_constraints()
		_show_instruction("✅ Left half sorted! Now sort the RIGHT half.")
	elif phase == 2 and values[3] < values[4] and values[4] < values[5]:
		_lock_half(3, 5)
		phase         = 3
		left_ptr      = 0
		right_ptr     = 3
		output_count  = 0
		output_values = []
		_apply_phase_constraints()
		_show_instruction("✅ Right half sorted! TAP the smaller front crate to merge!")
	else:
		_update_instruction()


func _lock_half(lo: int, hi: int) -> void:
	for i in range(lo, hi + 1):
		crates[i].modulate = Color(1.5, 1.2, 0.0)
		crates[i].disabled = true


# ── Phase 3 — merge pick animation ───────────────────────────────────────────
func _animate_merge_pick(src: int, slot: int) -> void:
	is_animating = true
	claw.visible = true
	claw_anim.play("open")

	var slot_node = output_slots[slot]
	var slot_cx   = slot_node.global_position.x + slot_node.size.x * 0.5
	var slot_cy   = slot_node.global_position.y + slot_node.size.y * 0.5

	var tween = create_tween()
	tween.tween_property(claw, "position", Vector2(_cx(crates[src]), CLAW_UP), ANIM_SPEED * 0.4)
	tween.tween_property(claw, "position:y", CLAW_DOWN, ANIM_SPEED)
	tween.tween_callback(func(): claw_anim.play("grip"))
	tween.tween_property(claw, "position:y", CLAW_UP, ANIM_SPEED)
	tween.tween_property(claw, "position:x", slot_cx, ANIM_SPEED)
	tween.tween_property(claw, "position:y", slot_cy - 40.0, ANIM_SPEED * 0.6)
	tween.tween_callback(func():
		claw_anim.play("open")
		var val = values[src]
		_fill_output_slot(slot, val)
		output_values.append(val)
		crates[src].visible = false
		if src == left_ptr:
			left_ptr += 1
		else:
			right_ptr += 1
		output_count += 1
		machine.report_placement(output_values)
	)
	tween.tween_property(claw, "position:y", CLAW_UP, ANIM_SPEED * 0.6)
	tween.tween_callback(func():
		is_animating = false
		claw.visible = false
		if output_count >= 6:
			_win()
			return
		# Auto-collect if one side exhausted
		if left_ptr >= 3 or right_ptr >= 6:
			_p3_auto_collect()
		else:
			_p3_highlight_fronts()
			_update_instruction()
	)


# ── Phase 3: auto-collect remaining when one side runs out ────────────────────
func _p3_auto_collect() -> void:
	if output_count >= 6:
		_win()
		return
	var src: int
	if left_ptr >= 3:
		src = right_ptr
	else:
		src = left_ptr

	_animate_merge_pick(src, output_count)


func _fill_output_slot(slot: int, val: int) -> void:
	var panel = output_slots[slot]
	var lbl: Label = panel.get_node_or_null("SlotLabel")
	if lbl == null:
		lbl = Label.new()
		lbl.name = "SlotLabel"
		lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 32)
		panel.add_child(lbl)
	lbl.text       = str(val)
	panel.modulate = Color(0.3, 1.0, 0.5)


# ── Hint ──────────────────────────────────────────────────────────────────────
func _on_hint() -> void:
	if is_animating:
		return

	if phase == 3:
		var correct_idx: int
		if left_ptr >= 3:
			correct_idx = right_ptr
		elif right_ptr >= 6:
			correct_idx = left_ptr
		elif values[left_ptr] <= values[right_ptr]:
			correct_idx = left_ptr
		else:
			correct_idx = right_ptr
		crates[correct_idx].modulate = Color(0.2, 2.5, 0.4)
		_show_instruction("💡 Tap crate %d — it's the smaller front crate!" % values[correct_idx])
		await get_tree().create_timer(1.5).timeout
		if not is_animating:
			_p3_highlight_fronts()
		return

	var lo = 0 if phase == 1 else 3
	var hi = 2 if phase == 1 else 5
	for i in range(lo, hi):
		if values[i] > values[i + 1]:
			_show_instruction("💡 Swap crate %d and crate %d!" % [values[i], values[i + 1]])
			_flash_pair(i, i + 1)
			return
	_show_instruction("💡 This half is sorted already — check the other!")


func _flash_pair(a: int, b: int) -> void:
	_set_highlight(a, true)
	_set_highlight(b, true)
	await get_tree().create_timer(1.2).timeout
	if sel_a != a: _set_highlight(a, false)
	if sel_b != b: _set_highlight(b, false)


# ── Reset / Undo ──────────────────────────────────────────────────────────────
func _on_reset() -> void:
	get_tree().reload_current_scene()


func _on_end() -> void:
	is_animating      = false
	sel_a             = -1
	sel_b             = -1
	swapbtn.disabled  = true
	hintbtn.disabled  = true
	undobtn.disabled  = true
	resetbtn.disabled = true
	claw.visible      = false

	for i in range(crates.size()):
		crates[i].modulate = Color(1, 1, 1)

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


func _save_undo() -> void:
	history.append({
		"values":        values.duplicate(),
		"output_values": output_values.duplicate(),
		"positions":     crates.map(func(c): return c.position),
		"order":         crates.duplicate(),
		"visible":       crates.map(func(c): return c.visible),
		"sel_a":         sel_a,
		"sel_b":         sel_b,
		"phase":         phase,
		"left_ptr":      left_ptr,
		"right_ptr":     right_ptr,
		"output_count":  output_count,
	})


func _on_undo() -> void:
	if is_animating or history.is_empty():
		return
	var last = history.pop_back()

	values        = last["values"]
	output_values = last["output_values"]
	crates        = last["order"]
	sel_a         = last["sel_a"]
	sel_b         = last["sel_b"]
	phase         = last["phase"]
	left_ptr      = last["left_ptr"]
	right_ptr     = last["right_ptr"]
	output_count  = last["output_count"]

	for i in range(crates.size()):
		crates[i].position = last["positions"][i]
		crates[i].visible  = last["visible"][i]

	for i in range(output_slots.size()):
		output_slots[i].modulate = Color(1, 1, 1)
		var lbl = output_slots[i].get_node_or_null("SlotLabel")
		if lbl:
			lbl.queue_free()
	for i in range(output_values.size()):
		_fill_output_slot(i, output_values[i])

	_apply_phase_constraints()

	if sel_a != -1:
		_set_highlight(sel_a, true)
		claw.visible  = true
		claw.position = Vector2(_cx(crates[sel_a]), CLAW_UP)
		claw_anim.play("open")
	else:
		claw.visible = false
	if sel_b != -1:
		_set_highlight(sel_b, true)

	half_divider.visible = (phase < 3)
	output_row.visible   = (phase == 3)

	machine.report_placement(values if phase < 3 else output_values)
	_show_instruction("↩️ Undo! Last move reverted.")


# ── Helpers ───────────────────────────────────────────────────────────────────
func _set_highlight(idx: int, on: bool) -> void:
	if idx < 0 or idx >= crates.size():
		return
	if on:
		crates[idx].modulate = Color(1.5, 1.2, 0.3)
	else:
		match phase:
			1: crates[idx].modulate = Color(0.5, 0.5, 0.5) if idx >= 3 else Color(1, 1, 1)
			2: crates[idx].modulate = Color(1.5, 1.2, 0.0) if idx < 3  else Color(1, 1, 1)
			3: crates[idx].modulate = Color(1.5, 1.2, 0.0)


func _cx(crate: Control) -> float:
	return crate.position.x + crate.size.x * 0.5


func _update_instruction() -> void:
	match phase:
		1:
			if sel_a == -1:
				instruction_label.text = "PHASE 1: Sort the LEFT half (crates 1–3). Tap two crates, then press PICK to swap."
			elif sel_b == -1:
				instruction_label.text = "Crate %d selected — tap another to compare." % values[sel_a]
			else:
				var a = values[sel_a]; var b = values[sel_b]
				instruction_label.text = "%d vs %d — %s" % [a, b, "PICK to swap!" if a > b else "Already in order, try another pair."]
		2:
			if sel_a == -1:
				instruction_label.text = "PHASE 2: Sort the RIGHT half (crates 4–6). Tap two crates, then press PICK to swap."
			elif sel_b == -1:
				instruction_label.text = "Crate %d selected — tap another to compare." % values[sel_a]
			else:
				var a = values[sel_a]; var b = values[sel_b]
				instruction_label.text = "%d vs %d — %s" % [a, b, "PICK to swap!" if a > b else "Already in order, try another pair."]
		3:
			if output_count >= 6:
				instruction_label.text = "🎉 Merge complete!"
			else:
				var l_val = values[left_ptr]  if left_ptr  < 3 else 0
				var r_val = values[right_ptr] if right_ptr < 6 else 0
				instruction_label.text = "PHASE 3: MERGE — TAP the smaller front crate!   L:%d   R:%d" % [l_val, r_val]


func _show_instruction(msg: String) -> void:
	instruction_label.text     = msg
	instruction_label.modulate = Color(0.3, 0.85, 1)


func _show_error(msg: String) -> void:
	instruction_label.text     = msg
	instruction_label.modulate = Color(1, 0.3, 0.3)
	await get_tree().create_timer(2.2).timeout
	instruction_label.modulate = Color(0.3, 0.85, 1)
	_update_instruction()


# ── Win ───────────────────────────────────────────────────────────────────────

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


func _win() -> void:
	swapbtn.disabled = true
	hintbtn.disabled = true

	var progress = {}
	if FileAccess.file_exists("user://progress.dat"):
		var file   = FileAccess.open("user://progress.dat", FileAccess.READ)
		var parsed = JSON.parse_string(file.get_as_text())
		file.close()
		if parsed != null and typeof(parsed) == TYPE_DICTIONARY:
			progress = parsed

	progress["merge_done"] = true
	var save = FileAccess.open("user://progress.dat", FileAccess.WRITE)
	save.store_string(JSON.stringify(progress))
	save.close()

	if move_count <= 9:
		star1.texture         = STAR_3
		efficiency_label.text = "EFFICIENCY REMAINING : HIGH"
	elif move_count <= 14:
		star1.texture         = STAR_2
		efficiency_label.text = "EFFICIENCY REMAINING : MEDIUM"
	else:
		star1.texture         = STAR_1
		efficiency_label.text = "EFFICIENCY REMAINING : LOW"

	moves_label.text        = "MOVES : " + str(move_count)
	$Winpoint.visible       = true
	$Winpoint/Panel.visible = true
