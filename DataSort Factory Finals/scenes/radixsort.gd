extends Node2D

# ══════════════════════════════════════════════════════════════════════════════
#  RADIX SORT — LSD Base-10
#  Starting order : [30, 10, 60, 20, 50, 40]
#  Target         : [10, 20, 30, 40, 50, 60]
#  Pass 1 → sort by ones digit  (all are 0 → identity pass, teaches algorithm)
#  Pass 2 → sort by tens digit  (1,2,3,4,5,6 → fully sorted)
# ══════════════════════════════════════════════════════════════════════════════

# ── Node refs ────────────────────────────────────────────────────────────────
@onready var collectbtn        = $collectbtn
@onready var hintbtn           = $hintbtn
@onready var resetbtn          = $resetbtn
@onready var undobtn           = $undobtn
@onready var claw              = $Claw
@onready var claw_anim         = $Claw/Anim
@onready var cable             = $Claw/Cable
@onready var instruction_popup = $Howtoplaybtn/Instruction
@onready var instruction_label = $InstructionLabel
@onready var pass_label        = $PassLabel
@onready var machine           = $ProcessingMachine
@onready var star1             = $Winpoint/Panel/HBoxContainer/"1star"
@onready var moves_label       = $Winpoint/Panel/moves
@onready var efficiency_label  = $Winpoint/Panel/efficiency
@onready var retrybtn          = $Winpoint/Panel/retrybtn
@onready var mainmenubtn       = $Winpoint/Panel/mainmenubtn
@onready var nextlevelbtn      = $Winpoint/Panel/nextlevelbtn

# Crate TextureButton nodes in the InputRow (left → right display order)
@onready var crate_nodes: Array = [
	$InputRow/Slot0/CrateBtn,
	$InputRow/Slot1/CrateBtn,
	$InputRow/Slot2/CrateBtn,
	$InputRow/Slot3/CrateBtn,
	$InputRow/Slot4/CrateBtn,
	$InputRow/Slot5/CrateBtn,
]
# Digit label under each crate slot
@onready var digit_labels: Array = [
	$InputRow/Slot0/DigitLabel,
	$InputRow/Slot1/DigitLabel,
	$InputRow/Slot2/DigitLabel,
	$InputRow/Slot3/DigitLabel,
	$InputRow/Slot4/DigitLabel,
	$InputRow/Slot5/DigitLabel,
]
# Bucket Panel nodes (0–9)
@onready var bucket_panels: Array = [
	$BucketArea/B0, $BucketArea/B1, $BucketArea/B2,
	$BucketArea/B3, $BucketArea/B4, $BucketArea/B5,
	$BucketArea/B6, $BucketArea/B7, $BucketArea/B8,
	$BucketArea/B9,
]

const STAR_1 = preload("res://assets/ui/stars_1.png")
const STAR_2 = preload("res://assets/ui/stars_2.png")
const STAR_3 = preload("res://assets/ui/stars_3.png")

# Crate textures — index matches crate value / 10  (10→idx0, 20→idx1 … 60→idx5)
const CRATE_TEX = {
	10: preload("res://assets/crates/10c.png"),
	20: preload("res://assets/crates/20c.png"),
	30: preload("res://assets/crates/30c.png"),
	40: preload("res://assets/crates/40c.png"),
	50: preload("res://assets/crates/50c.png"),
	60: preload("res://assets/crates/60c.png"),
}

# ── State ─────────────────────────────────────────────────────────────────────
var input_values : Array  = [30, 10, 60, 20, 50, 40]  # live order in input row
var buckets      : Array  = []   # Array of 10 Arrays
var history      : Array  = []   # for undo

var pass_num        : int  = 1   # 1 = ones pass, 2 = tens pass
var digit_place     : int  = 1   # 1 = ones, 10 = tens
var placed_count    : int  = 0   # crates placed into buckets this pass
var selected_crate  : int  = -1  # index into input_values / crate_nodes
var move_count      : int  = 0
var is_animating    : bool = false
var placed_flags    : Array = []  # bool per slot: true = already in a bucket

const CLAW_UP    = 300
const CLAW_DOWN  = 490
const BASE_ANIM_SPEED = 0.35
var   ANIM_SPEED       = BASE_ANIM_SPEED
const RAIL_Y     = 300.0   # InputRow world-Y; cable stretches down to bucket area


func _process(_delta: float) -> void:
	if claw.visible:
		var local_top = (RAIL_Y - claw.global_position.y) / claw.scale.y
		cable.points = PackedVector2Array([Vector2(0, local_top), Vector2(0, 0)])


# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	instruction_popup.visible = false
	$Winpoint.visible         = false
	$Winpoint/Panel.visible   = false
	claw.visible              = false

	_reset_buckets()
	placed_flags = []
	for i in range(input_values.size()):
		placed_flags.append(false)

	collectbtn.pressed.connect(_on_collect)
	hintbtn.pressed.connect(_on_hint)
	resetbtn.pressed.connect(_on_reset)
	undobtn.pressed.connect(_on_undo)
	$Howtoplaybtn.pressed.connect(_on_howtoplay)
	retrybtn.pressed.connect(_on_reset)
	mainmenubtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/difficulty.tscn"))
	nextlevelbtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/difficulty.tscn"))

	# Wire crate buttons
	for i in range(crate_nodes.size()):
		var idx = i
		crate_nodes[i].pressed.connect(func(): _on_crate_tapped(idx))

	# Wire bucket taps
	for b in range(10):
		var bi = b
		bucket_panels[b].gui_input.connect(func(ev): _on_bucket_input(ev, bi))

	collectbtn.disabled = true
	_refresh_crate_display()
	_refresh_digit_labels()
	_update_pass_label()
	_show_instruction("PASS 1: Tap a crate, then tap the bucket matching its ONES digit.")
	machine.setup(input_values, [10, 20, 30, 40, 50, 60])


	_apply_settings()
func _on_howtoplay() -> void:
	instruction_popup.visible = !instruction_popup.visible


# ── Digit helper ──────────────────────────────────────────────────────────────
func _get_digit(value: int, place: int) -> int:
	return (value / place) % 10


# ── Crate tapped ─────────────────────────────────────────────────────────────
func _on_crate_tapped(idx: int) -> void:
	if is_animating:
		return
	if placed_flags[idx]:
		_show_error("Crate " + str(input_values[idx]) + " is already in a bucket!")
		return

	# Deselect if tapping the same one
	if selected_crate == idx:
		_set_highlight(selected_crate, false)
		selected_crate = -1
		claw.visible = false
		_show_instruction(_idle_instruction())
		return

	# Select new crate
	if selected_crate != -1:
		_set_highlight(selected_crate, false)

	selected_crate = idx
	_set_highlight(idx, true)
	claw.visible = true
	claw_anim.play("open")
	claw.position = Vector2(_cx(crate_nodes[idx]), CLAW_UP)

	var val = input_values[idx]
	var d   = _get_digit(val, digit_place)
	var pass_word = "ones" if pass_num == 1 else "tens"
	_show_instruction("Crate [" + str(val) + "] — " + pass_word + " digit is [" + str(d) + "]. Tap bucket " + str(d) + ".")


# ── Bucket tapped ─────────────────────────────────────────────────────────────
func _on_bucket_input(event: InputEvent, bucket_idx: int) -> void:
	if not (event is InputEventScreenTouch or event is InputEventMouseButton):
		return
	if event is InputEventMouseButton and not event.pressed:
		return
	if event is InputEventScreenTouch and not event.pressed:
		return
	if is_animating:
		return
	if selected_crate == -1:
		_show_instruction("Select a crate first, then tap a bucket.")
		return

	var val          = input_values[selected_crate]
	var correct_digit = _get_digit(val, digit_place)

	if bucket_idx != correct_digit:
		# Wrong bucket — flash red, no move counted
		_flash_bucket_error(bucket_idx)
		var pass_word = "ones" if pass_num == 1 else "tens"
		_show_error("❌ Wrong bucket! Crate [" + str(val) + "]'s " + pass_word + " digit is [" + str(correct_digit) + "], not [" + str(bucket_idx) + "]. Try bucket " + str(correct_digit) + ".")
		return

	# Correct placement
	move_count += 1
	history.append({
		"input_values":  input_values.duplicate(),
		"placed_flags":  placed_flags.duplicate(),
		"buckets":       _deep_copy_buckets(),
		"selected":      -1,
		"placed_count":  placed_count,
	})

	_animate_to_bucket(selected_crate, bucket_idx)


func _animate_to_bucket(crate_idx: int, bucket_idx: int) -> void:
	is_animating = true
	var val = input_values[crate_idx]
	var bucket_cx = _bucket_cx(bucket_idx)
	var bucket_top_y = _bucket_drop_y(bucket_idx)

	var tween = create_tween()
	# Rise to CLAW_UP (already there) → move X to bucket column → descend
	claw_anim.play("grip")
	tween.tween_property(claw, "position:y", CLAW_UP, ANIM_SPEED * 0.5)
	tween.tween_property(claw, "position:x", bucket_cx, ANIM_SPEED)
	tween.tween_property(claw, "position:y", bucket_top_y, ANIM_SPEED)
	tween.tween_callback(func():
		# Drop crate into bucket
		claw_anim.play("open")
		buckets[bucket_idx].append(val)
		placed_flags[crate_idx] = true
		placed_count += 1
		crate_nodes[crate_idx].visible = false
		_refresh_bucket_display(bucket_idx)
	)
	tween.tween_property(claw, "position:y", CLAW_UP, ANIM_SPEED * 0.5)
	tween.tween_callback(func():
		is_animating = false
		_set_highlight(crate_idx, false)
		selected_crate = -1
		claw.visible = false

		_show_instruction("✅ Placed crate [" + str(val) + "] in bucket " + str(bucket_idx) + ".")

		if placed_count >= input_values.size():
			collectbtn.disabled = false
			_show_instruction("All crates distributed! Press COLLECT to gather them back.")
	)


# ── Collect ───────────────────────────────────────────────────────────────────
func _on_collect() -> void:
	if is_animating:
		return
	collectbtn.disabled = true
	is_animating = true

	# Build new input order by reading buckets 0→9, top→bottom
	var new_order: Array = []
	for b in range(10):
		for v in buckets[b]:
			new_order.append(v)

	# Animate collection (simple sequential tween per crate)
	var tween = create_tween()
	tween.tween_callback(func():
		# Instantly update internal state — visual refresh follows
		input_values = new_order
		placed_flags = []
		for i in range(input_values.size()):
			placed_flags.append(false)
		placed_count = 0
		_reset_buckets()
		_clear_all_bucket_displays()
		_refresh_crate_display()
	)
	tween.tween_interval(0.4)
	tween.tween_callback(func():
		is_animating = false
		machine.report_placement(input_values)

		if pass_num == 1:
			pass_num = 2
			digit_place = 10
			_update_pass_label()
			_refresh_digit_labels()
			_show_instruction("Pass 1 done! Now sort by the TENS digit.\nPASS 2: Tap a crate, then tap the bucket matching its TENS digit.")
		else:
			# Pass 2 done — should be sorted
			_refresh_digit_labels()
			if _is_sorted():
				_win()
			else:
				_show_instruction("⚠️ Something went wrong — check your placements.")
	)


# ── Hint ─────────────────────────────────────────────────────────────────────
func _on_hint() -> void:
	if is_animating:
		return
	# If no crate selected, auto-select the next unplaced one
	if selected_crate == -1:
		for i in range(input_values.size()):
			if not placed_flags[i]:
				_on_crate_tapped(i)
				break
		return

	# Flash the correct bucket
	var val = input_values[selected_crate]
	var d   = _get_digit(val, digit_place)
	_flash_bucket_hint(d)
	var pass_word = "ones" if pass_num == 1 else "tens"
	_show_instruction("💡 Hint: Crate [" + str(val) + "]'s " + pass_word + " digit is [" + str(d) + "] — tap bucket " + str(d) + "!")


# ── Undo ──────────────────────────────────────────────────────────────────────
func _on_undo() -> void:
	if is_animating or history.is_empty():
		return
	var last         = history.pop_back()
	input_values     = last["input_values"]
	placed_flags     = last["placed_flags"]
	buckets          = last["buckets"]
	placed_count     = last["placed_count"]
	selected_crate   = -1
	claw.visible     = false
	collectbtn.disabled = (placed_count < input_values.size())
	_clear_all_bucket_displays()
	for b in range(10):
		_refresh_bucket_display(b)
	_refresh_crate_display()
	machine.report_placement(input_values)
	_show_instruction("↩️ Undo! Last placement reverted.")


func _on_reset() -> void:
	get_tree().reload_current_scene()


# ── Display helpers ───────────────────────────────────────────────────────────
func _refresh_crate_display() -> void:
	for i in range(input_values.size()):
		var val = input_values[i]
		crate_nodes[i].texture_normal = CRATE_TEX[val]
		crate_nodes[i].visible = not placed_flags[i]
		crate_nodes[i].modulate = Color(1, 1, 1)
	_refresh_digit_labels()


func _refresh_digit_labels() -> void:
	for i in range(input_values.size()):
		if placed_flags[i]:
			digit_labels[i].text = ""
		else:
			var d = _get_digit(input_values[i], digit_place)
			digit_labels[i].text = str(d)
			digit_labels[i].modulate = Color(1, 0.25, 0.25) if pass_num == 1 else Color(0.25, 0.55, 1)


func _refresh_bucket_display(b: int) -> void:
	# The VBoxContainer inside each bucket panel holds small Label nodes
	var vbox = bucket_panels[b].get_node("VBox")
	# Clear existing crate icons
	for child in vbox.get_children():
		child.queue_free()
	# Re-add one label per stacked crate
	for val in buckets[b]:
		var lbl = Label.new()
		lbl.text = str(val)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
		vbox.add_child(lbl)


func _clear_all_bucket_displays() -> void:
	for b in range(10):
		var vbox = bucket_panels[b].get_node("VBox")
		for child in vbox.get_children():
			child.queue_free()


func _update_pass_label() -> void:
	if pass_num == 1:
		pass_label.text = "PASS 1 — ONES DIGIT"
		pass_label.modulate = Color(1.0, 0.4, 0.4)
	else:
		pass_label.text = "PASS 2 — TENS DIGIT"
		pass_label.modulate = Color(0.4, 0.6, 1.0)


func _set_highlight(idx: int, on: bool) -> void:
	if idx < 0 or idx >= crate_nodes.size():
		return
	crate_nodes[idx].modulate = Color(1.5, 1.2, 0.3) if on else Color(1, 1, 1)


func _flash_bucket_error(b: int) -> void:
	var panel = bucket_panels[b]
	var orig  = panel.modulate
	panel.modulate = Color(2.0, 0.3, 0.3)
	await get_tree().create_timer(0.5).timeout
	panel.modulate = orig


func _flash_bucket_hint(b: int) -> void:
	var panel = bucket_panels[b]
	var orig  = panel.modulate
	panel.modulate = Color(0.3, 2.0, 0.8)
	await get_tree().create_timer(0.6).timeout
	panel.modulate = orig


func _reset_buckets() -> void:
	buckets = []
	for i in range(10):
		buckets.append([])


func _deep_copy_buckets() -> Array:
	var copy: Array = []
	for b in buckets:
		copy.append(b.duplicate())
	return copy


func _idle_instruction() -> String:
	var pass_word = "ones" if pass_num == 1 else "tens"
	return "PASS " + str(pass_num) + ": Tap a crate, then tap the bucket matching its " + pass_word.to_upper() + " digit."


func _show_instruction(msg: String) -> void:
	instruction_label.text = msg
	instruction_label.modulate = Color(0.3, 0.85, 1)


func _show_error(msg: String) -> void:
	instruction_label.text = msg
	instruction_label.modulate = Color(1, 0.3, 0.3)
	await get_tree().create_timer(2.0).timeout
	instruction_label.modulate = Color(0.3, 0.85, 1)
	_show_instruction(_idle_instruction())


# ── Position helpers ──────────────────────────────────────────────────────────
func _cx(node: Control) -> float:
	return node.global_position.x + node.size.x * 0.5


func _bucket_cx(b: int) -> float:
	var panel = bucket_panels[b]
	return panel.global_position.x + panel.size.x * 0.5


func _bucket_drop_y(b: int) -> float:
	# Descend to just above the bucket top
	return bucket_panels[b].global_position.y + 40.0


# ── Win check ─────────────────────────────────────────────────────────────────

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
	for i in range(input_values.size()):
		if input_values[i] != target[i]:
			return false
	return true


# ── Win ────────────────────────────────────────────────────────────────────────
func _win() -> void:
	collectbtn.disabled = true
	hintbtn.disabled    = true
	_show_instruction("🎉 All sorted! Radix Sort complete!")

	var progress = {}
	if FileAccess.file_exists("user://progress.dat"):
		var file   = FileAccess.open("user://progress.dat", FileAccess.READ)
		var parsed = JSON.parse_string(file.get_as_text())
		file.close()
		if parsed != null and typeof(parsed) == TYPE_DICTIONARY:
			progress = parsed

	progress["radix_done"] = true
	var save = FileAccess.open("user://progress.dat", FileAccess.WRITE)
	save.store_string(JSON.stringify(progress))
	save.close()

	# Stars: 12 perfect = 3 stars, ≤15 = 2 stars, else 1 star
	if move_count <= 12:
		star1.texture         = STAR_3
		efficiency_label.text = "EFFICIENCY REMAINING : HIGH"
	elif move_count <= 15:
		star1.texture         = STAR_2
		efficiency_label.text = "EFFICIENCY REMAINING : MEDIUM"
	else:
		star1.texture         = STAR_1
		efficiency_label.text = "EFFICIENCY REMAINING : LOW"

	moves_label.text        = "MOVES : " + str(move_count)
	$Winpoint.visible       = true
	$Winpoint/Panel.visible = true
