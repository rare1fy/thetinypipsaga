## 通用骰子配置（v2 数据驱动格式）
## 不属于任何职业的基础骰子、诅咒骰子、临时骰子

class_name DiceConfigCommon
extends RefCounted

const ET := EffectTypes.EffectType
const TT := EffectTypes.TriggerType
const ES := EffectTypes.EffectScope
const SR := EffectTypes.StackingRule
const TS := EffectTypes.TargetScope


## 获取所有通用骰子定义
static func get_all() -> Array[Dictionary]:
	return [
		_standard(),
		_blade(),
		_amplify(),
		_split(),
		_magnet(),
		_joker(),
		_chaos(),
		_heavy(),
		_cursed(),
		_cracked(),
		_temp_rogue(),
	]


# ============================================================
# 普通骰子 — 标准六面骰
# ============================================================
static func _standard() -> Dictionary:
	return {
		"id": "standard",
		"name": "普通骰子",
		"element": GameTypes.DiceElement.NORMAL,
		"faces": [1, 2, 3, 4, 5, 6],
		"rarity": GameTypes.DiceRarity.COMMON,
		"class_type": "",
		"description": "标准六面骰",
		"effects": [],
	}


# ============================================================
# 锋刃骰子 — 出牌时追加5点固定伤害
# ============================================================
static func _blade() -> Dictionary:
	return {
		"id": "blade",
		"name": "锋刃骰子",
		"element": GameTypes.DiceElement.NORMAL,
		"faces": [1, 2, 3, 4, 5, 6],
		"rarity": GameTypes.DiceRarity.RARE,
		"class_type": "",
		"description": "出牌时追加5点固定伤害",
		"effects": [
			EffectTypes.create_effect(ET.BONUS_DAMAGE,
				{"value": 5},
				TT.ON_PLAY, ES.PLAY, SR.INDEPENDENT, TS.MAIN),
		],
	}


# ============================================================
# 倍增骰子 — 出牌时最终伤害提升20%
# ============================================================
static func _amplify() -> Dictionary:
	return {
		"id": "amplify",
		"name": "倍增骰子",
		"element": GameTypes.DiceElement.NORMAL,
		"faces": [1, 2, 3, 4, 5, 6],
		"rarity": GameTypes.DiceRarity.RARE,
		"class_type": "",
		"description": "出牌时最终伤害提升20%",
		"effects": [
			EffectTypes.create_effect(ET.BONUS_MULT,
				{"value": 0.2},
				TT.ON_PLAY, ES.PLAY, SR.INDEPENDENT, TS.MAIN),
		],
	}


# ============================================================
# 分裂骰子 — 出牌时分裂出1颗相同点数的临时骰子
# ============================================================
static func _split() -> Dictionary:
	return {
		"id": "split",
		"name": "分裂骰子",
		"element": GameTypes.DiceElement.NORMAL,
		"faces": [1, 2, 3, 4, 5, 6],
		"rarity": GameTypes.DiceRarity.RARE,
		"class_type": "",
		"description": "出牌时分裂出1颗相同点数的临时骰子",
		"effects": [
			EffectTypes.create_effect(ET.GRANT_TEMP_DIE,
				{"die_type": "copy", "count": 1},
				TT.ON_PLAY, ES.INSTANT, SR.INDEPENDENT, TS.SELF),
		],
	}


# ============================================================
# 磁吸骰子 — 出牌时随机将1颗同伴骰子点数变为与本骰子相同
# ============================================================
static func _magnet() -> Dictionary:
	return {
		"id": "magnet",
		"name": "磁吸骰子",
		"element": GameTypes.DiceElement.NORMAL,
		"faces": [1, 2, 3, 4, 5, 6],
		"rarity": GameTypes.DiceRarity.RARE,
		"class_type": "",
		"description": "出牌时随机将1颗同伴骰子点数变为与本骰子相同",
		"effects": [
			EffectTypes.create_effect(ET.COPY_VALUE,
				{"source": "self_to_random"},
				TT.ON_PLAY, ES.INSTANT, SR.INDEPENDENT, TS.SELF),
		],
	}


# ============================================================
# 小丑骰子 — 点数1到9随机
# ============================================================
static func _joker() -> Dictionary:
	return {
		"id": "joker",
		"name": "小丑骰子",
		"element": GameTypes.DiceElement.NORMAL,
		"faces": [1, 2, 3, 4, 5, 6, 7, 8, 9],
		"rarity": GameTypes.DiceRarity.RARE,
		"class_type": "",
		"description": "点数1到9随机，突破六面骰限制",
		"effects": [],
	}


# ============================================================
# 混沌骰子 — 只会掷出1或6
# ============================================================
static func _chaos() -> Dictionary:
	return {
		"id": "chaos",
		"name": "混沌骰子",
		"element": GameTypes.DiceElement.NORMAL,
		"faces": [1, 1, 1, 6, 6, 6],
		"rarity": GameTypes.DiceRarity.LEGENDARY,
		"class_type": "",
		"description": "只会掷出1或6",
		"effects": [],
	}


# ============================================================
# 灌铅骰子 — 只会掷出4/5/6
# ============================================================
static func _heavy() -> Dictionary:
	return {
		"id": "heavy",
		"name": "灌铅骰子",
		"element": GameTypes.DiceElement.NORMAL,
		"faces": [4, 4, 5, 5, 6, 6],
		"rarity": GameTypes.DiceRarity.UNCOMMON,
		"class_type": "",
		"description": "只会掷出4/5/6",
		"effects": [],
	}


# ============================================================
# 诅咒骰子 — 点数固定0
# ============================================================
static func _cursed() -> Dictionary:
	return {
		"id": "cursed",
		"name": "诅咒骰子",
		"element": GameTypes.DiceElement.NORMAL,
		"faces": [0, 0, 0, 0, 0, 0],
		"rarity": GameTypes.DiceRarity.CURSE,
		"class_type": "",
		"is_cursed": true,
		"description": "点数固定0",
		"effects": [],
	}


# ============================================================
# 碎裂骰子 — 出牌后受2点反噬
# ============================================================
static func _cracked() -> Dictionary:
	return {
		"id": "cracked",
		"name": "碎裂骰子",
		"element": GameTypes.DiceElement.NORMAL,
		"faces": [1, 1, 1, 2, 2, 2],
		"rarity": GameTypes.DiceRarity.CURSE,
		"class_type": "",
		"is_cracked": true,
		"description": "出牌后受2点反噬",
		"effects": [
			EffectTypes.create_effect(ET.SELF_DAMAGE,
				{"value": 2},
				TT.ON_PLAY, ES.INSTANT, SR.INDEPENDENT, TS.SELF),
		],
	}


# ============================================================
# 暗影残骰 — 连击奖励临时骰子
# ============================================================
static func _temp_rogue() -> Dictionary:
	return {
		"id": "temp_rogue",
		"name": "暗影残骰",
		"element": GameTypes.DiceElement.NORMAL,
		"faces": [1, 1, 2, 2, 3, 3],
		"rarity": GameTypes.DiceRarity.COMMON,
		"class_type": "",
		"description": "连击奖励临时骰子",
		"effects": [],
	}
