## 遗物效果引擎 — 对应原版 engine/relicQueries + buildRelicContext + relicUpdates
## 遗物触发与效果计算的统一入口

class_name RelicEngine


## 检查是否拥有指定ID的遗物
static func has_relic(relics: Array[Dictionary], relic_id: String) -> bool:
	return relics.any(func(r): return r.id == relic_id)


## 查询遗物层数
static func get_relic_level(relics: Array[Dictionary], relic_id: String) -> int:
	for r in relics:
		if r.id == relic_id:
			return r.get("level", 1)
	return 0


## 检查是否有致命保护（时光沙漏）
static func has_fatal_protection(relics: Array[Dictionary]) -> bool:
	return has_relic(relics, "hourglass")


## 触发时光沙漏（消耗遗物）
static func trigger_hourglass(relics: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for r in relics:
		if r.id != "hourglass":
			result.append(r)
	return result


## 战斗开始触发
static func on_battle_start(relics: Array[Dictionary], game: Node) -> void:
	for r in relics:
		var def: RelicDef = GameData.get_relic_def(r.id)
		if def.trigger == GameTypes.RelicTrigger.ON_BATTLE_START:
			_apply_relic_effect(def, r, game)


## 出牌时触发
static func on_play(relics: Array[Dictionary], game: Node, dice: Array[Dictionary], hand_type: String) -> void:
	for r in relics:
		var def: RelicDef = GameData.get_relic_def(r.id)
		if def.trigger == GameTypes.RelicTrigger.ON_PLAY:
			_apply_relic_effect(def, r, game, dice, hand_type)


## 击杀时触发
static func on_kill(relics: Array[Dictionary], game: Node, overkill: int) -> void:
	for r in relics:
		var def: RelicDef = GameData.get_relic_def(r.id)
		if def.trigger == GameTypes.RelicTrigger.ON_KILL:
			if def.id == "soul_crystal":
				var mult := GameBalance.get_soul_crystal_mult(game.current_node, 1.0)
				var soul_gain := int(overkill * mult * SOUL_CRYSTAL_CONFIG.conversionRate)
				game.souls += soul_gain
				if soul_gain > 0:
					EventBus.floating_text.emit("+%d魂晶" % soul_gain, Color.PURPLE, "player", "")


## 受伤时触发
static func on_damage_taken(relics: Array[Dictionary], game: Node, damage: int) -> void:
	for r in relics:
		var def: RelicDef = GameData.get_relic_def(r.id)
		if def.trigger == GameTypes.RelicTrigger.ON_DAMAGE_TAKEN:
			if def.id == "rage_fire":
				game.rage_fire_bonus += def.damage
				EventBus.toast.emit("怒火燎原: 下次出牌+%d伤害" % def.damage, "buff")


## 回合结束触发
static func on_turn_end(relics: Array[Dictionary], game: Node) -> void:
	for r in relics:
		var def: RelicDef = GameData.get_relic_def(r.id)
		if def.trigger == GameTypes.RelicTrigger.ON_TURN_END:
			if def.id == "magic_glove":
				game.relic_temp_draw_bonus += def.temp_draw_bonus
			elif def.id == "whetstone":
				game.relic_temp_extra_play += def.grant_extra_play


## 楼层通过触发
static func on_floor_clear(relics: Array[Dictionary], game: Node) -> void:
	for r in relics:
		var def: RelicDef = GameData.get_relic_def(r.id)
		if def.trigger == GameTypes.RelicTrigger.ON_FLOOR_CLEAR:
			_apply_relic_effect(def, r, game)


## 计算遗物提供的额外伤害
static func get_bonus_damage(relics: Array[Dictionary], game: Node) -> int:
	var total := 0
	for r in relics:
		var def: RelicDef = GameData.get_relic_def(r.id)
		if def.trigger == GameTypes.RelicTrigger.ON_PLAY and def.damage > 0:
			# 生命熔炉：计数器
			if def.id == "life_furnace":
				var counter: int = r.get("counter", 0) + 1
				r["counter"] = counter
				if counter >= def.max_counter:
					total += def.heal
					r["counter"] = 0
				continue
			total += def.damage
	# 加上怒火燎原的累积伤害
	total += game.rage_fire_bonus
	return total


## 计算遗物提供的额外倍率
static func get_bonus_mult(relics: Array[Dictionary], hand_type: String) -> float:
	var total := 0.0
	for r in relics:
		var def: RelicDef = GameData.get_relic_def(r.id)
		if def.multiplier > 0:
			# 棱镜聚焦：同元素牌型加成
			if def.id == "prism_focus" and "同元素" in hand_type:
				total += def.multiplier
	return total


## 计算额外出牌次数
static func get_extra_plays(relics: Array[Dictionary], game: Node) -> int:
	var total := 0
	total += game.relic_temp_extra_play
	game.relic_temp_extra_play = 0
	return total


## 计算额外免费重投
static func get_extra_free_rerolls(relics: Array[Dictionary]) -> int:
	var total := 0
	for r in relics:
		var def: RelicDef = GameData.get_relic_def(r.id)
		total += def.free_rerolls
	return total


## 应用遗物效果
static func _apply_relic_effect(def: RelicDef, relic_data: Dictionary, game: Node, dice: Array[Dictionary] = [], hand_type: String = "") -> void:
	if def.armor > 0:
		game.gain_armor(def.armor)
		EventBus.floating_text.emit("+%d护甲" % def.armor, Color.CYAN, "player", "")
	if def.heal > 0:
		if def.id != "life_furnace":  # 生命熔炉在 get_bonus_damage 中处理
			game.heal(def.heal)
	if def.draw_count_bonus > 0:
		game.draw_count += def.draw_count_bonus
	if def.extra_play > 0:
		game.plays_left += def.extra_play


const SOUL_CRYSTAL_CONFIG := {"conversionRate": 0.15}
