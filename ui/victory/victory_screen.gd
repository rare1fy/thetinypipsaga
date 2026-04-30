## 胜利画面

extends Node2D
@onready var ui_root: Control = %Root
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
		# 清除 run 存档
		SaveManager.clear_run_save()
		# 累加 meta 统计（通关次数 + 按职业通关标记）
		var meta: Dictionary = SaveManager.load_meta()
		meta["total_victories"] = int(meta.get("total_victories", 0)) + 1
		var cls_record: Dictionary = meta.get("class_victories", {})
		var cls: String = PlayerState.player_class
		if cls != "":
			cls_record[cls] = int(cls_record.get(cls, 0)) + 1
			meta["class_victories"] = cls_record
		SaveManager.save_meta(meta)
		# 胜利特效
		VFX.pop_in(stats_label, 0.5)
		VFX.victory_burst(ui_root, ui_root.size * 0.5, 25)
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
