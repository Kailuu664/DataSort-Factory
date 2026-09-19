extends Node2D

# ─────────────────────────────────────────────────────────────────────────────
# SELECTION SORT
# Crates: 50c, 60c, 40c, 10c, 20c, 30c — randomized on _ready()
# Target : [10, 20, 30, 40, 50, 60]
# Mechanic: tap any unsorted crate → SWAP places it into sorted_count slot
# Wrong picks swap anyway — natural consequence
# Correctly placed crates turn gold but are NOT disabled
# ─────────────────────────────────────────────────────────────────────────────

@onready var crates            = [$"50c", $"60c", $"40c", $"10c", $"20c", $"30c"]
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
const TARGET     : Array = [10, 20, 30, 40, 50, 60]
const RAIL_Y     = 27.0
const CLAW_UP    = 220
const CLAW_DOWN  = 430
const BASE_ANIM_SPEED = 0.35
var   ANIM_SPEED      = BASE_ANIM_SPEED

var values       : Array = [50, 60, 40, 10, 20, 30]
var history      : Array = []
var is_animating : bool  = false
var selected     : int   = -1
var move_count   : int   = 0
var sorted_count : int   = 0


# ─────────────────────────────────────────────────────────────────────────────
# GODOT LIFECYCLE
# ─────────────────────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if claw.visible:
		var local_top = (RAIL_Y - claw.global_position.y) / claw.scale.y
		cable.points  = PackedVector2Array([Vector2(0, local_top), Vector2(0, 0)])


func _ready() -> void:
	instruction_popup.visible = false
	$Winpoint.visible         = false
	$Failpoint.visible        = false
	redflash.modulate.a       = 0.0
	claw.visible              = false
	here_label.visible        = false

	_randomize_crates()

	for i in range(crates.size()):
		var node = crates[i]
		node.pressed.connect(func(): _on_crate_tapped(crates.find(node)))

	swapbtn.pressed.connect(_on_swap)
	hintbtn.pressed.connect(_on_hint)
	resetbtn.pressed.connect(_on_end)
	undobtn.pressed.connect(_on_undo)
	$Howtoplaybtn.pressed.connect(_on_howtoplay)
	retrybtn.pressed.connect(_on_reset)
	mainmenubtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/easymode.tscn"))
	nextlevelbtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/insertionsort.tscn"))
	failretrybtn.pressed.connect(_on_reset)
	failmenubtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/menu.tscn"))

	swapbtn.disabled = true
	machine.setup(values, TARGET)
	_mark_gold_all()
	_advance_sorted_count()
	_update_instruction()
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

func _on_crate_tapped(idx: int) -> void:
	if is_animating:
		return

	# Block tapping crates that are locked into final position
	if idx < sorted_count:
		_show_error("This crate is already in its final position!")
		return

	# Deselect on same tap
	if selected == idx:
		selected        = -1
		claw.visible    = false
		swapbtn.disabled = true
		_mark_gold_all()
		_update_instruction()
		return

	# Deselect previous
	if selected != -1:
		_mark_gold_all()

	selected = idx
	_mark_gold_all()
	crates[idx].modulate = Color(1.5, 1.2, 0.3)   # highlight selected
	claw.visible  = true
	claw.position = Vector2(_cx(crates[idx]), CLAW_UP)
	claw_anim.play("open")
	swapbtn.disabled = false

	var min_idx = _find_min()
	if idx == min_idx:
		_show_instruction("✅ [" + str(values[idx]) + "] is the minimum! Press SWAP to place it.")
	else:
		_show_instruction("⚠️ [" + str(values[idx]) + "] is NOT the minimum — [" + str(values[min_idx]) + "] is smaller. Swap anyway?")


# ─────────────────────────────────────────────────────────────────────────────
# SWAP
# ─────────────────────────────────────────────────────────────────────────────

func _on_swap() -> void:
	if is_animating or selected == -1:
		return

	var was_correct : bool = (selected == _find_min())

	move_count += 1
	_save_history()

	# If selected is already in the sorted_count slot — no physical swap needed
	if selected == sorted_count:
		_show_instruction("🔒 [" + str(values[selected]) + "] is already in position — confirming placement.")
		_mark_gold(sorted_count)
		sorted_count += 1
		_advance_sorted_count()
		selected         = -1
		claw.visible     = false
		swapbtn.disabled = true
		machine.report_placement(values)
		_update_instruction()
		if _is_sorted():
			_win()
		return

	_animate_swap(selected, sorted_count, was_correct)


func _animate_swap(a: int, b: int, was_correct: bool) -> void:
	is_animating     = true
	swapbtn.disabled = true
	var val_a : int  = values[a]

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
		claw.visible     = false
		is_animating     = false
		selected         = -1
		swapbtn.disabled = true

		# Check if correct value landed at sorted_count
		if values[sorted_count] == TARGET[sorted_count]:
			sorted_count += 1
			_advance_sorted_count()
			if was_correct:
				_show_instruction("✅ Correct! [" + str(val_a) + "] placed in position.")
			else:
				_show_instruction("🤔 Lucky! [" + str(val_a) + "] happened to land in the right spot.")
		else:
			_show_instruction("❌ Wrong pick! [" + str(val_a) + "] isn't the minimum — you'll need extra moves to fix this.")

		_mark_gold_all()
		machine.report_placement(values)
		_update_instruction()
		if _is_sorted():
			_win()
	)


# ─────────────────────────────────────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────────────────────────────────────

func _find_min() -> int:
	var min_idx = sorted_count
	for i in range(sorted_count + 1, values.size()):
		if values[i] < values[min_idx]:
			min_idx = i
	return min_idx


func _advance_sorted_count() -> void:
	while sorted_count < values.size() and values[sorted_count] == TARGET[sorted_count]:
		_mark_gold(sorted_count)
		sorted_count += 1


func _mark_gold(idx: int) -> void:
	crates[idx].modulate = Color(1.5, 1.2, 0.0)


func _mark_gold_all() -> void:
	for i in range(crates.size()):
		if _is_gold(i):
			crates[i].modulate = Color(1.5, 1.2, 0.0)
		elif i != selected:
			crates[i].modulate = Color(1, 1, 1)


func _is_gold(idx: int) -> bool:
	return values[idx] == TARGET[idx] and idx < sorted_count


func _cx(crate: Control) -> float:
	return crate.position.x + crate.size.x * 0.5


func _save_history() -> void:
	history.append({
		"values"      : values.duplicate(),
		"positions"   : crates.map(func(c): return c.position),
		"order"       : crates.duplicate(),
		"sorted_count": sorted_count,
		"selected"    : selected
	})


func _update_instruction() -> void:
	if sorted_count >= values.size():
		instruction_label.text = "✅ All crates sorted!"
		return
	if selected == -1:
		var min_val = values[_find_min()]
		instruction_label.text = "Find and tap the SMALLEST unsorted crate — it's [" + str(min_val) + "]"
	# If selected, message already set in _on_crate_tapped


func _show_instruction(msg: String) -> void:
	instruction_label.text     = msg
	instruction_label.modulate = Color(0.3, 0.85, 1)


func _show_error(msg: String) -> void:
	instruction_label.text     = "❌ " + msg
	instruction_label.modulate = Color(1, 0.3, 0.3)
	await get_tree().create_timer(2.0).timeout
	instruction_label.modulate = Color(0.3, 0.85, 1)
	_update_instruction()


func _is_sorted() -> bool:
	for i in range(values.size()):
		if values[i] != TARGET[i]:
			return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# HINT
# ─────────────────────────────────────────────────────────────────────────────

func _on_hint() -> void:
	if is_animating:
		return
	var min_idx = _find_min()
	here_label.position.x = _cx(crates[min_idx]) - here_label.size.x * 0.5
	here_label.visible    = true
	_show_instruction("💡 Tap crate [" + str(values[min_idx]) + "] — it's the smallest unsorted value!")
	crates[min_idx].modulate = Color(0.3, 1.5, 0.5)
	await get_tree().create_timer(2.0).timeout
	here_label.visible = false
	if selected != min_idx:
		_mark_gold_all()


# ─────────────────────────────────────────────────────────────────────────────
# UNDO
# ─────────────────────────────────────────────────────────────────────────────

func _on_undo() -> void:
	if is_animating or history.is_empty():
		return
	var last     = history.pop_back()
	values       = last["values"]
	crates       = last["order"]
	sorted_count = last["sorted_count"]
	selected     = last["selected"]

	for i in range(crates.size()):
		crates[i].position = last["positions"][i]

	_mark_gold_all()

	if selected != -1:
		crates[selected].modulate = Color(1.5, 1.2, 0.3)
		claw.visible              = true
		claw.position             = Vector2(_cx(crates[selected]), CLAW_UP)
		swapbtn.disabled          = false
	else:
		claw.visible     = false
		swapbtn.disabled = true

	_show_instruction("↩️ Undo! Last swap reverted.")
	machine.report_placement(values)
	_update_instruction()


# ─────────────────────────────────────────────────────────────────────────────
# RESET / END
# ─────────────────────────────────────────────────────────────────────────────

func _on_reset() -> void:
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


# ─────────────────────────────────────────────────────────────────────────────
# WIN
# ─────────────────────────────────────────────────────────────────────────────

func _win() -> void:
	swapbtn.disabled = true
	hintbtn.disabled = true
	claw.visible     = false

	var progress = _load_progress()
	progress["selection_done"] = true
	_save_progress(progress)

	# Optimal for 6 crates = 5 swaps
	if move_count <= 6:
		star1.texture         = STAR_3
		efficiency_label.text = "EFFICIENCY REMAINING : HIGH"
	elif move_count <= 10:
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
	var file = FileAccess.open("user://progress.dat", FileAccess.WRITE)
	file.store_string(JSON.stringify(progress))
	file.close()


# ─────────────────────────────────────────────────────────────────────────────
# SETTINGS
# ─────────────────────────────────────────────────────────────────────────────

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
		0: ANIM_SPEED = BASE_ANIM_SPEED
		1: ANIM_SPEED = BASE_ANIM_SPEED * 0.4
		2: ANIM_SPEED = 0.001

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

	# ── Audio ──────────────────────────────────────────────────────────────────
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
