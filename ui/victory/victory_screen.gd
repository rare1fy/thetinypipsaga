## 胜利画面

extends Control

@onready var stats_label: RichTextLabel = %StatsLabel
@onready var restart_btn: Button = %RestartBtn


func _ready() -> void:
	restart_btn.pressed.connect(_on_restart)
	GameManager.phase_changed.connect(_on_phase_changed)
	# 兜底：main.gd 走销毁重建，进场景时 phase 已就位，手动触发一次内容生成
	_on_phase_changed(GameManager.phase)


func _on_phase_changed(new_phase: GameTypes.GamePhase) -> void:
	visible = new_phase == GameTypes.GamePhase.VICTORY
	if visible:
		_show_stats()
		# 胜利特效
		VFX.pop_in(stats_label, 0.5)
		VFX.victory_burst(self, size * 0.5, 25)
		VFX.pop_in(restart_btn, 0.4, 0.5)


func _show_stats() -> void:
	stats_label.text = """[b]恭喜通关![/b]

总伤害: %d
最高单次: %d
出牌次数: %d
重投次数: %d
击杀敌人: %d
战斗胜利: %d
精英胜利: %d
Boss胜利: %d
获得金币: %d""" % [
		GameManager.stats.totalDamageDealt,
		GameManager.stats.maxSingleHit,
		GameManager.stats.totalPlays,
		GameManager.stats.totalRerolls,
		GameManager.stats.enemiesKilled,
		GameManager.stats.battlesWon,
		GameManager.stats.elitesWon,
		GameManager.stats.bossesWon,
		GameManager.stats.goldEarned,
	]


func _on_restart() -> void:
	GameManager.set_phase(GameTypes.GamePhase.START)
