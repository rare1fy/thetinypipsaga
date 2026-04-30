## 开始画面 — 游戏入口

extends Node2D

const ModalHubRef := preload("res://common/ui/modal_hub.gd")
const SettingsPanelRef := preload("res://common/ui/settings_panel.gd")
const HandGuideRef := preload("res://common/ui/hand_guide.gd")
const RelicGuideRef := preload("res://common/ui/relic_guide.gd")

@onready var ui_root: Control = %Root
@onready var title_label: Label = %TitleLabel
@onready var start_btn: Button = %StartBtn
@onready var new_run_btn: Button = %NewRunBtn
@onready var version_label: Label = %VersionLabel


var _title_tween: Tween
var _star_tweens: Array[Tween] = []


func _ready() -> void:
	start_btn.pressed.connect(_on_start_pressed)
	new_run_btn.pressed.connect(_on_new_run_pressed)
	SoundPlayer.play_music("start")
	
	# 检测是否有未完成的 run 存档：
	# - 有存档：主按钮=继续冒险（加载存档），副按钮=新的冒险（清存档新开）
	# - 无存档：只显示主按钮=开始冒险，副按钮隐藏
	if SaveManager.has_run_save():
		start_btn.text = "继续冒险"
		new_run_btn.visible = true
	else:
		start_btn.text = "开始冒险"
		new_run_btn.visible = false
	
	# 标题弹入
	VFX.pop_in(title_label, 0.6, 0.2, 1.3)
	VFX.slide_in_from_bottom(start_btn, 30.0, 0.4, 0.5)
	VFX.fade_in(version_label, 0.3, 0.6)
	
	# 背景星星
	_spawn_stars()
	
	# 右上角快捷按钮栏（脚本动态创建，不改 tscn）
	_spawn_topright_buttons()


# ============================================================
# 右上角按钮栏（牌型图鉴 + 设置，从右到左布局）
# ============================================================
func _spawn_topright_buttons() -> void:
	# 设置按钮（最右）
	_spawn_icon_button("⚙", "设置", Vector2(-52, 12), _on_settings_pressed)
	# 牌型图鉴按钮
	_spawn_icon_button("📖", "牌型图鉴", Vector2(-100, 12), _on_hand_guide_pressed)
	# 遗物图鉴按钮
	_spawn_icon_button("🏺", "遗物图鉴", Vector2(-148, 12), _on_relic_guide_pressed)


func _spawn_icon_button(text: String, tooltip: String, pos: Vector2, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 20)
	btn.custom_minimum_size = Vector2(40, 40)
	btn.flat = true
	btn.add_theme_color_override("font_color", Color("#c8d0e8"))
	btn.tooltip_text = tooltip
	btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	btn.position = pos
	btn.pressed.connect(callback)
	ui_root.add_child(btn)


func _on_settings_pressed() -> void:
	SoundPlayer.play_sound("click")
	ModalHubRef.open(
		SettingsPanelRef.new(),
		"设置",
		{"size": Vector2(420, 520), "close_on_backdrop": true}
	)


func _on_hand_guide_pressed() -> void:
	SoundPlayer.play_sound("click")
	ModalHubRef.open(
		HandGuideRef.new(),
		"牌型图鉴",
		{"size": Vector2(560, 780), "close_on_backdrop": true}
	)


func _on_relic_guide_pressed() -> void:
	SoundPlayer.play_sound("click")
	ModalHubRef.open(
		RelicGuideRef.new(),
		"遗物图鉴",
		{"size": Vector2(560, 780), "close_on_backdrop": true}
	)


func _on_start_pressed() -> void:
	SoundPlayer.play_sound("click")
	# 有存档则加载并直接进入地图；无存档走正常新游戏流程
	if SaveManager.has_run_save() and SaveManager.load_run():
		VFX.show_toast("已恢复上次冒险", "success")
		GameManager.set_phase(GameTypes.GamePhase.MAP)
	else:
		GameManager.set_phase(GameTypes.GamePhase.CLASS_SELECT)


## 新的冒险：清空当前存档，强制走职业选择重新开始
## 只有在存在存档时才会看到这个按钮，所以一定要清掉旧存档再进入
func _on_new_run_pressed() -> void:
	SoundPlayer.play_sound("click")
	SaveManager.clear_run_save()
	VFX.show_toast("已开启新的冒险", "buff")
	GameManager.set_phase(GameTypes.GamePhase.CLASS_SELECT)


func _process(_delta: float) -> void:
	# 标题脉动已随全局 VFX 禁用一起关闭
	pass


## 生成背景闪烁星星
func _spawn_stars() -> void:
	var colors: Array[Color] = [Color(1.0, 0.95, 0.7), Color(0.7, 0.85, 1.0), Color(1.0, 0.8, 0.6)]
	for i in 6:
		var star := ColorRect.new()
		star.color = colors[i % colors.size()]
		star.size = Vector2(2, 2)
		star.position = Vector2(randf_range(20, 340), randf_range(50, 400))
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui_root.add_child(star)
		# 移到最底层（标题后面）
		ui_root.move_child(star, 0)
		var tw := VFX.star_twinkle(star, randf_range(2.0, 4.0))
		if tw:
			_star_tweens.append(tw)
