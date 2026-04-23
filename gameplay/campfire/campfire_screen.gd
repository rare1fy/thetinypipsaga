## 营火界面 — 休息恢复 or 升级遗物

extends Node2D
@onready var rest_btn: Button = %RestBtn
@onready var heal_label: Label = %HealLabel
@onready var back_btn: Button = %BackBtn
@onready var relic_list: VBoxContainer = %RelicList


func _ready() -> void:
	rest_btn.pressed.connect(_on_rest)
	back_btn.pressed.connect(_on_back)
	GameManager.phase_changed.connect(_on_phase_changed)
	# 兜底：main.gd 走销毁重建，进场景时 phase 已就位，手动触发一次内容生成
	_on_phase_changed(GameManager.phase)


func _on_phase_changed(new_phase: GameTypes.GamePhase) -> void:
	visible = new_phase == GameTypes.GamePhase.CAMPFIRE
	if visible:
		_refresh_ui()
		VFX.pop_in(rest_btn, 0.3)
		VFX.fade_in(heal_label, 0.3, 0.1)
		VFX.slide_in_from_bottom(relic_list, 20.0, 0.3, 0.2)


func _refresh_ui() -> void:
	heal_label.text = "休息可恢复 %d HP" % GameBalance.CAMPFIRE_CONFIG.restHeal
	rest_btn.disabled = GameManager.hp >= GameManager.max_hp
	
	# 显示可升级遗物
	for child in relic_list.get_children():
		child.queue_free()
	
	for i in GameManager.relics.size():
		var r: Dictionary = GameManager.relics[i]
		var def: RelicDef = GameData.get_relic_def(r.id)
		var level: int = r.get("level", 1)
		if level >= GameBalance.CAMPFIRE_CONFIG.maxRelicLevel:
			continue
		
		var cost := level * GameBalance.CAMPFIRE_CONFIG.upgradeCostPerLevel
		var hbox := HBoxContainer.new()
		var name_l := Label.new()
		name_l.text = "%s Lv%d→%d" % [def.name, level, level + 1]
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var upgrade_btn := Button.new()
		upgrade_btn.text = "升级(%d金)" % cost
		upgrade_btn.pressed.connect(_on_upgrade_relic.bind(i, cost))
		
		hbox.add_child(name_l)
		hbox.add_child(upgrade_btn)
		relic_list.add_child(hbox)


func _on_rest() -> void:
	GameManager.heal(GameBalance.CAMPFIRE_CONFIG.restHeal)
	SoundPlayer.play_sound("heal")
	_refresh_ui()


func _on_upgrade_relic(index: int, cost: int) -> void:
	if not GameManager.spend_gold(cost):
		SoundPlayer.play_sound("error")
		return
	GameManager.relics[index]["level"] = GameManager.relics[index].get("level", 1) + 1
	SoundPlayer.play_sound("upgrade")
	_refresh_ui()


func _on_back() -> void:
	GameManager.set_phase(GameTypes.GamePhase.MAP)
