## 战斗工具 helpers — 从 battle_scene.gd 抽出
## 辅助函数，部分方法有 GameManager 全局副作用（heal / add_gold / stats），调用方须知

class_name BattleHelpers


## 优先嘲讽目标 → 否则第一个存活敌人
static func pick_target(enemies: Array[EnemyInstance], target_uid: String) -> EnemyInstance:
	if target_uid != "":
		for e: EnemyInstance in enemies:
			if e.uid == target_uid and e.hp > 0:
				return e
	for e: EnemyInstance in enemies:
		if e.hp > 0:
			return e
	return null


## 应用元素效果（火/冰/雷/毒/圣），直接修改 enemies & GameManager 状态
static func apply_element_effects(enemy: EnemyInstance, selected_dice: Array[Dictionary], enemies: Array[EnemyInstance]) -> void:
	for d: Dictionary in selected_dice:
		var elem: String = d.get("collapsedElement", d.get("element", "normal"))
		match elem:
			"fire":
				enemy.armor = 0
				var burn_val := maxi(1, int(d.value * 0.5))
				var s := StatusEffect.new()
				s.type = GameTypes.StatusType.BURN
				s.value = burn_val
				s.duration = 3
				enemy.statuses.append(s)
			"ice":
				var s := StatusEffect.new()
				s.type = GameTypes.StatusType.FREEZE
				s.value = 1
				s.duration = 1
				enemy.statuses.append(s)
			"thunder":
				for other: EnemyInstance in enemies:
					if other.uid != enemy.uid and other.hp > 0:
						other.hp = maxi(0, other.hp - int(d.value))
			"poison":
				var s := StatusEffect.new()
				s.type = GameTypes.StatusType.POISON
				s.value = int(d.value)
				s.duration = 3
				enemy.statuses.append(s)
			"holy":
				GameManager.heal(int(d.value))


## 扫描死亡敌人发放奖励，返回被结算的 uid 列表（供 UI 清理）
static func settle_enemy_deaths(enemies: Array[EnemyInstance]) -> Array[String]:
	var settled: Array[String] = []
	for e: EnemyInstance in enemies:
		if e.hp <= 0 and e.hp > -9999:
			GameManager.add_gold(e.drop_gold)
			GameManager.stats.enemiesKilled += 1
			e.hp = -9999
			settled.append(e.uid)
	return settled


## 构造盗贼暗影残骰（append 到 GameManager.hand_dice 的 Dictionary）
static func make_shadow_remnant() -> Dictionary:
	return {
		"id": randi(), "defId": "temp_rogue", "value": randi_range(1, 3),
			"element": "normal", "selected": false, "rolling": false,
		"isShadowRemnant": true, "isTemp": true, "shadowRemnantPersistent": false,
		"kept": false, "keptBonusAccum": 0,
	}


## 出牌后的骰子特效（分裂、影分身）：返回要追加进 hand_dice 的新骰子列表
static func compute_dice_on_play_extras(selected_dice: Array[Dictionary]) -> Array[Dictionary]:
	var extras: Array[Dictionary] = []
	for d: Dictionary in selected_dice:
		var def: DiceDef = GameData.get_dice_def(d.defId)
		if def.shadow_clone_play:
			var clone: Dictionary = d.duplicate()
			clone.id = randi()
			clone.spent = true
			clone["isShadowRemnant"] = true
			extras.append(clone)
	return extras


## AOE 检测（雷元素 或 顺子 / 多条 / 元素系顺子牌型）
## 演出 Phase4 震屏强度 + UI AOE 标识共用
## §6.8 对齐：aoe_hands = ['顺子','4顺','5顺','6顺','三连对','四条','五条','六条','元素顺','元素葫芦','皇家元素顺']
static func detect_aoe(selected_dice: Array[Dictionary], hand_result: Dictionary) -> bool:
	for d: Dictionary in selected_dice:
		var elem: String = d.get("collapsedElement", d.get("element", "normal"))
		if elem == "thunder":
			return true
	var aoe_hands := [
		"顺子", "4顺", "5顺", "6顺",
		"三连对", "四条", "五条", "六条",
		"元素顺", "元素葫芦", "皇家元素顺",
	]
	for h: String in hand_result.get("activeHands", []):
		if h in aoe_hands:
			return true
	return false


## 主导元素 — 取本次出牌中出现次数最多的非 normal 元素，用于受击粒子配色
## 全 normal 返回 "physical"；平局时按 ELEMENT_PRIORITY 打破平局，保证同组牌输出同一粒子色
static func dominant_element(selected_dice: Array[Dictionary]) -> String:
	var counts: Dictionary = {}
	for d: Dictionary in selected_dice:
		var elem: String = d.get("collapsedElement", d.get("element", "normal"))
		if elem == "normal" or elem == "":
			continue
		counts[elem] = counts.get(elem, 0) + 1
	if counts.is_empty():
		return "physical"
	# 平局打破：火>雷>冰>毒>圣
	var priority := ["fire", "thunder", "ice", "poison", "holy"]
	var best := ""
	var best_count := 0
	var best_rank := 999
	for k: String in counts.keys():
		var rank: int = priority.find(k) if k in priority else 500
		if counts[k] > best_count or (counts[k] == best_count and rank < best_rank):
			best = k
			best_count = counts[k]
			best_rank = rank
	return best


## 敌方 DoT 预结算（灼烧/中毒扣血 + 过期清理），供 controller 和 enemy_ai 共用
static func settle_enemy_dot_damage(enemies: Array[EnemyInstance]) -> void:
	for e: EnemyInstance in enemies:
		if e.hp <= 0:
			continue
		for s: StatusEffect in e.statuses:
			if s.type == GameTypes.StatusType.BURN and s.value > 0:
				e.hp = maxi(0, e.hp - s.value)
				s.value = 0
			elif s.type == GameTypes.StatusType.POISON and s.value > 0:
				e.hp = maxi(0, e.hp - s.value)
				s.duration -= 1
		e.statuses = e.statuses.filter(func(s: StatusEffect) -> bool: return s.duration > 0)
