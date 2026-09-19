extends Node2D

# ── Node references ────────────────────────────────────────────────────────────
@onready var crates            = [$"30c", $"60c", $"10c", $"50c", $"20c", $"40c"]
@onready var swapbtn           = $swapbtn
@onready var hintbtn           = $hintbtn
@onready var resetbtn          = $resetbtn
@onready var undobtn           = $undobtn
@onready var claw              = $Claw
@onready var claw_anim         = $Claw/Anim
@onready var cable             = $Claw/Cable
@onready var machine           = $ProcessingMachine
@onready var instruction_popup = $Howtoplaybtn/Instruction
@onready var instruction_label = $InstructionLabel
@onready var here_label        = $Label
@onready var pivot_indicator   = $PivotIndicator
@onready var small_zone_div    = $SmallZoneDivider
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

const RAIL_Y     = 27.0
const CLAW_UP    = 220
const CLAW_DOWN  = 430
const BASE_ANIM_SPEED = 0.5
var   ANIM_SPEED       = BASE_ANIM_SPEED

const STAR_1 = preload("res://assets/ui/stars_1.png")
const STAR_2 = preload("res://assets/ui/stars_2.png")
const STAR_3 = preload("res://assets/ui/stars_3.png")

# ── Core state ─────────────────────────────────────────────────────────────────
var values         = [30, 60, 10, 50, 20, 40]
var history        = []
var is_animating   = false
var move_count     = 0

# ── Partition state ────────────────────────────────────────────────────────────
var active_lo        : int   = 0
var active_hi        : int   = 0
var pivot_val        : int   = 0
var pivot_idx        : int   = -1
var scan_ptr         : int   = 0
var small_end        : int   = -1
var partition_stack  : Array = []
var locked_indices   : Array = []
var pivot_placed     : bool  = false

# ── Pivot selection phase ──────────────────────────────────────────────────────
# true  = waiting for player to tap a pivot
# false = pivot chosen, scanning phase active
var choosing_pivot : bool = true


# ── Cable ──────────────────────────────────────────────────────────────────────
func _process(_delta: float) -> void:
	if claw.visible:
		var local_top = (RAIL_Y - claw.global_position.y) / claw.scale.y
		cable.points = PackedVector2Array([Vector2(0, local_top), Vector2(0, 0)])


# ── Ready ──────────────────────────────────────────────────────────────────────
func _ready():
	instruction_popup.visible = false
	$Winpoint.visible         = false
	$Failpoint.visible        = false
	redflash.modulate.a       = 0.0
	claw.visible              = false
	here_label.visible        = false
	pivot_indicator.visible   = false
	small_zone_div.visible    = false

	for i in range(crates.size()):
		var node = crates[i]
		node.pressed.connect(func(): _on_crate_tapped(crates.find(node)))

	swapbtn.pressed.connect(_on_compare)
	hintbtn.pressed.connect(_on_hint)
	resetbtn.pressed.connect(_on_end)
	undobtn.pressed.connect(_on_undo)
	$Howtoplaybtn.pressed.connect(_on_howtoplay)
	retrybtn.pressed.connect(_on_reset)
	mainmenubtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/difficulty.tscn"))
	nextlevelbtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/difficulty.tscn"))
	failretrybtn.pressed.connect(_on_reset)
	failmenubtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/menu.tscn"))

	machine.setup(values, [10, 20, 30, 40, 50, 60])
	partition_stack.push_back([0, values.size() - 1])
	_start_next_partition()


	_apply_settings()
func _on_howtoplay():
	instruction_popup.visible = !instruction_popup.visible


# ═════════════════════════════════════════════════════════════════════
#  PARTITION ROUND MANAGEMENT
# ═════════════════════════════════════════════════════════════════════
func _start_next_partition():
	# Check first — values may already be fully sorted before touching the stack
	if _is_sorted():
		_win()
		return

	while not partition_stack.is_empty():
		var pair = partition_stack.pop_back()
		var lo   = pair[0]
		var hi   = pair[1]

		if lo >= hi:
			if lo == hi:
				_lock_crate(lo)
				if _check_win(): return
			continue

		active_lo      = lo
		active_hi      = hi
		pivot_placed   = false
		choosing_pivot = true
		pivot_idx      = -1
		scan_ptr       = active_lo
		small_end      = active_lo - 1

		swapbtn.disabled = true   # locked until pivot chosen
		_refresh_visuals()
		_show_instruction(
			"🎯 TAP any lit crate to choose it as the PIVOT for this partition!"
		)
		return

	# Stack is empty — lock any remaining unlocked crates and win
	for i in range(values.size()):
		_lock_crate(i)
	machine.report_placement(values)
	_win()


# ═════════════════════════════════════════════════════════════════════
#  CRATE TAPPED — pivot selection only
# ═════════════════════════════════════════════════════════════════════
func _on_crate_tapped(idx: int):
	if is_animating or not choosing_pivot:
		return
	if idx < active_lo or idx > active_hi or idx in locked_indices:
		_show_error("Pick a crate inside the active (lit) range!")
		return

	pivot_idx = idx
	pivot_val = values[idx]

	# If not already at active_hi, move it there so Lomuto scan works
	if pivot_idx != active_hi:
		_show_instruction(
			"⚙️ Moving your pivot " + str(pivot_val) + " to the end of the range..."
		)
		_animate_swap(pivot_idx, active_hi, func():
			pivot_idx = active_hi
			_begin_scanning()
		)
	else:
		_begin_scanning()


func _begin_scanning():
	choosing_pivot   = false
	scan_ptr         = active_lo
	small_end        = active_lo - 1
	swapbtn.disabled = false

	_refresh_visuals()
	_show_instruction(
		"Pivot is " + str(pivot_val) + ".  Press COMPARE to check crate " +
		str(values[scan_ptr]) + "."
	)


# ═════════════════════════════════════════════════════════════════════
#  COMPARE BUTTON
# ═════════════════════════════════════════════════════════════════════
func _on_compare():
	if is_animating or pivot_placed or choosing_pivot:
		return

	_save_undo()
	move_count += 1

	if scan_ptr < active_hi:
		var cmp_val = values[scan_ptr]

		if cmp_val < pivot_val:
			small_end += 1
			if small_end != scan_ptr:
				_show_instruction(
					"✅ " + str(cmp_val) + " < " + str(pivot_val) +
					" — moving it to the small zone."
				)
				_animate_swap(small_end, scan_ptr, func():
					scan_ptr += 1
					if _check_win(): return
					_after_compare_step()
				)
				return
			else:
				_flash_crate(scan_ptr, Color(0.2, 2.0, 0.4))
				_show_instruction(
					"✅ " + str(cmp_val) + " < " + str(pivot_val) +
					" — already in place!"
				)
		else:
			_flash_crate(scan_ptr, Color(2.0, 1.2, 0.1))
			_show_instruction(
				"➡️ " + str(cmp_val) + " >= " + str(pivot_val) +
				" — leaving it in place."
			)

		scan_ptr += 1
		if _check_win(): return
		_after_compare_step()
	else:
		_place_pivot()


func _after_compare_step():
	if scan_ptr < active_hi:
		_refresh_visuals()
		_show_instruction(
			"Pivot is " + str(pivot_val) + ".  Press COMPARE to check crate " +
			str(values[scan_ptr]) + "."
		)
	else:
		_refresh_visuals()
		_show_instruction(
			"All elements compared! Press COMPARE to lock pivot " +
			str(pivot_val) + " in its final position."
		)


# ═════════════════════════════════════════════════════════════════════
#  PIVOT PLACEMENT
# ═════════════════════════════════════════════════════════════════════
func _place_pivot():
	pivot_placed = true
	small_end   += 1
	var pivot_final = small_end

	if pivot_final != active_hi:
		_show_instruction(
			"🔒 Pivot " + str(pivot_val) + " locked at position " +
			str(pivot_final + 1) + "!  Starting next partition."
		)
		_animate_swap(pivot_final, active_hi, func():
			_finish_pivot(pivot_final)
		)
	else:
		_show_instruction(
			"🔒 Pivot " + str(pivot_val) + " already at position " +
			str(pivot_final + 1) + "!  Starting next partition."
		)
		_finish_pivot(pivot_final)


func _finish_pivot(pivot_final: int):
	_lock_crate(pivot_final)
	if _check_win(): return

	var right_lo = pivot_final + 1
	var right_hi = active_hi
	var left_lo  = active_lo
	var left_hi  = pivot_final - 1

	if right_lo < right_hi:
		partition_stack.push_back([right_lo, right_hi])
	elif right_lo == right_hi:
		_lock_crate(right_lo)
		if _check_win(): return

	if left_lo < left_hi:
		partition_stack.push_back([left_lo, left_hi])
	elif left_lo == left_hi:
		_lock_crate(left_lo)
		if _check_win(): return

	await get_tree().create_timer(0.6).timeout
	_start_next_partition()


# ═════════════════════════════════════════════════════════════════════
#  CLAW ANIMATION
# ═════════════════════════════════════════════════════════════════════
func _animate_swap(a: int, b: int, after_fn: Callable):
	is_animating = true
	claw.visible = true
	claw_anim.play("open")
	claw.position = Vector2(_cx(crates[a]), CLAW_UP)

	var tween = create_tween()
	tween.tween_property(claw, "position", Vector2(_cx(crates[a]), CLAW_DOWN), ANIM_SPEED)
	tween.tween_callback(func(): claw_anim.play("grip"))
	tween.tween_property(claw, "position:y", CLAW_UP, ANIM_SPEED)
	tween.tween_property(claw, "position:x", _cx(crates[b]), ANIM_SPEED)
	tween.tween_property(claw, "position:y", CLAW_DOWN, ANIM_SPEED)
	tween.tween_callback(func():
		claw_anim.play("open")
		var tv = values[a];          values[a]          = values[b];          values[b]          = tv
		var tp = crates[a].position; crates[a].position = crates[b].position; crates[b].position = tp
		var tn = crates[a];          crates[a]          = crates[b];          crates[b]          = tn
	)
	tween.tween_property(claw, "position:y", CLAW_UP, ANIM_SPEED)
	tween.tween_callback(func():
		is_animating = false
		claw.visible = false
		after_fn.call()
	)


# ═════════════════════════════════════════════════════════════════════
#  VISUALS
# ═════════════════════════════════════════════════════════════════════
func _refresh_visuals():
	for i in range(crates.size()):
		if i in locked_indices:
			crates[i].modulate = Color(1.5, 1.2, 0.0)     # gold
			crates[i].disabled = true
		elif choosing_pivot:
			if i >= active_lo and i <= active_hi:
				crates[i].modulate = Color(1.0, 1.0, 1.0) # lit — tappable
				crates[i].disabled = false
			else:
				crates[i].modulate = Color(0.4, 0.4, 0.4) # dimmed
				crates[i].disabled = true
		else:
			crates[i].disabled = true
			if i == active_hi:
				crates[i].modulate = Color(2.0, 1.0, 0.1) # orange — pivot
			elif i >= active_lo and i < active_hi:
				if i == scan_ptr:
					crates[i].modulate = Color(0.3, 0.8, 2.0)  # blue — scan ptr
				elif i <= small_end:
					crates[i].modulate = Color(0.4, 1.3, 0.5)  # green — small zone
				else:
					crates[i].modulate = Color(1.0, 1.0, 1.0)  # white — active
			else:
				crates[i].modulate = Color(0.35, 0.35, 0.35)   # grey — outside range

	# Pivot indicator
	pivot_indicator.visible = not choosing_pivot
	if not choosing_pivot:
		pivot_indicator.position = Vector2(
			_cx(crates[active_hi]),
			crates[active_hi].position.y - 50.0
		)

	# Small zone divider
	if not choosing_pivot and small_end >= active_lo:
		var right_idx = small_end + 1
		var div_x: float
		if right_idx < crates.size() and right_idx <= active_hi:
			div_x = (_cx(crates[small_end]) + _cx(crates[right_idx])) * 0.5
		else:
			div_x = _cx(crates[small_end]) + 100.0
		small_zone_div.position.x = div_x
		small_zone_div.visible    = true
	else:
		small_zone_div.visible = false


func _lock_crate(idx: int):
	if idx in locked_indices:
		return
	locked_indices.append(idx)
	crates[idx].modulate = Color(1.5, 1.2, 0.0)
	crates[idx].disabled = true


func _flash_crate(idx: int, col: Color):
	var orig  = crates[idx].modulate
	var tween = create_tween()
	tween.tween_property(crates[idx], "modulate", col,  0.12)
	tween.tween_property(crates[idx], "modulate", orig, 0.25)


func _cx(crate: Control) -> float:
	return crate.position.x + crate.size.x * 0.5


# ═════════════════════════════════════════════════════════════════════
#  HINT
# ═════════════════════════════════════════════════════════════════════
func _on_hint():
	if is_animating:
		return

	if choosing_pivot:
		# Suggest the median value in the active range as the best pivot
		var mid = (active_lo + active_hi) / 2
		_show_instruction(
			"💡 Tip: a middle value like " + str(values[mid]) +
			" as pivot means fewer compares and a better score!"
		)
		_flash_crate(mid, Color(0.3, 2.0, 0.6))
		return

	if pivot_placed:
		return

	if scan_ptr < active_hi:
		var cmp_val = values[scan_ptr]
		if cmp_val < pivot_val:
			_show_instruction(
				"💡 Crate " + str(cmp_val) + " < Pivot " + str(pivot_val) +
				" — it will move to the small zone!"
			)
		else:
			_show_instruction(
				"💡 Crate " + str(cmp_val) + " >= Pivot " + str(pivot_val) +
				" — it will stay in place."
			)
		here_label.position.x = _cx(crates[scan_ptr]) - here_label.size.x * 0.5
		here_label.visible    = true
		await get_tree().create_timer(2.0).timeout
		here_label.visible = false
	else:
		_show_instruction(
			"💡 All scanned! Press COMPARE to lock pivot " +
			str(pivot_val) + " at its final position."
		)


# ═════════════════════════════════════════════════════════════════════
#  UNDO / RESET
# ═════════════════════════════════════════════════════════════════════
func _save_undo():
	history.push_back({
		"values":          values.duplicate(),
		"positions":       crates.map(func(c): return c.position),
		"order":           crates.duplicate(),
		"active_lo":       active_lo,
		"active_hi":       active_hi,
		"pivot_val":       pivot_val,
		"pivot_idx":       pivot_idx,
		"scan_ptr":        scan_ptr,
		"small_end":       small_end,
		"partition_stack": partition_stack.duplicate(true),
		"locked_indices":  locked_indices.duplicate(),
		"pivot_placed":    pivot_placed,
		"choosing_pivot":  choosing_pivot,
	})


func _on_reset():
	get_tree().reload_current_scene()


func _on_end() -> void:
	is_animating      = false
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


func _on_undo():
	if is_animating or history.is_empty():
		return
	var last = history.pop_back()

	values          = last["values"]
	crates          = last["order"]
	active_lo       = last["active_lo"]
	active_hi       = last["active_hi"]
	pivot_val       = last["pivot_val"]
	pivot_idx       = last["pivot_idx"]
	scan_ptr        = last["scan_ptr"]
	small_end       = last["small_end"]
	partition_stack = last["partition_stack"]
	locked_indices  = last["locked_indices"]
	pivot_placed    = last["pivot_placed"]
	choosing_pivot  = last["choosing_pivot"]

	for i in range(crates.size()):
		crates[i].position = last["positions"][i]

	swapbtn.disabled = choosing_pivot
	machine.report_placement(values)
	_refresh_visuals()

	if choosing_pivot:
		_show_instruction("↩️ Undo! TAP a crate to choose your pivot again.")
	else:
		_show_instruction(
			"↩️ Undo! Pivot " + str(pivot_val) +
			" — next compare: crate " + str(values[scan_ptr]) + "."
		)


# ═════════════════════════════════════════════════════════════════════
#  INSTRUCTION HELPERS
# ═════════════════════════════════════════════════════════════════════
func _show_instruction(msg: String):
	instruction_label.text     = msg
	instruction_label.modulate = Color(0.3, 0.85, 1)


func _show_error(msg: String):
	instruction_label.text     = "❌ " + msg
	instruction_label.modulate = Color(1, 0.3, 0.3)
	await get_tree().create_timer(2.0).timeout
	instruction_label.modulate = Color(0.3, 0.85, 1)


# ═════════════════════════════════════════════════════════════════════
#  WIN
# ═════════════════════════════════════════════════════════════════════

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


func _check_win() -> bool:
	if _is_sorted():
		for i in range(values.size()):
			_lock_crate(i)
		machine.report_placement(values)
		_win()
		return true
	return false


func _win():
	swapbtn.disabled        = true
	hintbtn.disabled        = true
	pivot_indicator.visible = false
	small_zone_div.visible  = false

	var progress = {}
	if FileAccess.file_exists("user://progress.dat"):
		var file   = FileAccess.open("user://progress.dat", FileAccess.READ)
		var parsed = JSON.parse_string(file.get_as_text())
		file.close()
		if parsed != null and typeof(parsed) == TYPE_DICTIONARY:
			progress = parsed

	progress["quick_done"] = true
	var save = FileAccess.open("user://progress.dat", FileAccess.WRITE)
	save.store_string(JSON.stringify(progress))
	save.close()

	if move_count <= 10:
		star1.texture         = STAR_3
		efficiency_label.text = "EFFICIENCY REMAINING : HIGH"
	elif move_count <= 16:
		star1.texture         = STAR_2
		efficiency_label.text = "EFFICIENCY REMAINING : MEDIUM"
	else:
		star1.texture         = STAR_1
		efficiency_label.text = "EFFICIENCY REMAINING : LOW"

	moves_label.text         = "MOVES : " + str(move_count)
	$Winpoint.visible        = true
	$Winpoint/Panel.visible  = true
