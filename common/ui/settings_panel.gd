## SettingsPanel — 设置面板内容（塞到 ModalHub 里显示）
## 包括：音乐音量 / 音效音量 / BGM 开关 / SFX 开关 / 返回主菜单
##
## 设置值通过 SaveManager.save_meta / load_meta 持久化
## 调用方式（不依赖 class_name，直接 preload 本脚本并 new()）：
##   const SettingsPanelRef := preload("res://common/ui/settings_panel.gd")
##   ModalHubRef.open(SettingsPanelRef.new(), "设置", {...})

extends VBoxContainer

const ModalHubRef := preload("res://common/ui/modal_hub.gd")


# ============================================================
# 生命周期
# ============================================================
func _ready() -> void:
	add_theme_constant_override("separation", 14)
	_build_controls()
	_load_from_save()


# ============================================================
# 构建 UI
# ============================================================
var _music_slider: HSlider
var _sfx_slider: HSlider
var _bgm_toggle: CheckBox
var _sfx_toggle: CheckBox

func _build_controls() -> void:
	# 音乐音量
	add_child(_make_slider_row("🎵 音乐音量", 0.0, 1.0, SoundPlayer.music_volume, func(v: float):
		SoundPlayer.set_music_volume(v)
		_save_audio_meta()
	, "music"))
	
	# 音效音量
	add_child(_make_slider_row("🔊 音效音量", 0.0, 1.0, SoundPlayer.sfx_volume, func(v: float):
		SoundPlayer.set_sfx_volume(v)
		SoundPlayer.play_sound("click")
		_save_audio_meta()
	, "sfx"))
	
	# 开关区
	var toggle_box := HBoxContainer.new()
	toggle_box.add_theme_constant_override("separation", 20)
	_bgm_toggle = _make_toggle("BGM", SoundPlayer.bgm_enabled, func(on: bool):
		SoundPlayer.set_bgm_enabled(on)
		if on:
			# 重播当前 phase 对应的 BGM（记住上次在播的曲目，否则回退到 start）
			var last_track: String = SoundPlayer._current_bgm if SoundPlayer._current_bgm != "" else "start"
			SoundPlayer.play_music(last_track)
		_save_audio_meta()
	)
	_sfx_toggle = _make_toggle("SFX", SoundPlayer.sfx_enabled, func(on: bool):
		SoundPlayer.set_sfx_enabled(on)
		_save_audio_meta()
	)
	toggle_box.add_child(_bgm_toggle)
	toggle_box.add_child(_sfx_toggle)
	add_child(toggle_box)
	
	# 分隔
	add_child(HSeparator.new())
	
	# 危险区：放弃当前冒险
	if SaveManager.has_run_save():
		var abandon_btn := Button.new()
		abandon_btn.text = "🏳 放弃当前冒险（回到主菜单）"
		abandon_btn.add_theme_color_override("font_color", Color("#ff8080"))
		abandon_btn.pressed.connect(_on_abandon_pressed)
		add_child(abandon_btn)
	
	# 统计摘要
	var meta := SaveManager.load_meta()
	var stats_label := Label.new()
	stats_label.text = "累计死亡 %d 次  ·  通关 %d 次" % [
		int(meta.get("total_deaths", 0)),
		int(meta.get("total_victories", 0)),
	]
	stats_label.add_theme_color_override("font_color", Color("#9aa0ac"))
	stats_label.add_theme_font_size_override("font_size", 12)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(stats_label)


func _make_slider_row(label_text: String, min_v: float, max_v: float, init_v: float, cb: Callable, tag: String) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	
	var top := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(label)
	var value_label := Label.new()
	value_label.text = "%d%%" % int(init_v * 100)
	value_label.add_theme_color_override("font_color", Color("#a8c0ff"))
	top.add_child(value_label)
	row.add_child(top)
	
	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = 0.05
	slider.value = init_v
	slider.custom_minimum_size = Vector2(0, 28)
	slider.value_changed.connect(func(v: float):
		value_label.text = "%d%%" % int(v * 100)
		cb.call(v)
	)
	row.add_child(slider)
	
	if tag == "music":
		_music_slider = slider
	elif tag == "sfx":
		_sfx_slider = slider
	
	return row


func _make_toggle(text: String, init: bool, cb: Callable) -> CheckBox:
	var box := CheckBox.new()
	box.text = text
	box.button_pressed = init
	box.toggled.connect(func(on: bool): cb.call(on))
	return box


# ============================================================
# 持久化
# ============================================================

func _load_from_save() -> void:
	var meta: Dictionary = SaveManager.load_meta()
	var audio: Dictionary = meta.get("audio", {})
	if audio.is_empty():
		return
	if audio.has("music_volume"):
		SoundPlayer.set_music_volume(float(audio.music_volume))
		if _music_slider: _music_slider.set_value_no_signal(float(audio.music_volume))
	if audio.has("sfx_volume"):
		SoundPlayer.set_sfx_volume(float(audio.sfx_volume))
		if _sfx_slider: _sfx_slider.set_value_no_signal(float(audio.sfx_volume))
	if audio.has("bgm_enabled"):
		SoundPlayer.set_bgm_enabled(bool(audio.bgm_enabled))
		if _bgm_toggle: _bgm_toggle.set_pressed_no_signal(bool(audio.bgm_enabled))
	if audio.has("sfx_enabled"):
		SoundPlayer.set_sfx_enabled(bool(audio.sfx_enabled))
		if _sfx_toggle: _sfx_toggle.set_pressed_no_signal(bool(audio.sfx_enabled))


func _save_audio_meta() -> void:
	var meta: Dictionary = SaveManager.load_meta()
	meta["audio"] = {
		"music_volume": SoundPlayer.music_volume,
		"sfx_volume": SoundPlayer.sfx_volume,
		"bgm_enabled": SoundPlayer.bgm_enabled,
		"sfx_enabled": SoundPlayer.sfx_enabled,
	}
	SaveManager.save_meta(meta)


# ============================================================
# 动作
# ============================================================

func _on_abandon_pressed() -> void:
	SaveManager.clear_run_save()
	VFX.show_toast("已放弃当前冒险", "warn")
	ModalHubRef.close_all()
	GameManager.set_phase(GameTypes.GamePhase.START)
