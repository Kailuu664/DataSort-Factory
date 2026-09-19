extends Node2D

# ─────────────────────────────────────────────────────────────────────────────
# HEAP SORT  ·  heapsort.gd
# Starting : [20, 50, 30, 10, 60, 40, 70, 80, 90]   Target : [10, 20, 30, 40, 50, 60, 70, 80, 90]
# ─────────────────────────────────────────────────────────────────────────────

@onready var crates            = [$"20c", $"50c", $"30c", $"10c", $"60c", $"40c", $"70c", $"80c", $"90c"]
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
const BASE_ANIM_SPEED = 0.35
var   ANIM_SPEED       = BASE_ANIM_SPEED

var values      : Array = [20, 50, 30, 10, 60, 40, 70, 80, 90]
var heap_size   : int   = 9
var phase       : int   = 1
var is_animating: bool  = false
var move_count  : int   = 0
var history     : Array = []
var locked_nodes: Array = []
var tree_nodes  : Array = []

var heapify_seq : Array = []
var heapify_ptr : int   = 0

var sift_node      : int  = -1
var choosing_child : bool = false
var correct_child  : int  = -1
var decoy_child    : int  = -1

var extraction_pending: bool = false


func _process(_delta: float) -> void:
	if claw.visible:
		var local_top = (RAIL_Y - claw.global_position.y) / claw.scale.y
		cable.points  = PackedVector2Array([Vector2(0, local_top), Vector2(0, 0)])


func _ready() -> void:
	var progress = _load_progress()
	if not progress.get("quick_done", false):
		instruction_label.text = "⚠️  Complete Quick Sort first to unlock this level!"
		swapbtn.disabled       = true
		hintbtn.disabled       = true
		$Winpoint.visible      = false
		$Failpoint.visible     = false
		claw.visible           = false
		here_label.visible     = false
		return

	$Winpoint.visible                  = false
	$Failpoint.visible                 = false
	redflash.modulate.a                = 0.0
	claw.visible                       = false
	here_label.visible                 = false
	$Howtoplaybtn/Instruction/PanelContainer.visible = false

	for i in range(crates.size()):
		var node = crates[i]
		node.pressed.connect(func(): _on_crate_tapped(crates.find(node)))

	swapbtn.pressed.connect(_on_swap)
	hintbtn.pressed.connect(_on_hint)
	resetbtn.pressed.connect(_on_end)
	undobtn.pressed.connect(_on_undo)
	$Howtoplaybtn.pressed.connect(func():
		var panel = $Howtoplaybtn/Instruction/PanelContainer
		panel.visible = !panel.visible
	)
	retrybtn.pressed.connect(_on_reset)
	mainmenubtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/difficulty.tscn"))
	nextlevelbtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/shellsort.tscn"))
	failretrybtn.pressed.connect(_on_reset)
	failmenubtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/menu.tscn"))

	for i in range(9):
		tree_nodes.append($HeapTree.get_node_or_null("TreeNode" + str(i)))

	machine.setup(values, [10, 20, 30, 40, 50, 60, 70, 80, 90])

	for i in range(values.size() / 2 - 1, -1, -1):
		heapify_seq.append(i)

	phase_label.text = "PHASE 1: BUILD MAX-HEAP"
	_refresh_tree()
	_begin_sift(heapify_seq[0])

	_apply_settings()


func _on_crate_tapped(idx: int) -> void:
	if is_animating or not choosing_child:
		return

	if idx == correct_child:
		choosing_child = false
		_save_history()
		move_count    += 1
		_show_instruction("✅ Correct! Swapping parent with the larger child [%d]." % values[idx])
		_animate_swap(sift_node, correct_child, func():
			var swapped_to = correct_child
			_post_sift_swap(swapped_to)
		)

	elif idx == decoy_child:
		choosing_child    = false
		_save_history()
		move_count       += 1
		var original_sift = sift_node
		_animate_swap(sift_node, idx, func():
			instruction_label.text     = "❌ Wrong child! That one was smaller — heap needs extra fixing!"
			instruction_label.modulate = Color(1, 0.3, 0.3)
			await get_tree().create_timer(1.5).timeout
			instruction_label.modulate = Color(0.3, 0.85, 1)
			_post_sift_swap(original_sift)
		)


func _on_swap() -> void:
	if is_animating or choosing_child:
		return

	if extraction_pending:
		_save_history()
		move_count += 1
		_animate_swap(0, heap_size - 1, func():
			extraction_pending = false
			heap_size         -= 1
			_lock_crate_at(heap_size)
			_refresh_tree()
			machine.report_placement(values)
			_show_instruction("🔒 [%d] locked!  %d crate(s) still in heap." \
				% [values[heap_size], heap_size])
			if heap_size <= 1:
				_finish_last()
				return
			await get_tree().create_timer(0.9).timeout
			_begin_sift(0)
		)
		return

	if sift_node == -1:
		return
	_save_history()
	move_count += 1
	_animate_swap(sift_node, correct_child, func():
		var swapped_to = correct_child
		_post_sift_swap(swapped_to)
	)


func _begin_sift(node_idx: int) -> void:
	sift_node = node_idx
	var left  = 2 * node_idx + 1
	var right = 2 * node_idx + 2

	var children: Array = []
	if left  < heap_size: children.append(left)
	if right < heap_size: children.append(right)

	if children.is_empty():
		_advance_after_sift()
		return

	var largest = children[0]
	for c in children:
		if values[c] > values[largest]:
			largest = c

	if values[node_idx] >= values[largest]:
		_show_instruction("✅ [%d] ≥ its children — heap property satisfied, moving on." \
			% values[node_idx])
		await get_tree().create_timer(0.7).timeout
		_advance_after_sift()
		return

	correct_child = largest

	if children.size() == 2:
		decoy_child    = children[0] if children[1] == largest else children[1]
		choosing_child = true
		swapbtn.disabled = true
		_highlight_choice()
		_show_instruction(
			"🎯 Parent [%d] is too small!  TAP the child you want to swap it with." \
			% values[node_idx]
		)
	else:
		decoy_child      = -1
		choosing_child   = false
		swapbtn.disabled = false
		for i in range(crates.size()):
			if not _is_locked(crates[i]):
				crates[i].modulate = Color(0.15, 0.15, 0.15)
				crates[i].disabled = true
		crates[node_idx].modulate      = Color(2.5, 0.7, 0.0)
		crates[correct_child].modulate = Color(0.30, 0.85, 1.55)
		claw.visible  = true
		claw_anim.play("open")
		claw.position = Vector2(_cx(crates[node_idx]), CLAW_UP)
		_show_instruction(
			"[%d] < child [%d] — press SWAP to move the larger value up!" \
			% [values[node_idx], values[correct_child]]
		)
		_refresh_tree()


func _post_sift_swap(swapped_to: int) -> void:
	_refresh_tree()
	machine.report_placement(values)
	_begin_sift(swapped_to)


func _advance_after_sift() -> void:
	_clear_highlights()
	claw.visible = false
	_refresh_tree()

	if phase == 1:
		heapify_ptr += 1
		if heapify_ptr >= heapify_seq.size():
			_on_heap_built()
		else:
			_begin_sift(heapify_seq[heapify_ptr])
	else:
		_on_sift_complete()


func _on_heap_built() -> void:
	_clear_highlights()
	claw.visible = false
	var root = crates[0]
	root.modulate = Color(1.6, 1.5, 0.25)
	_show_instruction("✅ Max-Heap built! Root [%d] is the largest. Starting extraction…" % values[0])
	await get_tree().create_timer(1.3).timeout
	root.modulate = Color(1, 1, 1)

	phase            = 2
	phase_label.text = "PHASE 2: EXTRACT"
	_start_extraction()


func _start_extraction() -> void:
	if heap_size <= 1:
		_finish_last()
		return

	extraction_pending   = true
	choosing_child       = false
	swapbtn.disabled     = false
	sift_node            = -1
	for i in range(crates.size()):
		if not _is_locked(crates[i]):
			crates[i].modulate = Color(0.15, 0.15, 0.15)
			crates[i].disabled = true
	crates[0].modulate             = Color(2.5, 0.7, 0.0)
	crates[heap_size - 1].modulate = Color(0.30, 0.85, 1.55)
	claw.visible  = true
	claw_anim.play("open")
	claw.position = Vector2(_cx(crates[0]), CLAW_UP)
	_refresh_tree()
	_show_instruction(
		"PHASE 2: Extract [%d] (max) — press SWAP to move it to its final position." \
		% values[0]
	)


func _on_sift_complete() -> void:
	_clear_highlights()
	claw.visible = false
	var extracted_val = values[heap_size]
	_show_instruction("🔒 [%d] in final position!  %d crate(s) still in heap." \
		% [extracted_val, heap_size])
	_refresh_tree()

	if heap_size <= 1:
		_finish_last()
		return

	await get_tree().create_timer(1.0).timeout
	_start_extraction()


func _finish_last() -> void:
	_lock_crate_at(0)
	_refresh_tree()
	await get_tree().create_timer(0.5).timeout
	_win()


func _animate_swap(a: int, b: int, after_fn: Callable) -> void:
	is_animating     = true
	swapbtn.disabled = true
	claw.visible     = true
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
		var tv = values[a];          values[a]          = values[b];          values[b]          = tv
		var tp = crates[a].position; crates[a].position = crates[b].position; crates[b].position = tp
		var tn = crates[a];          crates[a]          = crates[b];          crates[b]          = tn
	)
	tween.tween_property(claw, "position:y", CLAW_UP, ANIM_SPEED)
	tween.tween_callback(func():
		is_animating     = false
		claw.visible     = false
		_clear_highlights()
		after_fn.call()
	)


func _refresh_tree() -> void:
	for i in range(9):
		if i >= tree_nodes.size() or tree_nodes[i] == null:
			continue
		var node: Polygon2D = tree_nodes[i]
		node.get_node("ValueLabel").text = str(values[i])

		if i == sift_node and not choosing_child:
			node.color = Color(1.0, 0.55, 0.10)
		elif choosing_child and i == sift_node:
			node.color = Color(1.0, 0.55, 0.10)
		elif choosing_child and (i == correct_child or i == decoy_child):
			node.color = Color(0.10, 0.75, 0.80)
		elif i >= heap_size:
			node.color = Color(0.82, 0.66, 0.08)
		elif extraction_pending and i == 0:
			node.color = Color(1.0, 0.55, 0.10)
		elif extraction_pending and i == heap_size - 1:
			node.color = Color(0.15, 0.75, 1.0)
		else:
			node.color = Color(0.18, 0.46, 0.82)


func _highlight_choice() -> void:
	for i in range(crates.size()):
		if not _is_locked(crates[i]):
			crates[i].modulate = Color(0.15, 0.15, 0.15)
			crates[i].disabled = true
	crates[sift_node].modulate     = Color(2.5, 0.7, 0.0)
	crates[correct_child].modulate = Color(0.0, 2.5, 0.4)
	crates[correct_child].disabled = false
	crates[decoy_child].modulate   = Color(0.0, 2.5, 0.4)
	crates[decoy_child].disabled   = false
	claw.visible = false
	_refresh_tree()


func _clear_highlights() -> void:
	for i in range(crates.size()):
		if not _is_locked(crates[i]):
			crates[i].modulate = Color(1, 1, 1)
			crates[i].disabled = false


func _lock_crate_at(idx: int) -> void:
	var node = crates[idx]
	if _is_locked(node):
		return
	node.modulate = Color(1.45, 1.10, 0.25)
	node.disabled = true
	locked_nodes.append(node)


func _is_locked(node) -> bool:
	return locked_nodes.has(node)


func _on_hint() -> void:
	if is_animating:
		return
	if choosing_child:
		_show_instruction(
			"💡 Tap [%d] — it's larger than [%d], so it should rise above the parent [%d]!" \
			% [values[correct_child], values[decoy_child], values[sift_node]]
		)
		crates[correct_child].modulate = Color(0.20, 2.0, 0.50)
		await get_tree().create_timer(1.0).timeout
		if not is_animating:
			crates[correct_child].modulate = Color(0.0, 2.5, 0.4)
		return
	if extraction_pending:
		_show_instruction(
			"💡 Root [%d] is the current maximum — press SWAP to lock it at the end." \
			% values[0]
		)
		return
	_show_instruction("Nothing needs a decision right now — just watch the step complete.")


func _on_reset() -> void:
	get_tree().reload_current_scene()


func _on_end() -> void:
	is_animating      = false
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


func _save_history() -> void:
	history.append({
		"values":             values.duplicate(),
		"crate_positions":    crates.map(func(c): return c.position),
		"crate_order":        crates.duplicate(),
		"heap_size":          heap_size,
		"phase":              phase,
		"heapify_ptr":        heapify_ptr,
		"sift_node":          sift_node,
		"choosing_child":     choosing_child,
		"correct_child":      correct_child,
		"decoy_child":        decoy_child,
		"extraction_pending": extraction_pending,
		"move_count":         move_count,
		"locked_nodes":       locked_nodes.duplicate(),
	})


func _on_undo() -> void:
	if is_animating or history.is_empty():
		return
	var last = history.pop_back()

	values             = last["values"]
	crates             = last["crate_order"]
	heap_size          = last["heap_size"]
	phase              = last["phase"]
	heapify_ptr        = last["heapify_ptr"]
	sift_node          = last["sift_node"]
	choosing_child     = last["choosing_child"]
	correct_child      = last["correct_child"]
	decoy_child        = last["decoy_child"]
	extraction_pending = last["extraction_pending"]
	move_count         = last["move_count"]

	for i in range(crates.size()):
		crates[i].position = last["crate_positions"][i]

	# Reset all crates to neutral first, then re-apply locked state
	for node in crates:
		node.modulate = Color(1, 1, 1)
		node.disabled = false
	locked_nodes = last["locked_nodes"]
	for node in locked_nodes:
		node.modulate = Color(1.45, 1.10, 0.25)
		node.disabled = true

	phase_label.text = "PHASE 1: BUILD MAX-HEAP" if phase == 1 else "PHASE 2: EXTRACT"
	_refresh_tree()
	machine.report_placement(values)

	if choosing_child:
		# Two-child choice state — re-highlight the two children for tapping
		swapbtn.disabled = true
		_highlight_choice()
		_show_instruction("↩️ Undo!  TAP the child to swap with parent [%d]." % values[sift_node])

	elif extraction_pending:
		# About to extract root — re-show claw over root, enable SWAP
		swapbtn.disabled = false
		_clear_highlights()
		crates[0].modulate             = Color(2.5, 0.7, 0.0)
		crates[heap_size - 1].modulate = Color(0.30, 0.85, 1.55)
		claw.visible  = true
		claw_anim.play("open")
		claw.position = Vector2(_cx(crates[0]), CLAW_UP)
		_show_instruction("↩️ Undo!  Press SWAP to extract [%d]." % values[0])

	else:
		# Normal sift state — re-enter _begin_sift so crates are highlighted
		# correctly and SWAP is enabled/disabled based on child count
		claw.visible = false
		_begin_sift(sift_node)
		# Prepend ↩️ to whatever instruction _begin_sift just set
		instruction_label.text = "↩️ Undo!  " + instruction_label.text


func _show_instruction(msg: String) -> void:
	instruction_label.text     = msg
	instruction_label.modulate = Color(0.3, 0.85, 1)


func _show_error(msg: String) -> void:
	instruction_label.text     = msg
	instruction_label.modulate = Color(1, 0.3, 0.3)
	await get_tree().create_timer(1.8).timeout
	instruction_label.modulate = Color(0.3, 0.85, 1)


# ── Settings loader ────────────────────────────────────────────────────────────
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


func _win() -> void:
	swapbtn.disabled = true
	hintbtn.disabled = true
	claw.visible     = false
	_show_instruction("🎉 Sorting complete! All crates are in their final positions!")

	var progress = _load_progress()
	progress["heap_done"] = true
	_save_progress(progress)

	if move_count <= 20:
		star1.texture         = STAR_3
		efficiency_label.text = "EFFICIENCY REMAINING : HIGH"
	elif move_count <= 28:
		star1.texture         = STAR_2
		efficiency_label.text = "EFFICIENCY REMAINING : MEDIUM"
	else:
		star1.texture         = STAR_1
		efficiency_label.text = "EFFICIENCY REMAINING : LOW"

	moves_label.text = "MOVES : " + str(move_count)
	await get_tree().create_timer(1.5).timeout
	$Winpoint.visible       = true
	$Winpoint/Panel.visible = true


func _cx(crate) -> float:
	return crate.position.x + crate.size.x * 0.5


func _load_progress() -> Dictionary:
	if FileAccess.file_exists("user://progress.dat"):
		var file   = FileAccess.open("user://progress.dat", FileAccess.READ)
		var parsed = JSON.parse_string(file.get_as_text())
		file.close()
		if parsed != null and typeof(parsed) == TYPE_DICTIONARY:
			return parsed
	return {}


func _save_progress(progress: Dictionary) -> void:
	var file = FileAccess.open("user://progress.dat", FileAccess.WRITE)
	file.store_string(JSON.stringify(progress))
	file.close()
