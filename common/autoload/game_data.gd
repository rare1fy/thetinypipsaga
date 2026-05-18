## 游戏数据注册表 — 所有骰子定义、遗物定义的统一查询入口
## 数据源：config/json/ 目录下的 dice.json + relic.json（由 Excel 工具链生成）

extends Node

# ============================================================
# 数据注册表
# ============================================================

var _dice_defs: Dictionary = {}
var _relic_defs: Dictionary = {}

func _ready() -> void:
	_dice_defs = ConfigLoader.load_dice_defs()
	_relic_defs = ConfigLoader.load_relic_defs()
	if _dice_defs.is_empty():
		push_error("[GameData] dice.json 加载失败，骰子定义为空！")
	if _relic_defs.is_empty():
		push_error("[GameData] relic.json 加载失败，遗物定义为空！")
	# 敌人配置（从 enemy.json 加载并注入 EnemyConfig._all_configs）
	var enemy_defs := ConfigLoader.load_enemy_configs()
	if enemy_defs.is_empty():
		push_error("[GameData] enemy.json 加载失败，敌人定义为空！")
	# 魂晶商店遗物（独立于 JSON，硬编码注册）
	_register_soul_shop_relics()
	print("[GameData] dice=%d relics=%d enemies=%d" % [_dice_defs.size(), _relic_defs.size(), enemy_defs.size()])


# ============================================================
# 公共查询接口
# ============================================================

## 获取所有骰子定义
func get_all_dice() -> Dictionary:
	return _dice_defs


## 获取所有遗物定义（返回 Dictionary[String, Dictionary]）
func get_all_relics() -> Dictionary:
	var result: Dictionary = {}
	for id: String in _relic_defs:
		var rdef: RelicDef = _relic_defs[id]
		var rarity_str: String = "common"
		match rdef.rarity:
			GameTypes.RelicRarity.COMMON: rarity_str = "common"
			GameTypes.RelicRarity.UNCOMMON: rarity_str = "uncommon"
			GameTypes.RelicRarity.RARE: rarity_str = "rare"
			GameTypes.RelicRarity.LEGENDARY: rarity_str = "legendary"
		result[id] = {
			"id": rdef.id, "name": rdef.name, "description": rdef.description,
			"rarity": rarity_str,
		}
	return result


## 获取所有敌人配置（从 JSON 加载）
func get_all_enemies() -> Dictionary:
	return ConfigLoader.load_enemy_configs()


## 获取骰子定义
func get_dice_def(id: String) -> DiceDef:
	if _dice_defs.has(id):
		return _dice_defs[id]
	push_warning("DiceDef not found: %s, fallback to standard" % id)
	return _dice_defs.get("standard", DiceDef.new())


## 获取遗物定义
func get_relic_def(id: String) -> RelicDef:
	if _relic_defs.has(id):
		return _relic_defs[id]
	push_warning("RelicDef not found: %s" % id)
	return RelicDef.new()


## 掷骰子
func roll_dice(id: String) -> int:
	var def := get_dice_def(id)
	if def.faces.is_empty():
		return 1
	return def.faces[randi() % def.faces.size()]


## 获取骰子奖励池
func get_dice_reward_pool(battle_type: String, p_class: String = "") -> Array[DiceDef]:
	var pool: Array[DiceDef] = []
	var all_defs: Array[DiceDef] = []
	all_defs.assign(_dice_defs.values())

	# 职业骰子加权
	var prefix := ""
	if p_class == "warrior":
		prefix = "w_"
	elif p_class == "mage":
		prefix = "mage_"
	elif p_class == "rogue":
		prefix = "r_"

	for d in all_defs:
		if prefix != "" and d.id.begins_with(prefix):
			# 职业骰子高权重
			var weight := 3
			if d.rarity == GameTypes.DiceRarity.RARE:
				weight = 2 if battle_type == "enemy" else 3
			elif d.rarity == GameTypes.DiceRarity.LEGENDARY:
				weight = 1 if battle_type != "boss" else 3
			for i in weight:
				pool.append(d)
		elif not d.id.begins_with("w_") and not d.id.begins_with("mage_") and not d.id.begins_with("r_") and not d.id == "temp_rogue" and not d.id == "cursed" and not d.id == "cracked":
			# 通用骰子
			if d.rarity != GameTypes.DiceRarity.CURSE:
				pool.append(d)

	return pool


## 随机挑选N个不重复骰子
func pick_random_dice(pool: Array[DiceDef], count: int) -> Array[DiceDef]:
	var shuffled := pool.duplicate()
	shuffled.shuffle()
	var seen: Dictionary = {}
	var result: Array[DiceDef] = []
	for d in shuffled:
		if not seen.has(d.id):
			seen[d.id] = true
			result.append(d)
			if result.size() >= count:
				break
	return result


# ============================================================
# 魂晶商店遗物（独立于 JSON 数据源）
# ============================================================

func _reg_relic(r: RelicDef) -> void:
	_relic_defs[r.id] = r


## 魂晶商店常驻遗物
func _register_soul_shop_relics() -> void:
	_reg_relic(_mk_relic_fx("grindstone", "磨刀石", "每次出牌+2伤害", GameTypes.RelicRarity.UNCOMMON,
		GameTypes.RelicTrigger.ON_PLAY, [
			EffectTypes.create_effect(EffectTypes.EffectType.BONUS_DAMAGE,
				{"value": 2}, EffectTypes.TriggerType.ON_PLAY, EffectTypes.EffectScope.INSTANT),
		]))
	_reg_relic(_mk_relic_fx("iron_skin_relic", "铁皮护符", "战斗开始时获得8护甲", GameTypes.RelicRarity.UNCOMMON,
		GameTypes.RelicTrigger.ON_BATTLE_START, [
			EffectTypes.create_effect(EffectTypes.EffectType.ARMOR,
				{"value": 8}, EffectTypes.TriggerType.ON_BATTLE_START, EffectTypes.EffectScope.INSTANT),
		]))
	_reg_relic(_mk_relic_fx("fate_coin", "命运硬币", "每回合首次重投免费", GameTypes.RelicRarity.RARE,
		GameTypes.RelicTrigger.PASSIVE, [
			EffectTypes.create_effect(EffectTypes.EffectType.GRANT_REROLL,
				{"count": 1}, EffectTypes.TriggerType.ON_TURN_START, EffectTypes.EffectScope.TURN),
		]))
	_reg_relic(_mk_relic_fx("greedy_hand", "贪婪之手", "金币获取+30%", GameTypes.RelicRarity.RARE,
		GameTypes.RelicTrigger.PASSIVE, [
			EffectTypes.create_effect(EffectTypes.EffectType.GAIN_GOLD,
				{"value": 30, "mode": "percent"}, EffectTypes.TriggerType.PASSIVE, EffectTypes.EffectScope.RUN),
		]))
	_reg_relic(_mk_relic_fx("crimson_grail", "绯红圣杯", "击杀敌人恢复8HP", GameTypes.RelicRarity.RARE,
		GameTypes.RelicTrigger.ON_KILL, [
			EffectTypes.create_effect(EffectTypes.EffectType.HEAL,
				{"value": 8}, EffectTypes.TriggerType.ON_KILL, EffectTypes.EffectScope.INSTANT),
		]))
	_reg_relic(_mk_relic_fx("schrodinger_bag", "薛定谔之袋", "每回合额外抽1颗骰子", GameTypes.RelicRarity.RARE,
		GameTypes.RelicTrigger.PASSIVE, [
			EffectTypes.create_effect(EffectTypes.EffectType.MODIFY_DRAW_COUNT,
				{"delta": 1}, EffectTypes.TriggerType.PASSIVE, EffectTypes.EffectScope.RUN),
		]))
	_reg_relic(_mk_relic_fx("treasure_sense_relic", "寻宝直觉", "商店折扣15%", GameTypes.RelicRarity.UNCOMMON,
		GameTypes.RelicTrigger.PASSIVE, [
			EffectTypes.create_effect(EffectTypes.EffectType.SHOP_DISCOUNT,
				{"value": 15}, EffectTypes.TriggerType.PASSIVE, EffectTypes.EffectScope.RUN),
		]))
	_reg_relic(_mk_relic_fx("warm_ember_relic", "温暖余烬", "营火恢复量+50%", GameTypes.RelicRarity.UNCOMMON,
		GameTypes.RelicTrigger.PASSIVE, [
			EffectTypes.create_effect(EffectTypes.EffectType.HEAL,
				{"value": 50, "mode": "percent"}, EffectTypes.TriggerType.PASSIVE, EffectTypes.EffectScope.RUN),
		]))
	_reg_relic(_mk_relic_fx("symmetry_seeker", "对称追寻者", "对子伤害+20%", GameTypes.RelicRarity.RARE,
		GameTypes.RelicTrigger.ON_PLAY, [
			EffectTypes.create_effect(EffectTypes.EffectType.BONUS_MULT,
				{"value": 0.2, "condition": "hand_type_pair"}, EffectTypes.TriggerType.ON_PLAY, EffectTypes.EffectScope.INSTANT),
		]))
	_reg_relic(_mk_relic_fx("iron_banner", "铁旗", "每回合开始获得3护甲", GameTypes.RelicRarity.UNCOMMON,
		GameTypes.RelicTrigger.ON_TURN_START, [
			EffectTypes.create_effect(EffectTypes.EffectType.ARMOR,
				{"value": 3}, EffectTypes.TriggerType.ON_TURN_START, EffectTypes.EffectScope.INSTANT),
		]))


func _mk_relic_fx(id: String, rname: String, desc: String, rarity: GameTypes.RelicRarity,
	trigger: GameTypes.RelicTrigger, effects: Array[Dictionary]) -> RelicDef:
	var r := RelicDef.new()
	r.id = id; r.name = rname; r.description = desc; r.rarity = rarity; r.trigger = trigger
	r.effects = effects
	return r
