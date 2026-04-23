## 开始画面 — 游戏入口

extends Control

@onready var title_label: Label = %TitleLabel
@onready var start_btn: Button = %StartBtn
@onready var version_label: Label = %VersionLabel


var _title_tween: Tween
var _star_tweens: Array[Tween] = []


func _ready() -> void:
	start_btn.pressed.connect(_on_start_pressed)
	# 竖屏布局
	anchor_right = 1.0
	anchor_bottom = 1.0
	
	# 标题弹入
	VFX.pop_in(title_label, 0.6, 0.2, 1.3)
	VFX.slide_in_from_bottom(start_btn, 30.0, 0.4, 0.5)
	VFX.fade_in(version_label, 0.3, 0.6)
	
	# 背景星星
	_spawn_stars()


func _on_start_pressed() -> void:
	SoundPlayer.play_sound("click")
	GameManager.set_phase(GameTypes.GamePhase.CLASS_SELECT)


func _process(_delta: float) -> void:
	# 标题脉动动画（使用 _process 正弦比 Tween 循环更平滑）
	if title_label:
		var t := Time.get_ticks_msec() / 1000.0
		title_label.modulate.a = 0.8 + 0.2 * sin(t * 2.0)


## 生成背景闪烁星星
func _spawn_stars() -> void:
	var colors: Array[Color] = [Color(1.0, 0.95, 0.7), Color(0.7, 0.85, 1.0), Color(1.0, 0.8, 0.6)]
	for i in 6:
		var star := ColorRect.new()
		star.color = colors[i % colors.size()]
		star.size = Vector2(2, 2)
		star.position = Vector2(randf_range(20, 340), randf_range(50, 400))
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(star)
		# 移到标题后面
		move_child(star, 0)
		var tw := VFX.star_twinkle(star, randf_range(2.0, 4.0))
		_star_tweens.append(tw)
