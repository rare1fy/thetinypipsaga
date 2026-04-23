## 商店界面

extends Control

@onready var relic_container: VBoxContainer = %RelicContainer
@onready var gold_label: Label = %GoldLabel
@onready var remove_btn: Button = %RemoveBtn
@onready var back_btn: Button = %BackBtn

var _shop_relics: Array[RelicDef] = []


func _ready() -> void:
	back_btn.pressed.connect(_on_back)
	remove_btn.pressed.connect(_on_remove_dice)
	GameManager.phase_changed.connect(_on_phase_changed)
	# 兜底：main.gd 走销毁重建，进场景时 phase 已就位，手动触发一次内容生成
	_on_phase_changed(GameManager.phase)


func _on_phase_changed(new_phase: GameTypes.GamePhase) -> void:
	visible = new_phase == GameTypes.GamePhase.MERCHANT
	if visible:
		_generate_shop()
		VFX.slide_in_from_bottom(relic_container, 20.0, 0.3, 0.1)
		VFX.fade_in(gold_label, 0.2, 0.2)


func _generate_shop() -> void:
	# 清空
	for child in relic_container.get_children():
		child.queue_free()
	_shop_relics.clear()
	
	gold_label.text = "金币: %d" % GameManager.gold
	
	# 生成3个随机遗物
	var all_relics: Array = GameData._relic_defs.values()
	all_relics.shuffle()
	var count := mini(3, all_relics.size())
	
	for i in count:
		var def: RelicDef = all_relics[i]
		_shop_relics.append(def)
		
		var hbox := HBoxContainer.new()
		var name_label := Label.new()
		name_label.text = "%s (%s)" % [def.name, _rarity_name(def.rarity)]
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var price := randi_range(GameBalance.SHOP_CONFIG.priceRange[0], GameBalance.SHOP_CONFIG.priceRange[1])
		var buy_btn := Button.new()
		buy_btn.text = "购买(%d金)" % price
		buy_btn.pressed.connect(_on_buy_relic.bind(def, price))
		
		hbox.add_child(name_label)
		hbox.add_child(buy_btn)
		relic_container.add_child(hbox)


func _on_buy_relic(def: RelicDef, price: int) -> void:
	if GameManager.gold < price:
		SoundPlayer.play_sound("error")
		return
	if RelicEngine.has_relic(GameManager.relics, def.id):
		return
	
	GameManager.spend_gold(price)
	GameManager.relics.append({"id": def.id, "level": 1})
	SoundPlayer.play_sound("buy")
	gold_label.text = "金币: %d" % GameManager.gold


func _on_remove_dice() -> void:
	var price := GameBalance.SHOP_CONFIG.removeDicePrice
	if not GameManager.spend_gold(price):
		SoundPlayer.play_sound("error")
		return
	# TODO: 弹出骰子选择界面移除一个骰子
	SoundPlayer.play_sound("buy")


func _on_back() -> void:
	GameManager.set_phase(GameTypes.GamePhase.MAP)


static func _rarity_name(r: GameTypes.RelicRarity) -> String:
	match r:
		GameTypes.RelicRarity.COMMON: return "普通"
		GameTypes.RelicRarity.UNCOMMON: return "精良"
		GameTypes.RelicRarity.RARE: return "稀有"
		GameTypes.RelicRarity.LEGENDARY: return "传说"
		_: return "??"
