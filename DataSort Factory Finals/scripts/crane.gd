extends Node2D

# ─── Exports ─────────────────────────────────────────────────────────────────
@export var sway_speed: float = 1.2   # radians per second for idle sway
@export var sway_deg:   float = 12.0  # degrees of sway left/right
@export var cable_min:  float = 80.0  # cable length at rest / after raising
@export var cable_max:  float = 160.0 # cable length when fully lowered
@export var lower_spd:  float = 60.0  # pixels per second for lowering/raising

# ─── Node references ─────────────────────────────────────────────────────────
# Expected scene tree under this node:
#   Crane (Node2D)          ← this script
#   ├── Arm (Node2D)        ← pivot at top-center; rotation_point = top
#   │   ├── ArmSprite (Sprite2D)
#   │   ├── Cable (Line2D)
#   │   └── Claw (Node2D)
#   │       ├── ClawBody (Sprite2D)
#   │       ├── FingerL (Sprite2D)
#   │       ├── FingerC (Sprite2D)
#   │       ├── FingerR (Sprite2D)
#   │       └── Anim (AnimationPlayer)  ← needs "grip" and "open" animations
#   └── Base (Sprite2D)
@onready var arm:       Node2D          = $Arm
@onready var cable:     Line2D          = $Arm/Cable
@onready var claw:      Node2D          = $Arm/Claw
@onready var claw_anim: AnimationPlayer = $Arm/Claw/Anim

# ─── State machine ────────────────────────────────────────────────────────────
enum S { IDLE, LOWER, GRIP, RAISE }
var state:    S     = S.IDLE
var sway_t:   float = 0.0   # time accumulator for sin() sway
var clen:     float = 80.0  # current cable length in pixels
var tgt_slot: int   = 0     # slot index passed in by pick_up()

# ─── Signals ─────────────────────────────────────────────────────────────────
signal crate_picked(slot: int)  # emitted the moment the claw closes
signal crate_placed(slot: int)  # emitted once the claw opens after raising

# ─── Main loop ───────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	match state:
		S.IDLE:
			# Gentle left-right sway + slight cable bob
			sway_t += delta * sway_speed
			arm.rotation_degrees = sin(sway_t) * sway_deg
			clen = 80.0 + sin(sway_t * 0.7) * 10.0
			_set_cable(clen)

		S.LOWER:
			# Extend cable until fully lowered, then grip
			clen += lower_spd * delta
			_set_cable(clen)
			if clen >= cable_max:
				state = S.GRIP
				claw_anim.play("grip")
				await claw_anim.animation_finished
				emit_signal("crate_picked", tgt_slot)
				state = S.RAISE

		S.RAISE:
			# Retract cable until back to rest, then open claw
			clen -= lower_spd * delta
			_set_cable(clen)
			if clen <= cable_min:
				state = S.IDLE
				claw_anim.play("open")
				emit_signal("crate_placed", tgt_slot)

# ─── Helpers ─────────────────────────────────────────────────────────────────
func _set_cable(l: float) -> void:
	# Update the Line2D endpoints and move the claw to the cable tip
	cable.points = [Vector2(0, 0), Vector2(0, l)]
	claw.position = Vector2(0, l)

# ─── Public API ──────────────────────────────────────────────────────────────
## Call this to start a pick-up sequence on the given slot index.
## Connect to crate_picked / crate_placed signals to handle crate logic.
func pick_up(slot: int) -> void:
	tgt_slot = slot
	state    = S.LOWER
