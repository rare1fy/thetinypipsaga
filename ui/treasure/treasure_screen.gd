## 宝藏界面

extends Control

@onready var treasure_label: Label = %TreasureLabel
@onready var reward_container: VBoxContainer = %RewardContainer
@onready var take_btn: Button = %TakeBtn


func _ready() -> void:
	take_btn.pressed.connect(_on_take)
	GameManager.phase_changed.connect(_on_phase_changed)


func _on_phase_changed(new_phase: GameTypes.GamePhase) -> void:
	visible = new_phase == GameTypes.GamePhase.TREASURE
	if visible:
		_generate_treasure()
		VFX.pop_in(treasure_label, 0.4)
		VFX.coin_burst(self, treasure_label.position + treasure_label.size * 0.5, 10)
		VFX.slide_in_from_bottom(reward_container, 20.0, 0.3, 0.2)


func _generate_treasure() -> void:
	for child in reward_container.get_children():
		child.queue_free()
	
	# 宝藏奖励：金币 + 随机遗物/骰子
	var gold_reward := randi_range(30, 60)
	GameManager.add_gold(gold_reward)
	treasure_label.text = "发现宝藏! 获得 %d 金币" % gold_reward
	
	# 50%概率额外遗物
	if randf() < 0.5:
		var all_relics: Array = GameData._relic_defs.values()
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
