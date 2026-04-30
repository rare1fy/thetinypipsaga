## 商店界面

extends Node2D
@onready var relic_container: VBoxContainer = %RelicContainer
@onready var gold_label: Label = %GoldLabel
@onready var remove_btn: Button = %RemoveBtn
@onready var back_btn: Button = %BackBtn

var _shop_relics: Array[RelicDef] = []
var _shop_items: Array[Dictionary] = []
var _is_removing_dice: bool = false


func _ready() -> void:
	back_btn.pressed.connect(_on_back)
	remove_btn.pressed.connect(_on_remove_dice)
	GameManager.phase_changed.connect(_on_phase_changed)
	SoundPlayer.play_music("explore")
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
	_shop_items.clear()
	_is_removing_dice = false
	
	gold_label.text = "金币: %d" % GameManager.gold
	
	# 生成候选商品池
	var candidate_items: Array[Dictionary] = []
	
	# 候选：遗物（3个）
	var all_relics: Array[RelicDef] = []
	all_relics.assign(GameData._relic_defs.values())
	all_relics.shuffle()
	var owned_ids: Array[String] = []
	for r_raw: Variant in GameManager.relics:
		if typeof(r_raw) != TYPE_DICTIONARY:
			continue
		var r: Dictionary = r_raw
		owned_ids.append(r.get("id", ""))
	
	var relic_count := 0
	for def: RelicDef in all_relics:
		if relic_count >= 3:
			break
		if def.id in owned_ids:
			continue
		var price: int = randi_range(
			GameBalance.SHOP_CONFIG.priceRange[0],
			GameBalance.SHOP_CONFIG.priceRange[1]
		)
		candidate_items.append({
			"type": "relic", "def": def,
			"label": def.name, "desc": def.description,
			"price": price,
		})
		relic_count += 1
	
	# 候选：骰子（2个非基础骰子）
	var dice_pool: Array[Dictionary] = []
	const BASIC_DICE_IDS := ["standard", "w_ironwall", "w_bloodthirst", "m_starter", "r_starter"]
	for dice_id: String in GameData._dice_defs.keys():
		var ddef: DiceDef = GameData._dice_defs[dice_id] as DiceDef
		if ddef == null:
			continue
		if dice_id in BASIC_DICE_IDS:
			continue
		if ddef.is_cursed:
			continue
		var rarity_str: String = "common"
		match ddef.rarity:
			GameTypes.DiceRarity.UNCOMMON: rarity_str = "uncommon"
			GameTypes.DiceRarity.RARE: rarity_str = "rare"
			GameTypes.DiceRarity.LEGENDARY: rarity_str = "rare"
		dice_pool.append({
			"id": dice_id,
			"name": ddef.name,
			"desc": ddef.description,
			"rarity": rarity_str,
		})
	dice_pool.shuffle()
	for i: int in mini(2, dice_pool.size()):
		var d: Dictionary = dice_pool[i]
		var price: int = randi_range(
			GameBalance.SHOP_CONFIG.priceRange[0],
			GameBalance.SHOP_CONFIG.priceRange[1]
		)
		if d.rarity == "rare":
			price += 30
		elif d.rarity == "uncommon":
			price += 10
		candidate_items.append({
			"type": "specialDice", "dice_def_id": d.id,
			"label": d.name, "desc": d.desc,
			"price": price,
		})
	
	# 从候选池随机抽3个
	candidate_items.shuffle()
	var shop_count := mini(3, candidate_items.size())
	for i: int in shop_count:
		_shop_items.append(candidate_items[i])
	
	# 始终添加"骰子净化"选项
	_shop_items.append({
		"type": "removeDice",
		"label": "骰子净化",
		"desc": "移除一颗骰子，瘦身构筑",
		"price": GameBalance.SHOP_CONFIG.removeDicePrice,
	})
	
	# 渲染商品
	for item: Dictionary in _shop_items:
		_render_shop_item(item)


func _render_shop_item(item: Dictionary) -> void:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var type: String = item.get("type", "relic")
	var label_text: String = item.get("label", "???")
	var desc_text: String = item.get("desc", "")
	var price: int = item.get("price", 0)
	
	# 类型标记
	var type_tag: String = ""
	match type:
		"relic":
			type_tag = "[遗物] "
		"specialDice":
			type_tag = "[骰子] "
		"removeDice":
			type_tag = "[净化] "
	
	var name_label := Label.new()
	name_label.text = "%s%s - %d金" % [type_tag, label_text, price]
	name_label.tooltip_text = desc_text
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var buy_btn := Button.new()
	buy_btn.text = "购买"
	buy_btn.pressed.connect(_on_buy_item.bind(item))
	
	hbox.add_child(name_label)
	hbox.add_child(buy_btn)
	relic_container.add_child(hbox)


func _on_buy_item(item: Dictionary) -> void:
	var price: int = item.get("price", 0)
	if GameManager.gold < price:
		SoundPlayer.play_sound("error")
		VFX.show_toast("金币不足", "damage")
		return
	
	var type: String = item.get("type", "relic")
	match type:
		"relic":
			var def: RelicDef = item.get("def")
			if def and not RelicEngine.has_relic(GameManager.relics, def.id):
				GameManager.spend_gold(price)
				GameManager.relics.append({"id": def.id, "level": 1})
				SoundPlayer.play_sound("buy")
				VFX.show_toast("获得遗物: %s" % def.name, "buff")
		"specialDice":
			var dice_id: String = item.get("dice_def_id", "")
			if dice_id != "" and not dice_id in PlayerState.dice_bag:
				GameManager.spend_gold(price)
				PlayerState.dice_bag.append(dice_id)
				SoundPlayer.play_sound("buy")
				VFX.show_toast("获得骰子: %s" % item.get("label", dice_id), "buff")
		"removeDice":
			if PlayerState.dice_bag.size() <= 3:
				SoundPlayer.play_sound("error")
				VFX.show_toast("骰子太少，无法净化", "damage")
				return
			GameManager.spend_gold(price)
			_enter_dice_remove_mode()
			return
	
	gold_label.text = "金币: %d" % GameManager.gold


func _enter_dice_remove_mode() -> void:
	_is_removing_dice = true
	VFX.show_toast("点击骰子袋中要移除的骰子", "buff")


func _on_remove_dice() -> void:
	# 通过商店按钮触发时也走购买流程
	var price := GameBalance.SHOP_CONFIG.removeDicePrice
	if GameManager.gold < price:
		SoundPlayer.play_sound("error")
		VFX.show_toast("金币不足", "damage")
		return
	if PlayerState.dice_bag.size() <= 3:
		SoundPlayer.play_sound("error")
		VFX.show_toast("骰子太少，无法净化", "damage")
		return
	GameManager.spend_gold(price)
	_enter_dice_remove_mode()
	gold_label.text = "金币: %d" % GameManager.gold


func _on_back() -> void:
	if _is_removing_dice:
		# 退出骰子移除模式
		_is_removing_dice = false
		return
	GameManager.set_phase(GameTypes.GamePhase.MAP)


static func _rarity_name(r: GameTypes.RelicRarity) -> String:
	match r:
		GameTypes.RelicRarity.COMMON: return "普通"
		GameTypes.RelicRarity.UNCOMMON: return "精良"
		GameTypes.RelicRarity.RARE: return "稀有"
		GameTypes.RelicRarity.LEGENDARY: return "传说"
		_: return "??"
