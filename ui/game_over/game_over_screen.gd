## 游戏结束画面

extends Node2D
@onready var stats_label: RichTextLabel = %StatsLabel
@onready var retry_btn: Button = %RetryBtn


func _ready() -> void:
	retry_btn.pressed.connect(_on_retry)
	GameManager.phase_changed.connect(_on_phase_changed)
	# 兜底：main.gd 走销毁重建，进场景时 phase 已就位，手动触发一次内容生成
	_on_phase_changed(GameManager.phase)


func _on_phase_changed(new_phase: GameTypes.GamePhase) -> void:
	visible = new_phase == GameTypes.GamePhase.GAME_OVER
	if visible:
		_show_stats()
		# 败北特效
		VFX.fade_in(stats_label, 0.5)
		VFX.fade_in(retry_btn, 0.3, 0.5)


func _show_stats() -> void:
	stats_label.text = """[b]你倒下了……[/b]

总伤害: %d
最高单次: %d
出牌次数: %d
击杀敌人: %d
战斗胜利: %d
到达章节: %d""" % [
		GameManager.stats.totalDamageDealt,
		GameManager.stats.maxSingleHit,
		GameManager.stats.totalPlays,
		GameManager.stats.enemiesKilled,
		GameManager.stats.battlesWon,
		GameManager.chapter,
	]


func _on_retry() -> void:
	GameManager.set_phase(GameTypes.GamePhase.START)
