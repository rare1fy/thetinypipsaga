## 骰子特殊效果处理器 — 对应原版 logic/diceEffects.ts applyDiceSpecialEffects
## 职责：元素坍缩 / 小丑骰 / 棱镜双元素 / 共鸣骰
## 设计原则：
##   - 纯函数：不修改 autoload 状态，返回新骰子数组
##   - SRP：每个特殊效果独立函数
##   - 执行顺序（与原版一致）：元素坍缩 → 小丑骰 → 棱镜双元素 → 共鸣骰
class_name DiceSpecialEffects
extends RefCounted


# ============================================================
# 常量
# ============================================================

## 元素坍缩可选元素（fire/ice/thunder/poison/holy）
const ELEMENTAL_COLLAPSE_ELEMENTS: Array[String] = ["fire", "ice", "thunder", "poison", "holy"]


# ============================================================
# 主入口
# ============================================================

## 对手牌应用特殊效果（元素坍缩 + 小丑骰 + 棱镜 + 共鸣）
## 参数：
##   dice: 手牌数组 [{id, defId, value, element, ...}]
##   has_limit_breaker: 是否有突破极限遗物
##   locked_element: 法师棱镜锁定元素（空字符串表示无锁定）
## 返回：处理后的新手牌数组（不修改原数组）
static func apply(dice: Array[Dictionary], has_limit_breaker: bool, locked_element: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for d: Dictionary in dice:
		result.append(d.duplicate())

	# 1. 元素坍缩：所有 isElemental 骰子共享同一随机元素
	var has_elemental: bool = false
	for d: Dictionary in result:
		var def: DiceDef = GameData.get_dice_def(d.get("defId", ""))
		if def and def.is_elemental:
			has_elemental = true
			break

	var shared_element: String = ""
	var second_element: String = ""
	if has_elemental:
		if locked_element != "":
			shared_element = locked_element
		else:
			shared_element = ELEMENTAL_COLLAPSE_ELEMENTS[randi() % ELEMENTAL_COLLAPSE_ELEMENTS.size()]
		# 第二元素（给棱镜骰子用）
		var others: Array[String] = []
		for e: String in ELEMENTAL_COLLAPSE_ELEMENTS:
			if e != shared_element:
				others.append(e)
		second_element = others[randi() % others.size()]

	# 应用元素坍缩
	if shared_element != "":
		for i: int in result.size():
			var d: Dictionary = result[i]
			var def: DiceDef = GameData.get_dice_def(d.get("defId", ""))
			if def and def.is_elemental:
				if def.dual_element and second_element != "":
					# 棱镜骰子：双元素坍缩
					result[i]["element"] = shared_element
					result[i]["collapsedElement"] = shared_element
					result[i]["secondElement"] = second_element
				else:
					result[i]["element"] = shared_element
					result[i]["collapsedElement"] = shared_element

	# 2. 小丑骰：随机 1-9（有突破极限遗物则上限 100）
	#    边界：hand 中只有 joker → 取第一个非 joker 骰子的值（原版 fallback）
	for i: int in result.size():
		var d: Dictionary = result[i]
		if d.get("defId", "") == "joker":
			var fallback_val: int = 0
			for other: Dictionary in result:
				if other.get("defId", "") != "joker":
					fallback_val = other.get("value", 1)
					break
			if fallback_val > 0:
				result[i]["value"] = fallback_val
			else:
				var max_val: int = 100 if has_limit_breaker else 9
				result[i]["value"] = randi() % max_val + 1

	# 3. 共鸣骰子（copyMajorityElement）：复制手牌中数量最多的元素
	var resonance_indices: Array[int] = []
	for i: int in result.size():
		var def: DiceDef = GameData.get_dice_def(result[i].get("defId", ""))
		if def and def.copy_majority_element and def.is_elemental:
			resonance_indices.append(i)

	if not resonance_indices.is_empty():
		# 统计非共鸣骰的元素出现次数
		var elem_counts: Dictionary = {}
		for d: Dictionary in result:
			var ce: String = d.get("collapsedElement", "")
			if ce != "" and ce != "normal":
				var def: DiceDef = GameData.get_dice_def(d.get("defId", ""))
				if def and not def.copy_majority_element:
					elem_counts[ce] = elem_counts.get(ce, 0) + 1

		# 找出现次数最多的元素
		var majority_elem: String = ""
		var majority_count: int = 0
		for elem: String in elem_counts:
			if elem_counts[elem] > majority_count:
				majority_count = elem_counts[elem]
				majority_elem = elem

		# 应用共鸣
		if majority_elem != "":
			for idx: int in resonance_indices:
				result[idx]["element"] = majority_elem
				result[idx]["collapsedElement"] = majority_elem

	return result


## 判断是否有突破极限遗物
static func has_limit_breaker_relic(relics: Array[Dictionary]) -> bool:
	return RelicEngine.has_relic(relics, "limit_breaker")
