extends Sprite2D
## sprite_2d.gd
## Dual-purpose node script.
##   mode 0 = GAUGE  — original gauge needle sway (unchanged)
##   mode 1 = CRANE  — full robotic claw controller extracted from HTML guide
##
## Attach to the Claw Sprite2D in bubblesort.tscn.
## Set mode = 1 on that node in the Inspector.

# ── SHARED EXPORT ─────────────────────────────────────────────────────────────
@export_enum("Gauge", "Crane") var mode: int = 0

# ══════════════════════════════════════════════════════════════════════════════
# GAUGE MODE  (original behaviour — do not touch)
# ══════════════════════════════════════════════════════════════════════════════
var _g_target:      float = 0.0
var _g_current:     float = 0.0
var _g_timer:       float = 0.0
var _g_change_time: float = 2.0

# ══════════════════════════════════════════════════════════════════════════════
# CRANE MODE  (ported from HTML DataSortFactory sprite guide)
# ══════════════════════════════════════════════════════════════════════════════
## How fast the claw sways left/right when idle
@export var sway_speed:     float = 1.2
## Max sway angle in degrees (matches HTML keyframe 8 deg)
@export var sway_deg:       float = 8.0
## Grip tween duration in seconds
@export var grip_duration:  float = 0.22

# Signals — bubblesort.gd can await these
signal grip_done
signal open_done

# Internal crane state — matches the HTML's S enum (IDLE / LOWER / GRIP / RAISE)
enum _S { IDLE, BUSY }
var _crane_state: _S        = _S.IDLE
var _sway_t:      float     = 0.0
var _orig_scale:  Vector2   = Vector2.ONE
var _orig_modulate: Color   = Color.WHITE
var _c_tween:     Tween     = null

# Reference to the Cable Line2D (auto-created in _ready if absent)
var _cable: Line2D          = null

# Rail Y is fixed in the scene (Rail node is at y = 27)
const RAIL_Y: float = 37.0


# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	if mode == 0:
		# GAUGE — set random start angle
		_g_target = randf_range(-60.0, 60.0)
	else:
		# CRANE — snapshot original transform
		_orig_scale    = scale
		_orig_modulate = modulate

		# Find or create the Cable Line2D sibling
		_cable = get_parent().get_node_or_null("Cable")
		if _cable == null:
			_cable               = Line2D.new()
			_cable.name          = "Cable"
			_cable.width         = 3.5
			_cable.default_color = Color(0.55, 0.60, 0.67, 1.0)
			# Add two placeholder points; _update_cable() fills them each frame
			_cable.add_point(Vector2.ZERO)
			_cable.add_point(Vector2.ZERO)
			get_parent().add_child(_cable)
			# Draw cable behind claw sprite
			get_parent().move_child(_cable, get_index())

		_update_cable()


# ─────────────────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if mode == 0:
		_process_gauge(delta)
	elif _crane_state == _S.IDLE:
		_process_crane_sway(delta)
		_update_cable()


# ═════════════════════════════════════════════════════════════════════════════
# GAUGE HELPERS
# ═════════════════════════════════════════════════════════════════════════════
func _process_gauge(delta: float) -> void:
	_g_timer += delta
	if _g_timer >= _g_change_time:
		_g_timer       = 0.0
		_g_change_time = randf_range(1.5, 3.5)
		_g_target      = randf_range(-60.0, 60.0)
	_g_current       = lerp(_g_current, _g_target, delta * 2.0)
	rotation_degrees = _g_current


# ═════════════════════════════════════════════════════════════════════════════
# CRANE HELPERS
# ═════════════════════════════════════════════════════════════════════════════

## HTML animation "cs": arm sways -8deg … +8deg continuously
func _process_crane_sway(delta: float) -> void:
	_sway_t          += delta * sway_speed
	rotation_degrees  = sin(_sway_t) * sway_deg


## Keeps the cable Line2D stretched from the rail down to the claw sprite.
## Cable lives in parent (scene root) space, same as the Claw sprite.
func _update_cable() -> void:
	if _cable == null:
		return
	# Top of cable = rail level, aligned with claw X
	var top = Vector2(position.x, RAIL_Y)
	# Bottom of cable = top edge of claw sprite (offset half-height upward)
	var bot = Vector2(position.x, position.y - 20.0)
	_cable.set_point_position(0, top)
	_cable.set_point_position(1, bot)


# ═════════════════════════════════════════════════════════════════════════════
# CRANE PUBLIC API  — call these from bubblesort.gd
# ═════════════════════════════════════════════════════════════════════════════

## Stop idle sway — call BEFORE starting the swap tween in bubblesort.gd
func stop_idle() -> void:
	_crane_state     = _S.BUSY
	rotation_degrees = 0.0


## Resume idle sway — call AFTER the swap tween finishes and claw is hidden
func start_idle() -> void:
	_sway_t      = 0.0
	_crane_state = _S.IDLE


## HTML animation "cfl / cfr": fingers close when gripping a crate.
## Simulated on the single claw sprite via scale squeeze + blue tint.
## Call this when the claw reaches CLAW_DOWN in the descent tween.
## Awaitable via the grip_done signal.
func grip() -> void:
	_crane_state     = _S.BUSY
	rotation_degrees = 0.0
	if _c_tween: _c_tween.kill()

	_c_tween = create_tween().set_parallel(true)

	# Squeeze Y (fingers closing), widen X slightly
	_c_tween.tween_property(self, "scale:y", _orig_scale.y * 0.70, grip_duration)
	_c_tween.tween_property(self, "scale:x", _orig_scale.x * 1.20, grip_duration)

	# Blue-white tint — claw is energised / gripping
	_c_tween.tween_property(self, "modulate", Color(0.62, 0.91, 1.38), grip_duration)

	# Brief waggle to sell the "grab" feel
	var wag = create_tween()
	wag.tween_property(self, "rotation_degrees", -6.0, grip_duration * 0.30)
	wag.tween_property(self, "rotation_degrees",  6.0, grip_duration * 0.30)
	wag.tween_property(self, "rotation_degrees",  0.0, grip_duration * 0.40)
	wag.tween_callback(func(): emit_signal("grip_done"))


## HTML animation "open": fingers splay back to rest.
## Call this when the claw returns to CLAW_UP after placing a crate.
## Awaitable via the open_done signal.
func open_claw() -> void:
	if _c_tween: _c_tween.kill()

	_c_tween = create_tween().set_parallel(true)
	_c_tween.tween_property(self, "scale",    _orig_scale,    grip_duration)
	_c_tween.tween_property(self, "modulate", _orig_modulate, grip_duration)
	_c_tween.tween_callback(func():
		_crane_state = _S.IDLE
		emit_signal("open_done")
	)
