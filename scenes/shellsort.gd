extends Node2D

# ─────────────────────────────────────────────────────────────────────────────
# SHELL SORT — DataSort Factory
# Starting display order : randomized on _ready()
# Target                 : [10, 20, 30, 40, 50, 60, 70, 80, 90]
# Gap sequence (n=9)     : 4 → 2 → 1, reduced only when no pairs remain
# ─────────────────────────────────────────────────────────────────────────────

@onready var crates            = [$"50c", $"10c", $"60c", $"20c", $"40c", $"30c", $"70c", $"80c", $"90c"]
@onready var swapbtn           = $swapbtn
@onready var skipbtn           = $skipbtn
@onready var hintbtn           = $hintbtn
@onready var resetbtn          = $resetbtn
@onready var undobtn           = $undobtn
@onready var claw              = $Claw
@onready var claw_anim         = $Claw/Anim
@onready var cable             = $Claw/Cable
@onready var machine           = $ProcessingMachine
@onready var gap_label         = $GapLabel
@onready var gap_arcs          = $GapArcs
@onready var instruction_label = $InstructionLabel
@onready var instruction_popup = $Howtoplaybtn/Instruction
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

const RAIL_Y     = 27.0
const CLAW_UP    = 220
const CLAW_DOWN  = 430
const BASE_ANIM_SPEED = 0.4
var   ANIM_SPEED       = BASE_ANIM_SPEED

const STAR_1 = preload("res://assets/ui/stars_1.png")
const STAR_2 = preload("res://assets/ui/stars_2.png")
const STAR_3 = preload("res://assets/ui/stars_3.png")

const TARGET : Array = [10, 20, 30, 40, 50, 60, 70, 80, 90]

var values       : Array = [50, 10, 60, 20, 40, 30, 70, 80, 90]
var history      : Array = []
var is_animating : bool  = false
var move_count   : int   = 0
var selected_idx : int   = -1

# ── Shell Sort algorithm state ────────────────────────────────────────────────
var gap         : int  = 4
var scan_i      : int  = 4
var scan_j      : int  = 4
var swap_needed : bool = false


# ─────────────────────────────────────────────────────────────────────────────
# GODOT LIFECYCLE
# ─────────────────────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if claw.visible:
		var local_top = (RAIL_Y - claw.global_position.y) / claw.scale.y
		cable.points = PackedVector2Array([Vector2(0, local_top), Vector2(0, 0)])


func _ready() -> void:
	instruction_popup.visible = false
	$Winpoint.visible         = false
	$Failpoint.visible        = false
	redflash.modulate.a       = 0.0
	claw.visible              = false
	here_label.visible        = false

	for c in crates:
		c.disabled = false
		c.modulate = Color(1, 1, 1)

	_randomize_crates()

	var progress = _load_progress()
	if not progress.get("heap_done", false):
		_show_instruction("⚠️  Complete Heap Sort first to unlock Shell Sort!")
		swapbtn.disabled = true
		skipbtn.disabled = true
		hintbtn.disabled = true
		resetbtn.pressed.connect(_on_end)
		return

	for i in range(crates.size()):
		crates[i].pressed.connect(_on_crate_pressed.bind(i))

	swapbtn.pressed.connect(_on_swap)
	skipbtn.pressed.connect(_on_skip)
	hintbtn.pressed.connect(_on_hint)
	resetbtn.pressed.connect(_on_end)
	undobtn.pressed.connect(_on_undo)
	$Howtoplaybtn.pressed.connect(_on_howtoplay)
	retrybtn.pressed.connect(_on_reset)
	mainmenubtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/difficulty.tscn"))
	nextlevelbtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/radixsort.tscn"))
	failretrybtn.pressed.connect(_on_reset)
	failmenubtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/menu.tscn"))

	machine.setup(values, TARGET)
	gap_label.text = "GAP = " + str(gap)
	_show_current_step()


	_apply_settings()
func _on_howtoplay() -> void:
	instruction_popup.visible = !instruction_popup.visible


# ─────────────────────────────────────────────────────────────────────────────
# RANDOMIZE
# ─────────────────────────────────────────────────────────────────────────────

func _randomize_crates() -> void:
	var slot_positions : Array = crates.map(func(c): return c.position)

	var indices : Array = []
	for i in range(values.size()):
		indices.append(i)
	indices.shuffle()

	var new_values : Array = []
	var new_crates : Array = []
	for i in indices:
		new_values.append(values[i])
		new_crates.append(crates[i])

	values = new_values
	crates = new_crates

	for i in range(crates.size()):
		crates[i].position = slot_positions[i]


# ─────────────────────────────────────────────────────────────────────────────
# CRATE SELECTION
# ─────────────────────────────────────────────────────────────────────────────

func _on_crate_pressed(idx: int) -> void:
	if is_animating:
		return

	var left  : int = scan_j - gap
	var right : int = scan_j

	if left < 0:
		return

	if idx != left and idx != right:
		return

	if selected_idx == -1:
		selected_idx = idx
		crates[idx].modulate = Color(1.5, 0.65, 0.1)
	elif selected_idx == idx:
		selected_idx = -1
		_redraw_pair_highlight(left, right)
	else:
		var was_correct : bool = swap_needed
		selected_idx = -1
		_do_swap(left, right, was_correct)


func _redraw_pair_highlight(left: int, right: int) -> void:
	if swap_needed:
		_highlight(left,  Color(0.3, 0.85, 1.0))
		_highlight(right, Color(0.3, 0.85, 1.0))
	else:
		_highlight(left,  Color(0.65, 0.65, 0.65))
		_highlight(right, Color(0.65, 0.65, 0.65))


# ─────────────────────────────────────────────────────────────────────────────
# SWAP BUTTON
# ─────────────────────────────────────────────────────────────────────────────

func _on_swap() -> void:
	if is_animating:
		return

	if not swap_needed:
		return

	selected_idx = -1

	var left  : int = scan_j - gap
	var right : int = scan_j
	_do_swap(left, right, true)


# ─────────────────────────────────────────────────────────────────────────────
# SKIP BUTTON
# ─────────────────────────────────────────────────────────────────────────────

func _on_skip() -> void:
	if is_animating:
		return

	selected_idx = -1

	if gap == 1:
		_try_lock_sorted_prefix()

	_clear_highlights()
	_clear_gap_arcs()
	claw.visible = false
	_show_instruction("⏭ Skipped.")
	_advance_outer_i()


# ─────────────────────────────────────────────────────────────────────────────
# SWAP EXECUTION
# ─────────────────────────────────────────────────────────────────────────────

func _do_swap(a: int, b: int, was_correct: bool) -> void:
	move_count += 1
	history.append({
		"values"      : values.duplicate(),
		"positions"   : crates.map(func(c): return c.position),
		"order"       : crates.duplicate(),
		"gap"         : gap,
		"scan_i"      : scan_i,
		"scan_j"      : scan_j,
		"swap_needed" : swap_needed,
		"locked"      : _get_locked_indices()
	})
	_animate_swap(a, b, was_correct)


func _animate_swap(a: int, b: int, was_correct: bool) -> void:
	is_animating = true
	var val_a : int = values[a]
	var val_b : int = values[b]
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
		claw.visible = false
		_clear_highlights()
		machine.report_placement(values)
		if was_correct:
			_show_instruction("✅ Correct! Swapped [" + str(val_a) + "] ↔ [" + str(val_b) + "].")
		else:
			_show_instruction("❌ Wrong swap! [" + str(val_a) + "] ≤ [" + str(val_b) + "] — they were already in order.")
	)
	tween.tween_interval(1.0)
	tween.tween_callback(func():
		is_animating = false
		scan_j -= gap
		_show_current_step()
	)


# ─────────────────────────────────────────────────────────────────────────────
# CORE STEP LOGIC
# ─────────────────────────────────────────────────────────────────────────────

func _show_current_step() -> void:
	if is_animating:
		return
	if _is_sorted():
		_all_sorted()
		return

	_clear_highlights()
	_clear_gap_arcs()
	selected_idx = -1

	var left  : int = scan_j - gap
	var right : int = scan_j

	if scan_j >= gap and values[left] > values[right]:
		swap_needed = true
		claw.visible = true
		claw_anim.play("open")
		claw.position = Vector2(_cx(crates[left]), CLAW_UP)
		_highlight(left,  Color(0.3, 0.85, 1.0))
		_highlight(right, Color(0.3, 0.85, 1.0))
		_draw_current_arc(left, right)
		if gap > 1:
			_show_instruction(
				"GAP = " + str(gap) + ": [" + str(values[left]) + "] vs [" + str(values[right]) +
				"] — out of order!\nClick both crates, press SWAP, or SKIP."
			)
		else:
			_show_instruction(
				"GAP = 1: [" + str(values[left]) + "] vs [" + str(values[right]) +
				"] — out of order!\nClick both crates, press SWAP, or SKIP."
			)
	else:
		swap_needed = false
		claw.visible = false

		if gap == 1:
			_try_lock_sorted_prefix()

		if scan_j >= gap:
			_highlight(left,  Color(0.65, 0.65, 0.65))
			_highlight(right, Color(0.65, 0.65, 0.65))
			_draw_current_arc(left, right)
			_show_instruction(
				"✅ [" + str(values[left]) + "] ≤ [" + str(values[right]) +
				"] — in order. Press SKIP to move on, or click both to wrong-swap."
			)
		else:
			_show_instruction("✅ Reached left boundary — press SKIP to continue.")


func _advance_outer_i() -> void:
	scan_i += 1
	if scan_i >= values.size():
		_gap_pass_done()
	else:
		scan_j = scan_i
		_show_current_step()


func _gap_pass_done() -> void:
	if gap == 1:
		_try_lock_sorted_prefix()

	if _is_sorted():
		_all_sorted()
		return

	if _has_unsorted_pairs_at_gap():
		scan_i = gap
		scan_j = gap
		_show_instruction("🔄 Pass complete but pairs still unsorted at GAP = " + str(gap) + " — repeating.")
		_show_current_step()
		return

	var old_gap : int = gap
	gap = gap / 2
	if gap < 1:
		_all_sorted()
		return

	scan_i = gap
	scan_j = gap
	gap_label.text = "GAP = " + str(gap)

	if gap == 1:
		_show_instruction("✅ No more swaps at GAP = " + str(old_gap) + " — reducing to GAP = 1 (final pass).")
	else:
		_show_instruction("✅ No more swaps at GAP = " + str(old_gap) + " — reducing to GAP = " + str(gap) + ".")

	_show_current_step()


func _has_unsorted_pairs_at_gap() -> bool:
	for i in range(values.size() - gap):
		if values[i] > values[i + gap]:
			return true
	return false


func _all_sorted() -> void:
	_clear_gap_arcs()
	for i in range(crates.size()):
		_lock_crate(i)
	gap_label.text = "GAP = ✓"
	_show_instruction("🔒 All sorted!")
	machine.report_placement(values)
	_win()


func _try_lock_sorted_prefix() -> void:
	for i in range(values.size()):
		if values[i] == TARGET[i]:
			_lock_crate(i)
		else:
			break


# ─────────────────────────────────────────────────────────────────────────────
# ARC VISUALS
# ─────────────────────────────────────────────────────────────────────────────

func _draw_current_arc(left: int, right: int) -> void:
	_clear_gap_arcs()
	if left < 0 or right >= crates.size():
		return
	var from_x    : float = _cx(crates[left])
	var to_x      : float = _cx(crates[right])
	var base_y    : float = crates[left].position.y - 20
	var arc_color : Color = Color(0.5, 1.0, 0.5, 0.6)
	var arc = Line2D.new()
	arc.width         = 4.0
	arc.default_color = arc_color
	var pts = PackedVector2Array()
	for k in range(8):
		var t : float = float(k) / 7.0
		var x : float = lerp(from_x, to_x, t)
		var y : float = base_y - 110.0 * 4.0 * t * (1.0 - t)
		pts.append(Vector2(x, y))
	arc.points = pts
	gap_arcs.add_child(arc)


func _clear_gap_arcs() -> void:
	for child in gap_arcs.get_children():
		child.queue_free()


# ─────────────────────────────────────────────────────────────────────────────
# HINT
# ─────────────────────────────────────────────────────────────────────────────

func _on_hint() -> void:
	if is_animating:
		return
	if swap_needed:
		var left  : int = scan_j - gap
		var right : int = scan_j
		_show_instruction(
			"💡 [" + str(values[left]) + "] > [" + str(values[right]) +
			"] — click both highlighted crates or press SWAP to fix it."
		)
	else:
		_show_instruction(
			"💡 Pair is already in order. Press SKIP to move on, or click both crates to wrong-swap."
		)


# ─────────────────────────────────────────────────────────────────────────────
# RESET & UNDO
# ─────────────────────────────────────────────────────────────────────────────

func _on_reset() -> void:
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


func _on_undo() -> void:
	if is_animating or history.is_empty():
		return

	selected_idx = -1
	var last = history.pop_back()

	values      = last["values"]
	crates      = last["order"]
	gap         = last["gap"]
	scan_i      = last["scan_i"]
	scan_j      = last["scan_j"]
	swap_needed = last["swap_needed"]

	for i in range(crates.size()):
		crates[i].position = last["positions"][i]
		crates[i].modulate = Color(1, 1, 1)
		crates[i].disabled = false

	for idx in last["locked"]:
		_lock_crate(idx)

	claw.visible   = false
	gap_label.text = "GAP = " + str(gap)
	_clear_gap_arcs()

	_show_instruction("↩️ Undo! Last swap reverted.")
	machine.report_placement(values)
	_show_current_step()


# ─────────────────────────────────────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────────────────────────────────────

func _highlight(idx: int, col: Color) -> void:
	if idx >= 0 and idx < crates.size():
		crates[idx].modulate = col


func _clear_highlights() -> void:
	for i in range(crates.size()):
		if not crates[i].disabled:
			crates[i].modulate = Color(1, 1, 1)


func _lock_crate(idx: int) -> void:
	if idx >= 0 and idx < crates.size():
		crates[idx].modulate = Color(1.5, 1.2, 0.0)
		crates[idx].disabled = true


func _get_locked_indices() -> Array:
	var locked : Array = []
	for i in range(crates.size()):
		if crates[i].disabled:
			locked.append(i)
	return locked


func _cx(crate: Control) -> float:
	return crate.position.x + crate.size.x * 0.5


func _show_instruction(msg: String) -> void:
	instruction_label.text     = msg
	instruction_label.modulate = Color(0.3, 0.85, 1)



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
	for i in range(values.size()):
		if values[i] != TARGET[i]:
			return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# WIN
# ─────────────────────────────────────────────────────────────────────────────

func _win() -> void:
	swapbtn.disabled = true
	skipbtn.disabled = true
	hintbtn.disabled = true

	var progress = _load_progress()
	progress["shell_done"] = true
	_save_progress(progress)

	if move_count <= 10:
		star1.texture         = STAR_3
		efficiency_label.text = "EFFICIENCY REMAINING : HIGH"
	elif move_count <= 16:
		star1.texture         = STAR_2
		efficiency_label.text = "EFFICIENCY REMAINING : MEDIUM"
	else:
		star1.texture         = STAR_1
		efficiency_label.text = "EFFICIENCY REMAINING : LOW"

	moves_label.text        = "MOVES : " + str(move_count)
	$Winpoint.visible       = true
	$Winpoint/Panel.visible = true


func _load_progress() -> Dictionary:
	if FileAccess.file_exists("user://progress.dat"):
		var file   = FileAccess.open("user://progress.dat", FileAccess.READ)
		var parsed = JSON.parse_string(file.get_as_text())
		file.close()
		if parsed != null and typeof(parsed) == TYPE_DICTIONARY:
			return parsed
	return {}


func _save_progress(progress: Dictionary) -> void:
	var save = FileAccess.open("user://progress.dat", FileAccess.WRITE)
	save.store_string(JSON.stringify(progress))
	save.close()
