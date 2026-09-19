extends Node2D

# ─────────────────────────────────────────────────────────────────────────────
# TIM SORT  ·  timsort.gd
# Starting : [50, 20, 80, 10, 60, 30, 90, 40, 70]   Target : [10, 20, 30, 40, 50, 60, 70, 80, 90]
#
# PHASE 1 — Player taps to set 2 run boundaries (creates 3 runs of 3)
# PHASE 2 — Sort each run using tap+SWAP mechanic (insertion sort style)
# PHASE 3 — Player taps run buttons to choose which 2 runs to merge first
# PHASE 4 — PICK merges the 2 chosen runs into a temp row
# PHASE 5 — PICK merges the temp result with the remaining run (final output)
# ─────────────────────────────────────────────────────────────────────────────

@onready var crates            = [$"50c", $"20c", $"80c", $"10c", $"60c", $"30c", $"90c", $"40c", $"70c"]
@onready var swapbtn           = $swapbtn
@onready var hintbtn           = $hintbtn
@onready var resetbtn          = $resetbtn
@onready var undobtn           = $undobtn
@onready var claw              = $Claw
@onready var claw_anim         = $Claw/Anim
@onready var cable             = $Claw/Cable
@onready var machine           = $ProcessingMachine
@onready var instruction_label = $InstructionLabel
@onready var here_label        = $Label
@onready var run_div1          = $RunDivider1
@onready var run_div2          = $RunDivider2
@onready var run_btn           = [$RunLabel0, $RunLabel1, $RunLabel2]
@onready var temp_output_row   = $TempOutputRow
@onready var output_row        = $OutputRow
@onready var phase_label       = $PhaseLabel
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

const STAR_1     = preload("res://assets/ui/stars_1.png")
const STAR_2     = preload("res://assets/ui/stars_2.png")
const STAR_3     = preload("res://assets/ui/stars_3.png")
const RAIL_Y     = 27.0
const CLAW_UP    = 220
const CLAW_DOWN  = 430
const BASE_ANIM_SPEED = 0.38
var   ANIM_SPEED       = BASE_ANIM_SPEED

# ── Core ───────────────────────────────────────────────────────────────────────
var values       : Array = [50, 20, 80, 10, 60, 30, 90, 40, 70]
var history      : Array = []
var is_animating : bool  = false
var move_count   : int   = 0
var phase        : int   = 1

# ── Phase 1 ────────────────────────────────────────────────────────────────────
var run1_end      : int = -1
var run2_end      : int = -1
var boundary_step : int = 0

# ── Phase 2 ────────────────────────────────────────────────────────────────────
var current_run : int = 0
var sel_a       : int = -1
var sel_b       : int = -1

# ── Phase 3 ────────────────────────────────────────────────────────────────────
var merge_picks : Array = []
var merge_order : Array = []

# ── Phase 4 (first merge) ──────────────────────────────────────────────────────
var temp_values  : Array = []
var temp_slots   : Array = []
var ptr_a        : int   = 0
var ptr_b        : int   = 0
var run_a_hi     : int   = 0
var run_b_hi     : int   = 0
var temp_count   : int   = 0

# ── Phase 5 (final merge) ──────────────────────────────────────────────────────
var output_slots  : Array = []
var fin_ptr_temp  : int   = 0
var fin_ptr_rem   : int   = 0
var fin_rem_hi    : int   = 0
var output_count  : int   = 0


# ── Cable ──────────────────────────────────────────────────────────────────────
func _process(_delta: float) -> void:
	if claw.visible:
		var local_top = (RAIL_Y - claw.global_position.y) / claw.scale.y
		cable.points  = PackedVector2Array([Vector2(0, local_top), Vector2(0, 0)])


# ── Ready ──────────────────────────────────────────────────────────────────────
func _ready() -> void:
	$Howtoplaybtn/Instruction/PanelContainer.visible = false
	$Winpoint.visible  = false
	$Failpoint.visible = false
	redflash.modulate.a = 0.0
	claw.visible       = false
	here_label.visible = false
	run_div1.visible   = false
	run_div2.visible   = false
	temp_output_row.visible = false
	output_row.visible      = false
	for rb in run_btn: rb.visible = false

	for i in range(crates.size()):
		var node = crates[i]
		node.pressed.connect(func(): _on_crate_tapped(crates.find(node)))

	for i in range(3):
		var rb = run_btn[i]
		rb.pressed.connect(func(): _on_run_btn_tapped(run_btn.find(rb)))

	swapbtn.pressed.connect(_on_action)
	hintbtn.pressed.connect(_on_hint)
	resetbtn.pressed.connect(_on_end)
	undobtn.pressed.connect(_on_undo)
	$Howtoplaybtn.pressed.connect(func():
		var p = $Howtoplaybtn/Instruction/PanelContainer
		p.visible = !p.visible
	)
	retrybtn.pressed.connect(_on_reset)
	mainmenubtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/difficulty.tscn"))
	nextlevelbtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/shellsort.tscn"))
	failretrybtn.pressed.connect(_on_reset)
	failmenubtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/menu.tscn"))

	for child in temp_output_row.get_children():
		temp_slots.append(child)
	for child in output_row.get_children():
		output_slots.append(child)

	machine.setup(values.duplicate(), [10, 20, 30, 40, 50, 60, 70, 80, 90])
	_randomize_crates()
	_enter_phase1()
	_apply_settings()


# ═══════════════════════════════════════════════════════════════════════════════
#  PHASE 1 — BOUNDARY SELECTION (exactly 3 crates per run enforced)
# ═══════════════════════════════════════════════════════════════════════════════
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


func _enter_phase1() -> void:
	phase         = 1
	boundary_step = 0
	swapbtn.disabled = true
	phase_label.text = "PHASE 1: SET RUN BOUNDARIES"

	# ── Sync crates + values arrays to visual left-to-right order ──────────
	# Without this, array index != visual position, causing wrong dividers
	var paired = []
	for i in range(crates.size()):
		paired.append({"crate": crates[i], "value": values[i]})
	paired.sort_custom(func(a, b): return a["crate"].position.x < b["crate"].position.x)
	for i in range(crates.size()):
		crates[i] = paired[i]["crate"]
		values[i] = paired[i]["value"]
	# ───────────────────────────────────────────────────────────────────────

	_refresh_crate_states()
	_show_instruction("🎯 Tap the 3rd crate from the left to set RUN 1 boundary — splits crates 1–3.")


func _handle_boundary_tap(idx: int) -> void:
	if boundary_step == 0:
		# Only index 2 (3rd visual crate) is valid
		if idx != 2:
			_show_error("Tap the highlighted crate — Run 1 must contain exactly 3 crates!")
			return
		run1_end      = idx
		boundary_step = 1
		_place_divider(run_div1, idx)
		run_div1.visible = true
		crates[2].modulate = Color(1, 1, 1)
		_flash_crate(idx, Color(0.3, 0.85, 2.0))
		_show_instruction("✅ Run 1: crates 1–3.\nNow tap the 6th crate from the left to set RUN 2 boundary.")
	else:
		# Only index 5 (6th visual crate) is valid
		if idx != run1_end + 3:
			_show_error("Tap the highlighted crate — Run 2 must contain exactly 3 crates!")
			return
		run2_end = idx
		_place_divider(run_div2, idx)
		run_div2.visible = true
		_flash_crate(idx, Color(1.0, 0.6, 0.1))
		_show_instruction("✅ Runs set: [1–3]  [4–6]  [7–9] — 3 crates each. Now sort each run!")
		await get_tree().create_timer(1.2).timeout
		_enter_phase2()


func _place_divider(div: Line2D, after_idx: int) -> void:
	var right_edge = crates[after_idx].position.x + crates[after_idx].size.x
	var next_left  = crates[after_idx + 1].position.x if after_idx + 1 < crates.size() else right_edge + 20.0
	var x = (right_edge + next_left) * 0.5
	div.points = PackedVector2Array([Vector2(x, 385), Vector2(x, 605)])


# ═══════════════════════════════════════════════════════════════════════════════
#  PHASE 2 — SORT EACH RUN
# ═══════════════════════════════════════════════════════════════════════════════
func _enter_phase2() -> void:
	phase        = 2
	current_run  = 0
	sel_a        = -1
	sel_b        = -1
	swapbtn.disabled  = false
	phase_label.text  = "PHASE 2: SORT EACH RUN"
	_show_instruction("Sort RUN 1 (crates 1–3). Tap two crates, then press SWAP if out of order.")
	_refresh_crate_states()


func _handle_sort_tap(idx: int) -> void:
	var lo = _run_lo(current_run)
	var hi = _run_hi(current_run)
	if idx < lo or idx > hi:
		_show_error("Only tap crates inside the highlighted run!")
		return

	if idx == sel_a:
		_set_highlight(sel_a, false)
		sel_a = -1
		claw.visible = false
		return
	if idx == sel_b:
		_set_highlight(sel_b, false)
		sel_b = -1
		return

	if sel_a == -1:
		sel_a = idx
		_set_highlight(idx, true)
		claw.visible = true
		claw_anim.play("open")
		claw.position = Vector2(_cx(crates[idx]), CLAW_UP)
		_show_instruction("Crate %d picked — tap another in this run to compare." % values[idx])
	else:
		sel_b = idx
		_set_highlight(idx, true)
		var a = values[sel_a]; var b = values[sel_b]
		if a > b:
			_show_instruction("⚠️ %d > %d — press SWAP!" % [a, b])
		else:
			_show_instruction("✅ %d ≤ %d — already in order. Try another pair." % [a, b])


func _do_swap() -> void:
	if sel_a == -1 or sel_b == -1:
		_show_error("Select two crates inside the active run first!")
		return
	_save_history()
	move_count += 1
	_animate_swap(sel_a, sel_b, func():
		machine.report_placement(values)
		_set_highlight(sel_a, false)
		_set_highlight(sel_b, false)
		sel_a = -1; sel_b = -1
		claw.visible = false
		_check_run_sorted()
	)


func _check_run_sorted() -> void:
	if _is_run_sorted(current_run):
		_lock_run(current_run)
		current_run += 1
		if current_run >= 3:
			_show_instruction("✅ All runs sorted! Now choose which two runs to merge first.")
			await get_tree().create_timer(0.9).timeout
			_enter_phase3()
		else:
			var run_names = ["RUN 2", "RUN 3"]
			_show_instruction("✅ Run sorted! Now sort %s (crates %d–%d)." \
				% [run_names[current_run - 1], _run_lo(current_run) + 1, _run_hi(current_run) + 1])
			_refresh_crate_states()
	else:
		_show_instruction("Sort RUN %d — tap two crates and press SWAP if out of order." % (current_run + 1))
		_refresh_crate_states()


func _lock_run(run_idx: int) -> void:
	for i in range(_run_lo(run_idx), _run_hi(run_idx) + 1):
		crates[i].modulate = Color(1.5, 1.2, 0.0)
		crates[i].disabled = true


# ═══════════════════════════════════════════════════════════════════════════════
#  PHASE 3 — PICK MERGE ORDER
# ═══════════════════════════════════════════════════════════════════════════════
func _enter_phase3() -> void:
	phase       = 3
	merge_picks = []
	swapbtn.disabled = true
	phase_label.text = "PHASE 3: CHOOSE MERGE ORDER"

	for i in range(3):
		var lo    = _run_lo(i)
		var hi    = _run_hi(i)
		var mid_x = (_cx(crates[lo]) + _cx(crates[hi])) * 0.5
		var rb    = run_btn[i]
		rb.position = Vector2(mid_x - 100.0, 308.0)
		rb.size     = Vector2(200.0, 70.0)
		rb.text     = "RUN %d\n[%s]" % [i + 1, _run_values_str(i)]
		rb.modulate = Color(1, 1, 1)
		rb.visible  = true
		rb.disabled = false

	_show_instruction("🎯 Tap TWO run buttons to choose which runs to merge first. The third merges last.")
	_refresh_crate_states()


func _on_run_btn_tapped(run_idx: int) -> void:
	if phase != 3 or is_animating:
		return
	if run_idx in merge_picks:
		merge_picks.erase(run_idx)
		run_btn[run_idx].modulate = Color(1, 1, 1)
		_show_instruction("🎯 Tap TWO run buttons to choose which runs to merge first.")
		return
	if merge_picks.size() >= 2:
		return

	merge_picks.append(run_idx)
	run_btn[run_idx].modulate = Color(0.3, 1.5, 0.5)

	if merge_picks.size() == 2:
		var remain = -1
		for i in range(3):
			if i not in merge_picks:
				remain = i
				break
		merge_order = [merge_picks[0], merge_picks[1], remain]
		run_btn[remain].modulate = Color(0.4, 0.4, 0.4)

		var sz_a = _run_hi(merge_picks[0]) - _run_lo(merge_picks[0]) + 1
		var sz_b = _run_hi(merge_picks[1]) - _run_lo(merge_picks[1]) + 1
		_show_instruction("✅ Merging RUN %d + RUN %d (%d+%d elements). RUN %d merges last." \
			% [merge_picks[0]+1, merge_picks[1]+1, sz_a, sz_b, remain+1])
		await get_tree().create_timer(1.3).timeout
		_enter_phase4()
	else:
		_show_instruction("✅ RUN %d selected! Pick one more run to merge with it." % (run_idx + 1))


# ═══════════════════════════════════════════════════════════════════════════════
#  PHASE 4 — FIRST MERGE
# ═══════════════════════════════════════════════════════════════════════════════
func _enter_phase4() -> void:
	phase       = 4
	temp_count  = 0
	temp_values = []

	var ra = merge_order[0]
	var rb = merge_order[1]
	ptr_a    = _run_lo(ra)
	ptr_b    = _run_lo(rb)
	run_a_hi = _run_hi(ra)
	run_b_hi = _run_hi(rb)

	for i in range(3):
		for j in range(_run_lo(i), _run_hi(i) + 1):
			crates[j].modulate = Color(0.35, 0.35, 0.35) if i == merge_order[2] else Color(1, 1, 1)
			crates[j].disabled = (i == merge_order[2])

	for rb2 in run_btn: rb2.visible = false

	# ── Ensure temp_slots has enough panels for this merge ────────────────────
	var total = (run_a_hi - _run_lo(ra) + 1) + (run_b_hi - _run_lo(rb) + 1)
	while temp_slots.size() < total:
		var extra = temp_slots[0].duplicate()
		extra.modulate = Color(1, 1, 1)
		temp_output_row.add_child(extra)
		temp_slots.append(extra)
	for i in range(temp_slots.size()):
		var lbl = temp_slots[i].get_node_or_null("SlotLabel")
		if lbl != null: lbl.text = ""
		temp_slots[i].modulate = Color(1, 1, 1)
		temp_slots[i].visible  = (i < total)
	temp_output_row.visible = true

	# ── Tap-based picking — SWAP button not used in phase 4 ──────────────────
	swapbtn.disabled = true
	# enable only the two front crates so player taps them
	crates[ptr_a].disabled = false
	crates[ptr_b].disabled = false

	phase_label.text = "PHASE 4: MERGE RUN %d + RUN %d" % [merge_order[0]+1, merge_order[1]+1]
	_highlight_p4_fronts()
	_show_instruction("TAP the smaller front crate to send it to the output row.")


func _highlight_p4_fronts() -> void:
	for ri in [merge_order[0], merge_order[1]]:
		for j in range(_run_lo(ri), _run_hi(ri) + 1):
			if crates[j].visible: crates[j].modulate = Color(1, 1, 1)
	if ptr_a <= run_a_hi and crates[ptr_a].visible:
		crates[ptr_a].modulate = Color(0.3, 0.85, 2.0)
	if ptr_b <= run_b_hi and crates[ptr_b].visible:
		crates[ptr_b].modulate = Color(2.0, 0.85, 0.3)


func _on_crate_tapped_phase4(idx: int) -> void:
	if is_animating: return
	# only front crates of either run are valid taps
	if idx != ptr_a and idx != ptr_b:
		_show_error("Tap one of the highlighted front crates!")
		return

	# determine correct pick
	var correct: int
	if ptr_a > run_a_hi:
		correct = ptr_b
	elif ptr_b > run_b_hi:
		correct = ptr_a
	elif values[ptr_a] <= values[ptr_b]:
		correct = ptr_a
	else:
		correct = ptr_b

	if idx != correct:
		_show_error("❌ Wrong! %d is NOT the smallest — pick the smaller front crate first!" % values[idx])
		return

	_save_history()
	move_count += 1

	_animate_to_slot(crates[idx], temp_slots[temp_count], func():
		var val = values[idx]
		_fill_slot(temp_slots[temp_count], val)
		temp_values.append(val)
		crates[idx].visible = false
		if idx == ptr_a: ptr_a += 1
		else:             ptr_b += 1
		temp_count += 1
		machine.report_placement(values)
		if ptr_a > run_a_hi and ptr_b > run_b_hi:
			await get_tree().create_timer(0.7).timeout
			_enter_phase5()
		else:
			# re-enable only the new front crates
			for j in range(crates.size()): crates[j].disabled = true
			if ptr_a <= run_a_hi: crates[ptr_a].disabled = false
			if ptr_b <= run_b_hi: crates[ptr_b].disabled = false
			_highlight_p4_fronts()
			_show_instruction("TAP the smaller front crate to send it to the output row.")
	)


# ═══════════════════════════════════════════════════════════════════════════════
#  PHASE 5 — FINAL MERGE
# ═══════════════════════════════════════════════════════════════════════════════
func _enter_phase5() -> void:
	phase        = 5
	output_count = 0
	fin_ptr_temp = 0
	fin_ptr_rem  = _run_lo(merge_order[2])
	fin_rem_hi   = _run_hi(merge_order[2])

	# ── Ensure output_slots has 9 panels ──────────────────────────────────────
	while output_slots.size() < 9:
		var extra = output_slots[0].duplicate()
		var lbl = extra.get_node_or_null("SlotLabel")
		if lbl: lbl.text = ""
		extra.modulate = Color(1, 1, 1)
		output_row.add_child(extra)
		output_slots.append(extra)
	for i in range(output_slots.size()):
		var lbl = output_slots[i].get_node_or_null("SlotLabel")
		if lbl: lbl.text = ""
		output_slots[i].modulate = Color(1, 1, 1)
		output_slots[i].visible  = true
	output_row.visible = true

	# ── Add tappable Button overlays on temp_slots ────────────────────────────
	for i in range(temp_slots.size()):
		if i < temp_values.size():
			var existing = temp_slots[i].get_node_or_null("PickBtn")
			if existing == null:
				var btn = Button.new()
				btn.name = "PickBtn"
				btn.flat = true
				btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				var sbe = StyleBoxEmpty.new()
				btn.add_theme_stylebox_override("normal",   sbe)
				btn.add_theme_stylebox_override("hover",    sbe)
				btn.add_theme_stylebox_override("pressed",  sbe)
				btn.add_theme_stylebox_override("focus",    sbe)
				var capture_i = i
				btn.pressed.connect(func(): _on_temp_slot_tapped(capture_i))
				temp_slots[i].add_child(btn)

	# ── Enable remaining run crates for tapping ───────────────────────────────
	for j in range(fin_ptr_rem, fin_rem_hi + 1):
		crates[j].modulate = Color(1.0, 1.0, 1.0)
		crates[j].disabled = false

	swapbtn.disabled = true
	phase_label.text = "PHASE 5: FINAL MERGE"
	_highlight_p5_fronts()
	_show_instruction("TAP the smaller front crate from either source to move it to the output row.")


func _highlight_p5_fronts() -> void:
	if fin_ptr_temp < temp_slots.size() and fin_ptr_temp < temp_values.size():
		for i in range(temp_slots.size()):
			if i < temp_values.size():
				temp_slots[i].modulate = Color(0.3, 0.85, 2.0) if i == fin_ptr_temp else Color(0.6, 0.6, 0.6)
	if fin_ptr_rem <= fin_rem_hi:
		crates[fin_ptr_rem].modulate = Color(2.0, 0.85, 0.3)


func _on_temp_slot_tapped(slot_idx: int) -> void:
	if is_animating or phase != 5: return
	if slot_idx != fin_ptr_temp:
		_show_error("Tap the FRONT of the temp row — that's slot %d!" % fin_ptr_temp)
		return

	# validate it's the correct pick
	if fin_ptr_rem <= fin_rem_hi and temp_values[slot_idx] > values[fin_ptr_rem]:
		_show_error("❌ Wrong! %d is NOT the smallest — pick %d from RUN %d first!" \
			% [temp_values[slot_idx], values[fin_ptr_rem], merge_order[2]+1])
		return

	_save_history()
	move_count += 1
	_animate_to_slot(temp_slots[fin_ptr_temp], output_slots[output_count], func():
		_fill_slot(output_slots[output_count], temp_values[fin_ptr_temp])
		temp_slots[fin_ptr_temp].modulate = Color(0.3, 0.3, 0.3)
		var btn = temp_slots[fin_ptr_temp].get_node_or_null("PickBtn")
		if btn: btn.disabled = true
		fin_ptr_temp += 1
		output_count += 1
		machine.report_placement(_current_output_values())
		_after_p5_pick()
	)


func _on_crate_tapped_phase5(idx: int) -> void:
	if is_animating or phase != 5: return
	if idx != fin_ptr_rem:
		_show_error("Tap the FRONT of the remaining run!")
		return

	# validate it's the correct pick
	if fin_ptr_temp < temp_values.size() and values[idx] > temp_values[fin_ptr_temp]:
		_show_error("❌ Wrong! %d is NOT the smallest — pick %d from the temp row first!" \
			% [values[idx], temp_values[fin_ptr_temp]])
		return

	_save_history()
	move_count += 1
	_animate_to_slot(crates[fin_ptr_rem], output_slots[output_count], func():
		_fill_slot(output_slots[output_count], values[fin_ptr_rem])
		crates[fin_ptr_rem].visible  = false
		crates[fin_ptr_rem].disabled = true
		fin_ptr_rem += 1
		output_count += 1
		machine.report_placement(_current_output_values())
		_after_p5_pick()
	)


func _after_p5_pick() -> void:
	if output_count >= 9:
		_win()
	else:
		# auto-collect if one side is exhausted
		if fin_ptr_temp >= temp_values.size() and fin_ptr_rem <= fin_rem_hi:
			# remaining run side exhausted from temp — auto finish remaining
			_show_instruction("Temp row done! TAP the next crate from RUN %d." % (merge_order[2]+1))
		elif fin_ptr_rem > fin_rem_hi and fin_ptr_temp < temp_values.size():
			_show_instruction("Remaining run done! TAP the next crate from the temp row.")
		else:
			_show_instruction("TAP the smaller front crate to move it to the output row.")
		_highlight_p5_fronts()
		# keep correct crates enabled
		for j in range(crates.size()): crates[j].disabled = true
		if fin_ptr_rem <= fin_rem_hi:
			crates[fin_ptr_rem].disabled = false


func _current_output_values() -> Array:
	var out = []
	for slot in output_slots:
		var lbl = slot.get_node_or_null("SlotLabel")
		if lbl and lbl.text != "":
			out.append(int(lbl.text))
	return out


# ═══════════════════════════════════════════════════════════════════════════════
#  ACTION BUTTON ROUTER
# ═══════════════════════════════════════════════════════════════════════════════
func _on_action() -> void:
	if is_animating: return
	match phase:
		2: _do_swap()
		# phases 4 and 5 are tap-driven — SWAP button not used


# ═══════════════════════════════════════════════════════════════════════════════
#  CRATE TAP ROUTER
# ═══════════════════════════════════════════════════════════════════════════════
func _on_crate_tapped(idx: int) -> void:
	if is_animating: return
	match phase:
		1: _handle_boundary_tap(idx)
		2: _handle_sort_tap(idx)
		4: _on_crate_tapped_phase4(idx)
		5: _on_crate_tapped_phase5(idx)


# ═══════════════════════════════════════════════════════════════════════════════
#  CLAW ANIMATION
# ═══════════════════════════════════════════════════════════════════════════════
func _animate_swap(a: int, b: int, after_fn: Callable) -> void:
	is_animating = true
	claw.visible = true
	claw_anim.play("open")
	claw.position = Vector2(_cx(crates[a]), CLAW_UP)

	var tween = create_tween()
	tween.tween_property(claw, "position", Vector2(_cx(crates[a]), CLAW_DOWN), ANIM_SPEED)
	tween.tween_callback(func(): claw_anim.play("grip"))
	tween.tween_property(claw, "position:y", CLAW_UP,        ANIM_SPEED)
	tween.tween_property(claw, "position:x", _cx(crates[b]), ANIM_SPEED)
	tween.tween_property(claw, "position:y", CLAW_DOWN,      ANIM_SPEED)
	tween.tween_callback(func():
		claw_anim.play("open")
		var tv = values[a];            values[a]          = values[b];           values[b]          = tv
		var tp = crates[a].position;   crates[a].position = crates[b].position;  crates[b].position = tp
		var tn = crates[a];            crates[a]          = crates[b];           crates[b]          = tn
	)
	tween.tween_property(claw, "position:y", CLAW_UP, ANIM_SPEED)
	tween.tween_callback(func():
		is_animating = false
		claw.visible = false
		after_fn.call()
	)


func _animate_to_slot(from_node: Control, to_slot: Control, after_fn: Callable) -> void:
	is_animating = true
	claw.visible = true
	claw_anim.play("open")

	var from_cx = from_node.global_position.x + from_node.size.x * 0.5
	var slot_cx = to_slot.global_position.x + to_slot.size.x * 0.5
	var slot_cy = to_slot.global_position.y + to_slot.size.y * 0.5

	claw.position = Vector2(from_cx, CLAW_UP)
	var tween = create_tween()
	tween.tween_property(claw, "position:y", CLAW_DOWN,      ANIM_SPEED)
	tween.tween_callback(func(): claw_anim.play("grip"))
	tween.tween_property(claw, "position:y", CLAW_UP,        ANIM_SPEED)
	tween.tween_property(claw, "position:x", slot_cx,        ANIM_SPEED)
	tween.tween_property(claw, "position:y", slot_cy - 40.0, ANIM_SPEED * 0.6)
	tween.tween_callback(func(): claw_anim.play("open"))
	tween.tween_property(claw, "position:y", CLAW_UP,        ANIM_SPEED * 0.6)
	tween.tween_callback(func():
		is_animating = false
		claw.visible = false
		after_fn.call()
	)


# ═══════════════════════════════════════════════════════════════════════════════
#  HINT
# ═══════════════════════════════════════════════════════════════════════════════
func _on_hint() -> void:
	if is_animating: return
	match phase:
		1:
			if boundary_step == 0:
				_show_instruction("💡 Tap the 3rd crate (position 3) to end Run 1 there.")
			else:
				_show_instruction("💡 Tap the 6th crate (position 6) to end Run 2 there.")
		2:
			var lo = _run_lo(current_run)
			var hi = _run_hi(current_run)
			for i in range(lo, hi):
				if values[i] > values[i + 1]:
					_show_instruction("💡 Swap crate %d and %d!" % [values[i], values[i+1]])
					_flash_pair(i, i+1)
					return
			_show_instruction("💡 This run is already sorted — it will auto-advance!")
		3:
			_show_instruction("💡 Tip: merge the two smallest runs first for fewer total operations!")
		4:
			var pick: int
			if ptr_a > run_a_hi: pick = ptr_b
			elif ptr_b > run_b_hi: pick = ptr_a
			elif values[ptr_a] <= values[ptr_b]: pick = ptr_a
			else: pick = ptr_b
			_show_instruction("💡 TAP crate %d — it's the smaller front crate!" % values[pick])
			_flash_crate(pick, Color(0.3, 2.0, 0.5))
		5:
			if fin_ptr_temp < temp_values.size() and fin_ptr_rem <= fin_rem_hi:
				var tv = temp_values[fin_ptr_temp]
				var rv = values[fin_ptr_rem]
				if tv <= rv:
					_show_instruction("💡 TAP slot %d in the temp row (%d) — it's smaller than %d!" % [fin_ptr_temp, tv, rv])
				else:
					_show_instruction("💡 TAP crate %d from RUN %d — it's smaller than temp %d!" % [rv, merge_order[2]+1, tv])
			elif fin_ptr_rem > fin_rem_hi:
				_show_instruction("💡 TAP the next slot in the temp row — remaining run is done!")
			else:
				_show_instruction("💡 TAP the next crate from RUN %d — temp row is done!" % (merge_order[2]+1))


func _flash_pair(a: int, b: int) -> void:
	_set_highlight(a, true); _set_highlight(b, true)
	await get_tree().create_timer(1.2).timeout
	if sel_a != a: _set_highlight(a, false)
	if sel_b != b: _set_highlight(b, false)


func _flash_crate(idx: int, col: Color) -> void:
	var orig = crates[idx].modulate
	var tw   = create_tween()
	tw.tween_property(crates[idx], "modulate", col,  0.12)
	tw.tween_property(crates[idx], "modulate", orig, 0.35)


# ═══════════════════════════════════════════════════════════════════════════════
#  UNDO / RESET
# ═══════════════════════════════════════════════════════════════════════════════
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


func _save_history() -> void:
	history.push_back({
		"values":       values.duplicate(),
		"positions":    crates.map(func(c): return c.position),
		"order":        crates.duplicate(),
		"visible":      crates.map(func(c): return c.visible),
		"phase":        phase,
		"sel_a":        sel_a,
		"sel_b":        sel_b,
		"current_run":  current_run,
		"ptr_a":        ptr_a,   "ptr_b":       ptr_b,
		"temp_values":  temp_values.duplicate(),
		"temp_count":   temp_count,
		"fin_ptr_temp": fin_ptr_temp, "fin_ptr_rem": fin_ptr_rem,
		"output_count": output_count,
	})


func _on_undo() -> void:
	if is_animating or history.is_empty(): return
	var last = history.pop_back()

	values       = last["values"]
	crates       = last["order"]
	phase        = last["phase"]
	sel_a        = last["sel_a"]
	sel_b        = last["sel_b"]
	current_run  = last["current_run"]
	ptr_a        = last["ptr_a"];   ptr_b       = last["ptr_b"]
	temp_values  = last["temp_values"]; temp_count = last["temp_count"]
	fin_ptr_temp = last["fin_ptr_temp"]; fin_ptr_rem = last["fin_ptr_rem"]
	output_count = last["output_count"]

	for i in range(crates.size()):
		crates[i].position = last["positions"][i]
		crates[i].visible  = last["visible"][i]

	machine.report_placement(values)
	_refresh_crate_states()
	_show_instruction("↩️ Undo!")


# ═══════════════════════════════════════════════════════════════════════════════
#  HELPERS
# ═══════════════════════════════════════════════════════════════════════════════
func _run_lo(run_idx: int) -> int:
	match run_idx:
		0: return 0
		1: return run1_end + 1
		2: return run2_end + 1
	return 0


func _run_hi(run_idx: int) -> int:
	match run_idx:
		0: return run1_end
		1: return run2_end
		2: return 8
	return 8


func _is_run_sorted(run_idx: int) -> bool:
	var lo = _run_lo(run_idx)
	var hi = _run_hi(run_idx)
	for i in range(lo, hi):
		if values[i] > values[i + 1]: return false
	return true


func _run_values_str(run_idx: int) -> String:
	var lo = _run_lo(run_idx)
	var hi = _run_hi(run_idx)
	var parts = []
	for i in range(lo, hi + 1): parts.append(str(values[i]))
	return ", ".join(parts)


func _refresh_crate_states() -> void:
	for i in range(crates.size()):
		crates[i].disabled = true
		if phase == 1:
			crates[i].modulate = Color(1, 1, 1)
			crates[i].disabled = false
		elif phase == 2:
			var lo = _run_lo(current_run)
			var hi = _run_hi(current_run)
			if i < lo or i > hi:
				crates[i].modulate = Color(0.4, 0.4, 0.4) if i > hi else Color(1.5, 1.2, 0.0)
			else:
				if i != sel_a and i != sel_b:
					crates[i].modulate = Color(1, 1, 1)
				crates[i].disabled = false
		elif phase == 3:
			crates[i].modulate = Color(1.5, 1.2, 0.0)


func _set_highlight(idx: int, on: bool) -> void:
	if idx < 0 or idx >= crates.size(): return
	crates[idx].modulate = Color(1.5, 1.2, 0.3) if on else Color(1, 1, 1)


func _cx(crate: Control) -> float:
	return crate.position.x + crate.size.x * 0.5


func _fill_slot(panel: Control, val: int) -> void:
	var lbl: Label = panel.get_node_or_null("SlotLabel")
	if lbl == null:
		lbl = Label.new()
		lbl.name = "SlotLabel"
		lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 30)
		panel.add_child(lbl)
	lbl.text       = str(val)
	panel.modulate = Color(0.3, 1.0, 0.5)


func _show_instruction(msg: String) -> void:
	instruction_label.text     = msg
	instruction_label.modulate = Color(0.3, 0.85, 1)


func _show_error(msg: String) -> void:
	instruction_label.text     = "❌ " + msg
	instruction_label.modulate = Color(1, 0.3, 0.3)
	await get_tree().create_timer(2.2).timeout
	instruction_label.modulate = Color(0.3, 0.85, 1)


# ═══════════════════════════════════════════════════════════════════════════════
#  SETTINGS
# ═══════════════════════════════════════════════════════════════════════════════
func _apply_settings() -> void:
	const PATH = "user://settings.dat"
	if not FileAccess.file_exists(PATH):
		return
	var file   = FileAccess.open(PATH, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		return

	var speed_setting = int(parsed.get("anim_speed", 0))
	match speed_setting:
		0: ANIM_SPEED = BASE_ANIM_SPEED
		1: ANIM_SPEED = BASE_ANIM_SPEED * 0.4
		2: ANIM_SPEED = 0.001

	var hint_on = bool(parsed.get("hint_mode", true))
	if instruction_label:
		instruction_label.visible = hint_on

	var brightness = float(parsed.get("brightness", 1.0))
	if not has_node("SettingsBrightness"):
		var cm      = CanvasModulate.new()
		cm.name     = "SettingsBrightness"
		cm.color    = Color(brightness, brightness, brightness, 1.0)
		add_child(cm)
	else:
		$SettingsBrightness.color = Color(brightness, brightness, brightness, 1.0)

	var music_vol = float(parsed.get("music_volume", 1.0))
	var mute_all  = bool(parsed.get("mute_all", false))
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


# ═══════════════════════════════════════════════════════════════════════════════
#  WIN
# ═══════════════════════════════════════════════════════════════════════════════
func _win() -> void:
	swapbtn.disabled = true
	hintbtn.disabled = true
	claw.visible     = false

	var progress = {}
	if FileAccess.file_exists("user://progress.dat"):
		var file   = FileAccess.open("user://progress.dat", FileAccess.READ)
		var parsed = JSON.parse_string(file.get_as_text())
		file.close()
		if parsed != null and typeof(parsed) == TYPE_DICTIONARY:
			progress = parsed
	progress["timsort_done"] = true
	var save = FileAccess.open("user://progress.dat", FileAccess.WRITE)
	save.store_string(JSON.stringify(progress))
	save.close()

	if move_count <= 20:
		star1.texture         = STAR_3
		efficiency_label.text = "EFFICIENCY REMAINING : HIGH"
	elif move_count <= 30:
		star1.texture         = STAR_2
		efficiency_label.text = "EFFICIENCY REMAINING : MEDIUM"
	else:
		star1.texture         = STAR_1
		efficiency_label.text = "EFFICIENCY REMAINING : LOW"

	moves_label.text        = "MOVES : " + str(move_count)
	$Winpoint.visible       = true
	$Winpoint/Panel.visible = true
