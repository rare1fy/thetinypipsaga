## 法师骰子配置（v2 数据驱动格式）
## 所有骰子效果用 EffectType 枚举 + params 描述
## 新增骰子只需在此文件添加条目，不需要动任何代码

class_name DiceConfigMage
extends RefCounted

const ET := EffectTypes.EffectType
const TT := EffectTypes.TriggerType
const ES := EffectTypes.EffectScope
const SR := EffectTypes.StackingRule
const TS := EffectTypes.TargetScope


## 获取所有法师骰子定义
static func get_all() -> Array[Dictionary]:
	return [
		_elemental(),
		_reverse(),
		_crystal(),
		_stardust(),
		_flame_orb(),
		_frost_shard(),
		_chain_lightning(),
		_arcane_blast(),
		_prism(),
		_barrier_mage(),
		_chant_focus(),
		_elemental_storm(),
	]


# ============================================================
# 元素骰子 — 每回合随机变为火/冰/雷/毒/圣元素
# ============================================================
static func _elemental() -> Dictionary:
	return {
		"id": "mage_elemental",
		"name": "元素骰子",
		"element": GameTypes.DiceElement.NORMAL,
		"faces": [1, 2, 3, 4, 5, 6],
		"rarity": GameTypes.DiceRarity.UNCOMMON,
		"class_type": "mage",
		"is_elemental": true,
		"description": "每回合随机变为火/冰/雷/毒/圣元素",
		"effects": [
			EffectTypes.create_effect(ET.ELEMENT_TRIGGER, {},
				TT.ON_TURN_START, ES.TURN, SR.INDEPENDENT, TS.SELF),
		],
	}


# ============================================================
# 逆转骰子 — 出牌时点数翻转(7-点数)
# ============================================================
static func _reverse() -> Dictionary:
	return {
		"id": "mage_reverse",
		"name": "逆转骰子",
		"element": GameTypes.DiceElement.NORMAL,
		"faces": [1, 2, 3, 4, 5, 6],
		"rarity": GameTypes.DiceRarity.UNCOMMON,
		"class_type": "mage",
		"description": "出牌时点数翻转(7-点数)",
		"effects": [
			EffectTypes.create_effect(ET.REVERSE_VALUE, {},
				TT.ON_PLAY, ES.PLAY, SR.INDEPENDENT, TS.SELF),
		],
	}


# ============================================================
# 水晶骰子 — 保留到下回合时点数+1
# ============================================================
static func _crystal() -> Dictionary:
	return {
		"id": "mage_crystal",
		"name": "水晶骰子",
		"element": GameTypes.DiceElement.NORMAL,
		"faces": [1, 2, 3, 4, 5, 6],
		"rarity": GameTypes.DiceRarity.RARE,
		"class_type": "mage",
		"description": "保留到下回合时点数+1",
		"effects": [
			EffectTypes.create_effect(ET.BONUS_ON_KEEP,
				{"value": 1, "cap": 6},
				TT.ON_KEEP, ES.PLAY, SR.STACK_LIMITED, TS.SELF),
		],
	}


# ============================================================
# 星尘骰子 — 每保留1回合+1点(上限5)
# ============================================================
static func _stardust() -> Dictionary:
	return {
		"id": "mage_stardust",
		"name": "星尘骰子",
		"element": GameTypes.DiceElement.NORMAL,
		"faces": [1, 2, 3, 4, 5, 6],
		"rarity": GameTypes.DiceRarity.RARE,
		"class_type": "mage",
		"description": "每保留1回合+1点(上限5)，出牌时释放全部蓄力",
		"effects": [
			EffectTypes.create_effect(ET.BONUS_ON_KEEP,
				{"value": 1, "cap": 5},
				TT.ON_KEEP, ES.PLAY, SR.STACK_LIMITED, TS.SELF),
			EffectTypes.create_effect(ET.BONUS_DAMAGE_SCALED,
				{"source": "points", "ratio": 0.3},
				TT.ON_PLAY, ES.PLAY, SR.INDEPENDENT, TS.MAIN),
		],
	}


# ============================================================
# 烈焰球 — 造成灼烧+灼烧回响(目标已灼烧时额外伤害)
# ============================================================
static func _flame_orb() -> Dictionary:
	return {
		"id": "mage_flame_orb",
		"name": "烈焰球",
		"element": GameTypes.DiceElement.FIRE,
		"faces": [2, 3, 3, 4, 5, 6],
		"rarity": GameTypes.DiceRarity.RARE,
		"class_type": "mage",
		"description": "施加3层灼烧，目标已灼烧时+5伤害",
		"effects": [
			EffectTypes.create_effect(ET.APPLY_STATUS,
				{"status": "burn", "value": 3, "target": "enemy"},
				TT.ON_PLAY, ES.INSTANT, SR.INDEPENDENT, TS.MAIN),
			EffectTypes.create_effect(ET.BURN_ECHO, {},
				TT.ON_PLAY, ES.PLAY, SR.INDEPENDENT, TS.MAIN),
		],
	}


# ============================================================
# 冰霜碎片 — 施加冰冻+冰冻加成(目标已冰冻时额外伤害)
# ============================================================
static func _frost_shard() -> Dictionary:
	return {
		"id": "mage_frost_shard",
		"name": "冰霜碎片",
		"element": GameTypes.DiceElement.ICE,
		"faces": [1, 2, 3, 4, 5, 6],
		"rarity": GameTypes.DiceRarity.RARE,
		"class_type": "mage",
		"description": "施加2层冰冻，目标已冰冻时+8伤害",
		"effects": [
			EffectTypes.create_effect(ET.APPLY_STATUS,
				{"status": "freeze", "value": 2, "target": "enemy"},
				TT.ON_PLAY, ES.INSTANT, SR.INDEPENDENT, TS.MAIN),
			EffectTypes.create_effect(ET.BONUS_DAMAGE,
				{"value": 8, "condition": "freeze"},
				TT.ON_PLAY, ES.PLAY, SR.INDEPENDENT, TS.MAIN),
		],
	}


# ============================================================
# 连锁闪电 — 弹射3次，每次衰减
# ============================================================
static func _chain_lightning() -> Dictionary:
	return {
		"id": "mage_chain_lightning",
		"name": "连锁闪电",
		"element": GameTypes.DiceElement.LIGHTNING,
		"faces": [2, 3, 4, 4, 5, 6],
		"rarity": GameTypes.DiceRarity.EPIC,
		"class_type": "mage",
		"description": "弹射3次，每次伤害衰减30%",
		"effects": [
			EffectTypes.create_effect(ET.CHAIN_BOLT,
				{"bounce": 3},
				TT.ON_PLAY, ES.PLAY, SR.INDEPENDENT, TS.MAIN),
		],
	}


# ============================================================
# 奥术爆破 — 多元素爆破(同时施加灼烧+中毒+冰冻)
# ============================================================
static func _arcane_blast() -> Dictionary:
	return {
		"id": "mage_arcane_blast",
		"name": "奥术爆破",
		"element": GameTypes.DiceElement.NORMAL,
		"faces": [1, 2, 3, 4, 5, 6],
		"rarity": GameTypes.DiceRarity.EPIC,
		"class_type": "mage",
		"description": "同时施加灼烧+中毒+冰冻各2层",
		"effects": [
			EffectTypes.create_effect(ET.APPLY_STATUS,
				{"status": "burn", "value": 2, "target": "enemy"},
				TT.ON_PLAY, ES.INSTANT, SR.INDEPENDENT, TS.MAIN),
			EffectTypes.create_effect(ET.APPLY_STATUS,
				{"status": "poison", "value": 2, "target": "enemy"},
				TT.ON_PLAY, ES.INSTANT, SR.INDEPENDENT, TS.MAIN),
			EffectTypes.create_effect(ET.APPLY_STATUS,
				{"status": "freeze", "value": 2, "target": "enemy"},
				TT.ON_PLAY, ES.INSTANT, SR.INDEPENDENT, TS.MAIN),
		],
	}


# ============================================================
# 棱镜骰子 — 手牌每种不同元素+10%伤害
# ============================================================
static func _prism() -> Dictionary:
	return {
		"id": "mage_prism",
		"name": "棱镜骰子",
		"element": GameTypes.DiceElement.NORMAL,
		"faces": [1, 2, 3, 4, 5, 6],
		"rarity": GameTypes.DiceRarity.RARE,
		"class_type": "mage",
		"description": "手牌每种不同元素+10%伤害",
		"effects": [
			EffectTypes.create_effect(ET.BONUS_MULT,
				{"value": 0.1, "condition": "per_element"},
				TT.ON_PLAY, ES.PLAY, SR.INDEPENDENT, TS.MAIN),
		],
	}


# ============================================================
# 法师护盾 — 基于手牌数获得护甲+伤害护盾
# ============================================================
static func _barrier_mage() -> Dictionary:
	return {
		"id": "mage_barrier",
		"name": "法师护盾",
		"element": GameTypes.DiceElement.NORMAL,
		"faces": [1, 2, 3, 4, 5, 6],
		"rarity": GameTypes.DiceRarity.UNCOMMON,
		"class_type": "mage",
		"description": "获得护甲=手牌数×2，受伤时反弹3伤害",
		"effects": [
			EffectTypes.create_effect(ET.ARMOR,
				{"value": 0, "source": "hand_size", "ratio": 2.0},
				TT.ON_PLAY, ES.PLAY, SR.INDEPENDENT, TS.SELF),
			EffectTypes.create_effect(ET.DAMAGE_SHIELD,
				{"value": 3},
				TT.ON_PLAY, ES.TURN, SR.UNIQUE_OVERRIDE, TS.SELF),
		],
	}


# ============================================================
# 吟唱聚焦 — 蓄力3回合后释放，超出层数每层+15%倍率
# ============================================================
static func _chant_focus() -> Dictionary:
	return {
		"id": "mage_chant_focus",
		"name": "吟唱聚焦",
		"element": GameTypes.DiceElement.NORMAL,
		"faces": [2, 3, 4, 5, 5, 6],
		"rarity": GameTypes.DiceRarity.EPIC,
		"class_type": "mage",
		"description": "蓄力3回合后释放，超出每层+15%倍率",
		"effects": [
			EffectTypes.create_effect(ET.CHARGE,
				{"turns": 3, "bonus_per_extra": 0.15},
				TT.ON_KEEP, ES.BATTLE, SR.STACK_UNLIMITED, TS.SELF),
			EffectTypes.create_effect(ET.BONUS_MULT,
				{"value": 1.0},
				TT.ON_PLAY, ES.PLAY, SR.INDEPENDENT, TS.MAIN),
			EffectTypes.create_effect(ET.BONUS_MULT_ON_KEEP,
				{"value": 0.15},
				TT.ON_KEEP, ES.PLAY, SR.STACK_UNLIMITED, TS.SELF),
		],
	}


# ============================================================
# 元素风暴 — 统一元素+全体AOE+每种元素额外伤害
# ============================================================
static func _elemental_storm() -> Dictionary:
	return {
		"id": "mage_elemental_storm",
		"name": "元素风暴",
		"element": GameTypes.DiceElement.NORMAL,
		"faces": [1, 2, 3, 4, 5, 6],
		"rarity": GameTypes.DiceRarity.LEGENDARY,
		"class_type": "mage",
		"description": "统一元素+AOE全体+每种元素+5伤害",
		"effects": [
			EffectTypes.create_effect(ET.UNIFY_ELEMENT, {},
				TT.ON_PLAY, ES.PLAY, SR.INDEPENDENT, TS.SELF),
			EffectTypes.create_effect(ET.AOE, {},
				TT.ON_PLAY, ES.PLAY, SR.INDEPENDENT, TS.ALL_ENEMIES),
			EffectTypes.create_effect(ET.BONUS_DAMAGE,
				{"value": 5, "condition": "per_element"},
				TT.ON_PLAY, ES.PLAY, SR.INDEPENDENT, TS.ALL_ENEMIES),
		],
	}
