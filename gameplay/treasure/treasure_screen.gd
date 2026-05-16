## 宝藏界面

extends Node2D
@onready var ui_root: Control = %Root
@onready var treasure_label: Label = %TreasureLabel
@onready var reward_container: VBoxContainer = %RewardContainer
@onready var take_btn: Button = %TakeBtn

var _chest_opened: bool = false


func _ready() -> void:
	take_btn.pressed.connect(_on_take)
	GameManager.phase_changed.connect(_on_phase_changed)
	# 兜底：main.gd 走销毁重建，进场景时 phase 已就位，手动触发一次内容生成
	_on_phase_changed(GameManager.phase)


func _on_phase_changed(new_phase: GameTypes.GamePhase) -> void:
	visible = new_phase == GameTypes.GamePhase.TREASURE
	if visible:
		_chest_opened = false
		_play_chest_open_sequence()


## 宝箱开启动画序列
func _play_chest_open_sequence() -> void:
	# 初始状态：隐藏奖励内容
	treasure_label.modulate.a = 0.0
	reward_container.modulate.a = 0.0
	take_btn.modulate.a = 0.0
	take_btn.disabled = true

	# 阶段1：宝箱震动（模拟开箱）
	var tw := create_tween()
	# 震动效果
	var origin_x: float = treasure_label.position.x
	tw.tween_property(treasure_label, "position:x", origin_x - 4.0, 0.05)
	tw.tween_property(treasure_label, "position:x", origin_x + 4.0, 0.05)
	tw.tween_property(treasure_label, "position:x", origin_x - 3.0, 0.05)
	tw.tween_property(treasure_label, "position:x", origin_x + 3.0, 0.05)
	tw.tween_property(treasure_label, "position:x", origin_x, 0.05)
	# 阶段2：生成奖励内容
	tw.tween_callback(_generate_treasure)
	# 阶段3：标题淡入 + 粒子爆发
	tw.tween_property(treasure_label, "modulate:a", 1.0, 0.3)
	tw.tween_callback(func() -> void:
		VFX.coin_burst(ui_root, treasure_label.position + treasure_label.size * 0.5, 12)
		VFX.victory_burst(ui_root, treasure_label.position + treasure_label.size * 0.5, 8)
	)
	# 阶段4：奖励列表从下方滑入
	tw.tween_interval(0.2)
	tw.tween_property(reward_container, "modulate:a", 1.0, 0.3)
	# 阶段5：按钮淡入
	tw.tween_interval(0.3)
	tw.tween_property(take_btn, "modulate:a", 1.0, 0.25)
	tw.tween_callback(func() -> void:
		take_btn.disabled = false
		_chest_opened = true
	)


func _generate_treasure() -> void:
	for child in reward_container.get_children():
		child.queue_free()
	
	# 宝藏奖励：金币 + 随机遗物/骰子
	var gold_reward := randi_range(30, 60)
	GameManager.add_gold(gold_reward)
	treasure_label.text = "发现宝藏! 获得 %d 金币" % gold_reward
	
	# 50%概率额外遗物
	if randf() < 0.5:
		var all_relics: Array[RelicDef] = []
		all_relics.assign(GameData._relic_defs.values())
		all_relics.shuffle()
		var def: RelicDef = all_relics[0]
		var label := Label.new()
		label.text = "额外发现: %s (%s)" % [def.name, _rarity_name(def.rarity)]
		reward_container.add_child(label)
		if not RelicEngine.has_relic(GameManager.relics, def.id):
			GameManager.relics.append({"id": def.id, "level": 1})


func _on_take() -> void:
	SoundPlayer.play_sound("treasure")
	GameManager.set_phase(GameTypes.GamePhase.MAP)


static func _rarity_name(r: GameTypes.RelicRarity) -> String:
	match r:
		GameTypes.RelicRarity.COMMON: return "普通"
		GameTypes.RelicRarity.UNCOMMON: return "精良"
		GameTypes.RelicRarity.RARE: return "稀有"
		GameTypes.RelicRarity.LEGENDARY: return "传说"
		_: return "??"
