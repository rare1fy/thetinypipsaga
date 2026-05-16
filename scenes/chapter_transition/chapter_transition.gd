## 章节切换过渡界面
## 展示下一章标题 + 奖励提示，倒计时或点击后回 MAP 进入下一章
extends Node2D

@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var detail_label: RichTextLabel = %DetailLabel
@onready var continue_btn: Button = %ContinueBtn


func _ready() -> void:
	continue_btn.pressed.connect(_on_continue_pressed)
	GameManager.phase_changed.connect(_on_phase_changed)
	# 兜底：main.gd 走销毁重建，进场景时 phase 已就位，手动触发一次内容生成
	_on_phase_changed(GameManager.phase)


func _on_phase_changed(new_phase: GameTypes.GamePhase) -> void:
	visible = new_phase == GameTypes.GamePhase.CHAPTER_TRANSITION
	if not visible:
		return
	_show_chapter_info()


func _show_chapter_info() -> void:
	var chapter: int = GameManager.chapter
	var name_list: Array = GameBalance.CHAPTER_CONFIG.chapterNames  # [RULES-B2-EXEMPT] Dictionary.values() 返回裸 Array
	var chapter_name: String = name_list[chapter - 1] if chapter - 1 < name_list.size() else "未知之地"
	title_label.text = "第 %d 章" % chapter
	subtitle_label.text = chapter_name
	
	# 奖励文本
	var heal_percent: float = float(GameBalance.CHAPTER_CONFIG.get("chapterHealPercent", 0.6)) * 100.0
	var bonus_gold: int = int(GameBalance.CHAPTER_CONFIG.get("chapterBonusGold", 75))
	var scaling_list: Array = GameBalance.CHAPTER_CONFIG.get("chapterScaling", [])  # [RULES-B2-EXEMPT] dict.get 返回裸 Array
	var hp_mult: float = 1.0
	if chapter - 1 < scaling_list.size():
		hp_mult = float(scaling_list[chapter - 1].get("hpMult", 1.0))
	detail_label.text = "[center][color=#a8f0a8]已恢复 %d%% 生命值[/color]\n[color=#f0d888]获得 %d 金币[/color]\n[color=#f0a8a8]敌人血量倍率 ×%.2f[/color][/center]" % [int(heal_percent), bonus_gold, hp_mult]
	
	# 入场动画
	VFX.pop_in(title_label, 0.6)
	VFX.fade_in(subtitle_label, 0.5, 0.3)
	VFX.fade_in(detail_label, 0.4, 0.6)
	VFX.pop_in(continue_btn, 0.4, 1.0)


func _on_continue_pressed() -> void:
	SoundPlayer.play_sound("click")
	GameManager.set_phase(GameTypes.GamePhase.MAP)
