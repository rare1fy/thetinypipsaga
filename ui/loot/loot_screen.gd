## 战利品界面

extends Control

@onready var gold_label: Label = %GoldLabel
@onready var relic_container: VBoxContainer = %RelicContainer
@onready var dice_container: VBoxContainer = %DiceContainer
@onready var continue_btn: Button = %ContinueBtn


func _ready() -> void:
	continue_btn.pressed.connect(_on_continue)
	GameManager.phase_changed.connect(_on_phase_changed)
	# 兜底：main.gd 走销毁重建，进场景时 phase 已就位，手动触发一次内容生成
	_on_phase_changed(GameManager.phase)


func _on_phase_changed(new_phase: GameTypes.GamePhase) -> void:
	visible = new_phase == GameTypes.GamePhase.LOOT
	if visible:
		_generate_loot()
		# 战利品弹入
		VFX.pop_in(gold_label, 0.3)
		VFX.slide_in_from_bottom(relic_container, 25.0, 0.3, 0.15)
		VFX.slide_in_from_bottom(dice_container, 25.0, 0.3, 0.25)
		VFX.coin_burst(self, gold_label.position + gold_label.size * 0.5, 8)


func _generate_loot() -> void:
	for child in relic_container.get_children():
		child.queue_free()
	for child in dice_container.get_children():
		child.queue_free()
	
	gold_label.text = "获得金币: %d" % GameManager.gold
	
	# 生成3个随机遗物供选择
	var all_relics: Array = GameData._relic_defs.values()
	all_relics.shuffle()
	var count := mini(GameBalance.LOOT_CONFIG.relicChoiceCount, all_relics.size())
	
	for i in count:
		var def: RelicDef = all_relics[i]
		var btn := Button.new()
		btn.text = "%s (%s) — %s" % [def.name, _rarity_name(def.rarity), def.description]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.pressed.connect(_on_pick_relic.bind(def))
		relic_container.add_child(btn)
	
	# 生成3个随机骰子供选择
	var pool := GameData.get_dice_reward_pool("enemy", GameManager.player_class)
	var choices := GameData.pick_random_dice(pool, 3)
	
	for def in choices:
		var btn := Button.new()
		btn.text = "%s (%s) — %s" % [def.name, _dice_rarity_name(def.rarity), def.description]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.pressed.connect(_on_pick_dice.bind(def))
		dice_container.add_child(btn)


func _on_pick_relic(def: RelicDef) -> void:
	if not RelicEngine.has_relic(GameManager.relics, def.id):
		GameManager.relics.append({"id": def.id, "level": 1})
		SoundPlayer.play_sound("relic_acquire")
	_continue()


func _on_pick_dice(def: DiceDef) -> void:
	GameManager.owned_dice.append({"defId": def.id, "level": 1})
	SoundPlayer.play_sound("dice_acquire")
	_continue()


func _on_continue() -> void:
	_continue()


func _continue() -> void:
	GameManager.set_phase(GameTypes.GamePhase.MAP)


static func _rarity_name(r: GameTypes.RelicRarity) -> String:
	match r:
		GameTypes.RelicRarity.COMMON: return "普通"
		GameTypes.RelicRarity.UNCOMMON: return "精良"
		GameTypes.RelicRarity.RARE: return "稀有"
		GameTypes.RelicRarity.LEGENDARY: return "传说"
		_: return "??"


static func _dice_rarity_name(r: GameTypes.DiceRarity) -> String:
	match r:
		GameTypes.DiceRarity.COMMON: return "普通"
		GameTypes.DiceRarity.UNCOMMON: return "精良"
		GameTypes.DiceRarity.RARE: return "稀有"
		GameTypes.DiceRarity.LEGENDARY: return "传说"
		GameTypes.DiceRarity.CURSE: return "诅咒"
		_: return "??"
