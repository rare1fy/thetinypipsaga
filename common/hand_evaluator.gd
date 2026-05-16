## 牌型判定器 — 对应原版 utils/handEvaluator.ts
## 纯函数，无状态依赖

class_name HandEvaluator

# 牌型优先级（从高到低）
const HAND_PRIORITY: Array[String] = [
	"六条", "五条", "大葫芦", "四条", "葫芦",
	"6顺", "5顺", "4顺", "顺子", "三条", "三连对", "连对",
	"对子", "普通攻击"
]

# v0.5 牌型倍率表（纯倍率，废除旧 base 加法项）
# 多牌型同时生效时：handMultiplier = 1 + Σ(mult - 1)，相加不连乘
const HAND_MULT: Dictionary = {
	"普通攻击": {"mult": 1.0},
	"对子": {"mult": 1.8},
	"连对": {"mult": 2.4},
	"三连对": {"mult": 3.4},
	"三条": {"mult": 2.8},
	"顺子": {"mult": 1.5},
	"4顺": {"mult": 2.0},
	"5顺": {"mult": 2.6},
	"6顺": {"mult": 3.5},
	"葫芦": {"mult": 3.8},
	"大葫芦": {"mult": 5.8},  # v0.5 新增：3+3 或 4+2（6颗）
	"四条": {"mult": 4.5},
	"五条": {"mult": 6.5},
	"六条": {"mult": 10.0},
}


## 检测选中骰子的牌型
static func check_hands(dice: Array[Dictionary], straight_upgrade: int = 0) -> Dictionary:
	if dice.is_empty():
		return {"bestHand": "普通攻击", "allHands": [], "activeHands": ["普通攻击"]}
	
	# 过滤掉 ignoreForHandType 的骰子
	var hand_dice: Array[Dictionary] = []
	hand_dice.assign(dice.filter(func(d): return not _has_ignore_for_hand_type(d)))
	var source_dice: Array[Dictionary] = hand_dice if hand_dice.size() > 0 else dice
	var values: Array[int] = []
	values.assign(source_dice.map(func(d): return d.value))
	values.sort()
	var elements: Array[String] = []
	elements.assign(source_dice.map(func(d): return d.get("collapsedElement", "") if d.get("collapsedElement", "") else d.get("element", "normal")))
	var unique_elements: Dictionary = {}
	for e in elements:
		unique_elements[e] = true
	
	var valid_dice_count: int = hand_dice.size() if hand_dice.size() > 0 else dice.size()
	
	# 计数
	var counts: Dictionary = {}
	for v in values:
		counts[v] = counts.get(v, 0) + 1
	var sorted_counts: Array[int] = []
	sorted_counts.assign(counts.values())
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
	# N条：支持 N 颗精确匹配 + 超出颗数的 N+X 模式（如 6颗中 5+1 仍为五条）
	if max_count == 6: hands["六条"] = true
	if max_count == 5 and valid_dice_count >= 5: hands["五条"] = true
	if max_count == 4 and valid_dice_count >= 4: hands["四条"] = true
	if max_count == 3 and valid_dice_count >= 3: hands["三条"] = true
	if max_count == 2 and valid_dice_count >= 2: hands["对子"] = true
	
	# 葫芦 (3+2) / 大葫芦 (4+2 或 3+3，6颗)
	# v0.5 规则：4+2 优先识别为大葫芦（×5.8），不走四条（×4.5）
	if is_full_house and valid_dice_count == 5: hands["葫芦"] = true
	# 大葫芦：4+2 模式（6颗）
	if max_count >= 4 and sorted_counts.size() >= 2 and sorted_counts[1] >= 2 and valid_dice_count == 6: hands["大葫芦"] = true
	# 大葫芦：3+3 模式（6颗）
	if max_count >= 3 and sorted_counts.size() >= 2 and sorted_counts[1] >= 3 and valid_dice_count == 6: hands["大葫芦"] = true
	
	# 连对 / 三连对
	if is_two_pair and valid_dice_count == 4: hands["连对"] = true
	if is_three_pair and valid_dice_count == 6: hands["三连对"] = true
	
	# === 顺子牌型 ===
	if is_straight:
		if straight_len == 6: hands["6顺"] = true
		elif straight_len == 5: hands["5顺"] = true
		elif straight_len == 4: hands["4顺"] = true
		elif straight_len >= 3: hands["顺子"] = true
	
	# 普通攻击兜底
	if hands.is_empty():
		if valid_dice_count == 1:
			hands["普通攻击"] = true
		else:
			return {"bestHand": "普通攻击", "allHands": ["普通攻击"], "activeHands": ["普通攻击"]}
	
	var all_hands: Array[String] = []
	all_hands.assign(hands.keys())
	
	# 确定生效牌型
	var active_hands: Array[String] = []
	var has_base_hand: bool = false
	
	# === N条 / 大葫芦 / 葫芦 / 连对 / 对子 互斥，取最高 ===
	# v0.5 规则：大葫芦（×5.8）> 五条（×6.5）> 四条（×4.5）> 葫芦（×3.8）
	# 但六条（×10.0）> 大葫芦
	if hands.has("六条"): active_hands.append("六条"); has_base_hand = true
	elif hands.has("五条"): active_hands.append("五条"); has_base_hand = true
	elif hands.has("大葫芦"): active_hands.append("大葫芦"); has_base_hand = true
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
	
	# 普通攻击兜底
	if not has_base_hand and valid_dice_count == 1:
		active_hands.append("普通攻击")
	
	# 按优先级排序
	active_hands.sort_custom(func(a, b): return HAND_PRIORITY.find(a) < HAND_PRIORITY.find(b))
	
	var best_hand := " + ".join(active_hands)
	
	return {"bestHand": best_hand, "allHands": all_hands, "activeHands": active_hands}


## 获取牌型倍率（可选参数 upgrades 叠加升级加成）
## upgrades 格式：{牌型名: 升级层数}，每级 +0.3 倍率（v0.5 规范 §1.4.3）
static func get_hand_mult(hand_name: String, upgrades: Dictionary = {}) -> Dictionary:
	var base_mult: Dictionary = HAND_MULT.get(hand_name, {"mult": 1.0})
	var upgrade_level: int = int(upgrades.get(hand_name, 0))
	if upgrade_level <= 0:
		return base_mult
	return {
		"mult": float(base_mult.mult) + 0.3 * upgrade_level,
	}


## 计算 baseDamage（v0.5 公式第 1-2 步）
## step1: rawBase = Σ 骰子点数（amplify 骰子按 selfMultBeforeSum 放大后计入）+ onPlay.baseDamage
## step2: afterHand = ceil(rawBase × handMultiplier)
## 多牌型同时生效时：handMultiplier = 1 + Σ(mult - 1)，相加不连乘
static func calculate_base_damage(
	dice: Array[Dictionary],
	hand_result: Dictionary,
	upgrades: Dictionary = {}
) -> int:
	var total_points: int = _sum_dice_points(dice)
	var active_hands: Array[String] = []
	active_hands.assign(hand_result.get("activeHands", []))
	var hand_multiplier: float = _calc_hand_multiplier(active_hands, upgrades)
	return ceili(float(total_points) * hand_multiplier)


## 计算总伤害（v0.5 公式）
## 公式：(Σ点数 + baseDamage) × handMultiplier × outcome.multiplier
## outcome.multiplier = 遗物/骰子 bonusMult × 易伤系数 × 盗贼连击 等全部连乘
##
## 参数说明：
##   dice: 参与出牌的骰子数组
##   hand_result: check_hands 返回的牌型结果
##   bonus_base_damage: 骰子 onPlay.baseDamage 等额外基础伤害（进乘区）
##   outcome_multiplier: 增幅倍率（遗物/骰子 bonusMult 连乘后的总值，默认 1.0）
##   upgrades: 牌型升级等级
##   player_weak: 玩家被虚弱 → ×0.75
##   vulnerable_layers: 目标敌人易伤层数（0-5）
##   rogue_combo_bonus: 盗贼连击 ×1.2
##   precision_combo: 盗贼同牌型精准连击 ×1.25
static func calculate_damage(
	dice: Array[Dictionary],
	hand_result: Dictionary,
	bonus_base_damage: int = 0,
	outcome_multiplier: float = 1.0,
	upgrades: Dictionary = {},
	player_weak: bool = false,
	vulnerable_layers: int = 0,
	rogue_combo_bonus: bool = false,
	precision_combo: bool = false
) -> int:
	# step1: rawBase = Σ 骰子点数（含 amplify 放大）+ baseDamage
	var total_points: int = _sum_dice_points(dice) + bonus_base_damage

	# step2: afterHand = rawBase × handMultiplier
	var active_hands: Array[String] = []
	active_hands.assign(hand_result.get("activeHands", []))
	var hand_multiplier: float = _calc_hand_multiplier(active_hands, upgrades)
	var after_hand: float = float(total_points) * hand_multiplier

	# step3: totalDamage = afterHand × outcome.multiplier
	var damage: float = after_hand * outcome_multiplier

	# step4: 易伤系数（作为 outcome.multiplier 的一个因子）
	if vulnerable_layers > 0:
		damage *= GameBalance.get_vulnerable_mult(vulnerable_layers)

	# step5: 玩家虚弱
	if player_weak:
		damage *= GameBalance.STATUS_EFFECT_MULT.weak

	# step6: 盗贼连击 ×1.2
	if rogue_combo_bonus:
		damage *= 1.2

	# step7: 盗贼同牌型精准连击 ×1.25
	if precision_combo:
		damage *= 1.25

	return maxi(1, ceili(damage))


# ============================================================
# 内部辅助函数
# ============================================================

## 计算骰子点数总和（含 amplify selfMultBeforeSum 放大）
static func _sum_dice_points(dice: Array[Dictionary]) -> int:
	var total: int = 0
	for d: Dictionary in dice:
		var value: int = int(d.get("value", 0))
		var def_id: String = d.get("defId", "")
		# amplify 机制：仅放大自身点数 ×1.2 向上取整
		if def_id == "amplify":
			value = ceili(float(value) * GameBalance.AMPLIFY_SELF_MULT)
		total += value
	return total


## 计算 handMultiplier：多牌型同时生效时 = 1 + Σ(mult - 1)
static func _calc_hand_multiplier(active_hands: Array[String], upgrades: Dictionary = {}) -> float:
	if active_hands.is_empty():
		return 1.0
	var total_bonus: float = 0.0
	for h: String in active_hands:
		var hm: Dictionary = get_hand_mult(h, upgrades)
		total_bonus += float(hm.mult) - 1.0
	return 1.0 + total_bonus


static func _has_ignore_for_hand_type(d: Dictionary) -> bool:
	var def: DiceDef = GameData.get_dice_def(d.get("defId", "standard"))
	return def.get("ignore_for_hand_type") == true if def else false


## 查找可组成牌型的候选骰子
static func find_hand_candidates(all_dice: Array[Dictionary], selected_id: int = -1) -> Dictionary:
	var available: Array[Dictionary] = []
	available.assign(all_dice.filter(func(d): return not d.get("rolling", false)))
	var result: Dictionary = {}  # 模拟 Set，key=id
	
	if available.size() < 2:
		return result
	
	if selected_id >= 0:
		# 模式B：找能和 selected_id 组成牌型的骰子
		var anchor: Array[Dictionary] = []
		anchor.assign(available.filter(func(d): return d.id == selected_id))
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
	
	return result
