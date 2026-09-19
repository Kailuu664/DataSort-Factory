extends Node2D

# ── Node refs ────────────────────────────────────────────────────────────────
@onready var pct_label  : Label           = $Body/Screen/PctLabel
@onready var light_r    : Polygon2D       = $Body/Lights/LightR
@onready var light_g    : Polygon2D       = $Body/Lights/LightG
@onready var light_a    : Polygon2D       = $Body/Lights/LightA
@onready var anim       : AnimationPlayer = $AnimationPlayer
@onready var shake_timer: Timer           = $ShakeTimer
@onready var steam_t    : Timer           = $SteamTimer
@onready var steam_a    : Node2D          = $SteamPuff

# ── State ────────────────────────────────────────────────────────────────────
var _target  : Array = []
var _total   : int        = 0
var _correct : int        = 0
var _percent : float      = 0.0
var _base_pos: Vector2

# ── Signals ──────────────────────────────────────────────────────────────────
signal progress_changed(new_pct: float)
signal all_correct

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_base_pos = position
	pct_label.text = "0.00%"
	_set_lights(false, false, false)
	anim.play("idle_vibrate")
	shake_timer.timeout.connect(_on_shake_timeout)
	steam_t.timeout.connect(_on_steam_tick)
	steam_t.start(2.5)
	steam_a.visible = false

# ─────────────────────────────────────────────────────────────────────────────
func setup(crate_values: Array, sorted_target: Array) -> void:
	_target  = sorted_target.duplicate()
	_total   = crate_values.size()
	_correct = 0
	_percent = 0.0
	pct_label.text = "0.00%"
	await get_tree().create_timer(0.6).timeout
	report_placement(crate_values)

# ─────────────────────────────────────────────────────────────────────────────
func report_placement(crate_values: Array) -> void:
	_correct = 0
	for i in range(min(crate_values.size(), _target.size())):
		if crate_values[i] == _target[i]:
			_correct += 1

	var new_pct: float = 0.0
	if _total > 0:
		new_pct = (_correct * 100.0) / _total

	var went_up   := new_pct > _percent
	var went_down := new_pct < _percent
	_percent = new_pct

	# Direct label update — e.g. "33.33%" or "100.00%"
	pct_label.text = "%.2f%%" % _percent

	_update_lights(went_up, went_down)
	emit_signal("progress_changed", _percent)

	if went_down:
		_trigger_shake(3.0)
	elif went_up:
		_trigger_shake(1.0)

	if _percent >= 100.0:
		_on_complete()

# ─────────────────────────────────────────────────────────────────────────────
func _update_lights(went_up: bool, went_down: bool) -> void:
	if went_down:
		_set_lights(true, false, false)
		await get_tree().create_timer(0.8).timeout
		_set_lights(false, _percent > 0, _percent > 0 and _percent < 100)
	elif went_up:
		_set_lights(false, true, false)
		await get_tree().create_timer(0.5).timeout
		_set_lights(false, _percent >= 100, _percent > 0 and _percent < 100)
	else:
		_set_lights(false, _percent >= 100, false)

func _set_lights(r: bool, g: bool, a: bool) -> void:
	light_r.color = Color(1.0, 0.2, 0.2) if r else Color(0.25, 0.05, 0.05)
	light_g.color = Color(0.2, 1.0, 0.4) if g else Color(0.05, 0.25, 0.1)
	light_a.color = Color(1.0, 0.67, 0.0) if a else Color(0.25, 0.17, 0.0)

func _trigger_shake(intensity: float) -> void:
	set_meta("shake_intensity", intensity)
	shake_timer.start(0.05)
	await get_tree().create_timer(0.35).timeout
	shake_timer.stop()
	position = _base_pos

func _on_shake_timeout() -> void:
	var s: float = get_meta("shake_intensity", 1.5)
	position = _base_pos + Vector2(randf_range(-s, s), randf_range(-s, s))

func _on_steam_tick() -> void:
	steam_a.visible = true
	await get_tree().create_timer(0.6).timeout
	steam_a.visible = false
	steam_t.start(randf_range(1.8, 3.2))

func _on_complete() -> void:
	anim.play("complete_flash")
	_set_lights(false, true, false)
	steam_a.visible = true
	emit_signal("all_correct")
