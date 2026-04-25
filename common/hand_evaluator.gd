## 牌型判定器 — 对应原版 utils/handEvaluator.ts
## 纯函数，无状态依赖

class_name HandEvaluator

# 牌型优先级（从高到低）
const HAND_PRIORITY: Array[String] = [
	"皇家元素顺", "元素葫芦", "元素顺", "六条", "五条", "四条", "葫芦",
	"同元素", "6顺", "5顺", "4顺", "顺子", "三条", "三连对", "连对",
	"对子", "普通攻击"
]

# 牌型倍率表 {base, mult}
const HAND_MULT: Dictionary = {
	"普通攻击": {"base": 0, "mult": 1.0},
	"对子": {"base": 5, "mult": 1.0},
	"连对": {"base": 10, "mult": 1.2},
	"三连对": {"base": 20, "mult": 1.5},
	"三条": {"base": 10, "mult": 1.5},
	"顺子": {"base": 15, "mult": 1.3},
	"4顺": {"base": 25, "mult": 1.5},
	"5顺": {"base": 40, "mult": 1.8},
	"6顺": {"base": 60, "mult": 2.0},
	"同元素": {"base": 30, "mult": 1.8},
	"葫芦": {"base": 35, "mult": 1.8},
	"四条": {"base": 50, "mult": 2.0},
	"五条": {"base": 80, "mult": 2.5},
	"六条": {"base": 120, "mult": 3.0},
	"元素顺": {"base": 60, "mult": 2.2},
	"元素葫芦": {"base": 80, "mult": 2.5},
	"皇家元素顺": {"base": 150, "mult": 3.5},
}


## 检测选中骰子的牌型
static func check_hands(dice: Array[Dictionary], straight_upgrade: int = 0) -> Dictionary:
	if dice.is_empty():
		return {"bestHand": "普通攻击", "allHands": [], "activeHands": ["普通攻击"]}
	
	# 过滤掉 ignoreForHandType 的骰子
	var hand_dice: Array[Dictionary] = dice.filter(func(d): return not _has_ignore_for_hand_type(d))
	var values: Array[int] = (hand_dice if hand_dice.size() > 0 else dice).map(func(d): return d.value)
	values.sort()
	var elements: Array[String] = (hand_dice if hand_dice.size() > 0 else dice).map(func(d): return d.get("collapsedElement", "") if d.get("collapsedElement", "") else d.get("element", "normal"))
	var unique_elements: Dictionary = {}
	for e in elements:
		unique_elements[e] = true
	
	# 同元素: 所有骰子同一非normal元素，且≥4颗
	var valid_dice_count: int = hand_dice.size() if hand_dice.size() > 0 else dice.size()
	var is_same_element: bool = unique_elements.size() == 1 and valid_dice_count >= 4 and elements[0] != "normal"
	
	# 计数
	var counts: Dictionary = {}
	for v in values:
		counts[v] = counts.get(v, 0) + 1
	var sorted_counts: Array[int] = counts.values()
	sorted_counts.sort()
	sorted_counts.reverse()
	var max_count: int = sorted_counts[0] if sorted_counts.size() > 0 else 0
	var is_two_pair: bool = sorted_counts.size() >= 2 and sorted_counts[0] == 2 and sorted_counts[1] == 2
	var is_three_pair: bool = sorted_counts.size() >= 3 and sorted_counts[0] == 2 and sorted_counts[1] == 2 and sorted_counts[2] == 2
	var is_full_house: bool = sorted_counts.size() >= 2 and sorted_counts[0] >= 3 and sorted_counts[1] >= 2
	
	# 顺子检测
	var unique_values: Array[int] = []
	var seen_vals: Dictionary = {}
	for v in values:
		if not seen_vals.has(v):
			seen_vals[v] = true
			unique_values.append(v)
	unique_values.sort()
	
	# 找最长连续序列
	var is_straight: bool = false
	var straight_len: int = 0
	if unique_values.size() >= 3:
		# 计算最长连续子序列
		var max_run: int = 1
		var cur_run: int = 1
		for i in range(1, unique_values.size()):
			if unique_values[i] == unique_values[i - 1] + 1:
				cur_run += 1
				max_run = max(max_run, cur_run)
			else:
				cur_run = 1
		# 验证最长连续序列是否覆盖全部骰子
		if max_run == valid_dice_count and valid_dice_count >= 3:
			is_straight = true
			straight_len = valid_dice_count
		# 也检查是否有更短的顺子可用
		elif max_run >= 3 and max_run <= valid_dice_count:
			# 使用当前连续长度（可能小于骰子总数）
			straight_len = max_run
			is_straight = true
	
	# 应用顺子升级
	# TODO(v0.2): 顺子升级遗物实现，当前版本未决策是否保留该遗物
	# 现为兜底逻辑：不改变 is_straight 判定，保持基础顺子规则
	if straight_upgrade > 0 and not is_straight and valid_dice_count >= 3:
		pass  # [HOLD] 等待设计决策后填入扩展顺子逻辑
	
	var hands: Dictionary = {}  # 用 Dictionary 模拟 Set
	
	# === 基础牌型 ===
	# N条
	if max_count == 6 and valid_dice_count == 6: hands["六条"] = true
	if max_count == 5 and valid_dice_count == 5: hands["五条"] = true
	if max_count == 4 and valid_dice_count == 4: hands["四条"] = true
	if max_count == 3 and valid_dice_count == 3: hands["三条"] = true
	if max_count == 2 and valid_dice_count == 2: hands["对子"] = true
	
	# 葫芦 (3+2): 多种模式
	if is_full_house and valid_dice_count == 5: hands["葫芦"] = true
	# 4+2 模式的葫芦
	if max_count >= 4 and sorted_counts.size() >= 2 and sorted_counts[1] >= 2 and valid_dice_count == 6: hands["葫芦"] = true
	# 3+3 模式的葫芦
	if max_count >= 3 and sorted_counts.size() >= 2 and sorted_counts[1] >= 3 and valid_dice_count == 6: hands["葫芦"] = true
	
	# 连对 / 三连对
	if is_two_pair and valid_dice_count == 4: hands["连对"] = true
	if is_three_pair and valid_dice_count == 6: hands["三连对"] = true
	
	# === 顺子牌型 ===
	if is_straight:
		if straight_len == 6: hands["6顺"] = true
		elif straight_len == 5: hands["5顺"] = true
		elif straight_len == 4: hands["4顺"] = true
		elif straight_len >= 3: hands["顺子"] = true
	
	# === 元素牌型 ===
	if is_same_element: hands["同元素"] = true
	
	# === 组合牌型 ===
	# 元素顺：顺子 + 同元素
	if is_straight and is_same_element: hands["元素顺"] = true
	# 皇家元素顺：A-6 的元素顺
	if is_straight and is_same_element and values[0] == 1 and values[values.size() - 1] == 6: hands["皇家元素顺"] = true
	# 元素葫芦：同元素 + 葫芦
	if is_same_element and is_full_house: hands["元素葫芦"] = true
	
	# 普通攻击兜底
	if hands.is_empty():
		if valid_dice_count == 1:
			hands["普通攻击"] = true
		else:
			return {"bestHand": "普通攻击", "allHands": ["普通攻击"], "activeHands": ["普通攻击"]}
	
	var all_hands: Array[String] = hands.keys()
	
	# 确定生效牌型
	var active_hands: Array[String] = []
	var has_base_hand: bool = false
	
	# === N条 / 葫芦 / 连对 / 对子 互斥，取最高 ===
	if hands.has("六条"): active_hands.append("六条"); has_base_hand = true
	elif hands.has("五条"): active_hands.append("五条"); has_base_hand = true
	elif hands.has("四条"): active_hands.append("四条"); has_base_hand = true
	elif hands.has("葫芦"): active_hands.append("葫芦"); has_base_hand = true
	elif hands.has("三条"): active_hands.append("三条"); has_base_hand = true
	elif hands.has("三连对"): active_hands.append("三连对"); has_base_hand = true
	elif hands.has("连对"): active_hands.append("连对"); has_base_hand = true
	elif hands.has("对子"): active_hands.append("对子"); has_base_hand = true
	
	# === 顺子可叠加 ===
	if hands.has("6顺"): active_hands.append("6顺"); has_base_hand = true
	elif hands.has("5顺"): active_hands.append("5顺"); has_base_hand = true
	elif hands.has("4顺"): active_hands.append("4顺"); has_base_hand = true
	elif hands.has("顺子"): active_hands.append("顺子"); has_base_hand = true
	
	# === 元素可叠加 ===
	if hands.has("同元素"): active_hands.append("同元素"); has_base_hand = true
	
	# === 组合牌型可叠加 ===
	if hands.has("皇家元素顺"): active_hands.append("皇家元素顺")
	elif hands.has("元素顺"): active_hands.append("元素顺")
	if hands.has("元素葫芦"): active_hands.append("元素葫芦")
	
	# 普通攻击兜底
	if not has_base_hand and valid_dice_count == 1:
		active_hands.append("普通攻击")
	
	# 按优先级排序
	active_hands.sort_custom(func(a, b): return HAND_PRIORITY.find(a) < HAND_PRIORITY.find(b))
	
	var best_hand := " + ".join(active_hands)
	
	return {"bestHand": best_hand, "allHands": all_hands, "activeHands": active_hands}


## 获取牌型基础伤害倍率
static func get_hand_mult(hand_name: String) -> Dictionary:
	if HAND_MULT.has(hand_name):
		return HAND_MULT[hand_name]
	return {"base": 0, "mult": 1.0}


## 计算总伤害
static func calculate_damage(dice: Array[Dictionary], hand_result: Dictionary, bonus_mult: float = 0.0, bonus_damage: int = 0) -> int:
	var total_points: int = 0
	for d in dice:
		total_points += d.value
	
	var active_hands: Array[String] = hand_result.get("activeHands", [])
	var best_base: int = 0
	var best_mult: float = 1.0
	
	for h in active_hands:
		var hm := get_hand_mult(h)
		if hm.base > best_base:
			best_base = hm.base
		if hm.mult > best_mult:
			best_mult = hm.mult
	
	# 总伤害 = (点数之和 + 牌型基础) × 牌型倍率 × (1 + 额外倍率) + 额外伤害
	var damage := int((total_points + best_base) * best_mult * (1.0 + bonus_mult)) + bonus_damage
	return maxi(1, damage)


static func _has_ignore_for_hand_type(d: Dictionary) -> bool:
	var def: DiceDef = GameData.get_dice_def(d.get("defId", "standard"))
	return def.ignore_for_hand_type


## 查找可组成牌型的候选骰子
static func find_hand_candidates(all_dice: Array[Dictionary], selected_id: int = -1) -> Dictionary:
	var available: Array[Dictionary] = all_dice.filter(func(d): return not d.get("spent", false) and not d.get("rolling", false))
	var result: Dictionary = {}  # 模拟 Set，key=id
	
	if available.size() < 2:
		return result
	
	if selected_id >= 0:
		# 模式B：找能和 selected_id 组成牌型的骰子
		var anchor: Array[Dictionary] = available.filter(func(d): return d.id == selected_id)
		if anchor.is_empty():
			return result
		result[selected_id] = true
		
		for other in available:
			if other.id == selected_id:
				continue
			var pair: Array[Dictionary] = [anchor[0], other]
			var hand := check_hands(pair)
			if hand.activeHands.any(func(h): return h != "普通攻击"):
				result[other.id] = true
				continue
		return result
	
	# 模式A：找所有可组合的骰子
	# 对子检测
	var value_counts: Dictionary = {}
	for d in available:
		if not value_counts.has(d.value):
			value_counts[d.value] = []
		value_counts[d.value].append(d.id)
	for ids in value_counts.values():
		if ids.size() >= 2:
			for id in ids:
				result[id] = true
	
	# 顺子检测
	var unique_vals: Array = []
	var seen: Dictionary = {}
	for d in available:
		if not seen.has(d.value):
			seen[d.value] = true
			unique_vals.append(d.value)
	unique_vals.sort()
	
	for i in range(unique_vals.size() - 2):
		if unique_vals[i + 1] == unique_vals[i] + 1 and unique_vals[i + 2] == unique_vals[i] + 2:
			var seq_vals: Dictionary = {}
			seq_vals[unique_vals[i]] = true
			seq_vals[unique_vals[i + 1]] = true
			seq_vals[unique_vals[i + 2]] = true
			var j := i + 3
			while j < unique_vals.size() and unique_vals[j] == unique_vals[j - 1] + 1:
				seq_vals[unique_vals[j]] = true
				j += 1
			for d in available:
				if seq_vals.has(d.value):
					result[d.id] = true
	
	# 同元素检测
	var elem_counts: Dictionary = {}
	for d in available:
		var elem: String = d.get("collapsedElement", d.get("element", "normal"))
		if elem != "normal":
			if not elem_counts.has(elem):
				elem_counts[elem] = []
			elem_counts[elem].append(d.id)
	for ids in elem_counts.values():
		if ids.size() >= 4:
			for id in ids:
				result[id] = true
	
	return result