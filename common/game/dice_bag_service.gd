## 骰子库服务 — 纯函数集合
## 负责：洗牌、抽骰、掷骰、弃骰
## 契约：只依赖入参和 GameData 查表，不读写 GameManager 成员。
## 副作用（toast 等）由 GameManager wrapper 负责，本模块不 emit 任何信号。
## 调用方应通过 GameManager thin wrapper 使用，不要直接调本模块以免遗漏副作用。

class_name DiceBagService
extends RefCounted


## Fisher-Yates 洗牌（返回新数组，不改入参）
static func shuffle(arr: Array[String]) -> Array[String]:
	var result: Array[String] = arr.duplicate()
	for i in range(result.size() - 1, 0, -1):
		var j: int = randi() % (i + 1)
		var tmp: String = result[i]
		result[i] = result[j]
		result[j] = tmp
	return result


## 掷骰（读 DiceDef.faces 随机取一）
static func roll_dice_def(def: DiceDef) -> int:
	if def == null or def.faces.is_empty():
		return 1
	return def.faces[randi() % def.faces.size()]


## 重掷单个手牌骰（按 defId 查表后取面）
static func reroll_die(die: Dictionary) -> int:
	var def: DiceDef = GameData.get_dice_def(die.defId)
	return roll_dice_def(def)


## 从骰子库抽取 count 个骰子
## 返回：{drawn: Array[Dictionary], shuffled: bool, bag: Array[String], discard: Array[String]}
## 注意：bag/discard 为抽后的新状态，调用方写回 GameManager 成员
static func draw_from_bag(
	bag_in: Array[String],
	discard_in: Array[String],
	count: int
) -> Dictionary:
	var bag: Array[String] = bag_in.duplicate()
	var discard: Array[String] = discard_in.duplicate()
	var shuffled := false

	if bag.size() < count:
		bag.append_array(shuffle(discard))
		discard = []
		shuffled = true

	var drawn_ids: Array[String] = []
	drawn_ids.assign(bag.slice(0, count))
	var remaining: Array[String] = []
	remaining.assign(bag.slice(count))
	bag = remaining

	var drawn: Array[Dictionary] = []
	for def_id in drawn_ids:
		var def: DiceDef = GameData.get_dice_def(def_id)
		var value: int = roll_dice_def(def)
		drawn.append({
			"id": randi(), "defId": def_id, "value": value,
			"element": GameTypes.DiceElement.keys()[def.element].to_lower(),
				"selected": false, "rolling": false,
			"kept": false, "isShadowRemnant": false, "isTemp": false,
			"shadowRemnantPersistent": false, "keptBonusAccum": 0,
		})

	return {
		"drawn": drawn,
		"shuffled": shuffled,
		"bag": bag,
		"discard": discard,
	}


## 用 owned_dice 初始化骰子库（返回洗好的 ids）
static func init_bag_from_owned(owned_dice: Array[Dictionary]) -> Array[String]:
	var ids: Array[String] = []
	for d in owned_dice:
		ids.append(d.defId)
	return shuffle(ids)
