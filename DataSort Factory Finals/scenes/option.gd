extends Node2D

# ── Node refs ─────────────────────────────────────────────────────────────────
@onready var music_slider      = $OptionsPanel/VBox/AudioSection/MusicRow/MusicSlider
@onready var music_val_label   = $OptionsPanel/VBox/AudioSection/MusicRow/ValLabel
@onready var sfx_slider        = $OptionsPanel/VBox/AudioSection/SFXRow/SFXSlider
@onready var sfx_val_label     = $OptionsPanel/VBox/AudioSection/SFXRow/ValLabel
@onready var mute_toggle       = $OptionsPanel/VBox/AudioSection/MuteRow/MuteToggle
@onready var brightness_slider = $OptionsPanel/VBox/DisplaySection/BrightnessRow/BrightnessSlider
@onready var bright_val_label  = $OptionsPanel/VBox/DisplaySection/BrightnessRow/ValLabel
@onready var canvas_modulate   = $BrightnessLayer
@onready var hint_toggle       = $OptionsPanel/VBox/GameplaySection/HintRow/HintToggle
@onready var btn_normal        = $OptionsPanel/VBox/GameplaySection/AnimRow/AnimBtns/NormalBtn
@onready var btn_fast          = $OptionsPanel/VBox/GameplaySection/AnimRow/AnimBtns/FastBtn
@onready var btn_instant       = $OptionsPanel/VBox/GameplaySection/AnimRow/AnimBtns/InstantBtn
@onready var reset_btn         = $OptionsPanel/VBox/ProgressSection/ResetRow/ResetBtn
@onready var confirm_panel     = $ConfirmPanel
@onready var confirm_yes       = $ConfirmPanel/YesBtn
@onready var confirm_no        = $ConfirmPanel/NoBtn
@onready var audio_player      = $AudioStreamPlayer

const SETTINGS_PATH = "user://settings.dat"
const PROGRESS_PATH = "user://progress.dat"

var settings = {
	"music_volume": 1.0,
	"sfx_volume":   1.0,
	"mute_all":     false,
	"brightness":   1.0,
	"hint_mode":    true,
	"anim_speed":   0        # 0 = Normal, 1 = Fast, 2 = Instant
}


func _ready() -> void:
	confirm_panel.visible = false
	_load_settings()
	_apply_all()
	_connect_signals()


# ── Signal wiring ─────────────────────────────────────────────────────────────
func _connect_signals() -> void:
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	mute_toggle.toggled.connect(_on_mute_toggled)
	brightness_slider.value_changed.connect(_on_brightness_changed)
	hint_toggle.toggled.connect(_on_hint_toggled)
	btn_normal.pressed.connect(func(): _on_anim_speed(0))
	btn_fast.pressed.connect(func():   _on_anim_speed(1))
	btn_instant.pressed.connect(func(): _on_anim_speed(2))
	reset_btn.pressed.connect(_on_reset_pressed)
	confirm_yes.pressed.connect(_on_confirm_yes)
	confirm_no.pressed.connect(_on_confirm_no)


# ── Audio ─────────────────────────────────────────────────────────────────────
func _on_music_changed(value: float) -> void:
	settings["music_volume"] = value
	music_val_label.text = str(int(value * 100)) + "%"
	_apply_music_volume()
	_save_settings()

func _on_sfx_changed(value: float) -> void:
	settings["sfx_volume"] = value
	sfx_val_label.text = str(int(value * 100)) + "%"
	_apply_sfx_volume()
	_save_settings()

func _on_mute_toggled(toggled: bool) -> void:
	settings["mute_all"] = toggled
	_apply_mute()
	_save_settings()

func _apply_music_volume() -> void:
	var bus = AudioServer.get_bus_index("Music")
	if bus == -1:
		bus = 0   # fallback to Master
	if settings["mute_all"]:
		AudioServer.set_bus_mute(bus, true)
	else:
		AudioServer.set_bus_mute(bus, false)
		AudioServer.set_bus_volume_db(bus, linear_to_db(settings["music_volume"]))

func _apply_sfx_volume() -> void:
	var bus = AudioServer.get_bus_index("SFX")
	if bus == -1:
		return   # no SFX bus yet — skip
	if settings["mute_all"]:
		AudioServer.set_bus_mute(bus, true)
	else:
		AudioServer.set_bus_mute(bus, false)
		AudioServer.set_bus_volume_db(bus, linear_to_db(settings["sfx_volume"]))

func _apply_mute() -> void:
	var muted = settings["mute_all"]
	for i in range(AudioServer.bus_count):
		AudioServer.set_bus_mute(i, muted)
	if not muted:
		_apply_music_volume()
		_apply_sfx_volume()


# ── Display ───────────────────────────────────────────────────────────────────
func _on_brightness_changed(value: float) -> void:
	settings["brightness"] = value
	bright_val_label.text = str(int(value * 100)) + "%"
	_apply_brightness()
	_save_settings()

func _apply_brightness() -> void:
	var b = settings["brightness"]
	canvas_modulate.color = Color(b, b, b, 1.0)


# ── Gameplay ──────────────────────────────────────────────────────────────────
func _on_hint_toggled(toggled: bool) -> void:
	settings["hint_mode"] = toggled
	_save_settings()

func _on_anim_speed(speed: int) -> void:
	settings["anim_speed"] = speed
	_refresh_anim_buttons()
	_save_settings()

func _refresh_anim_buttons() -> void:
	var speed = settings["anim_speed"]
	btn_normal.modulate  = Color(1.4, 1.1, 0.2) if speed == 0 else Color(1, 1, 1)
	btn_fast.modulate    = Color(1.4, 1.1, 0.2) if speed == 1 else Color(1, 1, 1)
	btn_instant.modulate = Color(1.4, 1.1, 0.2) if speed == 2 else Color(1, 1, 1)


# ── Progress reset ────────────────────────────────────────────────────────────
func _on_reset_pressed() -> void:
	confirm_panel.visible = true

func _on_confirm_yes() -> void:
	if FileAccess.file_exists(PROGRESS_PATH):
		DirAccess.remove_absolute(PROGRESS_PATH)
	confirm_panel.visible = false
	reset_btn.text = "✔ PROGRESS CLEARED"
	reset_btn.disabled = true

func _on_confirm_no() -> void:
	confirm_panel.visible = false


# ── Apply all on load ─────────────────────────────────────────────────────────
func _apply_all() -> void:
	music_slider.value      = settings["music_volume"]
	sfx_slider.value        = settings["sfx_volume"]
	mute_toggle.button_pressed = settings["mute_all"]
	brightness_slider.value = settings["brightness"]
	hint_toggle.button_pressed = settings["hint_mode"]

	music_val_label.text  = str(int(settings["music_volume"]  * 100)) + "%"
	sfx_val_label.text    = str(int(settings["sfx_volume"]    * 100)) + "%"
	bright_val_label.text = str(int(settings["brightness"]    * 100)) + "%"

	_apply_music_volume()
	_apply_sfx_volume()
	_apply_mute()
	_apply_brightness()
	_refresh_anim_buttons()


# ── Save / Load ───────────────────────────────────────────────────────────────
func _save_settings() -> void:
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(settings))
	file.close()

func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file   = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed != null and typeof(parsed) == TYPE_DICTIONARY:
		for key in settings.keys():
			if parsed.has(key):
				settings[key] = parsed[key]
