## 盗贼骰子配置（v2 数据驱动格式）
## 所有骰子效果用 EffectType 枚举 + params 描述
## 新增骰子只需在此文件添加条目，不需要动任何代码

class_name DiceConfigRogue
extends RefCounted

const ET := EffectTypes.EffectType
const TT := EffectTypes.TriggerType
const ES := EffectTypes.EffectScope
const SR := EffectTypes.StackingRule
const TS := EffectTypes.TargetScope


## 获取所有盗贼骰子定义
static func get_all() -> Array[Dictionary]:
	return [
		_quickdraw(),
		_combo_mastery(),
		_poison_dart(),
		_shadow_clone(),
		_venom_blade(),
		_chain_strike(),
		_phantom_die(),
		_toxin_burst(),
		_shadow_step(),
		_assassin_mark(),
		_smoke_bomb(),
		_shadow_storm(),
	]


# ============================================================
# 快攻骰子 — 连击时+20%伤害
# ============================================================
static func _quickdraw() -> Dictionary:
	return {
		"id": "r_quickdraw",
		"name": "快攻骰子",
		"element": GameTypes.DiceElement.NORMAL,
		"faces": [1, 2, 3, 4, 5, 6],
		"rarity": GameTypes.DiceRarity.UNCOMMON,
		"class_type": "rogue",
		"description": "连击时+20%伤害",
		"effects": [
			EffectTypes.create_effect(ET.BONUS_MULT,
				{"value": 0.2, "condition": "combo"},
				TT.ON_PLAY, ES.PLAY, SR.INDEPENDENT, TS.MAIN),
		],
	}


# ============================================================
# 连击心得 — 连击时获得暗影残骰
# ============================================================
static func _combo_mastery() -> Dictionary:
	return {
		"id": "r_combomastery",
		"name": "连击心得",
		"element": GameTypes.DiceElement.NORMAL,
		"faces": [1, 2, 3, 4, 5, 6],
		"rarity": GameTypes.DiceRarity.UNCOMMON,
		"class_type": "rogue",
		"description": "连击时获得暗影残骰",
		"effects": [
			EffectTypes.create_effect(ET.GRANT_TEMP_DIE,
				{"die_type": "shadow", "count": 1},
				TT.ON_COMBO, ES.INSTANT, SR.INDEPENDENT, TS.SELF),
		],
	}


# ============================================================
# 毒镖骰子 — 附加2层中毒
# ============================================================
static func _poison_dart() -> Dictionary:
	return {
		"id": "r_poisondart",
		"name": "毒镖骰子",
		"element": GameTypes.DiceElement.POISON,
		"faces": [1, 2, 3, 4, 5, 6],
		"rarity": GameTypes.DiceRarity.RARE,
		"class_type": "rogue",
		"description": "附加2层中毒",
		"effects": [
			EffectTypes.create_effect(ET.APPLY_STATUS,
				{"status": "poison", "value": 2, "target": "enemy"},
				TT.ON_PLAY, ES.INSTANT, SR.INDEPENDENT, TS.MAIN),
		],
	}


# ============================================================
# 影分身 — 出牌时复制自身一同结算(+2伤害 ×+0.5)
# ============================================================
static func _shadow_clone() -> Dictionary:
	return {
		"id": "r_shadowclone",
		"name": "影分身",
		"element": GameTypes.DiceElement.NORMAL,
		"faces": [1, 2, 3, 4, 5, 6],
		"rarity": GameTypes.DiceRarity.RARE,
		"class_type": "rogue",
		"description": "出牌时+2伤害+50%倍率，获得影分身残骰",
		"effects": [
			EffectTypes.create_effect(ET.BONUS_DAMAGE,
				{"value": 2},
				TT.ON_PLAY, ES.PLAY, SR.INDEPENDENT, TS.MAIN),
			EffectTypes.create_effect(ET.BONUS_MULT,
				{"value": 0.5},
				TT.ON_PLAY, ES.PLAY, SR.INDEPENDENT, TS.MAIN),
			EffectTypes.create_effect(ET.GRANT_TEMP_DIE,
				{"die_type": "shadow", "count": 1},
				TT.ON_PLAY, ES.INSTANT, SR.INDEPENDENT, TS.SELF),
		],
	}


# ============================================================
# 淬毒之刃 — 基于骰子面值施毒+目标已中毒时额外中毒
# ============================================================
static func _venom_blade() -> Dictionary:
	return {
		"id": "r_venom_blade",
		"name": "淬毒之刃",
		"element": GameTypes.DiceElement.POISON,
		"faces": [2, 3, 3, 4, 5, 6],
		"rarity": GameTypes.DiceRarity.RARE,
		"class_type": "rogue",
		"description": "施毒=骰子点数，目标已中毒时额外+2层",
		"effects": [
			EffectTypes.create_effect(ET.POISON_FROM_VALUE,
				{"bonus": 0},
				TT.ON_PLAY, ES.INSTANT, SR.INDEPENDENT, TS.MAIN),
			EffectTypes.create_effect(ET.APPLY_STATUS,
				{"status": "poison", "value": 2, "target": "enemy", "bonus_if_existing": 2},
				TT.ON_PLAY, ES.INSTANT, SR.INDEPENDENT, TS.MAIN),
		],
	}


# ============================================================
# 连环打击 — 连击缩放伤害+连击时额外出牌
# ============================================================
static func _chain_strike() -> Dictionary:
	return {
		"id": "r_chain_strike",
		"name": "连环打击",
		"element": GameTypes.DiceElement.NORMAL,
		"faces": [1, 2, 3, 4, 5, 6],
		"rarity": GameTypes.DiceRarity.EPIC,
		"class_type": "rogue",
		"description": "连击时+3伤害/次，第3次出牌额外+1出牌",
		"effects": [
			EffectTypes.create_effect(ET.BONUS_DAMAGE_SCALED,
				{"source": "combo", "ratio": 3.0},
				TT.ON_PLAY, ES.PLAY, SR.INDEPENDENT, TS.MAIN),
			EffectTypes.create_effect(ET.GRANT_PLAY,
				{"count": 1, "condition": "third_play"},
				TT.ON_PLAY, ES.TURN, SR.ONCE_PER_SCOPE, TS.SELF),
		],
	}


# ============================================================
# 幻影骰子 — 手牌中影骰数量×2伤害+弹回手牌
# ============================================================
static func _phantom_die() -> Dictionary:
	return {
		"id": "r_phantom",
		"name": "幻影骰子",
		"element": GameTypes.DiceElement.NORMAL,
		"faces": [1, 2, 3, 4, 5, 6],
		"rarity": GameTypes.DiceRarity.RARE,
		"class_type": "rogue",
		"description": "手牌中影骰数量×2伤害，弹回手牌",
		"effects": [
			EffectTypes.create_effect(ET.BONUS_DAMAGE_SCALED,
				{"source": "shadow", "ratio": 2.0},
				TT.ON_PLAY, ES.PLAY, SR.INDEPENDENT, TS.MAIN),
			EffectTypes.create_effect(ET.BOUNCE,
				{"grow_per_bounce": 1, "grow_cap": 5},
				TT.ON_PLAY, ES.INSTANT, SR.INDEPENDENT, TS.SELF),
		],
	}


# ============================================================
# 毒素爆发 — 引爆目标全部中毒层数造成伤害
# ============================================================
static func _toxin_burst() -> Dictionary:
	return {
		"id": "r_toxin_burst",
		"name": "毒素爆发",
		"element": GameTypes.DiceElement.POISON,
		"faces": [1, 2, 3, 4, 5, 6],
		"rarity": GameTypes.DiceRarity.EPIC,
		"class_type": "rogue",
		"description": "引爆目标全部中毒层数，每层造成2伤害",
		"effects": [
			EffectTypes.create_effect(ET.DETONATE,
				{"status": "poison", "damage_per_stack": 2},
				TT.ON_PLAY, ES.INSTANT, SR.INDEPENDENT, TS.MAIN),
		],
	}


# ============================================================
# 暗影步 — 偷取护甲+无视嘲讽+额外出牌
# ============================================================
static func _shadow_step() -> Dictionary:
	return {
		"id": "r_shadow_step",
		"name": "暗影步",
		"element": GameTypes.DiceElement.NORMAL,
		"faces": [2, 3, 4, 4, 5, 6],
		"rarity": GameTypes.DiceRarity.EPIC,
		"class_type": "rogue",
		"description": "偷取30%护甲+无视嘲讽+额外出牌1次",
		"effects": [
			EffectTypes.create_effect(ET.STEAL_ARMOR,
				{"ratio": 0.3},
				TT.ON_PLAY, ES.INSTANT, SR.INDEPENDENT, TS.MAIN),
			EffectTypes.create_effect(ET.IGNORE_TAUNT, {},
				TT.ON_PLAY, ES.PLAY, SR.INDEPENDENT, TS.SELF),
			EffectTypes.create_effect(ET.GRANT_PLAY,
				{"count": 1},
				TT.ON_PLAY, ES.TURN, SR.INDEPENDENT, TS.SELF),
		],
	}


# ============================================================
# 刺客印记 — 第二次出牌暴击+50%，连击时中毒翻倍
# ============================================================
static func _assassin_mark() -> Dictionary:
	return {
		"id": "r_assassin_mark",
		"name": "刺客印记",
		"element": GameTypes.DiceElement.NORMAL,
		"faces": [1, 2, 3, 4, 5, 6],
		"rarity": GameTypes.DiceRarity.RARE,
		"class_type": "rogue",
		"description": "第二次出牌+50%暴击，连击时中毒翻倍",
		"effects": [
			EffectTypes.create_effect(ET.BONUS_MULT,
				{"value": 0.5, "condition": "combo"},
				TT.ON_PLAY, ES.PLAY, SR.INDEPENDENT, TS.MAIN),
			EffectTypes.create_effect(ET.DOUBLE_STATUS_ON_COMBO,
				{"status": "poison"},
				TT.ON_COMBO, ES.INSTANT, SR.INDEPENDENT, TS.MAIN),
		],
	}


# ============================================================
# 烟雾弹 — 转移自身负面状态给敌人+闪避1回合
# ============================================================
static func _smoke_bomb() -> Dictionary:
	return {
		"id": "r_smoke_bomb",
		"name": "烟雾弹",
		"element": GameTypes.DiceElement.NORMAL,
		"faces": [1, 2, 3, 4, 5, 6],
		"rarity": GameTypes.DiceRarity.RARE,
		"class_type": "rogue",
		"description": "净化自身全部负面状态，每清1层+1伤害",
		"effects": [
			EffectTypes.create_effect(ET.PURIFY,
				{"scope": "all", "bonus_per_cleanse": 1},
				TT.ON_PLAY, ES.INSTANT, SR.INDEPENDENT, TS.SELF),
		],
	}


# ============================================================
# 影刃风暴 — 传说：AOE+无视嘲讽+连击递增+影骰加成
# ============================================================
static func _shadow_storm() -> Dictionary:
	return {
		"id": "r_shadow_storm",
		"name": "影刃风暴",
		"element": GameTypes.DiceElement.NORMAL,
		"faces": [2, 3, 4, 5, 5, 6],
		"rarity": GameTypes.DiceRarity.LEGENDARY,
		"class_type": "rogue",
		"description": "AOE全体+无视嘲讽+连击递增+影骰加成",
		"effects": [
			EffectTypes.create_effect(ET.AOE, {},
				TT.ON_PLAY, ES.PLAY, SR.INDEPENDENT, TS.ALL_ENEMIES),
			EffectTypes.create_effect(ET.IGNORE_TAUNT, {},
				TT.ON_PLAY, ES.TURN, SR.INDEPENDENT, TS.SELF),
			EffectTypes.create_effect(ET.ESCALATE,
				{"per_trigger": 0.15, "cap": 1.5},
				TT.ON_PLAY, ES.BATTLE, SR.STACK_LIMITED, TS.ALL_ENEMIES),
			EffectTypes.create_effect(ET.BONUS_DAMAGE_SCALED,
				{"source": "shadow", "ratio": 3.0},
				TT.ON_PLAY, ES.PLAY, SR.INDEPENDENT, TS.ALL_ENEMIES),
		],
	}
